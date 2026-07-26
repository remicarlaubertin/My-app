# Guide d'installation

Ce guide s'adresse à l'utilisateur final. Aucune connaissance technique
n'est nécessaire.

---

## 1. Où trouver les fichiers

À chaque nouvelle version, les fichiers d'installation sont publiés dans
l'onglet **Releases** du dépôt GitHub :

> `https://github.com/remicarlaubertin/My-app/releases`

Deux fichiers y sont disponibles :

| Fichier | Pour |
|---|---|
| `BudgetSetup-1.0.0.exe` | Windows |
| `budget-android.apk` | Android |

> **Astuce** : les versions intermédiaires (avant publication officielle) se
> trouvent dans l'onglet **Actions** → dernière exécution → section
> **Artifacts**.

---

## 2. Installer sur Windows

1. Télécharge **`BudgetSetup-1.0.0.exe`**.
2. Double-clique dessus.
3. Windows peut afficher un avertissement bleu « Windows a protégé votre
   ordinateur » — c'est normal pour une application qui n'est pas signée par un
   certificat commercial. Clique sur **Informations complémentaires** puis
   **Exécuter quand même**.
4. Suis l'assistant. Coche **Créer une icône sur le Bureau**.
5. L'application est ensuite accessible :
   - par l'icône sur le Bureau,
   - dans le **menu Démarrer** sous « Budget ».

**Version portable** : si tu préfères ne rien installer, télécharge
`budget-windows-portable.zip`, décompresse-le où tu veux et lance
`budget_app.exe`.

### Raccourcis clavier (Windows)

| Raccourci | Action |
|---|---|
| `Ctrl + N` | Nouvelle transaction |
| `Ctrl + I` | Importer un fichier CSV Desjardins |
| `Ctrl + S` | Synchroniser maintenant |
| `Ctrl + 1…6` | Naviguer entre les sections |

Tu peux aussi **glisser-déposer** un fichier CSV n'importe où dans la fenêtre
pour lancer l'import.

---

## 3. Installer sur Android

1. Sur le téléphone, ouvre la page **Releases** et télécharge
   **`budget-android.apk`**.
2. Ouvre le fichier téléchargé (barre de notifications ou dossier
   *Téléchargements*).
3. Android demande d'autoriser l'installation depuis cette source :
   **Paramètres → Autoriser depuis cette source**, puis reviens en arrière.
4. Touche **Installer**.
5. L'icône « Budget » apparaît sur l'écran d'accueil.

À la première ouverture, l'application demande l'autorisation d'envoyer des
**notifications** : accepte, sinon les rappels de factures ne s'afficheront pas.

---

## 4. Relier les deux appareils

Sans compte, l'application fonctionne parfaitement, mais chaque appareil garde
ses propres données. Pour que Windows et Android partagent les mêmes données :

1. Ouvre l'application → onglet **Profil**.
2. Touche **Se connecter** → **Créer un nouveau compte**.
3. Entre un courriel et un mot de passe (6 caractères minimum).
4. Répète l'opération sur l'autre appareil, **avec le même compte**.

La synchronisation se fait automatiquement à l'ouverture et à chaque
modification ; le bouton **Synchroniser** (ou `Ctrl + S`) la force
immédiatement.

> Si le bouton indique « La synchronisation cloud n'est pas configurée », c'est
> que la version installée a été compilée sans clés Supabase.
> Voir [Configuration Supabase](CONFIGURATION_SUPABASE.md).

---

## 5. Importer ses transactions Desjardins

1. Sur AccèsD : **Comptes → Opérations → Télécharger** → format **CSV**.
2. Dans l'application : bouton **Importer CSV** (ou glisse le fichier dans la
   fenêtre sur Windows).
3. L'application affiche la liste des opérations lues :
   - les doublons déjà importés sont détectés et décochés automatiquement ;
   - une catégorie est proposée pour chaque ligne (épicerie, essence,
     restaurant…) et reste modifiable ;
   - décoche ce que tu ne veux pas importer.
4. Clique sur **Importer**.

---

## 6. Protéger l'application par un code

**Profil → Sécurité → Verrouiller avec un code PIN**, puis choisis un code à
4 chiffres. Il sera demandé à chaque ouverture.

Le code n'est jamais enregistré tel quel : seule son empreinte chiffrée est
conservée dans le coffre sécurisé du système.

---

## 7. Questions fréquentes

**L'application est-elle reliée à ma banque ?**
Non. Aucune connexion bancaire, aucun mot de passe bancaire, aucun numéro de
carte n'est demandé ni stocké. Le seul lien avec Desjardins est le fichier CSV
que tu télécharges toi-même.

**Où sont mes données ?**
Dans une base locale sur chaque appareil, et — si tu as créé un compte — dans
ton projet Supabase privé, protégé pour que seul ton compte puisse les lire.

**Puis-je utiliser l'application sans Internet ?**
Oui. Tout fonctionne hors ligne ; la synchronisation reprend dès que la
connexion revient.
