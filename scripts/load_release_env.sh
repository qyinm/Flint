#!/usr/bin/env bash

load_release_env() {
  local root_dir="$1"
  local env_file="$root_dir/.env.release.local"
  local names=(
    APPLE_APP_SPECIFIC_PASSWORD
    APPLE_ID
    APPLE_TEAM_ID
    FLINT_NOTARIZE
    FLINT_RELEASE_AUTHOR
    FLINT_RELEASE_DRY_RUN
    FLINT_RELEASE_NOTES_PATH
    FLINT_SIGN_IDENTITY
    FLINT_VERSION
    SPARKLE_ACCOUNT
    SPARKLE_DOWNLOAD_URL_PREFIX
    SPARKLE_FEED_URL
    SPARKLE_FULL_RELEASE_NOTES_URL
    SPARKLE_GENERATE_APPCAST
    SPARKLE_PUBLIC_ED_KEY
  )

  local name
  for name in "${names[@]}"; do
    eval "if [[ \${$name+x} ]]; then export FLINT_PRESET_${name}=\"\${$name}\"; fi"
  done

  if [[ -f "$env_file" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
  fi

  for name in "${names[@]}"; do
    eval "if [[ \${FLINT_PRESET_${name}+x} ]]; then export ${name}=\"\${FLINT_PRESET_${name}}\"; unset FLINT_PRESET_${name}; fi"
  done
}
