#!/usr/bin/env bash
set -euo pipefail
pkexec /usr/local/lib/omarchy-vpn/uninstall
rm -rf "$HOME/.config/omarchy/plugins/community.omarchy-vpn" "$HOME/.config/omarchy/plugins/marlo.vpn"
python3 - "$HOME/.config/omarchy/shell.json" "$HOME/.config/hypr/bindings.lua" <<'PY'
import json, os, pathlib, re, sys, tempfile
shell=pathlib.Path(sys.argv[1])
if shell.exists():
    config=json.loads(shell.read_text()); layout=config.get("bar",{}).get("layout",{})
    for section in ("left","center","right"):
        if isinstance(layout.get(section),list): layout[section][:]=[e for e in layout[section] if not (isinstance(e,dict) and e.get("id") in {"community.omarchy-vpn","marlo.vpn"})]
    fd,tmp=tempfile.mkstemp(prefix="shell.json.",dir=shell.parent)
    try:
        with os.fdopen(fd,"w",encoding="utf-8") as f: json.dump(config,f,indent=2,ensure_ascii=False); f.write("\n")
        os.chmod(tmp,shell.stat().st_mode&0o777); os.replace(tmp,shell)
    finally:
        if os.path.exists(tmp): os.unlink(tmp)
lua=pathlib.Path(sys.argv[2])
if lua.exists(): lua.write_text(re.sub(r'(?ms)^-- BEGIN omarchy-vpn\n.*?^-- END omarchy-vpn\n?','',lua.read_text()).rstrip()+"\n")
PY
omarchy restart shell
hyprctl reload
echo "Omarchy VPN uninstalled."
