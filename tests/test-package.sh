#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

tmp=$(mktemp -d "$PWD/.test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

python3 lib/install-profiles --validate tests/fixtures/pk tests/fixtures/profiles
python3 lib/install-profiles tests/fixtures/pk tests/fixtures/profiles "$tmp/profiles"
python3 lib/build-metadata tests/fixtures/profiles tests/fixtures/locations.tsv > "$tmp/locations.tsv"

grep -qx 'PrivateKey = AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=' "$tmp/profiles/example.conf"
! grep -q '^DNS' "$tmp/profiles/example.conf"
grep -qx '9.9.9.9 149.112.112.112' "$tmp/profiles/dns/example"
grep -qx $'example\t🌐\tExample Gateway\tTest Provider' "$tmp/locations.tsv"
echo "Package tests passed."
