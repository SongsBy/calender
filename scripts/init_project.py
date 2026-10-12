#!/usr/bin/env python3
"""Turn this template into a new project.

Usage (from the project root):

    python3 scripts/init_project.py --name "My App" --org com.example

What it does:
  * sets PROJECT_NAME and fresh SECRET_KEY / POSTGRES_PASSWORD in .env
  * renames the Flutter app (display name) and its bundle id / package
    for Android, iOS, macOS and web
  * updates the README title

Only standard library is used, so it runs anywhere Python 3 is available.
"""

from __future__ import annotations

import argparse
import re
import secrets
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FRONTEND = ROOT / "frontend"

OLD_ORG = "com.fastapi.template"
OLD_APP = "frontend"


def slugify(name: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")
    if not slug or slug[0].isdigit():
        slug = f"app_{slug}"
    return slug


def replace_in_file(path: Path, pairs: list[tuple[str, str]]) -> None:
    text = path.read_text()
    new = text
    for old, repl in pairs:
        new = new.replace(old, repl)
    if new != text:
        path.write_text(new)
        print(f"  updated {path.relative_to(ROOT)}")


def update_env(name: str) -> None:
    path = ROOT / ".env"
    text = path.read_text()
    text = re.sub(r'^PROJECT_NAME=.*$', f'PROJECT_NAME="{name}"', text, flags=re.M)
    text = re.sub(r"^SECRET_KEY=.*$", f"SECRET_KEY={secrets.token_urlsafe(32)}", text, flags=re.M)
    text = re.sub(
        r"^POSTGRES_PASSWORD=.*$",
        f"POSTGRES_PASSWORD={secrets.token_urlsafe(16)}",
        text,
        flags=re.M,
    )
    path.write_text(text)
    print(f"  updated .env (PROJECT_NAME, SECRET_KEY, POSTGRES_PASSWORD)")


def update_flutter(name: str, org: str) -> None:
    new_id = f"{org}.{OLD_APP}"
    old_id = f"{OLD_ORG}.{OLD_APP}"

    # Bundle ids / namespaces
    for rel in [
        "android/app/build.gradle.kts",
        "ios/Runner.xcodeproj/project.pbxproj",
        "macos/Runner.xcodeproj/project.pbxproj",
        "macos/Runner/Configs/AppInfo.xcconfig",
    ]:
        replace_in_file(FRONTEND / rel, [(old_id, new_id), (OLD_ORG, org)])

    # Android Kotlin package directory
    old_pkg_dir = FRONTEND / "android/app/src/main/kotlin" / Path(*OLD_ORG.split(".")) / OLD_APP
    new_pkg_dir = FRONTEND / "android/app/src/main/kotlin" / Path(*org.split(".")) / OLD_APP
    if old_pkg_dir.exists() and old_pkg_dir != new_pkg_dir:
        new_pkg_dir.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(old_pkg_dir), str(new_pkg_dir))
        # Remove now-empty old package directories
        parent = old_pkg_dir.parent
        kotlin_root = FRONTEND / "android/app/src/main/kotlin"
        while parent != kotlin_root and parent.exists() and not any(parent.iterdir()):
            parent.rmdir()
            parent = parent.parent
        print(f"  moved Kotlin package to {new_pkg_dir.relative_to(ROOT)}")
    for kt in new_pkg_dir.glob("*.kt"):
        replace_in_file(kt, [(f"package {old_id}", f"package {new_id}")])

    # Display names
    replace_in_file(
        FRONTEND / "android/app/src/main/AndroidManifest.xml",
        [(f'android:label="{OLD_APP}"', f'android:label="{name}"')],
    )
    replace_in_file(
        FRONTEND / "ios/Runner/Info.plist",
        [
            ("<key>CFBundleDisplayName</key>\n\t<string>Frontend</string>",
             f"<key>CFBundleDisplayName</key>\n\t<string>{name}</string>"),
        ],
    )
    replace_in_file(
        FRONTEND / "macos/Runner/Configs/AppInfo.xcconfig",
        [(f"PRODUCT_NAME = {OLD_APP}", f"PRODUCT_NAME = {name}")],
    )
    replace_in_file(
        FRONTEND / "web/index.html",
        [
            (f'content="{OLD_APP}"', f'content="{name}"'),
            (f"<title>{OLD_APP}</title>", f"<title>{name}</title>"),
            ('content="A new Flutter project."', f'content="{name}"'),
        ],
    )
    replace_in_file(
        FRONTEND / "web/manifest.json",
        [
            (f'"name": "{OLD_APP}"', f'"name": "{name}"'),
            (f'"short_name": "{OLD_APP}"', f'"short_name": "{name}"'),
            ('"description": "A new Flutter project."', f'"description": "{name}"'),
        ],
    )
    replace_in_file(
        FRONTEND / "lib/core/config.dart",
        [("static const String appTitle = 'FastAPI Template';",
          f"static const String appTitle = '{name}';")],
    )


def update_readme(name: str) -> None:
    path = ROOT / "README.md"
    text = path.read_text()
    text = re.sub(r"^# .*$", f"# {name}", text, count=1, flags=re.M)
    path.write_text(text)
    print("  updated README.md title")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--name", required=True, help='Project / app display name, e.g. "My App"')
    parser.add_argument("--org", required=True, help="Reverse-domain org for bundle ids, e.g. com.example")
    args = parser.parse_args()

    if not re.fullmatch(r"[a-z][a-z0-9]*(\.[a-z][a-z0-9]*)+", args.org):
        parser.error("--org must look like com.example (lowercase, dot-separated)")

    print(f"Initializing project '{args.name}' with org '{args.org}'")
    update_env(args.name)
    update_flutter(args.name, args.org)
    update_readme(args.name)
    print("Done. Next: review .env, then run the backend and frontend as described in README.md.")


if __name__ == "__main__":
    main()
