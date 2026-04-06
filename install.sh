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
echo '  /$$$$$$                                    /$$                  /$$$$$$   /$$$$$$   /$$$$$$  '
echo ' /$$__  $$                                  |__/                 /$$__  $$ /$$__  $$ /$$__  $$ '
echo '| $$  \__/  /$$$$$$   /$$$$$$$ /$$$$$$/$$$$  /$$  /$$$$$$$      |__/  \ $$| $$  \ $$| $$  \ $$'
echo '| $$       /$$__  $$ /$$_____/| $$_  $$_  $$| $$ /$$_____/         /$$$$$/|  $$$$$$$|  $$$$$$$'
echo '| $$      | $$  \ $$|  $$$$$$ | $$ \ $$ \ $$| $$| $$              |___  $$ \____  $$ \____  $$'
echo '| $$    $$| $$  | $$ \____  $$| $$ | $$ | $$| $$| $$             /$$  \ $$ /$$  \ $$ /$$  \ $$'
echo '|  $$$$$$/|  $$$$$$/ /$$$$$$$/| $$ | $$ | $$| $$|  $$$$$$$      |  $$$$$$/|  $$$$$$/|  $$$$$$/'
echo ' \______/  \______/ |_______/ |__/ |__/ |__/|__/ \_______/       \______/  \______/  \______/ '
echo ''
echo '  /$$$$$$  /$$$$$$$$ /$$   /$$  /$$$$$$   /$$$$$$   /$$$$$$$  '
echo ' /$$__  $$|____ /$$/| $$  | $$ /$$__  $$ /$$__  $$ /$$_____/  '
echo '| $$$$$$$$   /$$$$/ | $$  | $$| $$  \__/| $$  \ $$|  $$$$$$   '
echo '| $$_____/  /$$__/  | $$  | $$| $$      | $$  | $$ \____  $$  '
echo '|  $$$$$$$ /$$$$$$$$|  $$$$$$$| $$      |  $$$$$$/ /$$$$$$$/  '
echo ' \_______/|________/ \____  $$|__/       \______/ |_______/   '
echo '                     /$$  | $$                                 '
echo '                    |  $$$$$$/                                 '
echo '                     \______/                                  '
echo ""
echo -e "${NC}${YELLOW}"
echo '________________/\\\____________________________________/\\\\\\\\\\\\________/\\\\\\\\\_____/\\\\\\\\\\\______/\\\\\\\\\_____'
echo ' _______________\/\\\__________________________________/\\\//////////______/\\\////////____/\\\/////////\\\__/\\\///////\\\___'
echo '  _______________\/\\\___________/\\\__/\\\____________/\\\_______________/\\\/____________\//\\\______\///__\/\\\_____\/\\\___'
echo '   __/\\\\\\\\\\\_\/\\\__________\//\\\/\\\____________\/\\\____/\\\\\\\__/\\\_______________\////\\\_________\/\\\\\\\\\\\/____'
echo '    _\///////////__\/\\\\\\\\\_____\//\\\\\_____________\/\\\___\/////\\\_\/\\\__________________\////\\\______\/\\\//////\\\____'
echo '     _______________\/\\\////\\\_____\//\\\______________\/\\\_______\/\\\_\//\\\____________________\////\\\___\/\\\____\//\\\___'
echo '      _______________\/\\\__\/\\\__/\\_/\\\_______________\/\\\_______\/\\\__\///\\\___________/\\\______\//\\\__\/\\\_____\//\\\__'
echo '       _______________\/\\\\\\\\\__\//\\\\/________________\//\\\\\\\\\\\\/_____\////\\\\\\\\\_\///\\\\\\\\\\\/___\/\\\______\//\\\_'
echo '        _______________\/////////____\////___________________\////////////__________\/////////____\///////////_____\///________\///__'
echo -e "${NC}"
echo -e "  ${YELLOW}Zero headaches. Just robotics.${NC}"
echo ""

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
FREE_KB="${FREE_KB:-0}"
FREE_GB=$((FREE_KB / 1024 / 1024))
if [ "$FREE_GB" -lt 5 ]; then
  fail "Not enough disk space. Need 5GB free, have ${FREE_GB}GB."
fi
ok "Disk space OK (${FREE_GB}GB free)"

# Check: apt lock (wait up to 60s)
# BUG FIX: guard fuser — not installed on all minimal Ubuntu images
echo "  Checking apt lock..."
WAIT=0
if command -v fuser &>/dev/null; then
  while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
    if [ $WAIT -ge 60 ]; then
      fail "apt is locked by another process. Try again after reboot."
    fi
    warn "apt is locked, waiting... (${WAIT}s)"
    sleep 5
    WAIT=$((WAIT + 5))
  done
fi
ok "apt lock is free"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# DETECT EXISTING INSTALL — REINSTALL OR UNINSTALL
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

INSTALLED_DISTRO=""
for dir in /opt/ros/*/; do
  if [ -f "${dir}setup.bash" ]; then
    INSTALLED_DISTRO=$(basename "$dir")
    break
  fi
done

if [ -n "$INSTALLED_DISTRO" ]; then
  echo ""
  echo -e "  ${YELLOW}${BOLD}ROS2 '${INSTALLED_DISTRO}' is already installed.${NC}"
  echo ""
  echo -e "  Press ${BOLD}Enter${NC} to reinstall"
  echo -e "  Type  ${BOLD}uninstall${NC} to remove everything"
  echo ""
  read -r -p "  → Your choice: " ACTION || true

  if [ "${ACTION,,}" = "uninstall" ]; then
    echo ""
    echo -e "${RED}${BOLD}━━━ UNINSTALLING ROS2 ${INSTALLED_DISTRO^^} ━━━${NC}"
    echo ""

    echo "  Removing ROS2 packages..."
    sudo apt remove --purge -y "ros-${INSTALLED_DISTRO}-*" ros-dev-tools 2>/dev/null || true
    sudo apt autoremove -y 2>/dev/null || true
    ok "ROS2 packages removed"

    echo "  Removing ROS2 apt repository..."
    sudo rm -f /etc/apt/sources.list.d/ros2*.list \
               /etc/apt/sources.list.d/ros2*.sources 2>/dev/null || true
    sudo rm -f /usr/share/keyrings/ros-archive-keyring.gpg 2>/dev/null || true
    sudo dpkg -r ros2-apt-source 2>/dev/null || true
    sudo apt update -qq 2>/dev/null || true
    ok "ROS2 repository removed"

    echo "  Removing rosdep..."
    sudo rm -rf /etc/ros/rosdep 2>/dev/null || true
    ok "rosdep config removed"

    echo "  Cleaning ~/.bashrc..."
    sed -i "\|source /opt/ros/${INSTALLED_DISTRO}/setup.bash|d" "$HOME/.bashrc"
    sed -i "\|source $HOME/ros2_ws/install/setup.bash|d" "$HOME/.bashrc"
    sed -i '\|source /usr/share/colcon_cd/function/colcon_cd.sh|d' "$HOME/.bashrc"
    sed -i '\|source /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash|d' "$HOME/.bashrc"
    ok "bashrc cleaned"

    echo "  Removing install logs..."
    rm -rf "$HOME/.easyros2" 2>/dev/null || true
    ok "Logs removed"

    echo "  Cleaning stale Python packages..."
    find "$HOME/.local/lib" -maxdepth 3 \
      \( -name "setuptools*" -o -name "pkg_resources*" \) \
      -exec rm -rf {} + 2>/dev/null || true
    ok "Python packages cleaned"

    echo ""
    echo -e "${GREEN}${BOLD}"
    echo "╔══════════════════════════════════════════╗"
    echo "║         UNINSTALL COMPLETE ✓             ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "  ROS2 ${BOLD}${INSTALLED_DISTRO}${NC} has been fully removed."
    echo ""
    echo -e "  ${YELLOW}Workspace ${HOME}/ros2_ws was kept.${NC}"
    echo -e "  To delete it too: ${BOLD}rm -rf ~/ros2_ws${NC}"
    echo ""
    echo -e "  To reinstall: ${BOLD}bash install.sh${NC}"
    echo ""
    exit 0
  fi
  echo ""
  warn "Reinstalling ROS2 ${INSTALLED_DISTRO}..."
fi

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
# BUG FIX: added -r flag to read — prevents backslash mangling user input
if [ "$UBUNTU_CODENAME" = "jammy" ]; then
  echo "  1) ROS2 Humble  (Recommended — LTS until 2027)"
  echo "  2) ROS2 Iron    (Older — EOL but still used)"
  echo ""
  read -r -p "  Enter choice [1-2]: " CHOICE || fail "No input received."
  case $CHOICE in
    1) ROS_DISTRO="humble" ;;
    2) ROS_DISTRO="iron" ;;
    *) fail "Invalid choice: '$CHOICE'" ;;
  esac
elif [ "$UBUNTU_CODENAME" = "noble" ]; then
  echo "  1) ROS2 Jazzy   (Recommended — LTS until 2029)"
  echo ""
  read -r -p "  Enter choice [1]: " CHOICE || fail "No input received."
  case $CHOICE in
    1) ROS_DISTRO="jazzy" ;;
    *) fail "Invalid choice: '$CHOICE'" ;;
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

# BUG FIX: also remove ros2*.sources (new format from ros2-apt-source package)
sudo rm -f /etc/apt/sources.list.d/ros2*.list \
           /etc/apt/sources.list.d/ros2*.sources 2>/dev/null || true
sudo rm -f /usr/share/keyrings/ros-archive-keyring.gpg 2>/dev/null || true
ok "Old ROS2 repo configs cleared"

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

# BUG FIX: use $UBUNTU_CODENAME directly instead of subshell sourcing /etc/os-release
curl -L -o /tmp/ros2-apt-source.deb \
  "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.${UBUNTU_CODENAME}_all.deb" || \
  fail "Could not download ros2-apt-source package"

# BUG FIX: dpkg -i can fail on unmet deps — run apt-get install -f to resolve
sudo dpkg -i /tmp/ros2-apt-source.deb 2>&1 || \
  sudo apt-get install -f -y || \
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

# BUG FIX: don't suppress all rosdep init stderr — only the "already exists" message
sudo rosdep init 2>&1 | grep -v "already exists" || true

# PYTHONNOUSERSITE=1 prevents ~/.local packages from shadowing system
# pkg_resources — fixes Python 3.12 ImpImporter crash on Noble
PYTHONNOUSERSITE=1 rosdep update || true
# rosdep update exits non-zero for EOL distro warnings even on success
# verify by checking the cache was actually written
if [ ! -d "$HOME/.ros/rosdep/sources.cache" ]; then
  fail "rosdep update failed — cache not created."
fi
ok "rosdep database updated"

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

# Add ROS source — always safe, file is guaranteed to exist (verified in step 5)
grep -qxF "$ROS_SOURCE" "$BASHRC" || echo "$ROS_SOURCE" >> "$BASHRC"

# Add workspace source — safe, has 2>/dev/null || true guard
grep -qxF "$WS_SOURCE" "$BASHRC" || echo "$WS_SOURCE" >> "$BASHRC"

# BUG FIX: only add colcon lines if the files actually exist on disk
if [ -f /usr/share/colcon_cd/function/colcon_cd.sh ]; then
  grep -qxF "$COLCON_CD" "$BASHRC" || echo "$COLCON_CD" >> "$BASHRC"
fi

if [ -f /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash ]; then
  grep -qxF "$COLCON_ARG" "$BASHRC" || echo "$COLCON_ARG" >> "$BASHRC"
fi

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
