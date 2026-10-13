#!/usr/bin/env bash
# Builds the website and publishes it to the gh-pages branch, which GitHub Pages
# serves at https://smoothliekbutter.github.io/Roblox-game/
#
# Usage (from anywhere in the repo): psat-prep/scripts/publish-site.sh
set -euo pipefail

SITE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(git -C "$SITE_DIR" rev-parse --show-toplevel)"
SOURCE="$(git -C "$REPO_ROOT" rev-parse --short HEAD)"

node "$SITE_DIR/scripts/build-site.mjs" --out dist

WORKTREE="$(mktemp -d)"
cleanup() { git -C "$REPO_ROOT" worktree remove --force "$WORKTREE" >/dev/null 2>&1 || true; }
trap cleanup EXIT

git -C "$REPO_ROOT" fetch -q origin gh-pages
git -C "$REPO_ROOT" worktree add -q --detach "$WORKTREE" origin/gh-pages
git -C "$WORKTREE" rm -rq --ignore-unmatch .
cp -R "$SITE_DIR/dist/." "$WORKTREE/"
git -C "$WORKTREE" add -A

if git -C "$WORKTREE" diff --cached --quiet; then
  echo "The website is already up to date."
  exit 0
fi
git -C "$WORKTREE" commit -q -m "Publish PSAT Prep website from $SOURCE" ${PUBLISH_TRAILER:+-m "$PUBLISH_TRAILER"}
git -C "$WORKTREE" push -q origin HEAD:gh-pages
echo "Published. GitHub Pages updates the site within a couple of minutes."
