#!/usr/bin/env bash
# SPOT THE LIE — export + deploy pipeline (idempotent, re-runnable)
set -e
cd /opt/games/spot-the-lie
export GODOT_SILENCE_ROOT_WARNING=1
mkdir -p build/web
godot --headless --path . --export-release "Web" build/web/index.html 2>&1 | grep -E "^ERROR" | grep -v "icon.png" || true
cd build/web
gzip -k -9 -f index.wasm index.pck index.js index.html index.png index.icon.png index.audio.worklet.js

# refresh gh-pages worktree
DEPLOY=/tmp/stl-deploy
rm -rf "$DEPLOY" && mkdir -p "$DEPLOY"
if [ -d /tmp/stl-pages/.git ]; then
  git -C /tmp/stl-pages fetch -q origin gh-pages 2>/dev/null || true
fi
cd "$DEPLOY"
git init -q -b gh-pages 2>/dev/null || true
git config user.name engineering
git config user.email engineering@hermes.agency
git remote remove origin 2>/dev/null || true
git remote add origin https://github.com/sxaad69/spot-the-lie.git
git fetch -q origin gh-pages --depth 1 2>/dev/null || true
git reset -q --soft FETCH_HEAD 2>/dev/null || true
cp /opt/games/spot-the-lie/build/web/index.* .
cp /tmp/stl-thumb.png thumb.png
git add -A
if ! git diff --cached --quiet; then
  git commit -q -m "deploy: SPOT THE LIE v1 rebuild $(date -u +%H:%M)"
  git push -q --force origin gh-pages
else
  echo "no changes to deploy"
fi
echo "deployed: $(git rev-parse --short HEAD)"
