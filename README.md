# 💰 Budget — application de gestion financière personnelle

Application **Windows + Android** construite avec **Flutter**, à partir de la
version web initiale du projet.

| Plateforme | Fichier livré | Où le prendre |
|---|---|---|
| 💻 Windows | `BudgetSetup-1.0.0.exe` (installateur) + version portable `.zip` | Onglet **Releases** du dépôt |
| 📱 Android | `budget-android.apk` | Onglet **Releases** du dépôt |

Le même code Dart peut aussi viser macOS, Linux et iOS ; seules les cibles
Windows et Android sont compilées automatiquement pour l'instant.

Les deux applications partagent **la même base de données cloud** : une dépense
ajoutée sur Android apparaît sur Windows, et une facture cochée sur Windows est
mise à jour sur Android.

---

## Ce que fait l'application

- **Budget** — solde actuel, revenus, dépenses, argent restant, graphiques
- **Transactions** — dépenses et revenus avec montant, catégorie, date,
  description et compte
- **Factures** — récurrentes (hebdo / mensuelle / annuelle), rappels
  automatiques, création automatique de la transaction au paiement
- **Investissements** — à la fin du mois, 50 % (réglable) du solde restant part
  automatiquement vers le compte investissement ; total investi, historique,
  progression
- **Import CSV Desjardins** — lecture automatique du relevé, détection des
  doublons, catégorisation automatique, confirmation avant ajout
- **Agenda** — calendrier, événements, tâches, rappels ; les factures y
  apparaissent automatiquement
- **Notifications** — facture bientôt due, facture en retard, budget dépassé,
  solde faible, transfert d'investissement prévu
- **Sécurité** — compte utilisateur, code PIN, stockage local chiffré ;
  aucune information bancaire n'est enregistrée

---

## Documentation

| Document | Pour qui |
|---|---|
| [Guide d'installation](docs/GUIDE_INSTALLATION.md) | installer l'application sur PC et téléphone |
| [Configuration Supabase](docs/CONFIGURATION_SUPABASE.md) | activer la synchronisation entre appareils |
| [Documentation technique](docs/DOCUMENTATION.md) | comprendre le code et l'architecture |
| [Publier une mise à jour](docs/MISE_A_JOUR.md) | livrer une nouvelle version |
| [Spécifications](docs/SPECIFICATIONS.md) | le cahier des charges du projet |

---

## Développement rapide

```bash
# 1. Installer Flutter (une seule fois) : https://docs.flutter.dev/get-started/install
flutter --version        # 3.24 ou plus récent

# 2. Préparer le projet (génère android/ et windows/)
./scripts/bootstrap.sh   # Windows : .\scripts\bootstrap.ps1

# 3. Lancer
flutter run -d windows   # ou : flutter run -d <appareil android>
```

Avec la synchronisation cloud :

```bash
flutter run -d windows \
  --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
```

Sans ces deux clés, l'application démarre en mode **100 % local** : tout
fonctionne, mais les appareils ne se synchronisent pas.

---

## Structure du dépôt

```
lib/
  core/          thème, formats, utilitaires, widgets partagés
  data/
    models/      transactions, factures, budgets, agenda…
    local/       base SQLite (Android + Windows)
    remote/      authentification et synchronisation Supabase
    repository/  accès aux données et calculs dérivés
  features/      un dossier par écran (dashboard, transactions, agenda…)
  providers/     état global (Riverpod)
supabase/        schéma SQL à exécuter dans Supabase
scripts/         préparation du projet avant compilation
installer/       script Inno Setup pour l'installateur Windows
.github/         compilation automatique Windows + Android
legacy-web/      version web d'origine, conservée pour référence
```

Les dossiers `android/` et `windows/` **ne sont pas versionnés** : ils sont
regénérés par `scripts/bootstrap.sh`, ce qui évite des milliers de fichiers
générés dans le dépôt.
