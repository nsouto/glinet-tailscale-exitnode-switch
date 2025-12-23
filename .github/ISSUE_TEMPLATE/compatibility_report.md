---
name: Compatibility report
about: Report results on a new router model or firmware
title: "[Compat] "
labels: compatibility
assignees: ""
---

## Device / firmware

- Router model:
- GL.iNet firmware version:
- Tailscale version (`tailscale version`):

## Results

- [ ] Install succeeded
- [ ] Switch gating works (exit node toggles)
- [ ] Subnet routes still advertised (if enabled)
- [ ] Uninstall/rollback succeeded

## Output (redact secrets)

```sh
. /lib/functions/gl_util.sh; get_switch_button_status
tailscale debug prefs | grep -i -A3 -B2 'AdvertiseRoutes'
```

## Notes

Anything notable about this firmware/device.
