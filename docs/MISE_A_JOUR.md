# Publier une mise à jour

## En résumé

```bash
git add .
git commit -m "Ajout de la fonction X"
git push
```

GitHub compile automatiquement Windows et Android. Les fichiers se récupèrent
dans **Actions → dernière exécution → Artifacts**.

Pour une **vraie version publiée** (visible dans *Releases*, avec un texte
d'installation) :

```bash
# 1. Monter le numéro de version dans pubspec.yaml
#    version: 1.1.0+2      (1.1.0 = version affichée, +2 = numéro de build)

git add pubspec.yaml
git commit -m "Version 1.1.0"
git tag v1.1.0
git push origin main --tags
```

En quelques minutes, la page **Releases** contient :

- `BudgetSetup-1.1.0.exe`
- `budget-windows-portable.zip`
- `budget-android.apk`

---

## Détail des étapes

### 1. Numéro de version

Dans `pubspec.yaml` :

```yaml
version: 1.1.0+2
```

- `1.1.0` : ce que voient les utilisateurs (règle habituelle :
  `correctif` → 1.0.**1**, `nouveauté` → 1.**1**.0, `refonte` → **2**.0.0).
- `+2` : **doit toujours augmenter** — Android refuse d'installer une mise à
  jour dont le numéro de build est inférieur ou égal au précédent.

### 2. Installer la mise à jour

- **Windows** : lancer le nouveau `BudgetSetup-x.y.z.exe` par-dessus l'ancienne
  installation. Les données sont conservées.
- **Android** : ouvrir le nouveau `.apk` et confirmer la mise à jour. Les
  données sont conservées.

> Les données sont conservées parce que la base SQLite vit dans le dossier de
> données de l'application, jamais dans le dossier d'installation.

### 3. Si le modèle de données change

Ajouter une colonne ou une table demande deux gestes :

1. Dans `lib/data/local/database.dart` : monter `version: 1` → `2` et ajouter un
   `onUpgrade` qui exécute les `ALTER TABLE` nécessaires.
2. Dans `supabase/schema.sql` : ajouter la colonne, puis rejouer le script dans
   l'éditeur SQL de Supabase (il est écrit pour être rejouable).

Sans le `onUpgrade`, les appareils déjà installés garderont l'ancienne
structure et la synchronisation échouera sur la nouvelle colonne.

---

## Relancer une compilation sans changer le code

**Actions → Build Windows + Android → Run workflow → Run**.

Utile après avoir ajouté les secrets `SUPABASE_URL` et `SUPABASE_ANON_KEY` :
il faut recompiler pour que les applications sachent où se synchroniser.

---

## Travailler à deux sur le dépôt

```bash
git checkout -b ma-fonction     # une branche par sujet
# … modifications …
git push -u origin ma-fonction
```

Puis ouvrir une **Pull Request** sur GitHub. La compilation se lance
automatiquement sur la branche : si elle passe au vert, le code compile sur les
deux plateformes. Fusionner ensuite dans `main`.

---

## Si la compilation échoue

1. **Actions** → cliquer sur l'exécution rouge → ouvrir l'étape en erreur.
2. Causes fréquentes :

| Message | Cause | Solution |
|---|---|---|
| `pub get failed` | version de paquet incompatible | `flutter pub upgrade --major-versions` en local, puis pousser le `pubspec.lock` |
| `Execution failed for task ':app:...'` | outil Android manquant ou version de Java | vérifier que le job utilise Java 17 |
| `ISCC.exe not found` | Inno Setup non installé sur le runner | vérifier l'étape *Installation d'Inno Setup* |
| `flutter analyze` en erreur | code invalide | corriger, ou lancer `flutter analyze` en local avant de pousser |

La compilation locale reproduit exactement le même résultat :

```bash
./scripts/bootstrap.sh
flutter build apk --release
```
