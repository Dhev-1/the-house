#!/usr/bin/env bash
# Install the door as the system's SDDM theme.
#
# Not part of the repo's top-level install.sh, and not a stow package, because
# this is the one piece of the setup that does not live in $HOME: the greeter
# runs as the `sddm` user before any login, so the theme has to sit somewhere
# root-owned and world-readable. That means sudo, and a change to the machine's
# login screen - which is the sort of thing that should be its own deliberate
# command rather than a side effect of setting up dotfiles.
#
# Usage:  ./install.sh          install and make it the active theme
#         ./install.sh --copy   install only; leave the active theme alone
#
# To get out again, point Current= back at whatever was there before - the
# previous value is printed and backed up below.

set -euo pipefail

here=$(dirname "$(readlink -f "$0")")
name=door
dest=/usr/share/sddm/themes/$name
conf=/etc/sddm.conf.d/10-theme.conf

if [ "$(id -u)" -eq 0 ]; then
    echo "run this as yourself, not as root - it calls sudo where it needs to." >&2
    exit 1
fi

# --- the theme itself ---------------------------------------------------------
# --delete so a rename or a removed file does not leave a stale copy behind on
# reinstall; the greeter would happily keep loading it.
echo ":: installing to $dest"
sudo mkdir -p "$dest"
# make-chips.py and its input are build-time things: the greeter only ever loads
# the twelve baked chip-<n><a|b|c>.png files, so shipping the script and the
# master drawing to a root-owned system directory adds nothing the login screen
# can use. They stay in the repo, where you re-run them.
sudo rsync -a --delete \
    --exclude 'install.sh' \
    --exclude 'README.md' \
    --exclude 'make-chips.py' \
    --exclude 'assets/chip-src.png' \
    --exclude 'TestStack.qml' \
    --exclude '.*' \
    "$here"/ "$dest"/

# The greeter runs as a different user than the one that just copied these.
sudo chown -R root:root "$dest"
sudo chmod -R a+rX "$dest"

if [ "${1:-}" = "--copy" ]; then
    echo ":: installed. active theme left alone."
    exit 0
fi

# --- make it the active one ---------------------------------------------------
# A drop-in under /etc/sddm.conf.d rather than an edit to /etc/sddm.conf: the
# drop-in wins over the main file, it is one file to delete to undo all of this,
# and it does not fight the package manager over /etc/sddm.conf on upgrade.
existing=$(grep -rhm1 '^Current=' /etc/sddm.conf /etc/sddm.conf.d/ 2>/dev/null || true)
[ -n "$existing" ] && echo ":: previous theme: ${existing#Current=}"

if [ -f "$conf" ]; then
    sudo cp "$conf" "$conf.bak"
    echo ":: backed up $conf -> $conf.bak"
fi

sudo mkdir -p /etc/sddm.conf.d
sudo tee "$conf" >/dev/null <<EOF
# Written by cloon/newdot/door/install.sh.
# Delete this file (and any .bak beside it) to go back to the previous theme.
[Theme]
Current=$name
EOF

echo ":: done. the door is the active theme."
echo
echo "   preview it without logging out:"
echo "     sddm-greeter-qt6 --test-mode --theme $dest"
echo
echo "   note that in test mode logind refuses every power action, so the chips"
echo "   on the rail are hidden, and sddm.login() reaches no daemon at all - so"
echo "   enter deals the cards and then nothing, neither the bust nor the"
echo "   twenty-one. See the README for how to force a hand."
