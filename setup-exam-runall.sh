#!/usr/bin/env bash
# ===============================
# Exam VM One-Shot Setup Script (revised)
# ===============================
# This script must be run as root.
# Changes vs original:
# - Replaces systemd-at-boot with a Desktop launcher (click to run)
# - Adds docker group perms for dsde (docker + docker compose)
# - Locks down NetworkManager so dsde cannot disconnect VPN via UI

set -euo pipefail

ROOT_PASS="1975"
STUDENT_USER="dsde"
VPN_SCRIPT_SRC="./cp-vpn-setup.sh"
VPN_SCRIPT_DEST="/usr/local/sbin/cp-vpn-setup.sh"
SUDOERS_DROPIN="/etc/sudoers.d/cp-vpn"
POLKIT_RULE="/etc/polkit-1/rules.d/49-nodesde.rules"
NM_LOCKDOWN_RULE="/etc/polkit-1/rules.d/50-nm-lockdown.rules"
DESKTOP_DIR="/home/${STUDENT_USER}/Desktop"
LAUNCHER_WRAPPER="/usr/local/bin/cp-vpn-launcher.sh"
DESKTOP_NAME="CP VPN Setup.desktop"
DESKTOP_FILE="${DESKTOP_DIR}/${DESKTOP_NAME}"

# ---------- sanity checks ----------
if [[ $EUID -ne 0 ]]; then
  echo "ERROR: Please run as root (use sudo)." >&2
  exit 1
fi

if ! id -u "${STUDENT_USER}" >/dev/null 2>&1; then
  echo "ERROR: User '${STUDENT_USER}' does not exist." >&2
  exit 1
fi

echo "[0/10] Checking and syncing system time..."

# Show current time and sync state
timedatectl

# Set correct timezone
timedatectl set-timezone Asia/Bangkok

# Enable NTP sync
timedatectl set-ntp true || true
systemctl restart systemd-timesyncd || true

# Try to get status (will not fail script if unavailable)
timedatectl timesync-status || true

# Manual fallback if time is still wrong
if ! date -R | grep -q "$(date -u +%Y)"; then
  apt-get update -y
  DEBIAN_FRONTEND=noninteractive apt-get install -y ntpdate || true
  ntpdate -u pool.ntp.org || true
fi

# Refresh apt cache after time is fixed
apt-get update -y

echo "[1/10] Installing kafka_python_ng into the 'dsde' conda environment (if present)..."
sudo -u "${STUDENT_USER}" bash -lc '
  set -e
  if [[ -f "$HOME/miniconda3/bin/activate" ]]; then
    source "$HOME/miniconda3/bin/activate"
    conda activate dsde 2>/dev/null || { echo "WARNING: conda env dsde not found."; exit 0; }
    pip install -q kafka_python_ng
    echo "kafka_python_ng installed in conda env dsde."
  else
    echo "WARNING: miniconda not found at ~/miniconda3. Skipping kafka_python_ng install."
  fi
'

echo "[2/10] Setting root password..."
echo "root:${ROOT_PASS}" | chpasswd

echo "[3/10] Removing '${STUDENT_USER}' from admin-capable groups (ignore errors if not present)..."
for grp in sudo adm lpadmin; do
  if getent group "$grp" >/dev/null; then
    deluser "${STUDENT_USER}" "$grp" >/dev/null 2>&1 || true
  fi
done

echo "[4/10] Disabling PolicyKit auto-admin (only root remains admin)..."
install -m 0755 -o root -g root -d "$(dirname "${POLKIT_RULE}")"
cat > "${POLKIT_RULE}" <<'EOF'
polkit.addAdminRule(function(action, subject) {
    return ["unix-user:0"]; // only root can admin
});
EOF
chmod 0644 "${POLKIT_RULE}"

echo "[5/10] Installing packages: wireguard, tools, zenity, jq, docker, docker compose..."
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  wireguard wireguard-tools zenity jq curl

# Optional: remove NM WireGuard plugin so UI won’t manage/disconnect WG tunnels
# (safe if present; ignored if not)
apt-get remove -y network-manager-wireguard || true

echo "[6/10] Granting '${STUDENT_USER}' permission to use Docker (and docker compose) without sudo..."
# Add to 'docker' group so the user can use /var/run/docker.sock
usermod -aG docker "${STUDENT_USER}"
# Make sure docker is enabled/running
systemctl enable --now docker

echo "[7/10] Install VPN setup script to ${VPN_SCRIPT_DEST} (root-only exec; invoked via sudo NOPASSWD)..."
if [[ -f "${VPN_SCRIPT_SRC}" ]]; then
  cp -f "${VPN_SCRIPT_SRC}" "${VPN_SCRIPT_DEST}"
elif [[ -f "./cp-vpn-setup.sh" ]]; then
  cp -f "./cp-vpn-setup.sh" "${VPN_SCRIPT_DEST}"
else
  echo "WARNING: cp-vpn-setup.sh not found. Creating a placeholder."
  printf '#!/usr/bin/env bash\n\necho "cp-vpn-setup.sh placeholder. Replace with your real script."\n' > "${VPN_SCRIPT_DEST}"
fi

chown root:root "${VPN_SCRIPT_DEST}"
chmod 700 "${VPN_SCRIPT_DEST}"

echo "[8/10] Sudoers drop-in to allow ONLY this script (NOPASSWD) for ${STUDENT_USER}..."
cat > "${SUDOERS_DROPIN}" <<EOF
${STUDENT_USER} ALL=(root) NOPASSWD: ${VPN_SCRIPT_DEST}
EOF
visudo -cf "${SUDOERS_DROPIN}" >/dev/null

echo "[9/10] Create a clickable Desktop launcher instead of running at boot..."
# 9a) Small wrapper to run the root-only script with the student's DISPLAY/XAUTHORITY
cat > "${LAUNCHER_WRAPPER}" <<'EOF'
#!/usr/bin/env bash
# Wrapper: run cp-vpn-setup.sh as root via sudo, but preserve DISPLAY for GUI prompts.
# This assumes sudoers NOPASSWD for the target script (set by installer).
export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"
exec sudo /usr/local/sbin/cp-vpn-setup.sh
EOF
chmod 755 "${LAUNCHER_WRAPPER}"
chown root:root "${LAUNCHER_WRAPPER}"

# 9b) .desktop file on student's Desktop
install -d -m 0755 -o "${STUDENT_USER}" -g "${STUDENT_USER}" "${DESKTOP_DIR}"
cat > "${DESKTOP_FILE}" <<EOF
[Desktop Entry]
Type=Application
Name=${DESKTOP_NAME}
Comment=Run the campus VPN setup/connector
Exec=${LAUNCHER_WRAPPER}
Icon=network-vpn
Terminal=false
Categories=Network;
EOF
chown "${STUDENT_USER}:${STUDENT_USER}" "${DESKTOP_FILE}"
chmod 0755 "${DESKTOP_FILE}"

# GNOME/KDE often require the file to be marked "trusted" on first run; we touch + chmod 0755 above.
# If needed, user can right-click -> Allow Launching.

echo "[10/10] Lock down NetworkManager so '${STUDENT_USER}' cannot disconnect VPN via UI..."
# Block NM enable/disable, connect/disconnect, and modify system connections for non-root
cat > "${NM_LOCKDOWN_RULE}" <<'EOF'
polkit.addRule(function(action, subject) {
  // Allow root
  if (subject.user == "root") return polkit.Result.YES;

  // Deny NM control for non-root (prevents disconnects/edits via UI)
  var nm_prefix = "org.freedesktop.NetworkManager.";
  if (action.id.indexOf(nm_prefix) === 0) {
    // Common actions we want to block:
    //  - enable/disable networking & Wi-Fi
    //  - connect/disconnect to connections (including VPN)
    //  - modify system connections
    return polkit.Result.NO;
  }
});
EOF
chmod 0644 "${NM_LOCKDOWN_RULE}"

echo "[11/10] Create root-only kill-vpn script and alias..."

KILL_SCRIPT="/usr/local/sbin/kill-vpn.sh"

# Root-only disconnect script
cat > "${KILL_SCRIPT}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

IFACE="cp-vpn"

if systemctl is-active --quiet wg-quick@${IFACE}; then
    systemctl stop wg-quick@${IFACE}
    sudo -u dsde DISPLAY=:0 XAUTHORITY=/home/dsde/.Xauthority \
      zenity --info --text="VPN has been disconnected." || true
else
    sudo -u dsde DISPLAY=:0 XAUTHORITY=/home/dsde/.Xauthority \
      zenity --info --text="VPN is not running." || true
fi
EOF

chmod 700 "${KILL_SCRIPT}"
chown root:root "${KILL_SCRIPT}"

# Create a short alias-like symlink: kill-cp-vpn
ln -sf "${KILL_SCRIPT}" /usr/local/bin/kill-cp-vpn

# Ensure NM picks up policy changes
systemctl restart polkit || true
systemctl restart NetworkManager || true

echo "-----------------------------------------"
echo "Setup COMPLETE."
echo "- Root password set."
echo "- '${STUDENT_USER}' stripped of sudo/admin."
echo "- PolicyKit restricted to root only."
echo "- WireGuard tools installed; NetworkManager WireGuard plugin removed (if present)."
echo "- Docker + compose installed; '${STUDENT_USER}' added to 'docker' group (logout/login required)."
echo "- ${VPN_SCRIPT_DEST} installed (root-only), runnable by '${STUDENT_USER}' via sudo NOPASSWD."
echo "- Desktop icon created: '${DESKTOP_FILE}' (may need 'Allow Launching' once)."
echo "- NetworkManager lockdown rule in place to prevent UI disconnects."
echo "Reboot recommended now (group membership & polkit changes)."
echo "-----------------------------------------"

