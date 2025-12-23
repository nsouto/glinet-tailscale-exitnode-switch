# GL.iNet Tailscale Exit Node Switch

Enable the physical side toggle switch on supported GL.iNet travel routers to control whether your router uses a configured Tailscale Exit Node.

This is useful if you want to:
- Keep Tailscale enabled on the router
- Select or change the Exit Node from the GL.iNet UI
- Use the hardware switch to instantly enable or disable Exit Node usage without logging into the UI

---

## Supported devices and firmware

Tested:
- GL-MT3000 (Beryl AX) – firmware 4.8.1
- GL-BE3600 (Slate 7) – firmware 4.8.x

Likely works on other GL.iNet routers running 4.x firmware that include:
- /usr/bin/gl_tailscale
- /lib/functions/gl_util.sh
- get_switch_button_status

If the firmware layout differs significantly, the installer will fail safely and leave a backup in place.

---

## How it works

This installer applies a minimal and version-tolerant patch to /usr/bin/gl_tailscale:

- Adds a small get_switch_status() helper if missing
- Makes Exit Node usage conditional:
  - Tailscale must be enabled in the GL.iNet UI
  - An Exit Node must be selected in the UI (tailscale.settings.exit_node_ip must be non-empty)
  - The physical side switch must be ON
- Installs a lightweight background monitor that watches the switch state and restarts Tailscale when the switch changes

### Important behavior (by design)

- If no Exit Node is selected in the UI, the switch does nothing
- This avoids unexpected behavior such as reusing a previously selected Exit Node when the UI is blank

---

## Installation

Run the following command on the router via SSH:

curl -fsSL https://raw.githubusercontent.com/nsouto/glinet-tailscale-exitnode-switch/main/glinet-tailscale-exitnode-switch.sh | sh -s -- install

After installation:

1. Enable Tailscale in the GL.iNet UI
2. Select an Exit Node in the UI
3. Flip the physical switch ON to use the Exit Node, OFF to disable it

---

## Uninstall / Rollback

To restore the original system state:

curl -fsSL https://raw.githubusercontent.com/nsouto/glinet-tailscale-exitnode-switch/main/glinet-tailscale-exitnode-switch.sh | sh -s -- uninstall

This restores the backed-up gl_tailscale script and removes the background monitor.

---

## Status and troubleshooting

To check installation status:

curl -fsSL https://raw.githubusercontent.com/nsouto/glinet-tailscale-exitnode-switch/main/glinet-tailscale-exitnode-switch.sh | sh -s -- status

Useful diagnostics:

uci -q get tailscale.settings.enabled
uci -q get tailscale.settings.exit_node_ip
. /lib/functions/gl_util.sh; get_switch_button_status
tailscale status | head -n 40

Monitor log file:
- /tmp/gl_tailscale_switch_monitor.log

---

## Files modified and installed

Modified:
- /usr/bin/gl_tailscale (automatically backed up before patching)

Backups created:
- /usr/bin/gl_tailscale.bak.glinet-tailscale-exitnode-switch
- /usr/bin/gl_tailscale.bak.glinet-tailscale-exitnode-switch.<timestamp>

Installed:
- /usr/bin/gl_tailscale_switch_monitor
- A startup entry added to /etc/rc.local

---

## Credit

This project was inspired by the initial idea and direction shared by a community member in the GL.iNet forum thread:

https://forum.gl-inet.com/t/side-toggle-switch-for-tailscale-exit-node/64947/10

Credit goes to that contributor for the original concept that led to this implementation.

---

## Disclaimer

This is an unofficial community-maintained script that modifies system files on your router.

Use at your own risk. Always ensure you have backups before installing.
