#!/usr/bin/env bash
# =============================================================================
#  Prépare le projet avant compilation (Linux / macOS / GitHub Actions).
#
#  Les dossiers de plateforme (android/, windows/) ne sont pas versionnés :
#  ils sont regénérés par `flutter create`, puis complétés par nos réglages.
#  Cela garde le dépôt propre et évite les conflits sur des fichiers générés.
#
#  `flutter create` sans --overwrite n'écrase aucun fichier existant :
#  lib/, pubspec.yaml, README.md et test/ sont laissés intacts.
#
#  Utilisation :  ./scripts/bootstrap.sh
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "▶ Génération des dossiers de plateforme…"
flutter create \
  --org com.aubertin \
  --project-name budget_app \
  --platforms=android,windows \
  --empty \
  . >/dev/null

# `flutter create` ajoute un test d'exemple qui référence une classe
# inexistante dans ce projet : on le retire s'il apparaît.
rm -f test/widget_test.dart

echo "▶ Application des réglages Android…"
if [ -d platform_overrides/android ]; then
  cp -R platform_overrides/android/. android/
fi
python3 scripts/patch_android.py

echo "▶ Récupération des dépendances…"
flutter pub get

echo "▶ Génération des icônes…"
dart run flutter_launcher_icons

echo "✅ Projet prêt. Compile ensuite avec :"
echo "   flutter build apk --release"
echo "   flutter build windows --release   (sur Windows uniquement)"
