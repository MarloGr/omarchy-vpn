Warning, Vibecoded Project! Intended for personal use only. Use at your own risk

# Omarchy VPN

WireGuard client for Omarchy Quattro. Adds a themed Quickshell VPN panel to the bar and provides auto-connect and kill-switch controls.

### `profiles/*.conf`

Put standard WireGuard client profiles in `profiles/`. Profile filenames
become stable IDs and may contain letters, digits, `.`, `_`, and `-`. Each
profile must contain `[Interface]`, `[Peer]`, `PrivateKey`, `Endpoint`, and an
IPv4 default route in `AllowedIPs`.

Profiles exported with their real private key need no separate key file.
Profiles containing a placeholder can all share the key supplied through `pk`.

### `pk` (optional)

Use either a raw 44-character WireGuard private key or any WireGuard config
containing a `PrivateKey = ...` line. The installer never puts this file in
public runtime metadata. Installed profiles are root-only.

### `locations.tsv` (optional)

Customize labels with four tab-separated fields:

```text
# id<TAB>icon<TAB>name<TAB>group
oslo<TAB>🇳🇴<TAB>Oslo<TAB>Norway
new-york<TAB>🇺🇸<TAB>New York<TAB>United States
```

## Install

For the default `profiles/`, `pk`, and `locations.tsv` layout:

```bash
./install.sh
```

Or provide every input explicitly:

```bash
./install.sh \
  --profiles ~/Downloads/wireguard-profiles \
  --pk ~/.secrets/wireguard-pk \
  --locations ./locations.tsv \
  --default oslo \
  --dns "1.1.1.1 1.0.0.1"
```

`--dns` is optional. Otherwise each profile's `DNS =` values are applied with
`resolvectl`; profiles without DNS values retain the system resolver.

The installer validates profiles before requesting privileges, then installs
root services, the restricted control socket, the `community.omarchy-vpn`
Quickshell plugin, and the
`Super+Shift+V` Hyprland binding. Re-run it to update or replace profiles.
If the replacement set omits the currently connected profile, installation
stops safely and asks you to disconnect first.

Only install profiles from a provider you trust: `wg-quick` profiles can
contain hooks that execute as root.

## Usage

- Left-click the shield to open the profile picker.
- Right-click it to connect or disconnect.
- Press `Super+Shift+V` to open the panel anywhere.
- Lime means connected, red means disconnected, and the lock glyph means the
  kill switch is enabled.
- While connected, the panel shows the tunnel IP and endpoint reported locally
  by WireGuard.

```bash
omarchy-vpn status
omarchy-vpn menu
omarchy-vpn toggle
omarchy-vpn locations
```

## Safety model

The UI talks to a root-owned Unix socket that accepts only fixed VPN commands
and validated profile IDs. It cannot execute arbitrary privileged commands.

Connections and kill-switch activation arm a 60-second systemd dead-man timer.
If a connection transition fails, recovery removes the partial tunnel,
restores the previous IPv6 state, and preserves an enabled kill switch while
the watchdog retries. A failed kill-switch activation is rolled back for
availability. IPv6 is disabled only for profiles that do not route `::/0`.

The watchdog retries shortly after boot and repairs missing tunnels and
handshakes older than five minutes.
Unresponsive profiles are marked `STALE` until a successful retry.

## Uninstall

```bash
./uninstall.sh
```

This removes the system components and user-shell integration, disconnecting
the managed tunnel and restoring networking first.
