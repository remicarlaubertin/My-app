import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../local/database.dart';
import '../local/local_store.dart';
import '../models/app_settings.dart';

/// Résultat d'une synchronisation, affiché dans l'interface.
class SyncResult {
  const SyncResult({
    required this.pushed,
    required this.pulled,
    this.error,
  });

  const SyncResult.failure(String message)
      : pushed = 0,
        pulled = 0,
        error = message;

  final int pushed;
  final int pulled;
  final String? error;

  bool get ok => error == null;
}

/// Synchronisation bidirectionnelle entre SQLite et Supabase.
///
/// Stratégie : « dernier écrivain gagne » (comparaison de `updated_at`).
/// Les suppressions sont logiques (`deleted = true`) afin de se propager.
///
/// Envoi  : toutes les lignes marquées `dirty = 1` localement.
/// Récupération : toutes les lignes du cloud modifiées depuis la dernière
/// synchronisation ; une ligne n'écrase la version locale que si elle est
/// plus récente.
class SyncService {
  const SyncService(this._store);

  final LocalStore _store;

  /// Colonnes booléennes : SQLite les stocke en 0/1, Postgres attend `bool`.
  static const Set<String> _boolColumns = <String>{
    'is_investment',
    'is_system',
    'paid',
    'done',
    'deleted',
  };

  SupabaseClient get _client => Supabase.instance.client;

  bool get available =>
      AppConfig.cloudEnabled && _client.auth.currentUser != null;

  /// Remet à zéro le curseur de synchronisation (date du dernier sync) :
  /// le prochain appel à [synchronize] re-comparera donc TOUTES les lignes
  /// du cloud, pas seulement celles modifiées depuis la dernière fois.
  /// Utile en dépannage si un appareil semble « bloqué » et ne reçoit plus
  /// les changements des autres appareils.
  Future<void> resetSyncCursor() async {
    final AppSettings current = await _store.readSettings();
    await _store.writeSettings(
      AppSettings(
        darkMode: current.darkMode,
        investmentEnabled: current.investmentEnabled,
        investmentPercent: current.investmentPercent,
        notificationsEnabled: current.notificationsEnabled,
        lowBalanceThreshold: current.lowBalanceThreshold,
        pinEnabled: current.pinEnabled,
        hideAmounts: current.hideAmounts,
        lastAutoTransferMonth: current.lastAutoTransferMonth,
        lastSyncAt: null,
      ),
    );
  }

  Future<SyncResult> synchronize() async {
    if (!AppConfig.cloudConfigured) {
      return const SyncResult.failure(
        'Synchronisation non configurée sur cette version.',
      );
    }
    if (!AppConfig.cloudInitialized) {
      return const SyncResult.failure(
        'Service de synchronisation injoignable. Réessaie plus tard.',
      );
    }
    final User? user = _client.auth.currentUser;
    if (user == null) {
      return const SyncResult.failure(
        'Connecte-toi pour synchroniser tes données.',
      );
    }

    final AppSettings settings = await _store.readSettings();
    final DateTime since =
        settings.lastSyncAt ?? DateTime.utc(2000);
    final DateTime startedAt = DateTime.now().toUtc();

    int pushed = 0;
    int pulled = 0;

    try {
      for (final String table in Tables.synced) {
        pushed += await _push(table, user.id);
        pulled += await _pull(table, since);
      }
      await _syncSettings(user.id, settings, startedAt);
      return SyncResult(pushed: pushed, pulled: pulled);
    } on PostgrestException catch (e) {
      return SyncResult.failure(
        'Erreur de synchronisation : ${e.message}',
      );
    } catch (_) {
      return const SyncResult.failure(
        'Synchronisation impossible. Vérifie ta connexion Internet.',
      );
    }
  }

  // ---------------------------------------------------------------------------

  Future<int> _push(String table, String userId) async {
    final List<Map<String, dynamic>> dirty = await _store.readDirty(table);
    if (dirty.isEmpty) return 0;

    final List<Map<String, dynamic>> payload = dirty
        .map((Map<String, dynamic> row) => _toRemote(row, userId))
        .toList();

    await _client.from(table).upsert(payload);

    await _store.clearDirty(
      table,
      dirty.map((Map<String, dynamic> r) => r['id'].toString()).toList(),
    );
    return payload.length;
  }

  Future<int> _pull(String table, DateTime since) async {
    final List<Map<String, dynamic>> remote =
        List<Map<String, dynamic>>.from(
      await _client
          .from(table)
          .select()
          .gt('updated_at', since.toIso8601String()) as List<dynamic>,
    );
    if (remote.isEmpty) return 0;

    final Map<String, String> localIndex = await _store.updatedAtIndex(table);

    final List<Map<String, dynamic>> toApply = <Map<String, dynamic>>[];
    for (final Map<String, dynamic> row in remote) {
      final String id = row['id'].toString();
      // Les deux formats de date diffèrent (« …Z » côté application,
      // « …+00:00 » côté Postgres) : on compare des DateTime, jamais du texte.
      final DateTime? remoteUpdated =
          DateTime.tryParse(row['updated_at'].toString())?.toUtc();
      final DateTime? localUpdated =
          DateTime.tryParse(localIndex[id] ?? '')?.toUtc();

      // Conflit : on garde la version la plus récente.
      if (remoteUpdated != null &&
          localUpdated != null &&
          !remoteUpdated.isAfter(localUpdated)) {
        continue;
      }
      toApply.add(_toLocal(row));
    }

    await _store.upsertMany(table, toApply, markDirty: false);
    return toApply.length;
  }

  Future<void> _syncSettings(
    String userId,
    AppSettings settings,
    DateTime startedAt,
  ) async {
    final Map<String, dynamic> payload = settings.toMap()
      ..remove('last_sync_at')
      ..['user_id'] = userId
      ..['updated_at'] = startedAt.toIso8601String();

    await _client.from('user_settings').upsert(payload);
    await _store.writeSettings(settings.copyWith(lastSyncAt: startedAt));
  }

  /// SQLite → Supabase : retire les colonnes locales, rétablit les booléens.
  Map<String, dynamic> _toRemote(Map<String, dynamic> row, String userId) {
    final Map<String, dynamic> out = <String, dynamic>{};
    row.forEach((String key, dynamic value) {
      if (key == 'dirty') return;
      out[key] = _boolColumns.contains(key) ? _asBool(value) : value;
    });
    out['user_id'] = userId;
    return out;
  }

  /// Supabase → SQLite : retire les colonnes propres au cloud.
  Map<String, dynamic> _toLocal(Map<String, dynamic> row) {
    final Map<String, dynamic> out = Map<String, dynamic>.from(row)
      ..remove('user_id')
      ..remove('created_at');
    return out;
  }

  static bool _asBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return value.toString() == 'true';
  }
}
