#!/bin/bash
set -euo pipefail
if [ "$#" -ne 2 ] || [[ ! "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || [[ ! "$2" =~ ^[0-9a-f]{64}$ ]]; then
    echo 'usage: render-homebrew-cask.sh <version> <sha256>' >&2
    exit 2
fi
cd "$(dirname "$0")/.."
sed -e "s/@VERSION@/$1/g" -e "s/@SHA256@/$2/g" packaging/homebrew/lilt.rb.template
