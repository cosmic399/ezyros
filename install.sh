#!/bin/bash
set -euo pipefail

VERSION="1.0.0"

# ── COLORS ──────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── BANNER ──────────────────────────────────
clear
echo -e "${CYAN}${BOLD}"
echo "╔══════════════════════════════════════════╗"
echo "║          EASYROS2 INSTALLER              ║"
echo "║       by cosmic399 — NIT Patna           ║"
echo "║   Zero headaches. Just robotics.         ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"

# ── LOGGING ─────────────────────────────────
LOG_DIR="$HOME/.easyros2"
LOG_FILE="$LOG_DIR/install.log"
mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "━━━ Install started: $(date) ━━━"

# ── STEP TRACKER ────────────────────────────
TOTAL_STEPS=8
CURRENT_STEP=0

phase() {
  echo -e "\n${CYAN}${BOLD}◆ $1${NC}"
}

step() {
  CURRENT_STEP=$((CURRENT_STEP + 1))
  echo -e "\n${CYAN}[$CURRENT_STEP/$TOTAL_STEPS]${NC} ${BOLD}$1${NC}"
}

ok() {
  echo -e "  ${GREEN}✓${NC} $1"
}

fail() {
  echo -e "\n${RED}✗ FAILED: $1${NC}"
  echo -e "${YELLOW}→ Log saved at: $LOG_FILE${NC}"
  echo -e "${YELLOW}→ Fix the issue and run: bash install.sh${NC}"
  exit 1
}

warn() {
  echo -e "  ${YELLOW}⚠${NC} $1"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PHASE 0: PRE-FLIGHT CHECKS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

phase "Pre-flight checks"

# Check: not running as root
if [ "$EUID" -eq 0 ]; then
  fail "Do not run as root. Run as normal user with sudo access."
fi
ok "Not running as root"

# Check: Ubuntu only
if ! command -v lsb_release &>/dev/null; then
  fail "This installer only supports Ubuntu Linux."
fi
OS=$(lsb_release -si)
if [ "$OS" != "Ubuntu" ]; then
  fail "This installer only supports Ubuntu. Detected: $OS"
fi
ok "Ubuntu detected"

# Check: internet connectivity
if ! curl -s --max-time 5 https://google.com > /dev/null; then
  fail "No internet connection. Please connect and retry."
fi
ok "Internet connection verified"

# Check: disk space (need at least 5GB free)
FREE_KB=$(df / | tail -1 | awk '{print $4}')
FREE_GB=$((FREE_KB / 1024 / 1024))
if [ "$FREE_GB" -lt 5 ]; then
  fail "Not enough disk space. Need 5GB free, have ${FREE_GB}GB."
fi
ok "Disk space OK (${FREE_GB}GB free)"

# Check: apt lock (wait up to 60s)
echo "  Checking apt lock..."
WAIT=0
while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
  if [ $WAIT -ge 60 ]; then
    fail "apt is locked by another process. Try again after reboot."
  fi
  warn "apt is locked, waiting... (${WAIT}s)"
  sleep 5
  WAIT=$((WAIT + 5))
done
ok "apt lock is free"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DISTRO SELECTION MENU
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

phase "Select ROS2 Distribution"

UBUNTU_CODENAME=$(lsb_release -sc)
UBUNTU_VERSION=$(lsb_release -sr)

echo ""
echo -e "  Detected Ubuntu: ${BOLD}${UBUNTU_VERSION} (${UBUNTU_CODENAME})${NC}"
echo ""
echo "  Available distributions:"
echo ""

# Show only compatible distros based on Ubuntu version
if [ "$UBUNTU_CODENAME" = "jammy" ]; then
  echo "  1) ROS2 Humble  (Recommended — LTS until 2027)"
  echo "  2) ROS2 Iron    (Older — EOL but still used)"
  echo ""
  read -p "  Enter choice [1-2]: " CHOICE
  case $CHOICE in
    1) ROS_DISTRO="humble" ;;
    2) ROS_DISTRO="iron" ;;
    *) fail "Invalid choice." ;;
  esac
elif [ "$UBUNTU_CODENAME" = "noble" ]; then
  echo "  1) ROS2 Jazzy   (Recommended — LTS until 2029)"
  echo ""
  read -p "  Enter choice [1]: " CHOICE
  case $CHOICE in
    1) ROS_DISTRO="jazzy" ;;
    *) fail "Invalid choice." ;;
  esac
else
  fail "Unsupported Ubuntu version: $UBUNTU_CODENAME
  Supported: Ubuntu 22.04 (Jammy) → Humble/Iron
             Ubuntu 24.04 (Noble) → Jazzy"
fi

ok "Selected: ROS2 ${ROS_DISTRO}"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 1: LOCALE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

step "Setting up locale (UTF-8)"

if ! locale | grep -q "UTF-8"; then
  warn "UTF-8 not set. Fixing..."
  sudo apt update -qq
  sudo apt install -y locales
  sudo locale-gen en_US en_US.UTF-8
  sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
  export LANG=en_US.UTF-8
  ok "Locale fixed to UTF-8"
else
  ok "Locale already UTF-8"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 2: WIPE OLD BROKEN ROS2 CONFIGS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

step "Cleaning old ROS2 configurations"

if [ -f /etc/apt/sources.list.d/ros2.list ]; then
  warn "Found old ros2.list — removing..."
  sudo rm -f /etc/apt/sources.list.d/ros2.list
  ok "Old ros2.list removed"
fi

if [ -f /usr/share/keyrings/ros-archive-keyring.gpg ]; then
  warn "Found old GPG key — removing..."
  sudo rm -f /usr/share/keyrings/ros-archive-keyring.gpg
  ok "Old GPG key removed"
fi

# Clean stale user-local Python packages from any previous failed run
# These shadow system pkg_resources and crash rosdep on Python 3.12
if [ -d "$HOME/.local/lib" ]; then
  find "$HOME/.local/lib" -maxdepth 3 \
    \( -name "setuptools*" -o -name "pkg_resources*" \) \
    -exec rm -rf {} + 2>/dev/null || true
  ok "Cleared stale user-local Python packages"
fi

ok "Environment is clean"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 3: SETUP ROS2 REPOSITORY
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

step "Adding ROS2 repository"

sudo apt install -y software-properties-common curl || \
  fail "Could not install curl/software-properties-common"

sudo add-apt-repository universe -y || \
  fail "Could not enable universe repository"

# New official method — ros2-apt-source package
ROS_APT_SOURCE_VERSION=$(curl -s \
  https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest \
  | grep -F "tag_name" | awk -F'"' '{print $4}')

if [ -z "$ROS_APT_SOURCE_VERSION" ]; then
  fail "Could not fetch ros-apt-source version. Check internet."
fi

curl -L -o /tmp/ros2-apt-source.deb \
  "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.$(. /etc/os-release && echo ${UBUNTU_CODENAME:-${VERSION_CODENAME}})_all.deb" || \
  fail "Could not download ros2-apt-source package"

sudo dpkg -i /tmp/ros2-apt-source.deb || \
  fail "Could not install ros2-apt-source package"

ok "ROS2 repository configured"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 4: SYSTEM UPDATE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

step "Updating system packages"

sudo apt update || fail "apt update failed. Check internet."
sudo apt upgrade -y || fail "apt upgrade failed."

ok "System is up to date"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 5: INSTALL ROS2
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

step "Installing ROS2 ${ROS_DISTRO} (this takes 5-15 mins)"

echo "  Installing ros-${ROS_DISTRO}-desktop..."
sudo apt install -y ros-${ROS_DISTRO}-desktop || \
  fail "ROS2 desktop install failed."

echo "  Installing ros-dev-tools..."
sudo apt install -y ros-dev-tools || \
  fail "ros-dev-tools install failed."

# Verify installation
if [ ! -f "/opt/ros/${ROS_DISTRO}/setup.bash" ]; then
  fail "Installation verification failed. setup.bash not found."
fi

ok "ROS2 ${ROS_DISTRO} installed successfully"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 6: INSTALL DEV TOOLS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

step "Installing development tools"

sudo apt install -y \
  python3-colcon-common-extensions \
  python3-rosdep \
  python3-pip \
  python3-argcomplete || \
  fail "Dev tools install failed."

# Pin setuptools only on Ubuntu 22.04 (Jammy/Python 3.10)
# On Ubuntu 24.04 (Noble/Python 3.12) setuptools==58.2.0 breaks rosdep
if [ "$UBUNTU_CODENAME" = "jammy" ]; then
  pip3 install setuptools==58.2.0 --quiet || \
    warn "setuptools pin failed — non critical"
fi

# rosdep init (safe — won't fail if already done)
sudo rosdep init 2>/dev/null || \
  warn "rosdep already initialized — skipping"

# PYTHONNOUSERSITE=1 prevents ~/.local packages from shadowing system
# pkg_resources — fixes Python 3.12 ImpImporter crash on Noble
PYTHONNOUSERSITE=1 rosdep update || fail "rosdep update failed."

ok "Development tools ready"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 7: WORKSPACE SETUP
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

step "Setting up ROS2 workspace"

WORKSPACE="$HOME/ros2_ws"
if [ ! -d "$WORKSPACE" ]; then
  mkdir -p "$WORKSPACE/src"
  ok "Workspace created at $WORKSPACE"
else
  warn "Workspace already exists at $WORKSPACE — skipping"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# STEP 8: CONFIGURE ENVIRONMENT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

step "Configuring shell environment"

BASHRC="$HOME/.bashrc"
ROS_SOURCE="source /opt/ros/${ROS_DISTRO}/setup.bash"
WS_SOURCE="source $WORKSPACE/install/setup.bash 2>/dev/null || true"
COLCON_CD="source /usr/share/colcon_cd/function/colcon_cd.sh"
COLCON_ARG="source /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash"

# Add to bashrc only if not already there
grep -qxF "$ROS_SOURCE" "$BASHRC" || echo "$ROS_SOURCE" >> "$BASHRC"
grep -qxF "$WS_SOURCE" "$BASHRC" || echo "$WS_SOURCE" >> "$BASHRC"
grep -qxF "$COLCON_CD" "$BASHRC" || echo "$COLCON_CD" >> "$BASHRC"
grep -qxF "$COLCON_ARG" "$BASHRC" || echo "$COLCON_ARG" >> "$BASHRC"

ok "Shell environment configured"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DONE
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo ""
echo -e "${GREEN}${BOLD}"
echo "╔══════════════════════════════════════════╗"
echo "║         INSTALLATION COMPLETE ✓          ║"
echo "╚══════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  ROS2 Distro : ${BOLD}${ROS_DISTRO}${NC}"
echo -e "  Workspace   : ${BOLD}${WORKSPACE}${NC}"
echo -e "  Log         : ${BOLD}${LOG_FILE}${NC}"
echo ""
echo -e "  ${YELLOW}Next step: Close and reopen your terminal${NC}"
echo -e "  Then verify with: ${BOLD}ros2 --version${NC}"
echo ""
echo -e "  Built by cosmic399 — EasyROS2 v${VERSION}"
echo ""
