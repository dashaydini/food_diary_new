#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"

export BTW_UPLOAD_KEYSTORE="${BTW_UPLOAD_KEYSTORE:-$HOME/Documents/BITE_THE_WAY_private/upload-key.jks}"
export BTW_UPLOAD_KEY_ALIAS="${BTW_UPLOAD_KEY_ALIAS:-upload}"

if [[ ! -f "$BTW_UPLOAD_KEYSTORE" ]]; then
  printf 'Upload key not found: %s\n' "$BTW_UPLOAD_KEYSTORE" >&2
  exit 1
fi

if [[ ! -t 0 ]]; then
  printf 'Run this script in an interactive terminal to enter the signing password.\n' >&2
  exit 1
fi

read -r -s -p 'Upload keystore password: ' BTW_UPLOAD_STORE_PASSWORD
printf '\n'
if [[ -z "$BTW_UPLOAD_STORE_PASSWORD" ]]; then
  printf 'A password is required.\n' >&2
  exit 1
fi

read -r -s -p 'Key password (Enter if the same): ' BTW_UPLOAD_KEY_PASSWORD
printf '\n'
if [[ -z "$BTW_UPLOAD_KEY_PASSWORD" ]]; then
  BTW_UPLOAD_KEY_PASSWORD="$BTW_UPLOAD_STORE_PASSWORD"
fi

export BTW_UPLOAD_STORE_PASSWORD BTW_UPLOAD_KEY_PASSWORD
trap 'unset BTW_UPLOAD_STORE_PASSWORD BTW_UPLOAD_KEY_PASSWORD' EXIT

flutter build appbundle --release
printf 'Signed bundle: %s\n' "$project_dir/build/app/outputs/bundle/release/app-release.aab"
