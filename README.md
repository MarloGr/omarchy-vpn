# Omarchy VPN

A provider-neutral WireGuard client for Omarchy Quattro. It adds a themed
Quickshell panel to the bar, manages multiple profiles through a restricted
root service, and provides persistent auto-connect and kill-switch controls.

The package contains no VPN credentials or provider profiles.

## Requirements

- Omarchy Quattro with `omarchy-shell`
- WireGuard tools (`wg` and `wg-quick`)
- `nftables`, `systemd`, `python3`, `curl`, `iputils`, and `util-linux`
- Membership in the `wheel` group (for the restricted control socket)

## Inputs

Create these locally before installing. They are ignored by Git.

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

IDs match profile filenames without `.conf`. Missing rows receive a humanized
filename, shield icon, and the group `VPN`.

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
If a transition fails, recovery removes the partial tunnel and firewall,
disables the kill switch, and restores the previous IPv6 state. IPv6 is
disabled only for profiles that do not route `::/0`.

The watchdog repairs missing tunnels and handshakes older than five minutes.
Unresponsive profiles are marked `STALE` until a successful retry.

## Uninstall

```bash
./uninstall.sh
```

This removes the system components and user-shell integration, disconnecting
the managed tunnel and restoring networking first.
