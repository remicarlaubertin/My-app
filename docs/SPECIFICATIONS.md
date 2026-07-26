# Spécifications du projet

Cahier des charges rédigé par **Rémi Carl Aubertin**, formalisé ici comme
document de référence du dépôt. La colonne « État » indique ce qui est livré
dans la version actuelle.

---

## Objectif

Transformer l'application web de gestion de budget en **véritable application
installable** sur :

- 💻 Windows PC
- 📱 Android

Il ne s'agit pas d'un site web : les deux plateformes reçoivent une application
qui s'installe sur l'appareil.

---

## 1. Technologie

| Exigence | État |
|---|---|
| Technologie multiplateforme, un seul projet | ✅ Flutter / Dart |
| Application Windows `.exe` | ✅ Installateur Inno Setup + version portable |
| Application Android `.apk` | ✅ Compilée par GitHub Actions |
| Architecture propre, professionnelle, maintenable | ✅ `core / data / features / providers`, voir [DOCUMENTATION.md](DOCUMENTATION.md) |

---

## 2. Version Windows

| Exigence | État |
|---|---|
| Installation par fichier `.exe` | ✅ `BudgetSetup-x.y.z.exe` |
| Icône sur le Bureau | ✅ proposée par l'installateur |
| Accessible depuis le menu Démarrer | ✅ |
| Interface optimisée clavier / souris | ✅ menu latéral, tableaux larges, survol |
| Fenêtre redimensionnable | ✅ 1280×820 par défaut, minimum 900×640 |
| Glisser-déposer | ✅ dépôt d'un CSV n'importe où dans la fenêtre |
| Tableau de bord plus large, menu latéral | ✅ mise en page à partir de 900 px |
| Graphiques détaillés | ✅ répartition, revenus/dépenses, tendance 6 mois |
| Import CSV Desjardins par glisser-déposer | ✅ |
| Export PDF / Excel | ✅ |
| Raccourcis clavier utiles | ✅ `Ctrl+N`, `Ctrl+I`, `Ctrl+S`, `Ctrl+1…6` |

---

## 3. Version Android

| Exigence | État |
|---|---|
| Fichier `.apk` installable | ✅ |
| Icône sur l'écran d'accueil | ✅ icône adaptative |
| Interface tactile, navigation fluide | ✅ Material 3, barre de navigation basse |
| Utilisation à une main | ✅ actions principales en bas (bouton flottant + barre) |
| Boutons adaptés au téléphone | ✅ cibles tactiles de 48 px minimum |

**Navigation mobile** : 🏠 Accueil · 💳 Transactions · 🧾 Factures ·
📈 Investissements · 📅 Agenda · 👤 Profil ✅
(Budgets et Catégories s'ajoutent au menu latéral sur ordinateur.)

---

## 4. Synchronisation Windows + Android

| Exigence | État |
|---|---|
| Même base de données pour les deux versions | ✅ Supabase (Postgres) |
| Dépense ajoutée sur Android visible sur Windows | ✅ |
| Facture cochée sur Windows mise à jour sur Android | ✅ |
| Base cloud sécurisée | ✅ Row Level Security par utilisateur |

Détail du mécanisme : [CONFIGURATION_SUPABASE.md](CONFIGURATION_SUPABASE.md).

---

## 5. Fonctionnalités

### Budget
Solde actuel · revenus · dépenses · argent restant · graphiques ✅

### Transactions
Dépenses et revenus, avec montant, catégorie, date, description, compte ✅

### Factures
| Exigence | État |
|---|---|
| Factures récurrentes | ✅ une fois / hebdo / mensuelle / annuelle |
| Dates de paiement | ✅ |
| Rappels automatiques | ✅ délai réglable par facture |
| Cocher payé / non payé | ✅ |
| Création automatique de la transaction au paiement | ✅ + génération de l'échéance suivante |

### Investissements
| Exigence | État |
|---|---|
| Compte investissement | ✅ créé par défaut |
| À la fin du mois : restant = revenus − dépenses | ✅ |
| 50 % du surplus transféré automatiquement | ✅ pourcentage réglable de 0 à 100 |
| Total investi, historique, progression | ✅ |

### Import CSV Desjardins
| Exigence | État |
|---|---|
| Fonction « Importer mes transactions Desjardins » | ✅ |
| Lecture automatique des transactions | ✅ formats et séparateurs variables gérés |
| Identification date / montant / description | ✅ |
| Éviter les doublons | ✅ empreinte SHA-1 par opération |
| Catégorisation automatique | ✅ par mots-clés, modifiable ligne par ligne |
| Confirmation avant ajout | ✅ écran d'aperçu |

### Agenda intelligent
Calendrier · événements · rendez-vous · paiements · rappels ✅
Les factures apparaissent automatiquement dans l'agenda ✅

---

## 6. Notifications

| Type | Windows | Android |
|---|---|---|
| Facture bientôt due | ✅ | ✅ programmée |
| Facture en retard | ✅ | ✅ |
| Budget dépassé | ✅ | ✅ |
| Solde faible | ✅ seuil réglable | ✅ |
| Transfert investissement prévu | ✅ | ✅ |

---

## 7. Sécurité

| Exigence | État |
|---|---|
| Connexion utilisateur | ✅ courriel + mot de passe (Supabase Auth) |
| Protection des données | ✅ RLS : chaque compte ne voit que ses données |
| Stockage sécurisé local | ✅ SQLite dans l'espace privé de l'application, coffre système pour les secrets |
| Code PIN Android | ✅ (disponible aussi sur Windows) |
| Aucune information bancaire sensible enregistrée | ✅ aucune connexion à la banque, uniquement un CSV fourni par l'utilisateur |

---

## 8. Livraison finale

| Livrable | État |
|---|---|
| 1. Application Windows prête à installer (`.exe`) | ✅ publiée dans *Releases* |
| 2. Application Android prête à installer (`.apk`) | ✅ publiée dans *Releases* |
| 3. Guide d'installation simple | ✅ [GUIDE_INSTALLATION.md](GUIDE_INSTALLATION.md) |
| 4. Documentation du projet | ✅ [DOCUMENTATION.md](DOCUMENTATION.md) |
| 5. Instructions de mise à jour | ✅ [MISE_A_JOUR.md](MISE_A_JOUR.md) |

---

## Écarts assumés

Trois points méritent d'être connus :

1. **Signature des applications.** Les fichiers ne sont pas signés par un
   certificat commercial (environ 300 $ / an). Windows affiche donc un
   avertissement au premier lancement, et Android demande d'autoriser
   l'installation hors Play Store. Sans effet sur le fonctionnement.
2. **Notifications « push ».** Les rappels sont des notifications **locales**,
   calculées sur l'appareil. Elles couvrent tous les cas demandés sans serveur
   d'envoi. De vraies notifications push (Firebase) exigeraient un service en
   ligne supplémentaire ; c'est une évolution possible.
3. **Clés Supabase.** Tant que les secrets ne sont pas ajoutés dans GitHub, les
   applications compilées fonctionnent en mode local, sans synchronisation.
