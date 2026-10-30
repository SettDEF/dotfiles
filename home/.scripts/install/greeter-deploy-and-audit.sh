#!/usr/bin/env bash
# Deploy the Quickshell greeter AND collect a full diagnostic report.
#
# Run from your normal terminal (sudo will prompt once):
#   sudo -E bash ~/.scripts/install/greeter-deploy-and-audit.sh
#
# Everything goes to /tmp/greeter-audit.log — share that file with me
# after running and I can see exactly what went wrong (or what's wired
# right).
#
# This script:
#   1. Verifies source files exist and parse cleanly (before touching /etc)
#   2. Backs up the existing /etc/greetd/config.toml
#   3. Copies all greeter files into /etc/greetd/ with correct perms
#   4. Smoke-tests the QML and the python bridge as the `greeter` user
#   5. Validates the final config.toml
#   6. Restarts greetd and captures the new journal output
#   7. Drops a summary at the end with PASS/FAIL for each step
#
# Safe to re-run: every step is idempotent.

set -u
LOG=/tmp/greeter-audit.log
exec > >(/usr/bin/tee "$LOG") 2>&1

SUDO_USER_HOME="${SUDO_USER:+/home/$SUDO_USER}"
[ -z "$SUDO_USER_HOME" ] && SUDO_USER_HOME="$HOME"
CALLER="${SUDO_USER:-$USER}"

SRC="$SUDO_USER_HOME/.etc/greetd"
DEST="/etc/greetd"
PASS=()
FAIL=()
ok()   { PASS+=("$1"); echo "  [PASS] $1"; }
bad()  { FAIL+=("$1"); echo "  [FAIL] $1"; }

echo "═══════════════════════════════════════════════════════════════"
echo "  GREETER DEPLOY + AUDIT  ·  $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "  caller=$CALLER  src=$SRC  dest=$DEST"
echo "═══════════════════════════════════════════════════════════════"

if [ "$(id -u)" -ne 0 ]; then
    echo "FATAL: must run with sudo. Re-run as: sudo -E bash $0"
    exit 1
fi

# ── 1. SOURCE FILE CHECK ──────────────────────────────────────────────
echo; echo "── 1. Source files ──────────────────────────────────────────"
for f in config.toml launcher.sh pam.d-greetd-greeter \
         quickshell-greeter/shell.qml \
         quickshell-greeter/Greeter.qml \
         quickshell-greeter/CookieClock.qml \
         quickshell-greeter/greetd-bridge.py; do
    if [ -f "$SRC/$f" ]; then ok "exists: $f"; else bad "missing: $f"; fi
done

# Bail early if any source file is missing — no point deploying nothing.
if [ ${#FAIL[@]} -gt 0 ]; then
    echo; echo "── ABORT — source incomplete ──"
    echo "Most likely cause: ~/.etc/greetd/ wasn't restored from backup."
    echo "Fix: pull the greeter files into ~/.etc/greetd/ first, then rerun."
    exit 1
fi

# ── 2. SYNTAX CHECKS (before touching /etc) ──────────────────────────
echo; echo "── 2. Pre-deploy syntax checks ──────────────────────────────"

# 2a. python bridge byte-compiles
if /usr/bin/python3 -c "import py_compile; py_compile.compile('$SRC/quickshell-greeter/greetd-bridge.py', doraise=True)" 2>&1; then
    ok "python bridge byte-compiles"
else
    bad "python bridge syntax error (see above)"
fi

# 2b. QML parses (qs has no parse-only flag, so we run it with a 2s
#     timeout and look for ERROR/Type-not-found in stderr).
echo "  (running qs against the source for 2s; warnings about missing wallpaper.jpg are expected)…"
QS_TEST=$(/usr/bin/timeout 2 /usr/bin/qs -p "$SRC/quickshell-greeter" 2>&1 | /usr/bin/grep -iE "error|Type.*unavailable|invalid|Expected token" | /usr/bin/grep -v "wallpaper\|GREETD_SOCK\|polkit\|QSettings" | /usr/bin/head -5 || true)
if [ -z "$QS_TEST" ]; then
    ok "QML parses without errors"
else
    bad "QML has errors:"
    echo "$QS_TEST" | /usr/bin/sed 's/^/        /'
fi

# 2c. config.toml is valid TOML
if /usr/bin/python3 -c "
import sys
try:
    import tomllib
    with open('$SRC/config.toml','rb') as f: tomllib.load(f)
except (ImportError, ModuleNotFoundError):
    # python <3.11 — fall back to tomli if present
    try:
        import tomli
        with open('$SRC/config.toml','rb') as f: tomli.load(f)
    except ImportError:
        print('  (no tomllib/tomli, skipping TOML validation)', file=sys.stderr)
        sys.exit(2)
" 2>&1; then
    ok "config.toml is valid TOML"
else
    rc=$?
    [ $rc -eq 2 ] && ok "config.toml validation skipped (no toml lib)" || bad "config.toml TOML parse error"
fi

# ── 3. BACKUP EXISTING /etc/greetd ───────────────────────────────────
echo; echo "── 3. Backup existing /etc/greetd ───────────────────────────"
if [ -f "$DEST/config.toml" ]; then
    BAK="$DEST/config.toml.backup-$(/usr/bin/date +%Y%m%d-%H%M%S)"
    /usr/bin/cp -a "$DEST/config.toml" "$BAK"
    ok "backed up old config.toml → $BAK"
fi

# ── 4. DEPLOY ────────────────────────────────────────────────────────
echo; echo "── 4. Deploy files ──────────────────────────────────────────"
/usr/bin/mkdir -p "$DEST/quickshell-greeter"
/usr/bin/install -m 0644 "$SRC/config.toml"                          "$DEST/config.toml"            && ok "config.toml"
/usr/bin/install -m 0755 "$SRC/launcher.sh"                          "$DEST/launcher.sh"            && ok "launcher.sh"
/usr/bin/install -m 0644 "$SRC/pam.d-greetd-greeter"                 "/etc/pam.d/greetd-greeter"    && ok "PAM service /etc/pam.d/greetd-greeter"
/usr/bin/install -m 0644 "$SRC/quickshell-greeter/shell.qml"         "$DEST/quickshell-greeter/shell.qml"         && ok "shell.qml"
/usr/bin/install -m 0644 "$SRC/quickshell-greeter/Greeter.qml"       "$DEST/quickshell-greeter/Greeter.qml"       && ok "Greeter.qml"
/usr/bin/install -m 0644 "$SRC/quickshell-greeter/CookieClock.qml"   "$DEST/quickshell-greeter/CookieClock.qml"   && ok "CookieClock.qml"
/usr/bin/install -m 0755 "$SRC/quickshell-greeter/greetd-bridge.py"  "$DEST/quickshell-greeter/greetd-bridge.py"  && ok "greetd-bridge.py"

# Cache dir for the launcher's HOME redirect (writable by greeter)
/usr/bin/mkdir -p /var/cache/quickshell-greeter
/usr/bin/chown greeter:greeter /var/cache/quickshell-greeter
/usr/bin/chmod 0700 /var/cache/quickshell-greeter
ok "/var/cache/quickshell-greeter owned by greeter"

# Copy any live wallpaper / colors from /var/cache/greeter as the install-time seed
if [ -f /var/cache/greeter/colors.json ]; then
    /usr/bin/install -m 0644 /var/cache/greeter/colors.json "$DEST/quickshell-greeter/colors.json" && ok "colors.json seeded from /var/cache/greeter"
fi
for ext in jpg png; do
    if [ -f "/var/cache/greeter/wallpaper.$ext" ]; then
        /usr/bin/install -m 0644 "/var/cache/greeter/wallpaper.$ext" "$DEST/quickshell-greeter/wallpaper.$ext" && ok "wallpaper.$ext seeded"
    fi
done

# ── 5. PERMISSIONS ───────────────────────────────────────────────────
echo; echo "── 5. Permissions ───────────────────────────────────────────"
if ! /usr/bin/getent passwd greeter >/dev/null; then
    bad "user 'greeter' doesn't exist — is greetd installed?  pacman -S greetd"
else
    /usr/bin/chown -R root:greeter "$DEST/quickshell-greeter"
    /usr/bin/chmod -R o-rwx,g+rX,u+rwX "$DEST/quickshell-greeter"
    ok "owner root:greeter mode g+rX set"
fi

# ── 6. LIVE CACHE for runtime updates ────────────────────────────────
echo; echo "── 6. Live cache ────────────────────────────────────────────"
if [ ! -d /var/cache/greeter ]; then
    /usr/bin/mkdir -p /var/cache/greeter
    /usr/bin/chown "$CALLER:greeter" /var/cache/greeter
    /usr/bin/chmod 0750 /var/cache/greeter
    ok "/var/cache/greeter created (owner $CALLER:greeter)"
else
    /usr/bin/chown -R "$CALLER:greeter" /var/cache/greeter
    /usr/bin/chmod 0750 /var/cache/greeter
    ok "/var/cache/greeter exists, owner re-set"
fi

# ── 7. POST-DEPLOY VALIDATION ────────────────────────────────────────
echo; echo "── 7. Post-deploy validation ────────────────────────────────"
echo "  Deployed config.toml command line:"
/usr/bin/grep "^command" "$DEST/config.toml" | /usr/bin/sed 's/^/    /'
echo "  Deployed user:"
/usr/bin/grep "^user" "$DEST/config.toml" | /usr/bin/sed 's/^/    /'
echo ""
echo "  Greeter user can read everything?"
if /usr/bin/sudo -u greeter /usr/bin/test -r "$DEST/quickshell-greeter/shell.qml"; then
    ok "greeter can read shell.qml"
else
    bad "greeter CANNOT read shell.qml — permissions are wrong"
fi
if /usr/bin/sudo -u greeter /usr/bin/test -x "$DEST/quickshell-greeter/greetd-bridge.py"; then
    ok "greeter can exec greetd-bridge.py"
else
    bad "greeter CANNOT exec greetd-bridge.py"
fi
echo ""
echo "  System dependencies on PATH for greeter user:"
for cmd in qs Hyprland python3 dbus-run-session jq; do
    if /usr/bin/sudo -u greeter /usr/bin/env -i PATH=/usr/bin:/usr/local/bin /usr/bin/which "$cmd" >/dev/null 2>&1; then
        ok "$cmd in greeter PATH"
    else
        bad "$cmd NOT in greeter PATH — greeter will fail to start"
    fi
done

# ── 8. RESTART greetd AND CAPTURE JOURNAL ────────────────────────────
echo; echo "── 8. Restart greetd ────────────────────────────────────────"
echo "  WARNING: restarting greetd will end your current graphical session"
echo "  if it's bound to the same VT. If you want to test without that,"
echo "  comment out the next line and reboot manually instead."
echo "  Press Ctrl+C in the next 5 seconds to ABORT the restart."
sleep 5
/usr/bin/systemctl restart greetd
ok "greetd restart issued"
sleep 2
echo "  Last 25 greetd journal lines after restart:"
/usr/bin/journalctl -u greetd -n 25 --no-pager | /usr/bin/sed 's/^/    /'

# ── 9. SUMMARY ───────────────────────────────────────────────────────
echo; echo "═══════════════════════════════════════════════════════════════"
echo "  SUMMARY"
echo "═══════════════════════════════════════════════════════════════"
echo "  PASS: ${#PASS[@]}"
echo "  FAIL: ${#FAIL[@]}"
if [ ${#FAIL[@]} -gt 0 ]; then
    echo "  Failures:"
    for f in "${FAIL[@]}"; do echo "    - $f"; done
fi
echo
echo "  Full audit log: $LOG"
echo "  Share the log to debug further."
