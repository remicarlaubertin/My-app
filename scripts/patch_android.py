#!/usr/bin/env python3
"""Ajuste le projet Android généré par `flutter create`.

Le dossier `android/` n'est pas versionné : il est régénéré à chaque build
(en local comme dans GitHub Actions). Ce script applique ensuite les réglages
propres à l'application :

  * minSdk 23 (exigé par flutter_secure_storage et les notifications) ;
  * « core library desugaring », exigé par flutter_local_notifications ;
  * multidex, car l'application dépasse la limite de 64 K méthodes.

Le script est idempotent : on peut le relancer sans risque.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GRADLE = ROOT / "android" / "app" / "build.gradle"
GRADLE_KTS = ROOT / "android" / "app" / "build.gradle.kts"

DESUGAR_VERSION = "2.1.4"


def patch_groovy(text: str) -> str:
    text = re.sub(
        r"minSdk(Version)?\s*=?\s*[\w.]+",
        "minSdk 23",
        text,
        count=1,
    )

    if "coreLibraryDesugaringEnabled" not in text:
        text = re.sub(
            r"compileOptions\s*\{",
            "compileOptions {\n        coreLibraryDesugaringEnabled true",
            text,
            count=1,
        )

    if "multiDexEnabled" not in text:
        text = re.sub(
            r"(defaultConfig\s*\{)",
            r"\1\n        multiDexEnabled true",
            text,
            count=1,
        )

    if "desugar_jdk_libs" not in text:
        if re.search(r"^dependencies\s*\{", text, flags=re.MULTILINE):
            text = re.sub(
                r"^dependencies\s*\{",
                "dependencies {\n    coreLibraryDesugaring "
                f"'com.android.tools:desugar_jdk_libs:{DESUGAR_VERSION}'",
                text,
                count=1,
                flags=re.MULTILINE,
            )
        else:
            text += (
                "\n\ndependencies {\n    coreLibraryDesugaring "
                f"'com.android.tools:desugar_jdk_libs:{DESUGAR_VERSION}'\n"
                "}\n"
            )
    return text


def patch_kts(text: str) -> str:
    text = re.sub(r"minSdk\s*=\s*[\w.()]+", "minSdk = 23", text, count=1)

    if "isCoreLibraryDesugaringEnabled" not in text:
        text = re.sub(
            r"compileOptions\s*\{",
            "compileOptions {\n        isCoreLibraryDesugaringEnabled = true",
            text,
            count=1,
        )

    if "multiDexEnabled" not in text:
        text = re.sub(
            r"(defaultConfig\s*\{)",
            r"\1\n        multiDexEnabled = true",
            text,
            count=1,
        )

    if "desugar_jdk_libs" not in text:
        text += (
            "\n\ndependencies {\n    coreLibraryDesugaring("
            f'"com.android.tools:desugar_jdk_libs:{DESUGAR_VERSION}")\n'
            "}\n"
        )
    return text


def main() -> int:
    if GRADLE.exists():
        original = GRADLE.read_text(encoding="utf-8")
        GRADLE.write_text(patch_groovy(original), encoding="utf-8")
        print(f"[patch_android] {GRADLE.relative_to(ROOT)} mis à jour")
    elif GRADLE_KTS.exists():
        original = GRADLE_KTS.read_text(encoding="utf-8")
        GRADLE_KTS.write_text(patch_kts(original), encoding="utf-8")
        print(f"[patch_android] {GRADLE_KTS.relative_to(ROOT)} mis à jour")
    else:
        print("[patch_android] Aucun build.gradle trouvé — lance d'abord "
              "`flutter create`.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
