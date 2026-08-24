#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

profiles=profiles private_key=pk metadata=locations.tsv default_profile="" dns=""
usage() {
  cat <<'EOF'
Usage: ./install.sh [options]
  --profiles DIR       WireGuard profiles (default: profiles)
  --pk FILE            Raw private key or config containing one (default: pk)
  --locations FILE     TSV metadata: id, icon, name, group (default: locations.tsv)
  --default ID         Initial profile when no connection history exists
  --dns ADDRESSES      DNS override for every profile (comma/space separated)
  -h, --help           Show this help
EOF
}
while (($#)); do
  case "$1" in
    --profiles) [[ $# -ge 2 ]] || exit 2; profiles=$2; shift 2 ;;
    --pk) [[ $# -ge 2 ]] || exit 2; private_key=$2; shift 2 ;;
    --locations) [[ $# -ge 2 ]] || exit 2; metadata=$2; shift 2 ;;
    --default) [[ $# -ge 2 ]] || exit 2; default_profile=$2; shift 2 ;;
    --dns) [[ $# -ge 2 ]] || exit 2; dns=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done
[[ -d $profiles ]] || { echo "Profile directory not found: $profiles" >&2; exit 1; }
compgen -G "$profiles/*.conf" >/dev/null || { echo "No .conf profiles found in: $profiles" >&2; exit 1; }
[[ -e $private_key ]] || private_key=-
[[ -e $metadata ]] || metadata=-
for cmd in python3 wg-quick wg nft flock curl ping systemctl pkexec; do
  command -v "$cmd" >/dev/null || { echo "Missing dependency: $cmd" >&2; exit 1; }
done

tmp=$(mktemp -d "$PWD/.install.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
python3 lib/install-profiles --validate "$private_key" "$profiles"
python3 lib/build-metadata "$profiles" "$metadata" > "$tmp/locations.tsv"
if [[ -n $default_profile ]] && ! awk -F '\t' -v id="$default_profile" '$1 == id { found=1 } END { exit !found }' "$tmp/locations.tsv"; then
  echo "Default profile does not exist: $default_profile" >&2; exit 1
fi

pkexec "$(pwd)/lib/install-root" "$(pwd)" "$(realpath "$profiles")" \
  "$([[ $private_key == - ]] && printf '%s' - || realpath "$private_key")" \
  "$tmp/locations.tsv" "$default_profile" "$dns"

plugin="$HOME/.config/omarchy/plugins/community.omarchy-vpn"
install -d -m 755 "$plugin"
install -m 644 quickshell/community.omarchy-vpn/manifest.json quickshell/community.omarchy-vpn/Widget.qml "$plugin/"
rm -rf "$HOME/.config/omarchy/plugins/marlo.vpn"
python3 - "$HOME/.config/omarchy/shell.json" <<'PY'
import json, os, pathlib, sys, tempfile
path=pathlib.Path(sys.argv[1]); config=json.loads(path.read_text())
right=config.setdefault("bar",{}).setdefault("layout",{}).setdefault("right",[])
right[:]=[e for e in right if not (isinstance(e,dict) and e.get("id") in {"custom/vpn","omarchy.vpn","marlo.vpn","community.omarchy-vpn"})]
ids=[e.get("id") for e in right if isinstance(e,dict)]
right.insert(ids.index("omarchy.network") if "omarchy.network" in ids else len(right),{"id":"community.omarchy-vpn"})
fd,tmp=tempfile.mkstemp(prefix="shell.json.",dir=path.parent)
try:
 with os.fdopen(fd,"w",encoding="utf-8") as f: json.dump(config,f,indent=2,ensure_ascii=False); f.write("\n")
 os.chmod(tmp,path.stat().st_mode&0o777); os.replace(tmp,path)
finally:
 if os.path.exists(tmp): os.unlink(tmp)
PY
python3 - "$HOME/.config/hypr/bindings.lua" "$HOME/.config/hypr/bindings.conf" <<'PY'
import pathlib,re,sys
lua=pathlib.Path(sys.argv[1]); text=lua.read_text() if lua.exists() else ""
block='-- BEGIN omarchy-vpn\no.bind("SUPER + SHIFT + V", "VPN", "omarchy-vpn menu")\n-- END omarchy-vpn\n'
text=re.sub(r'(?ms)^-- BEGIN omarchy-vpn\n.*?^-- END omarchy-vpn\n?','',text).rstrip(); lua.write_text(text+'\n\n'+block)
legacy=pathlib.Path(sys.argv[2])
if legacy.exists(): legacy.write_text(re.sub(r'(?m)^bindd?\s*=\s*SUPER SHIFT,\s*V,\s*VPN,\s*exec,\s*omarchy-vpn menu\s*\n?','',legacy.read_text()))
PY
omarchy-shell shell rescanPlugins 2>/dev/null || true
echo "Omarchy VPN installed with $(find "$profiles" -maxdepth 1 -name '*.conf' | wc -l) profiles."
