import 'package:uuid/uuid.dart';

import '../models/agenda_models.dart';
import '../models/finance_models.dart';

/// Jeu de données initial, identique à celui de la version web :
/// deux comptes, douze catégories financières, huit catégories d'agenda.
class SeedData {
  const SeedData._();

  static const Uuid _uuid = Uuid();

  static List<Account> accounts() {
    final DateTime now = DateTime.now().toUtc();
    return <Account>[
      Account(
        id: _uuid.v4(),
        name: 'Compte courant',
        updatedAt: now,
      ),
      Account(
        id: _uuid.v4(),
        name: 'Investissements',
        isInvestment: true,
        updatedAt: now,
      ),
    ];
  }

  static List<Category> categories() {
    final DateTime now = DateTime.now().toUtc();
    const List<(String, TxnType, int)> defs = <(String, TxnType, int)>[
      ('Maison', TxnType.expense, 0xFF6366F1),
      ('Restaurant', TxnType.expense, 0xFFF59E0B),
      ('Épicerie', TxnType.expense, 0xFF10B981),
      ('Transport', TxnType.expense, 0xFF0EA5E9),
      ('Essence', TxnType.expense, 0xFFEF4444),
      ('Loisirs', TxnType.expense, 0xFFA855F7),
      ('Santé', TxnType.expense, 0xFFEC4899),
      ('Études', TxnType.expense, 0xFF14B8A6),
      ('Vêtements', TxnType.expense, 0xFFF97316),
      ('Salaire', TxnType.income, 0xFF22C55E),
      ('Investissement', TxnType.income, 0xFF3B82F6),
      ('Autres', TxnType.expense, 0xFF94A3B8),
    ];
    return defs
        .map(((String, TxnType, int) d) => Category(
              id: _uuid.v4(),
              name: d.$1,
              type: d.$2,
              color: d.$3,
              isSystem: true,
              updatedAt: now,
            ))
        .toList();
  }

  static List<AgendaCategory> agendaCategories() {
    final DateTime now = DateTime.now().toUtc();
    const List<(String, String, int)> defs = <(String, String, int)>[
      ('Personnel', '📅', 0xFF6366F1),
      ('Travail', '💼', 0xFF0EA5E9),
      ('Études', '🎓', 0xFF14B8A6),
      ('Sport', '🏈', 0xFFF59E0B),
      ('Finance', '💰', 0xFF10B981),
      ('Maison', '🏠', 0xFFA855F7),
      ('Transport', '🚗', 0xFFEF4444),
      ('Objectifs', '🎯', 0xFFEC4899),
    ];
    return defs
        .map(((String, String, int) d) => AgendaCategory(
              id: _uuid.v4(),
              name: d.$1,
              icon: d.$2,
              color: d.$3,
              updatedAt: now,
            ))
        .toList();
  }
}
