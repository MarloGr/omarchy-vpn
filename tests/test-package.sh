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

# Persistent safety preferences must survive connection/startup recovery.
python3 - <<'PY'
from pathlib import Path

script = Path("lib/vpnctl-root").read_text()
recovery = script.split("deadman_recover() {", 1)[1].split("\nsafe_connect() {", 1)[0]
assert "if [[ $transition == killswitch ]]" in recovery
assert recovery.index("set_setting killswitch false") > recovery.index("if [[ $transition == killswitch ]]")
assert recovery.index("apply_firewall") > recovery.index("else")
PY

# Boot retries should not wait a full minute when network-online is premature.
grep -qx 'OnBootSec=15s' systemd/omarchy-vpn-check.timer
grep -qx 'OnUnitActiveSec=30s' systemd/omarchy-vpn-check.timer

# The menu status includes locally sourced WireGuard connection details.
for field in address endpoint; do
  grep -q "^$field=" lib/vpnctl-root
done
for field in address endpoint; do
  grep -q "\"$field\"" lib/vpn-data
done
echo "Package tests passed."
