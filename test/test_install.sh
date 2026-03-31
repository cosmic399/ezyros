#!/bin/bash
# EasyROS2 — Automated Test Suite
set -uo pipefail

PASS=0
FAIL=0
SCRIPT="$(dirname "$0")/../install.sh"

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

pass() {
  echo -e "  ${GREEN}[PASS]${NC} $1"
  PASS=$((PASS + 1))
}

fail() {
  echo -e "  ${RED}[FAIL]${NC} $1"
  FAIL=$((FAIL + 1))
}

header() {
  echo -e "\n${CYAN}${BOLD}── $1 ──${NC}"
}

echo ""
echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════╗"
echo "║        EASYROS2 TEST SUITE               ║"
echo "╚══════════════════════════════════════════╝${NC}"
echo ""

# ── TEST 1: File exists and is executable ──
header "File Checks"

if [ -f "$SCRIPT" ]; then
  pass "install.sh exists"
else
  fail "install.sh NOT found at: $SCRIPT"
fi

if [ -x "$SCRIPT" ]; then
  pass "install.sh is executable"
else
  fail "install.sh is NOT executable (run: chmod +x install.sh)"
fi

# ── TEST 2: All 8 steps present ──
header "Step Count Verification"

STEP_COUNT=$(grep -c '^step "' "$SCRIPT" 2>/dev/null || echo 0)
if [ "$STEP_COUNT" -eq 8 ]; then
  pass "All 8 steps found in script"
else
  fail "Expected 8 steps, found: $STEP_COUNT"
fi

# ── TEST 3: Required commands / patterns present ──
header "Required Pattern Checks"

check_pattern() {
  local desc="$1"
  local pattern="$2"
  if grep -qE "$pattern" "$SCRIPT" 2>/dev/null; then
    pass "$desc"
  else
    fail "$desc — pattern not found: $pattern"
  fi
}

check_pattern "lsb_release check present"            "lsb_release"
check_pattern "apt lock wait loop present"           "fuser /var/lib/dpkg/lock-frontend"
check_pattern "ros2-apt-source download present"     "ros2-apt-source"
check_pattern "setup.bash verification present"      'setup\.bash'
check_pattern "bashrc idempotent write (grep -qxF)"  "grep -qxF"
check_pattern "set -euo pipefail present"            "set -euo pipefail"
check_pattern "Logging to LOG_FILE present"          "tee -a.*LOG_FILE"
check_pattern "Step progress tracker present"        'CURRENT_STEP=\$\(\(CURRENT_STEP \+ 1\)\)'
check_pattern "fail() function defined"              "^fail\(\)"
check_pattern "warn() function defined"              "^warn\(\)"
check_pattern "ok() function defined"                "^ok\(\)"
check_pattern "EUID root check present"              'EUID.*-eq.*0'
check_pattern "Internet connectivity check present"  "curl.*google"
check_pattern "Disk space check present"             "FREE_GB"
check_pattern "rosdep init present"                  "rosdep init"
check_pattern "Workspace creation present"           'WORKSPACE=.*ros2_ws'

# ── TEST 4: Bash syntax check ──
header "Syntax Check"

if bash -n "$SCRIPT" 2>/dev/null; then
  pass "bash -n install.sh — syntax OK"
else
  SYNTAX_ERR=$(bash -n "$SCRIPT" 2>&1)
  fail "bash -n install.sh — syntax ERRORS: $SYNTAX_ERR"
fi

# ── TEST 5: No hardcoded distro names ──
header "Hardcoded Distro Name Check"

# Check apt/install commands don't hardcode distro names (assignment in case statement is OK)
HARDCODED_APT=$(grep -v '#' "$SCRIPT" | grep -E 'apt install|apt-get install' | grep -E 'ros-(humble|iron|jazzy)-' 2>/dev/null | wc -l)
if [ "$HARDCODED_APT" -eq 0 ]; then
  pass "No hardcoded distro names in apt commands — uses \$ROS_DISTRO"
else
  fail "Found $HARDCODED_APT hardcoded distro name(s) in apt command(s) — must use \$ROS_DISTRO"
fi

# Verify $ROS_DISTRO is actually used
if grep -q '\$ROS_DISTRO\|${ROS_DISTRO}' "$SCRIPT" 2>/dev/null; then
  pass "\$ROS_DISTRO variable is used in script"
else
  fail "\$ROS_DISTRO variable not found in script"
fi

# ── TEST 6: TOTAL_STEPS consistency ──
header "Step Counter Consistency"

DECLARED_TOTAL=$(grep 'TOTAL_STEPS=' "$SCRIPT" | head -1 | grep -oE '[0-9]+' || echo 0)
if [ "$DECLARED_TOTAL" -eq 8 ]; then
  pass "TOTAL_STEPS=8 declared correctly"
else
  fail "TOTAL_STEPS=$DECLARED_TOTAL — expected 8"
fi

# ── TEST 7: bashrc guard uses grep -qxF (exact match) ──
header "Idempotency Guard"

GUARD_COUNT=$(grep -c "grep -qxF" "$SCRIPT" 2>/dev/null || echo 0)
if [ "$GUARD_COUNT" -ge 4 ]; then
  pass "bashrc idempotency guards present ($GUARD_COUNT guards)"
else
  fail "Expected ≥4 grep -qxF guards, found: $GUARD_COUNT"
fi

# ── SUMMARY ──
echo ""
echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
TOTAL=$((PASS + FAIL))
echo -e "  Results: ${GREEN}${PASS} passed${NC} / ${RED}${FAIL} failed${NC} / ${TOTAL} total"
echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ "$FAIL" -eq 0 ]; then
  echo -e "  ${GREEN}${BOLD}ALL TESTS PASSED ✓${NC}"
  exit 0
else
  echo -e "  ${RED}${BOLD}${FAIL} TEST(S) FAILED ✗${NC}"
  exit 1
fi
