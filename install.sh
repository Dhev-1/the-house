#!/usr/bin/env bash
# Copy dotfiles into place.  No symlinks, on purpose: once this finishes, the
# repo and your live config are two independent copies.  Editing ~/.config
# never dirties this git tree, and `git checkout` never changes your desktop.
# The tradeoff is that changes flow one way only - re-run this to push the
# repo's version out, and copy by hand when you want to bring changes back in.
#
# Usage: ./install.sh            # copy everything
#        ./install.sh hypr kitty # copy only named packages
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"

PACKAGES=(hypr kitty rofi btop gtk kvantum qt6ct starship icons)
[ "$#" -gt 0 ] && PACKAGES=("$@")

BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
backed_up=0

# Copy one package's tree into $HOME, preserving its relative layout
# (home/hypr/.config/hypr/... -> ~/.config/hypr/...).
copy_pkg() {
  local pkg="$1" src="home/$1" f rel dest
  if [ ! -d "$src" ]; then
    echo "   !! no such package: $pkg" >&2
    return 1
  fi
  while IFS= read -r -d '' f; do
    rel="${f#"$src"/}"
    dest="$HOME/$rel"

    # A leftover symlink from the old stow-based install has to go first:
    # cp would otherwise follow it and write straight back into the repo.
    if [ -L "$dest" ]; then
      rm "$dest"
    elif [ -e "$dest" ] && ! cmp -s "$f" "$dest"; then
      mkdir -p "$BACKUP/$(dirname "$rel")"
      cp -a "$dest" "$BACKUP/$rel"
      backed_up=$((backed_up + 1))
    fi

    mkdir -p "$(dirname "$dest")"
    cp -a "$f" "$dest"
  done < <(find "$src" -type f -print0)
}

echo ":: copying: ${PACKAGES[*]}"
for pkg in "${PACKAGES[@]}"; do
  copy_pkg "$pkg"
  echo "   - $pkg"
done

# Also a copy, not a path into this repo: the bar is a live part of the
# desktop, and it should not stop working because the repo moved or got
# checked out to an older commit.
if [ -d house ]; then
  dest="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/house"
  if [ -L "$dest" ]; then
    rm "$dest"
  elif [ -d "$dest" ]; then
    mkdir -p "$BACKUP/quickshell"
    cp -a "$dest" "$BACKUP/quickshell/house"
    backed_up=$((backed_up + 1))
    rm -rf "$dest"
  fi
  mkdir -p "$(dirname "$dest")"
  cp -a house "$dest"
  echo "   - house (quickshell) -> $dest"
fi

# GTK on Wayland reads the icon theme from gsettings, not settings.ini, so the
# House icon theme (gold folders) has to be set there too.
if command -v gsettings >/dev/null 2>&1; then
  gsettings set org.gnome.desktop.interface icon-theme 'House-Noir' || true
fi

echo
if [ "$backed_up" -gt 0 ]; then
  echo ":: $backed_up existing file(s) differed and were backed up to:"
  echo "   $BACKUP"
  echo
fi
echo ":: done.  Manual follow-ups:"
echo "   - restart the bar to pick up the copy:  pkill qs; qs -p ~/.config/quickshell/house &"
echo "   - wallpapers are still read from this repo (hyprland.conf: awww img ...);"
echo "     copy them somewhere outside it if you want that dependency gone too."
# door is not copied: the greeter's theme lives under /usr/share, not $HOME, so
# it needs sudo and its own deliberate command. See door/install.sh.
echo "   - the door (SDDM greeter) is separate - it installs system-wide:"
echo "       cd door && ./install.sh"
