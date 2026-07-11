#!/data/data/com.termux/files/usr/bin/bash

# ============================================
# OpenCode on Android - One-Click Setup Script
# ============================================
# Usage: curl -fsSL https://raw.githubusercontent.com/alivinshiva/opencode-android-dev/main/setup.sh | bash
#
# Or download and run:
#   curl -fsSL https://raw.githubusercontent.com/alivinshiva/opencode-android-dev/main/setup.sh -o setup.sh
#   bash setup.sh

set -e

# Error trap
trap 'echo -e "\n${RED}[FAILED]${NC} Something went wrong at line $LINENO."; echo -e "${YELLOW}The automatic installer gave up on you. But don'\''t worry —${NC}"; echo -e "${YELLOW}the manual guide in the README is always there for you."; echo -e "${YELLOW}Think of it as a breakup: the script left, but the docs stayed.${NC}"; echo -e "${YELLOW}Open the README and follow the steps one by one.${NC}\n"; exit 1' ERR

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Helper functions
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
step() { echo -e "\n${CYAN}=> Step $1: $2${NC}"; }

echo -e "${CYAN}"
echo "============================================"
echo "   OpenCode on Android - Setup Script"
echo "============================================"
echo -e "${NC}"
echo "This script will install:"
echo "  - Termux dependencies (libicu, nodejs, git, curl)"
echo "  - proot-distro with Ubuntu"
echo "  - OpenCode AI coding agent"
echo "  - Cloudflare Tunnel for remote access"
echo "  - Convenience scripts"
echo ""
echo "Tested on: Nothing Phone (2) / Android 16"
echo "Works on any ARM64 Android device with Termux"
echo ""

# Check if running in Termux
if [ -z "$TERMUX_VERSION" ] && [ ! -d "/data/data/com.termux" ]; then
    error "This script must be run in Termux, not in a regular terminal."
    error "Install Termux from F-Droid: https://f-droid.org/en/packages/com.termux/"
    exit 1
fi

# Confirm
read -p "Ready to start? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 0
fi

# ============================================
# Step 1: Update Termux packages
# ============================================
step 1 "Updating Termux packages"
pkg update -y && pkg upgrade -y
success "Termux packages updated"

# ============================================
# Step 2: Install dependencies
# ============================================
step 2 "Installing Termux dependencies (libicu, nodejs, git, curl)"
pkg install -y libicu nodejs git curl
success "Dependencies installed"

# Verify node works
if ! command -v node &> /dev/null; then
    error "Node.js installation failed. Try running: pkg install -y nodejs"
    exit 1
fi
success "Node.js $(node -v) verified"

# ============================================
# Step 3: Install proot-distro
# ============================================
step 3 "Installing proot-distro"
pkg install -y proot-distro
success "proot-distro installed"

# ============================================
# Step 4: Install Ubuntu
# ============================================
step 4 "Installing Ubuntu (this may take a few minutes)"
proot-distro install ubuntu
success "Ubuntu installed"

# ============================================
# Step 5: Setup storage access
# ============================================
step 5 "Setting up storage access"
if [ ! -d "$HOME/storage" ]; then
    termux-setup-storage
    warn "If you denied storage permission, run: termux-setup-storage"
else
    success "Storage already set up"
fi

# ============================================
# Step 6: Create ubuntu.sh convenience script
# ============================================
step 6 "Creating convenience script (ubuntu.sh)"
cat > ~/ubuntu.sh << 'UUBUNTU'
#!/data/data/com.termux/files/usr/bin/bash
# Quick launcher for Ubuntu with storage access
# Usage: ~/ubuntu.sh
proot-distro login ubuntu --bind /sdcard:/sdcard -- bash -c "cd /sdcard/projects && bash"
UUBUNTU
chmod +x ~/ubuntu.sh
success "Created ~/ubuntu.sh"

# ============================================
# Step 7: Setup Termux:Widget shortcuts (optional)
# ============================================
step 7 "Setting up home screen shortcut (optional)"
mkdir -p ~/.shortcuts
cp ~/ubuntu.sh ~/.shortcuts/ubuntu.sh
chmod +x ~/.shortcuts/ubuntu.sh
if [ -d "$HOME/.shortcuts" ]; then
    success "Shortcut ready. Install Termux:Widget from F-Droid to use it."
else
    warn "Could not create shortcut. You can create it manually later."
fi

# ============================================
# Step 8: Install OpenCode inside Ubuntu
# ============================================
step 8 "Installing OpenCode inside Ubuntu"
proot-distro login ubuntu --bind /sdcard:/sdcard -- bash -c '
    apt update -qq
    apt install -y -qq curl git >/dev/null 2>&1

    # Install OpenCode
    curl -fsSL https://opencode.ai/install | bash

    # Add to PATH
    echo "export PATH=/data/data/com.termux/files/home/.opencode/bin:\$PATH" >> ~/.bashrc

    echo "OpenCode installed successfully inside Ubuntu"
'
success "OpenCode installed"

# ============================================
# Step 9: Install cloudflared inside Ubuntu
# ============================================
step 9 "Installing Cloudflare Tunnel inside Ubuntu"
proot-distro login ubuntu --bind /sdcard:/sdcard -- bash -c '
    curl -fsSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 -o /usr/local/bin/cloudflared
    chmod +x /usr/local/bin/cloudflared
    echo "cloudflared installed successfully"
'
success "Cloudflare Tunnel installed"

# ============================================
# Step 10: Install SSH server inside Ubuntu
# ============================================
step 10 "Installing SSH server inside Ubuntu"
proot-distro login ubuntu --bind /sdcard:/sdcard -- bash -c '
    apt install -y -qq openssh-server >/dev/null 2>&1

    # Configure SSH for password login
    sed -i "s/#PermitRootLogin.*/PermitRootLogin yes/" /etc/ssh/sshd_config
    sed -i "s/#PasswordAuthentication.*/PasswordAuthentication yes/" /etc/ssh/sshd_config
    sed -i "s/PermitRootLogin prohibit-password/PermitRootLogin yes/" /etc/ssh/sshd_config

    echo "SSH server installed and configured"
'
success "SSH server installed"

# ============================================
# Step 11: Create ssh-start.sh helper
# ============================================
step 11 "Creating SSH + tunnel helper script"
cat > ~/start-server.sh << 'USERVER'
#!/data/data/com.termux/files/usr/bin/bash
# Start SSH server and Cloudflare tunnel
# Usage: ~/start-server.sh

echo "Starting Ubuntu with storage access..."
echo "Inside Ubuntu, run these commands:"
echo ""
echo "  1. Start SSH server:"
echo "     mkdir -p /run/sshd && /usr/sbin/sshd -p 8022"
echo ""
echo "  2. Set password (first time only):"
echo "     passwd"
echo ""
echo "  3. Start Cloudflare tunnel:"
echo "     cloudflared tunnel --url tcp://localhost:8022"
echo ""
echo "  4. SSH from your laptop:"
echo "     ssh root@localhost -o ProxyCommand=\"cloudflared access tcp --hostname YOUR-URL.trycloudflare.com\" -p 8022"
echo ""

proot-distro login ubuntu --bind /sdcard:/sdcard -- bash
USERVER
chmod +x ~/start-server.sh
success "Created ~/start-server.sh"

# ============================================
# Done!
# ============================================
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}   Setup Complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "Quick commands:"
echo ""
echo "  ~/ubuntu.sh          - Enter Ubuntu"
echo "  ~/start-server.sh    - Start SSH + tunnel"
echo ""
echo "Inside Ubuntu:"
echo ""
echo "  cd /sdcard/projects"
echo "  opencode             - Start OpenCode AI"
echo ""
echo "  mkdir -p /run/sshd"
echo "  /usr/sbin/sshd -p 8022    - Start SSH server"
echo "  passwd                     - Set password (first time)"
echo "  cloudflared tunnel --url tcp://localhost:8022  - Start tunnel"
echo ""
echo "From your laptop:"
echo ""
echo "  ssh root@localhost -o ProxyCommand=\"cloudflared access tcp --hostname YOUR-URL.trycloudflare.com\" -p 8022"
echo ""
echo -e "${CYAN}Happy coding! Remember: this was all built at 3am.${NC}"
echo ""
echo -e "${YELLOW}P.S. If this script failed, congratulations — you've discovered${NC}"
echo -e "${YELLOW}the fun part of being a developer. Don't worry, follow the${NC}"
echo -e "${YELLOW}manual guide in the README. Step by step. You'll learn more${NC}"
echo -e "${YELLOW}that way anyway. The script is for the impatient. The manual${NC}"
echo -e "${YELLOW}guide is for the enlightened.${NC}"
echo ""
