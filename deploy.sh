#!/usr/bin/env bash
# Выкладывает web/ в ветку gh-pages (GitHub Pages).
set -euo pipefail
ROOT=$(cd "$(dirname "$0")" && pwd)
TMP=$(mktemp -d)
git -C "$ROOT" fetch -q origin gh-pages
git -C "$ROOT" worktree add -q "$TMP" origin/gh-pages --detach
find "$TMP" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -R "$ROOT/web/." "$TMP/"
rm -rf "$TMP/tests" "$TMP/package.json" "$TMP/README.md"
touch "$TMP/.nojekyll"
git -C "$TMP" add -A
git -C "$TMP" commit -qm "Деплой $(git -C "$ROOT" rev-parse --short HEAD)" || echo "нет изменений"
git -C "$TMP" push -q origin HEAD:gh-pages
git -C "$ROOT" worktree remove --force "$TMP"
