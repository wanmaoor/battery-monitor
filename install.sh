#!/bin/zsh
# battery-monitor installer
set -euo pipefail

REPO_DIR="${0:A:h}"
BIN_DIR="$HOME/.local/bin"
STATE_DIR="$HOME/.local/state/battery-drain-monitor"
REPORT_DIR="$HOME/battery"
CONFIG_DIR="$HOME/.config/battery-drain-monitor"
PLIST_LABEL="com.$USER.battery-drain-monitor"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"
SUDOERS_FILE="/etc/sudoers.d/battery-monitor"

echo "==> Installing battery-monitor for user: $USER"

# 1. Directories
mkdir -p "$BIN_DIR" "$STATE_DIR" "$REPORT_DIR" "$CONFIG_DIR"

# 2. Scripts
cp "$REPO_DIR/bin/battery-drain-monitor" "$BIN_DIR/"
cp "$REPO_DIR/bin/battery-report-gen"    "$BIN_DIR/"
chmod +x "$BIN_DIR/battery-drain-monitor" "$BIN_DIR/battery-report-gen"
echo "    scripts → $BIN_DIR"

# 3. Config (skip if already exists)
CONFIG_FILE="$CONFIG_DIR/config"
if [[ ! -f "$CONFIG_FILE" ]]; then
  cat > "$CONFIG_FILE" <<'EOF'
# Battery Drain Monitor configuration
# Uncomment and edit to override defaults.

# BATTERY_DRAIN_MONITOR_TOP_N=20
# BATTERY_DRAIN_MONITOR_SAMPLE_MS=3000
# BATTERY_DRAIN_MONITOR_STATE_DIR=~/.local/state/battery-drain-monitor
# BATTERY_DRAIN_MONITOR_REPORT_DIR=~/battery
# BATTERY_DRAIN_MONITOR_TEMP_LOG=~/.local/state/battery-temp-monitor/status.log
EOF
  echo "    config  → $CONFIG_FILE"
else
  echo "    config  → $CONFIG_FILE (already exists, skipped)"
fi

# 4. Sudoers rule (allows passwordless powermetrics)
echo "    sudoers → $SUDOERS_FILE (requires sudo)"
echo "$USER ALL=(ALL) NOPASSWD: /usr/bin/powermetrics" \
  | sudo tee "$SUDOERS_FILE" > /dev/null
sudo chmod 440 "$SUDOERS_FILE"

# 5. LaunchAgent plist
cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$BIN_DIR/battery-drain-monitor</string>
        <string>--once</string>
    </array>
    <key>StartInterval</key>
    <integer>300</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$STATE_DIR/launchd.out.log</string>
    <key>StandardErrorPath</key>
    <string>$STATE_DIR/launchd.err.log</string>
</dict>
</plist>
EOF
echo "    plist   → $PLIST_PATH"

# 6. Load (or reload) LaunchAgent
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load   "$PLIST_PATH"
echo "    LaunchAgent loaded (runs every 5 min)"

# 7. First run
echo "==> Running first collection (~3s)..."
"$BIN_DIR/battery-drain-monitor" --once
echo "==> Done! Open your dashboard:"
echo "    open $REPORT_DIR/index.html"
