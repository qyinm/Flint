#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -f "$ROOT_DIR/.env.release.local" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT_DIR/.env.release.local"
  set +a
fi

VERSION="${FLINT_VERSION:-0.1.0}"
TAG="v${VERSION#v}"
DIST_DIR="$ROOT_DIR/dist"
NOTES_PATH="$DIST_DIR/release-notes-${TAG}.md"
DMG_PATH="$DIST_DIR/Flint-${VERSION#v}-mac-arm64.dmg"
ZIP_PATH="$DIST_DIR/Flint-${VERSION#v}-mac-arm64.zip"
DRY_RUN="${FLINT_RELEASE_DRY_RUN:-0}"
AUTHOR_HANDLE="${FLINT_RELEASE_AUTHOR:-}"

github_slug_from_remote() {
  local remote_url="$1"
  case "$remote_url" in
    git@github.com:*)
      remote_url="${remote_url#git@github.com:}"
      remote_url="${remote_url%.git}"
      ;;
    https://github.com/*)
      remote_url="${remote_url#https://github.com/}"
      remote_url="${remote_url%.git}"
      ;;
    *)
      echo "Could not derive GitHub repository from origin URL: $remote_url" >&2
      exit 1
      ;;
  esac
  echo "$remote_url"
}

require_clean_worktree() {
  if [[ -n "$(git status --porcelain)" ]]; then
    echo "Working tree must be clean before publishing a GitHub release." >&2
    git status --short >&2
    exit 1
  fi
}

previous_tag_for() {
  git tag --merged HEAD --sort=-version:refname | grep -v -F "$TAG" | head -n 1 || true
}

write_release_notes() {
  local previous_tag="$1"
  local repo_url="$2"
  local range
  mkdir -p "$DIST_DIR"

  if [[ -n "$previous_tag" ]]; then
    range="${previous_tag}..HEAD"
  else
    range="HEAD"
  fi

  {
    echo "## What Changed"
    echo
    git log --reverse --no-merges --pretty=format:'%H%x09%h%x09%s' "$range" |
      while IFS=$'\t' read -r full_hash short_hash subject || [[ -n "$full_hash" ]]; do
        [[ -n "$full_hash" ]] || continue
        echo "- ${subject} by ${AUTHOR_HANDLE} in [${short_hash}](${repo_url}/commit/${full_hash})"
      done
    echo
    echo
    if [[ -n "$previous_tag" ]]; then
      echo "**Full Changelog**: ${repo_url}/compare/${previous_tag}...${TAG}"
    else
      echo "**Full Changelog**: ${repo_url}/commits/${TAG}"
    fi
  } > "$NOTES_PATH"
}

remote_url="$(git remote get-url origin)"
github_slug="$(github_slug_from_remote "$remote_url")"
repo_url="https://github.com/${github_slug}"
repo_owner="${github_slug%%/*}"
if [[ -z "$AUTHOR_HANDLE" ]]; then
  AUTHOR_HANDLE="@${repo_owner}"
fi

previous_tag="$(previous_tag_for)"
write_release_notes "$previous_tag" "$repo_url"

if [[ "$DRY_RUN" == "1" ]]; then
  cat "$NOTES_PATH"
  exit 0
fi

require_clean_worktree

current_branch="$(git branch --show-current)"
if [[ -z "$current_branch" ]]; then
  echo "Cannot publish a GitHub release from a detached HEAD." >&2
  exit 1
fi

scripts/package_macos_app.sh

if [[ ! -f "$DMG_PATH" || ! -f "$ZIP_PATH" ]]; then
  echo "Expected release assets were not created:" >&2
  echo "  $DMG_PATH" >&2
  echo "  $ZIP_PATH" >&2
  exit 1
fi

if ! git rev-parse "$TAG" >/dev/null 2>&1; then
  git tag -a "$TAG" -m "Release $TAG"
fi

git push origin "$current_branch"
git push origin "$TAG"

if gh release view "$TAG" >/dev/null 2>&1; then
  gh release upload "$TAG" "$DMG_PATH" "$ZIP_PATH" --clobber
  gh release edit "$TAG" --title "$TAG" --notes-file "$NOTES_PATH"
else
  gh release create "$TAG" "$DMG_PATH" "$ZIP_PATH" \
    --target "$(git rev-parse HEAD)" \
    --title "$TAG" \
    --notes-file "$NOTES_PATH" \
    --latest
fi

echo "$NOTES_PATH"
