#!/usr/bin/env bash
# SPOT THE LIE — export + deploy pipeline (idempotent, re-runnable)
# BOARD DIRECTIVE (custodian, doctrine staging rule): gh-pages ROOT = the
# pulse-passed FEELER. Full-build deploys go to /v1/ ONLY until the
# board/design pulses the finished build. This script NEVER touches root.
set -e
cd /opt/games/spot-the-lie
export GODOT_SILENCE_ROOT_WARNING=1
mkdir -p build/web
godot --headless --path . --export-release "Web" build/web/index.html 2>&1 | grep -E "^ERROR" | grep -v "icon.png" || true
cd build/web
gzip -k -9 -f index.wasm index.pck index.js index.html index.png index.icon.png index.audio.worklet.js

# refresh gh-pages worktree: clone fresh, add/update ONLY v1/, fast-forward push
DEPLOY=/tmp/stl-deploy
rm -rf "$DEPLOY"
git clone -q --depth 1 --branch gh-pages https://github.com/sxaad69/spot-the-lie.git "$DEPLOY"
mkdir -p "$DEPLOY/v1"
# clear old v1 contents, keep root (feeler) untouched
find "$DEPLOY/v1" -mindepth 1 -maxdepth 1 -not -name '.git' -exec rm -rf {} +
cp /opt/games/spot-the-lie/build/web/index.* "$DEPLOY/v1/"
cp /tmp/stl-thumb.png "$DEPLOY/v1/thumb.png"
cd "$DEPLOY"
git config user.name engineering
git config user.email engineering@hermes.agency
git add -A v1/
if ! git diff --cached --quiet; then
  git commit -q -m "deploy(v1): SPOT THE LIE full-build rebuild $(date -u +%Y-%m-%dT%H:%MZ)"
  git push -q origin gh-pages
else
  echo "no changes to deploy"
fi
echo "deployed: $(git rev-parse --short HEAD) (v1/ subpath only)"
