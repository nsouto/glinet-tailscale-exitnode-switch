---
name: Bug report
about: Report a problem or regression
title: "[Bug] "
labels: bug
assignees: ""
---

## Describe the bug

A clear description of what happened.

## Router / firmware

- Router model:
- GL.iNet firmware version:
- Tailscale version (`tailscale version`):

## What you expected

What did you expect to happen?

## What happened

What actually happened?

## Logs / output (redact secrets)

Please include:

```sh
. /lib/functions/gl_util.sh; get_switch_button_status
uci -q get tailscale.settings.enabled
uci -q get tailscale.settings.exit_node_ip
tailscale debug prefs | grep -i -A3 -B2 'AdvertiseRoutes'
sh -x /usr/bin/gl_tailscale restart 2>&1 | tail -n 120
```

## Additional context

Anything else that might help reproduce.
