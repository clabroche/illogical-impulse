#!/bin/bash
# Run once with sudo to enable pkexec for pacman updates

POLICY_FILE="/usr/share/polkit-1/actions/org.archlinux.pacman.policy"
YAY_CONFIG="$HOME/.config/yay/config.json"

# ── Polkit action for pacman ───────────────────────────────────────────────────
cat > "$POLICY_FILE" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE policyconfig PUBLIC
 "-//freedesktop//DTD PolicyKit Policy Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/PolicyKit/1/policyconfig.dtd">
<policyconfig>
  <action id="org.archlinux.pacman.update">
    <description>Update system packages</description>
    <message>Authentication is required to update system packages</message>
    <defaults>
      <allow_any>auth_admin</allow_any>
      <allow_inactive>auth_admin</allow_inactive>
      <allow_active>auth_admin</allow_active>
    </defaults>
    <annotate key="org.freedesktop.policykit.exec.path">/usr/bin/pacman</annotate>
    <annotate key="org.freedesktop.policykit.exec.allow_gui">true</annotate>
  </action>
</policyconfig>
EOF

echo "✓ Polkit policy created at $POLICY_FILE"

# ── Configure yay to use pkexec instead of sudo ────────────────────────────────
if command -v yay &>/dev/null; then
    mkdir -p "$(dirname "$YAY_CONFIG")"
    if [ -f "$YAY_CONFIG" ]; then
        # Merge sudoBin into existing config
        tmp=$(mktemp)
        python3 -c "
import json, sys
with open('$YAY_CONFIG') as f:
    cfg = json.load(f)
cfg['sudoBin'] = 'pkexec'
print(json.dumps(cfg, indent=2))
" > "$tmp" && mv "$tmp" "$YAY_CONFIG"
    else
        echo '{"sudoBin": "pkexec"}' > "$YAY_CONFIG"
    fi
    echo "✓ yay configured to use pkexec ($YAY_CONFIG)"
fi

echo "Done. pkexec will now trigger the polkit agent for pacman/yay updates."
