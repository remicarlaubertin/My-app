# Documentation technique

## 1. Choix techniques

| Besoin | Choix | Pourquoi |
|---|---|---|
| Windows + Android, un seul code | **Flutter / Dart** | Compile en `.exe`, `.apk`, et aussi web, macOS, Linux, iOS si besoin plus tard |
| État de l'application | **Riverpod** | Un seul point d'écriture, testable, sans dépendance au `BuildContext` |
| Base locale | **SQLite** (`sqflite` + `sqflite_common_ffi`) | Même moteur sur Android et Windows, requêtes rapides, fonctionne hors ligne |
| Cloud | **Supabase** (Postgres + Auth) | Gratuit, SQL standard, sécurité par ligne (RLS), pas de serveur à maintenir |
| Graphiques | **fl_chart** | Rendu natif, léger, personnalisable |
| Notifications | `flutter_local_notifications` (Android), `local_notifier` (Windows) | Notifications système sur chaque plateforme |
| Compilation | **GitHub Actions** | Personne n'a besoin d'installer Android Studio ou Visual Studio |

---

## 2. Architecture

```
UI (features/)              écrans, formulaires, graphiques
        │  lit / appelle
        ▼
Providers (providers/)      AppNotifier : toutes les écritures passent ici
        │
        ▼
Repository (data/repository) chargement, calculs dérivés (soldes, budgets…)
        │
   ┌────┴─────┐
   ▼          ▼
SQLite      Supabase        la base locale est la source de vérité,
(local/)    (remote/)       le cloud n'est qu'une copie partagée
```

Principe directeur : **offline first**. Chaque action écrit d'abord dans SQLite,
l'interface se rafraîchit à partir du local, et la synchronisation se fait à
part. L'application ne dépend jamais du réseau pour fonctionner.

### Flux d'une écriture

1. L'écran appelle une méthode de `AppNotifier`
   (`saveTransaction`, `markBillPaid`…).
2. `BudgetRepository` écrit la ligne dans SQLite avec `dirty = 1`
   et une nouvelle date `updated_at`.
3. `reload()` relit toutes les tables et remplace l'état — l'interface se
   redessine.
4. `NotificationService.refresh()` recalcule les rappels.
5. À la prochaine synchronisation, les lignes `dirty` partent vers Supabase.

---

## 3. Modèle de données

Toutes les tables partagent trois colonnes techniques :

| Colonne | Rôle |
|---|---|
| `id` | UUID généré sur l'appareil — pas de collision entre appareils |
| `updated_at` | date UTC de dernière modification — arbitre les conflits |
| `deleted` | suppression logique — permet de propager un effacement |

Localement s'ajoute `dirty` (0/1), qui n'existe pas côté cloud : c'est la file
d'attente d'envoi.

### Tables

`accounts`, `categories`, `transactions`, `budgets`, `bills`,
`investment_transfers`, `agenda_categories`, `events`, `tasks`, `goals`,
plus les réglages (`settings` en local, `user_settings` dans le cloud).

### Règle des soldes

`Account.balance` est le **solde d'ouverture** saisi par l'utilisateur.
Le solde affiché est **recalculé** :

```
solde = ouverture
      + somme des transactions du compte (dépenses négatives)
      ± transferts d'investissement
```

Ce calcul évite toute dérive : si une transaction arrive deux fois par
synchronisation, elle est dédupliquée par son `id` et le solde reste juste —
contrairement à un solde incrémenté à chaque écriture.

---

## 4. Import CSV Desjardins

`lib/features/import_csv/desjardins_csv.dart`

Le format d'export d'AccèsD varie (séparateur, présence d'en-tête, ordre des
colonnes). Le lecteur est donc **tolérant** plutôt que rigide :

1. Détection du séparateur (`,` ou `;`).
2. Pour chaque ligne, recherche d'une cellule qui ressemble à une date
   (`aaaa-mm-jj` ou `jj/mm/aaaa`) — les lignes sans date (en-têtes, totaux)
   sont ignorées.
3. Détection du montant : dans le format classique
   `… | retrait | dépôt | solde`, la dernière valeur numérique est le solde et
   les deux colonnes précédentes donnent le sens de l'opération. En repli, une
   colonne unique est interprétée par son signe puis par la description.
4. Description : la plus longue cellule qui n'est ni un nombre, ni une date, ni
   un numéro de compte.
5. **Empreinte anti-doublon** : `SHA-1(date | montant | sens | description)`,
   stockée dans `external_key`. Une opération déjà importée est détectée même
   si le fichier est réimporté en entier.
6. **Catégorisation automatique** par mots-clés (IGA, ESSO, NETFLIX…), table
   `DesjardinsCsv.categoryRules` — facile à enrichir.

Rien n'est écrit avant confirmation : l'écran d'aperçu montre chaque ligne, sa
catégorie proposée et son statut de doublon.

---

## 5. Règle d'investissement

- Réglages : `investment_enabled` et `investment_percent` (50 % par défaut).
- À l'ouverture de l'application, `_maybeRunAutomaticTransfer()` regarde si le
  mois précédent a déjà été traité (`last_auto_transfer_month`).
- Sinon : `restant = revenus − dépenses` du mois précédent ; `percent %` de ce
  restant est enregistré comme transfert vers le compte investissement.
- Un mois donné ne peut être transféré qu'une seule fois, même si l'application
  est ouverte sur deux appareils.

---

## 6. Notifications

| Type | Android | Windows |
|---|---|---|
| Facture bientôt due | programmée à 9 h, `reminder_days` avant l'échéance | affichée à l'ouverture |
| Facture en retard | immédiate | immédiate |
| Budget dépassé / seuil atteint | immédiate | immédiate |
| Solde faible | immédiate | immédiate |
| Transfert d'investissement prévu | 2 derniers jours du mois | idem |
| Rappel d'agenda | programmé avant l'événement | affiché à l'ouverture |

Android utilise des alarmes *inexactes* (`inexactAllowWhileIdle`) : elles ne
demandent aucune permission spéciale et sont livrées à quelques minutes près,
ce qui est suffisant pour des rappels de factures.

---

## 7. Sécurité

- Le mot de passe du compte est géré par Supabase Auth ; l'application ne le
  stocke jamais.
- Le code PIN est haché (SHA-256 + sel) et conservé dans le coffre du système
  (Keystore Android / DPAPI Windows) via `flutter_secure_storage`.
- La clé Supabase embarquée est la clé **anon**, sans pouvoir en elle-même : les
  règles RLS exigent une session valide et filtrent par `user_id`.
- Aucune donnée bancaire d'authentification n'est collectée : l'application ne
  se connecte jamais à Desjardins, elle lit seulement un fichier CSV fourni par
  l'utilisateur.
- La déconnexion efface les données locales de l'appareil.

---

## 8. Tests

```bash
flutter test
```

`test/desjardins_csv_test.dart` couvre le lecteur CSV : format retrait/dépôt,
séparateur point-virgule, dates `jj/mm/aaaa`, lignes d'en-tête et détection des
doublons — c'est la partie la plus exposée aux variations de format, donc celle
qui mérite le plus d'être testée.

---

## 9. Points d'extension

- **Nouvelle catégorie automatique** : ajouter des mots-clés dans
  `DesjardinsCsv.categoryRules`.
- **Nouvel écran** : créer `lib/features/<nom>/`, puis ajouter une entrée dans
  `appSections` (`lib/features/shell/app_shell.dart`).
- **Nouvelle table synchronisée** : ajouter le modèle, la table SQLite dans
  `AppDatabase._schema`, le nom dans `Tables.synced`, et la table + les
  politiques RLS dans `supabase/schema.sql`.
- **iOS / macOS / Linux** : ajouter la plateforme dans `scripts/bootstrap.sh`
  (`--platforms=…`) et un job dans `.github/workflows/build.yml`.
- **Web** : la cible n'est pas compilée aujourd'hui. La base locale repose sur
  SQLite (`dart:io` / FFI), indisponible dans un navigateur ; il faudrait
  d'abord ajouter une implémentation de stockage web derrière `LocalStore`,
  avec des imports conditionnels. La version web d'origine reste disponible
  dans `legacy-web/`.
