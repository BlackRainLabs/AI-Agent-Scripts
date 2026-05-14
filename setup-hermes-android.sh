#!/data/data/com.termux/files/usr/bin/bash
#
# Hermes Agent Management
# Persistent Termux + Hermes AI Agent + SSH Setup Script for Android
#
# Version: 1.0.0
# Purpose: One-shot deployment of a fully persistent Hermes AI Agent environment
#          on Android via Termux, with always-on SSH remote management.
#
# Usage (Interactive Step-by-Step):
#   1. Install Termux from F-Droid (https://f-droid.org/packages/com.termux/)
#   2. Open Termux and run the script (or curl ... | bash)
#   3. The script will pause after each major phase. Press [Enter] to proceed.
#   4. Follow on-screen prompts (especially the SSH password setup).
#   5. Install Termux:Boot app + disable battery optimizations (see final instructions).
#
# This script is idempotent-friendly and safe to re-run.
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[Hermes Agent Mgmt]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Interactive pause helper - user must press Enter to proceed
pause() {
    echo
    read -rp ">>> Press [Enter] to continue to the next step... " _
    echo
}

echo "=================================================="
echo "   Hermes Agent Management :: Android Deployment"
echo "   Persistent Termux + Hermes AI + SSH"
echo "=================================================="
echo

log "Phase 1: Preparing Termux base environment..."

# Update Termux and install core packages first (SSH + essentials)
pkg update -y && pkg upgrade -y
pkg install -y \
    openssh \
    git \
    curl \
    termux-api \
    termux-services \
    tmux \
    ripgrep \
    ffmpeg

success "Core packages installed (openssh, git, curl, termux-api, tmux, etc.)"

pause

# Optional but recommended: Setup shared storage access
if command -v termux-setup-storage &> /dev/null; then
    log "Setting up Termux storage access..."
    termux-setup-storage || warn "Storage setup skipped or already configured."
fi

log "Phase 2: Configuring SSH access for remote management..."

# Set password for SSH (interactive prompt - choose a strong one)
echo
warn "You will now be prompted to set a password for SSH login."
warn "Choose a strong, unique password. This is required for initial access."
echo
passwd

# Ensure sshd host keys exist (sshd will generate on first start if missing)
if [ ! -f "$PREFIX/etc/ssh/ssh_host_rsa_key" ]; then
    log "Generating SSH host keys..."
    ssh-keygen -A || true
fi

# Start sshd immediately for testing (will also be started on boot)
log "Starting sshd for immediate testing..."
pkill sshd 2>/dev/null || true
sshd

success "SSH configured and sshd is now running on port 8022"

pause

log "Phase 3: Installing Hermes AI Agent (official installer)..."

warn "This step will install Hermes and its dependencies (Python, Node.js, build tools, etc.). It can take several minutes."
warn "The official installer will handle everything for Termux automatically."

pause

# The official Hermes installer auto-detects Termux and handles:
# - Additional pkg installs (python, nodejs, clang, rust, etc.)
# - Virtual environment creation
# - Installation of [termux] extra with constraints
# - Linking 'hermes' binary into $PREFIX/bin
curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash

success "Hermes AI Agent installed successfully"

pause

log "Phase 4: Establishing persistence (boot script + wake-lock)..."

# Create boot directory for Termux:Boot app
mkdir -p "$HOME/.termux/boot"

# Create the persistent startup script
cat > "$HOME/.termux/boot/hermes-persistent-startup.sh" << 'BOOTEOF'
#!/data/data/com.termux/files/usr/bin/sh
#
# Hermes Agent Management - Boot Persistence Script
# This runs automatically when the device boots (via Termux:Boot app)
#

# Acquire wake-lock so Android does not suspend Termux / Hermes
termux-wake-lock

# Start SSH daemon so you can always remote in
sshd

# Optional: Launch a detached tmux session with Hermes gateway or CLI
# Uncomment/adapt if you want Hermes to auto-start in background
# tmux new-session -d -s hermes-agent 'hermes gateway' 2>/dev/null || true

echo "[Hermes] Persistent environment activated: SSH ready + wake-lock held."
BOOTEOF

chmod +x "$HOME/.termux/boot/hermes-persistent-startup.sh"

success "Boot persistence script created at ~/.termux/boot/hermes-persistent-startup.sh"

pause

# Also add wake-lock to .bashrc for when user opens Termux manually
if ! grep -q "termux-wake-lock" "$HOME/.bashrc" 2>/dev/null; then
    echo 'termux-wake-lock' >> "$HOME/.bashrc"
    success "Added wake-lock to ~/.bashrc for interactive sessions"
fi

log "Phase 5: Final verification and cleanup..."

# Quick sanity checks
if command -v hermes &> /dev/null; then
    success "Hermes binary is available in PATH"
else
    warn "Hermes command not immediately in PATH. You may need to restart Termux or run 'source ~/.bashrc'"
fi

if pgrep -x sshd > /dev/null; then
    success "sshd is running"
else
    warn "sshd not detected as running (may still work on next boot)"
fi

echo
echo "=================================================="
echo "           DEPLOYMENT COMPLETE"
echo "=================================================="
echo
success "Hermes AI Agent is now installed with persistent SSH access."
echo
echo ">>> POST-SETUP INSTRUCTIONS (Hermes Agent Management) <<<"
echo
echo "1. INSTALL Termux:Boot APP (Critical for persistence)"
echo "   - Get it from F-Droid or https://github.com/termux/termux-boot/releases"
echo "   - Open the app once (it registers the boot receiver)"
echo
echo "2. DISABLE BATTERY OPTIMIZATIONS (Very Important)"
echo "   - Android Settings → Apps → Termux → Battery → Unrestricted"
echo "   - Same for 'Termux:Boot' app"
echo "   - This prevents Android from killing the agent/SSH in background"
echo
echo "3. REBOOT YOUR DEVICE"
echo "   - After reboot, the boot script will auto-start sshd + wake-lock"
echo
echo "4. CONNECT VIA SSH (from your computer or another device)"
echo "   Find your phone's IP:"
echo "     ip -4 addr show wlan0 | grep inet"
echo "   Then connect:"
echo "     ssh $(whoami)@YOUR_PHONE_IP -p 8022"
echo "   Use the password you set earlier."
echo
echo "5. VERIFY HERMES"
echo "   Once SSH'd in (or in Termux app):"
echo "     hermes doctor"
echo "     hermes version"
echo "     hermes setup          # Run the interactive setup wizard"
echo "     hermes model          # Configure your LLM provider (OpenRouter, Ollama, etc.)"
echo
echo "6. OPERATIONAL NOTES"
echo "   - Use 'tmux' for persistent sessions inside SSH"
echo "   - Run 'hermes' for interactive agent chat"
echo "   - For background/agent mode, explore 'hermes gateway' or the web dashboard"
echo "   - Termux:API is installed → Hermes can use SMS, camera, sensors, etc."
echo "   - Re-run this script anytime to update/repair"
echo
echo "7. SECURITY RECOMMENDATIONS"
echo "   - After first SSH login, set up key-based auth:"
echo "       ssh-keygen -t ed25519   (on your client)"
echo "       ssh-copy-id -p 8022 $(whoami)@PHONE_IP"
echo "     Then edit sshd_config to disable password auth if desired."
echo "   - Keep Termux and Hermes updated: hermes update (when available)"
echo
echo "Hermes Agent Management :: Your persistent AI agent is now live on Android."
echo "You can now manage and interact with it remotely via SSH from anywhere."
echo
echo "For issues: Run 'hermes doctor' and share output."
echo "=================================================="

# Optional: Start a welcome tmux session hint
echo
log "Tip: Run 'tmux new -s hermes' to start a persistent tmux session for Hermes work."
echo

exit 0