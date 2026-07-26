# Configuration de la synchronisation (Supabase)

À faire **une seule fois**, par une seule personne. Compte l'opération en
15 minutes. Le forfait gratuit de Supabase suffit largement.

---

## 1. Créer le projet

1. Va sur <https://supabase.com> → **Start your project** → connexion GitHub.
2. **New project** :
   - *Name* : `budget-app`
   - *Database password* : garde-le dans un gestionnaire de mots de passe
   - *Region* : `Canada (Central)` ou `East US`
3. Attends environ deux minutes que le projet démarre.

---

## 2. Créer les tables

1. Dans le menu de gauche : **SQL Editor** → **New query**.
2. Ouvre le fichier [`supabase/schema.sql`](../supabase/schema.sql) du dépôt,
   copie **tout** son contenu, colle-le dans l'éditeur.
3. Clique sur **Run**.

Le script crée les tables (transactions, factures, budgets, agenda…) et active
la sécurité *Row Level Security* : chaque utilisateur ne peut lire et écrire
que ses propres lignes, même si quelqu'un récupère la clé publique de
l'application.

Le script est rejouable sans risque : il ne détruit aucune donnée existante.

---

## 3. Régler l'authentification

**Authentication → Providers → Email** :

- *Enable Email provider* : activé
- *Confirm email* : **désactivé** si tu veux pouvoir te connecter tout de suite
  sans passer par un courriel de confirmation (usage personnel).

---

## 4. Récupérer les deux clés

**Project Settings → API** :

| Clé | Exemple |
|---|---|
| **Project URL** | `https://abcdefghijkl.supabase.co` |
| **anon public** | `eyJhbGciOiJIUzI1NiIsInR5cCI6...` |

> La clé `anon` est faite pour être distribuée dans une application : elle ne
> donne accès à rien sans connexion utilisateur, grâce aux règles RLS.
> ⚠️ Ne jamais utiliser la clé `service_role` dans l'application.

---

## 5. Donner les clés à GitHub Actions

Dans le dépôt GitHub : **Settings → Secrets and variables → Actions →
New repository secret**. Crée les deux secrets suivants :

| Nom | Valeur |
|---|---|
| `SUPABASE_URL` | l'URL du projet |
| `SUPABASE_ANON_KEY` | la clé `anon public` |

Les prochaines compilations produiront des applications capables de se
synchroniser. Les versions déjà compilées avant cette étape resteront en mode
local : il suffit de relancer la compilation (**Actions → Build Windows +
Android → Run workflow**) et de réinstaller.

---

## 6. Tester en local

```bash
flutter run -d windows \
  --dart-define=SUPABASE_URL=https://abcdefghijkl.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
```

Puis, dans l'application : **Profil → Se connecter → Créer un nouveau compte**.
Ajoute une transaction, connecte-toi avec le même compte sur l'autre appareil,
appuie sur **Synchroniser** : la transaction doit apparaître.

---

## Comment fonctionne la synchronisation

- Chaque ligne porte une date de modification (`updated_at`) et un marqueur de
  suppression (`deleted`).
- À la synchronisation, l'application **envoie** les lignes modifiées localement,
  puis **récupère** celles modifiées dans le cloud depuis la dernière fois.
- En cas de conflit sur la même ligne, la version la plus récente gagne
  (*last write wins*).
- Les suppressions sont logiques, ce qui permet à un effacement fait sur un
  appareil de se propager aux autres au lieu de « réapparaître ».
- Tout est écrit d'abord en local : l'application reste utilisable hors ligne et
  rattrape son retard à la connexion suivante.
