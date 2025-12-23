#!/bin/sh
set -eu

SCRIPT_NAME="glinet-tailscale-exitnode-switch"
GL_TAILSCALE="/usr/bin/gl_tailscale"
RC_LOCAL="/etc/rc.local"
MONITOR="/usr/bin/gl_tailscale_switch_monitor"
STATE_DIR="/etc/tailscale"
LAST_EXIT_NODE_FILE="/etc/tailscale/last_exit_node_ip"

timestamp() { date +"%Y%m%d-%H%M%S"; }
die() { echo "ERROR: $*" >&2; exit 1; }
need_root() { [ "$(id -u)" -eq 0 ] || die "must be run as root"; }
exists() { command -v "$1" >/dev/null 2>&1; }

backup_path() { echo "${GL_TAILSCALE}.bak.${SCRIPT_NAME}"; }

backup_now() {
  [ -f "$GL_TAILSCALE" ] || die "$GL_TAILSCALE not found"
  cp -f "$GL_TAILSCALE" "$(backup_path)"
  cp -f "$GL_TAILSCALE" "${GL_TAILSCALE}.bak.${SCRIPT_NAME}.$(timestamp)"
}

restore_backup() {
  [ -f "$(backup_path)" ] || die "backup not found: $(backup_path)"
  cp -f "$(backup_path)" "$GL_TAILSCALE"
  chmod 0755 "$GL_TAILSCALE" || true
}

install_monitor() {
  cat > "$MONITOR" <<'EOF'
#!/bin/sh

. /lib/functions/gl_util.sh

STATE_FILE="/tmp/gl_tailscale_switch_status"
POLL_INTERVAL=5
LOG_FILE="/tmp/gl_tailscale_switch_monitor.log"

log_message() {
  echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$LOG_FILE"
}

get_switch_status() {
  raw="$(get_switch_button_status 2>/dev/null || echo "no support")"
  [ -z "$raw" ] && raw="no support"
  case "$raw" in
    on|ON|1|up|UP|enable|enabled|true|TRUE|yes|YES) echo "on" ;;
    off|OFF|0|down|DOWN|disable|disabled|false|FALSE|no|NO) echo "off" ;;
    "no support"|no_support|NO_SUPPORT) echo "no_support" ;;
    *) echo "no_support" ;;
  esac
}

if [ ! -f "$STATE_FILE" ]; then
  echo "unknown" > "$STATE_FILE"
  log_message "Initialized state file with 'unknown' status"
fi

while true; do
  current_status=$(get_switch_status)
  last_status=$(cat "$STATE_FILE" 2>/dev/null || echo "unknown")
  if [ "$current_status" != "$last_status" ]; then
    log_message "Switch status changed from '$last_status' to '$current_status'"
    echo "$current_status" > "$STATE_FILE"
    log_message "Executing /usr/bin/gl_tailscale restart"
    /usr/bin/gl_tailscale restart >> "$LOG_FILE" 2>&1 || log_message "gl_tailscale restart returned non-zero"
  fi
  sleep "$POLL_INTERVAL"
done
EOF

  chmod +x "$MONITOR"

  if [ ! -f "$RC_LOCAL" ]; then
    cat > "$RC_LOCAL" <<'EOF'
#!/bin/sh
exit 0
EOF
    chmod +x "$RC_LOCAL"
  fi

  if ! grep -q "$MONITOR" "$RC_LOCAL"; then
    sed -i "\|^exit 0$|i $MONITOR \&" "$RC_LOCAL"
  fi

  # Start now (avoid duplicates)
  pkill -f "$MONITOR" >/dev/null 2>&1 || true
  "$MONITOR" &
}

uninstall_monitor() {
  pkill -f "$MONITOR" >/dev/null 2>&1 || true
  [ -f "$RC_LOCAL" ] && sed -i "\|$MONITOR|d" "$RC_LOCAL" || true
  rm -f "$MONITOR" || true
}

patch_gl_tailscale() {
  [ -f "$GL_TAILSCALE" ] || die "$GL_TAILSCALE not found"

  grep -q 'action="$1"' "$GL_TAILSCALE" || die "could not find action=\"\$1\" in $GL_TAILSCALE"
  grep -q 'if \[ "\$action" = "restart" \];then' "$GL_TAILSCALE" || die "could not find restart block header in $GL_TAILSCALE"

  # 1) Insert get_switch_status() + ubus_iface_status() after action="$1" if missing
  if ! grep -q '^get_switch_status()' "$GL_TAILSCALE"; then
    awk '
      { print }
      $0 ~ /^action="\$1"/ {
        print ""
        print "get_switch_status() {"
        print "    raw=\"$(get_switch_button_status 2>/dev/null || echo \"no support\")\""
        print "    [ -z \"$raw\" ] && raw=\"no support\""
        print "    case \"$raw\" in"
        print "        on|ON|1|up|UP|enable|enabled|true|TRUE|yes|YES) echo \"on\" ;;"
        print "        off|OFF|0|down|DOWN|disable|disabled|false|FALSE|no|NO) echo \"off\" ;;"
        print "        \"no support\"|no_support|NO_SUPPORT) echo \"no_support\" ;;"
        print "        *) echo \"no_support\" ;;"
        print "    esac"
        print "}"
        print ""
        print "ubus_iface_status() {"
        print "    iface=\"$1\""
        print "    ubus call \"network.interface.$iface\" status 2>/dev/null || true"
        print "}"
      }
    ' "$GL_TAILSCALE" > "${GL_TAILSCALE}.tmp"
    mv "${GL_TAILSCALE}.tmp" "$GL_TAILSCALE"
    chmod 0755 "$GL_TAILSCALE" || true
  fi

  # 2) Add LAST_EXIT_NODE_FILE constant if missing (optional improvement)
  if ! grep -q '^LAST_EXIT_NODE_FILE=' "$GL_TAILSCALE"; then
    if grep -q '^TAILSCALE_DNS_SERVER=' "$GL_TAILSCALE"; then
      sed -i '/^TAILSCALE_DNS_SERVER=/a LAST_EXIT_NODE_FILE="/etc/tailscale/last_exit_node_ip"' "$GL_TAILSCALE"
    else
      sed -i '/^action="\$1"/a LAST_EXIT_NODE_FILE="/etc/tailscale/last_exit_node_ip"' "$GL_TAILSCALE"
    fi
  fi

  # 3) Replace exit-node selection logic inside restart block (minimal)
  # Policy:
  # - UI must have exit node selected (tailscale.settings.exit_node_ip non-empty)
  # - physical switch must be ON
  # - otherwise do not set exit node
  awk '
    BEGIN { in_restart=0; patched=0; skip=0; seen_lan=0; seen_wan=0; }
    $0 ~ /^if \[ "\$action" = "restart" \];then/ { in_restart=1; print; next }
    {
      if (in_restart && !patched && $0 ~ /^[[:space:]]*exit_node_ip=\$\(uci -q get tailscale\.settings\.exit_node_ip\)/) {
        print ""
        print "        # UI-selected exit node (must be non-empty to be considered active)"
        print "        configured_exit_node_ip=$(uci -q get tailscale.settings.exit_node_ip)"
        print ""
        print "        # Optional: remember last configured exit node IP (useful for debugging/future)"
        print "        if [ -n \"$configured_exit_node_ip\" ]; then"
        print "            mkdir -p /etc/tailscale"
        print "            echo \"$configured_exit_node_ip\" > \"$LAST_EXIT_NODE_FILE\""
        print "        fi"
        print ""
        print "        # Physical switch controls whether we USE exit node,"
        print "        # but ONLY if UI has an active exit node selected."
        print "        switch_status=$(get_switch_status)"
        print "        if [ -n \"$configured_exit_node_ip\" ] && [ \"$switch_status\" = \"on\" ]; then"
        print "            exit_node_ip=\"$configured_exit_node_ip\""
        print "        else"
        print "            exit_node_ip=\"\""
        print "        fi"
        print ""

        skip=1
        next
      }

      if (skip==1) {
        if ($0 ~ /lan_enabled=/) seen_lan=1
        if ($0 ~ /wan_enabled=/) seen_wan=1
        if (seen_lan && seen_wan) {
          skip=0
          patched=1
          seen_lan=0
          seen_wan=0
        }
        next
      }

      print
    }
  ' "$GL_TAILSCALE" > "${GL_TAILSCALE}.tmp"

  if ! grep -q 'configured_exit_node_ip=$(uci -q get tailscale.settings.exit_node_ip)' "${GL_TAILSCALE}.tmp"; then
    rm -f "${GL_TAILSCALE}.tmp"
    die "patch failed: could not inject configured_exit_node_ip block (script layout differs on this firmware)"
  fi

  mv "${GL_TAILSCALE}.tmp" "$GL_TAILSCALE"
  chmod 0755 "$GL_TAILSCALE" || true
}

status() {
  echo "== $SCRIPT_NAME status =="
  echo "gl_tailscale: $GL_TAILSCALE"
  [ -f "$GL_TAILSCALE" ] && echo "  present" || echo "  missing"
  echo "backup: $(backup_path)"
  [ -f "$(backup_path)" ] && echo "  present" || echo "  missing"
  echo "monitor: $MONITOR"
  [ -f "$MONITOR" ] && echo "  present" || echo "  missing"
  echo "rc.local: $RC_LOCAL"
  [ -f "$RC_LOCAL" ] && echo "  present" || echo "  missing"
  echo "tailscale enabled (uci): $(uci -q get tailscale.settings.enabled 2>/dev/null || true)"
  echo "exit node ip (uci):     $(uci -q get tailscale.settings.exit_node_ip 2>/dev/null || true)"
  echo "switch status (raw):    $(. /lib/functions/gl_util.sh 2>/dev/null; get_switch_button_status 2>/dev/null || true)"
}

install() {
  need_root
  exists awk || die "awk is required"
  exists sed || die "sed is required"
  [ -f "$GL_TAILSCALE" ] || die "$GL_TAILSCALE not found (is this GL.iNet firmware with Tailscale?)"

  echo "Backing up $GL_TAILSCALE..."
  backup_now

  echo "Patching $GL_TAILSCALE..."
  patch_gl_tailscale

  echo "Installing monitor + rc.local hook..."
  install_monitor

  echo "Done."
  echo "Notes:"
  echo "- Ensure Tailscale is enabled in the GL.iNet UI."
  echo "- Select an Exit Node in the UI (exit_node_ip must be non-empty)."
  echo "- The side toggle switch controls whether the exit node is used."
}

uninstall() {
  need_root
  echo "Stopping/removing monitor..."
  uninstall_monitor

  echo "Restoring backup..."
  restore_backup

  echo "Done."
}

usage() {
  cat <<EOF
Usage:
  $0 install
  $0 uninstall
  $0 status

One-liners (run on the router):
  curl -fsSL https://raw.githubusercontent.com/nsouto/glinet-tailscale-exitnode-switch/main/glinet-tailscale-exitnode-switch.sh | sh -s -- install
  curl -fsSL https://raw.githubusercontent.com/nsouto/glinet-tailscale-exitnode-switch/main/glinet-tailscale-exitnode-switch.sh | sh -s -- uninstall
  curl -fsSL https://raw.githubusercontent.com/nsouto/glinet-tailscale-exitnode-switch/main/glinet-tailscale-exitnode-switch.sh | sh -s -- status
EOF
}

cmd="${1:-}"
case "$cmd" in
  install) install ;;
  uninstall) uninstall ;;
  status) status ;;
  *) usage; exit 1 ;;
esac
