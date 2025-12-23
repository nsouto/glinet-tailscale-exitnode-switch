# Contributing

Thanks for your interest in improving this project. The goal is to keep the patch **minimal, safe, and version-tolerant** across GL.iNet firmware variations.

## Ways to contribute

- Report compatibility with new devices/firmware versions
- Improve robustness of the patching logic
- Add documentation, examples, and troubleshooting steps
- Submit fixes for regressions or edge cases

## Ground rules

- Keep changes small and readable.
- Avoid replacing `/usr/bin/gl_tailscale` wholesale — patch only the smallest required sections.
- Prefer idempotent installer behavior and safe failure modes (fail without breaking the router).
- Any change that touches patch logic should be tested on at least one device if possible.

## Development workflow

1. Fork the repo
2. Create a feature branch:
   - `git checkout -b fix/your-change`
3. Make your changes
4. Run basic lint/sanity checks:
   - Ensure shell scripts are POSIX `sh` compatible (BusyBox ash)
   - Avoid bashisms
5. Update documentation if behavior changes
6. Open a Pull Request

## Testing checklist (recommended)

On a test router:

- Confirm `install` runs cleanly and creates backups
- Confirm `status` works
- Confirm `uninstall` restores the backup and removes monitor/rc.local entry
- Confirm subnet routes are still advertised:
  - `tailscale debug prefs | grep -i -A3 -B2 'AdvertiseRoutes'`
- Confirm exit node is gated by switch:
  - Switch OFF: no `--exit-node`
  - Switch ON: `--exit-node=<ui configured ip>`
- Confirm re-running `install` is safe (ideally: uninstall → install for clean iteration)

## Reporting compatibility

When reporting an issue, please include:

- Router model (e.g., MT3000, BE3600)
- GL.iNet firmware version
- Tailscale version (`tailscale version`)
- Output of:
  - `uci -q get tailscale.settings.enabled`
  - `uci -q get tailscale.settings.exit_node_ip`
  - `. /lib/functions/gl_util.sh; get_switch_button_status`
  - `tailscale debug prefs | grep -i -A3 -B2 'AdvertiseRoutes'`
  - `sh -x /usr/bin/gl_tailscale restart 2>&1 | tail -n 80`

## Pull request notes

- Explain the “why” and the scope of the change.
- If the change is device/firmware-specific, document it clearly.
- Avoid adding heavy dependencies or large frameworks.
