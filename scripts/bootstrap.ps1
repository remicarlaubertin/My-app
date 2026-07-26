# =============================================================================
#  Prépare le projet avant compilation (Windows / PowerShell).
#
#  Équivalent exact de scripts/bootstrap.sh.
#  Utilisation :  .\scripts\bootstrap.ps1
# =============================================================================
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host "> Generation des dossiers de plateforme..."
flutter create --org com.aubertin --project-name budget_app --platforms=android,windows --empty . | Out-Null
if ($LASTEXITCODE -ne 0) { throw "flutter create a echoue" }

# Test d'exemple genere par `flutter create` : il ne compile pas ici.
Remove-Item "test/widget_test.dart" -ErrorAction SilentlyContinue

if (Test-Path "platform_overrides/android") {
    Write-Host "> Application des reglages Android..."
    # robocopy fusionne les arborescences (Copy-Item -Recurse imbriquerait
    # platform_overrides/android/app dans android/app).
    robocopy "platform_overrides\android" "android" /E /NFL /NDL /NJH /NJS | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "copie des reglages Android echouee" }
    $global:LASTEXITCODE = 0
}

python scripts/patch_android.py
if ($LASTEXITCODE -ne 0) { throw "patch_android.py a echoue" }

Write-Host "> Recuperation des dependances..."
flutter pub get
if ($LASTEXITCODE -ne 0) { throw "flutter pub get a echoue" }

Write-Host "> Generation des icones..."
dart run flutter_launcher_icons
if ($LASTEXITCODE -ne 0) { throw "generation des icones echouee" }

Write-Host "OK - Compile ensuite avec : flutter build windows --release"
