import '../models/agenda_models.dart';
import '../models/finance_models.dart';

/// Jeu de données initial, identique à celui de la version web :
/// deux comptes, douze catégories financières, huit catégories d'agenda.
///
/// Les identifiants sont fixes (et non générés aléatoirement) : l'app peut
/// être réinstallée ou la base locale vidée sans que la synchronisation ne
/// recrée des catégories en double sur le cloud — un même nom retrouve
/// toujours le même identifiant.
class SeedData {
  const SeedData._();

  static List<Account> accounts() {
    final DateTime now = DateTime.now().toUtc();
    return <Account>[
      Account(
        id: 'f58b15af-3834-4dc6-889d-151e5a1c69bf',
        name: 'Compte courant',
        updatedAt: now,
      ),
      Account(
        id: '204eb4de-ee9e-4b6e-a61a-d51e28b808f6',
        name: 'Investissements',
        isInvestment: true,
        updatedAt: now,
      ),
    ];
  }

  static List<Category> categories() {
    final DateTime now = DateTime.now().toUtc();
    const List<(String, String, TxnType, int)> defs =
        <(String, String, TxnType, int)>[
      ('9eef1fc9-45a8-4746-9d47-cf5b45ef1e67', 'Maison', TxnType.expense, 0xFF6366F1),
      ('dbaa4f75-4985-44c4-b383-2a51d98edd33', 'Restaurant', TxnType.expense, 0xFFF59E0B),
      ('5416c70f-e439-4806-9652-c093138de886', 'Épicerie', TxnType.expense, 0xFF10B981),
      ('078f3af3-84f6-42c3-bfda-9f11ee49c1b8', 'Transport', TxnType.expense, 0xFF0EA5E9),
      ('478b0094-5002-4d50-a624-4dcf8ce75e69', 'Essence', TxnType.expense, 0xFFEF4444),
      ('5984b89c-419c-4a15-89ae-a6ea414e627b', 'Loisirs', TxnType.expense, 0xFFA855F7),
      ('5917625e-fa15-49a7-a213-e936872c06b5', 'Santé', TxnType.expense, 0xFFEC4899),
      ('5bb11e0f-dfbd-4bce-ab19-8d42c5ff2363', 'Études', TxnType.expense, 0xFF14B8A6),
      ('b7f83ffd-0f6d-47e3-88e1-7e571cc7b933', 'Vêtements', TxnType.expense, 0xFFF97316),
      ('a59ce2f3-5a04-48df-9ea4-76308d9baa1c', 'Salaire', TxnType.income, 0xFF22C55E),
      ('7392e8b2-47e6-4110-84c7-6454fa83a7da', 'Investissement', TxnType.income, 0xFF3B82F6),
      ('ba52ef42-c2e4-4f77-8c25-faf048c30b4e', 'Autres', TxnType.expense, 0xFF94A3B8),
    ];
    return defs
        .map(((String, String, TxnType, int) d) => Category(
              id: d.$1,
              name: d.$2,
              type: d.$3,
              color: d.$4,
              isSystem: true,
              updatedAt: now,
            ))
        .toList();
  }

  static List<AgendaCategory> agendaCategories() {
    final DateTime now = DateTime.now().toUtc();
    const List<(String, String, String, int)> defs =
        <(String, String, String, int)>[
      ('a13e6c17-5669-4202-9849-180ee4da7fa1', 'Personnel', '📅', 0xFF6366F1),
      ('039d8df5-9d5c-464c-b1e8-7bf08bc98b57', 'Travail', '💼', 0xFF0EA5E9),
      ('07a97203-dbb9-43d7-a844-da6d5abea378', 'Études', '🎓', 0xFF14B8A6),
      ('5e1f29a7-2428-4efd-98e7-64d25bf0c6df', 'Sport', '🏈', 0xFFF59E0B),
      ('d51af4db-fd9c-458e-85f4-bd2432e9cbd3', 'Finance', '💰', 0xFF10B981),
      ('d33ada24-a263-401f-96c7-05d010158d38', 'Maison', '🏠', 0xFFA855F7),
      ('c6f21841-3572-4e4a-ba3b-0d6f823719a4', 'Transport', '🚗', 0xFFEF4444),
      ('748bf898-82a1-4b27-9da3-f8708a427329', 'Objectifs', '🎯', 0xFFEC4899),
    ];
    return defs
        .map(((String, String, String, int) d) => AgendaCategory(
              id: d.$1,
              name: d.$2,
              icon: d.$3,
              color: d.$4,
              updatedAt: now,
            ))
        .toList();
  }
}
