#!/usr/bin/env bash
# Put the dotfiles in home/ into place, as copies or as GNU Stow symlinks.
#
#   copy   (default) the repo and your live config end up as two independent
#          trees. Editing ~/.config never dirties this one - but changes only
#          flow outward: re-run to push, and copy by hand to bring them back.
#   stow   ~/.config points into this repo. Edits land straight in the tree and
#          `git checkout` changes your desktop, which is the whole point of it.
#          The repo has to stay where it is.
#
# Usage: ./install.sh [--copy | --stow | --unstow] [package ...]
#
#        ./install.sh                    copy everything
#        ./install.sh --stow             symlink everything
#        ./install.sh --stow hypr kitty  symlink only these
#        ./install.sh --unstow           remove the symlinks again
#
# Whatever a mode would overwrite is backed up under ~/.dotfiles-backup first.
set -euo pipefail

cd "$(dirname "$(readlink -f "$0")")"
repo=$PWD

MODE=copy
case "${1:-}" in
  --copy) MODE=copy; shift ;;
  --stow) MODE=stow; shift ;;
  --unstow) MODE=unstow; shift ;;
  -h | --help)
    sed -n '2,18p' "$0" | cut -c3-
    exit 0
    ;;
  -*)
    echo "unknown option: $1  (try --help)" >&2
    exit 2
    ;;
esac

PACKAGES=(hypr kitty rofi btop gtk kvantum qt6ct starship icons)
[ "$#" -gt 0 ] && PACKAGES=("$@")

if [ "$MODE" != copy ] && ! command -v stow >/dev/null 2>&1; then
  echo "!! GNU Stow is not installed:  sudo pacman -S stow" >&2
  exit 1
fi

BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
backed_up=0
quickshell="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/house"

# Every file a package owns, relative to the package root
# (home/hypr/.config/hypr/hyprland.conf -> .config/hypr/hyprland.conf).
pkg_files() {
  find "home/$1" -type f -printf '%P\0'
}

# Is this path a symlink pointing somewhere inside the repo - i.e. one of ours?
ours() {
  [ -L "$1" ] || return 1
  case "$(readlink -f "$1" 2>/dev/null)" in
  "$repo" | "$repo"/*) return 0 ;;
  esac
  return 1
}

# Does this path resolve to somewhere inside the repo, however it got there?
inside_repo() {
  case "$(readlink -f "$1" 2>/dev/null)" in
  "$repo" | "$repo"/*) return 0 ;;
  esac
  return 1
}

# Stow *folds*: where a whole directory belongs to one package it links the
# directory itself, so ~/.config/hypr can be a single link into the repo. Every
# path under it then resolves into the repo too - which means "back up the file
# in $HOME and write the new one" would move the repo's own copy into the
# backup and then copy a file onto itself. Replace any such link on this file's
# way down with a real directory first.
#
# New installs pass --no-folding, but an older stowed install still has them.
unfold() {
  local rel dir path part
  rel=$(dirname "$1")
  [ "$rel" = "." ] && return 0

  path=""
  local IFS=/
  for part in $rel; do
    path="${path:+$path/}$part"
    IFS=$' \t\n'
    if ours "$HOME/$path"; then
      rm "$HOME/$path"
      mkdir -p "$HOME/$path"
    fi
    IFS=/
  done
}

# --- copy ---------------------------------------------------------------------

copy_pkg() {
  local pkg="$1" src="home/$1" rel dest
  if [ ! -d "$src" ]; then
    echo "   !! no such package: $pkg" >&2
    return 1
  fi
  while IFS= read -r -d '' rel; do
    unfold "$rel"
    dest="$HOME/$rel"

    # A leftover symlink from a stow install has to go first: cp would follow
    # it and write straight back into the repo.
    if [ -L "$dest" ]; then
      rm "$dest"
    elif [ -e "$dest" ] && ! cmp -s "$src/$rel" "$dest"; then
      mkdir -p "$BACKUP/$(dirname "$rel")"
      cp -a "$dest" "$BACKUP/$rel"
      backed_up=$((backed_up + 1))
    fi

    # unfold() should have made this impossible. It is checked anyway because
    # the failure mode is writing over the repo's own copy of the file.
    if inside_repo "$dest"; then
      echo "   !! refusing to write through a link into the repo: $rel" >&2
      return 1
    fi

    mkdir -p "$(dirname "$dest")"
    cp -a "$src/$rel" "$dest"
  done < <(pkg_files "$pkg")
}

# --- stow ---------------------------------------------------------------------

stow_pkg() {
  local pkg="$1" src="home/$1" rel dest
  if [ ! -d "$src" ]; then
    echo "   !! no such package: $pkg" >&2
    return 1
  fi

  # Stow aborts rather than overwrite a real file, and it aborts having already
  # linked some of the package. So anything sitting at one of this package's
  # targets is moved into the backup first - which is what makes a first stow
  # over a hand-made config work. Symlinks are left for stow to reuse or replace.
  while IFS= read -r -d '' rel; do
    unfold "$rel"
    dest="$HOME/$rel"
    if [ ! -L "$dest" ] && [ -e "$dest" ] && ! inside_repo "$dest"; then
      mkdir -p "$BACKUP/$(dirname "$rel")"
      mv "$dest" "$BACKUP/$rel"
      backed_up=$((backed_up + 1))
    fi
  done < <(pkg_files "$pkg")

  # --restow rather than --stow, so re-running clears links whose target has
  # since been renamed instead of leaving them dangling.
  # --no-folding: folded, the first package takes the whole shared parent and
  # the next package's unfold() breaks it, dropping the first silently.
  stow --no-folding --restow --dir home --target "$HOME" "$pkg"
}

unstow_pkg() {
  if [ ! -d "home/$1" ]; then
    echo "   !! no such package: $1" >&2
    return 1
  fi
  stow --delete --dir home --target "$HOME" "$1"
}

# --- the quickshell config ----------------------------------------------------
# house/ is not a stow package (it does not live under home/), so it is placed
# by hand either way. Copied, it survives the repo moving or being checked out
# to an older commit; stowed, apply-theme.sh resolves back through the link and
# finds wallpapers/ on its own.

place_house() {
  [ -d house ] || return 0

  if [ -L "$quickshell" ]; then
    rm "$quickshell"
  elif [ -d "$quickshell" ]; then
    mkdir -p "$BACKUP/quickshell"
    cp -a "$quickshell" "$BACKUP/quickshell/house"
    backed_up=$((backed_up + 1))
    rm -rf "$quickshell"
  fi

  mkdir -p "$(dirname "$quickshell")"
  if [ "$MODE" = stow ]; then
    ln -s "$repo/house" "$quickshell"
    echo "   - house (quickshell) -> $quickshell (link)"
  else
    cp -a house "$quickshell"
    echo "   - house (quickshell) -> $quickshell"
  fi
}

# --- go -----------------------------------------------------------------------

if [ "$MODE" = unstow ]; then
  echo ":: unstowing: ${PACKAGES[*]}"
  for pkg in "${PACKAGES[@]}"; do
    unstow_pkg "$pkg"
    echo "   - $pkg"
  done
  # Only if it is ours - a copied house is not something --unstow put there.
  if ours "$quickshell"; then
    rm "$quickshell"
    echo "   - house (quickshell) link removed"
  fi
  echo
  echo ":: done. ~/.dotfiles-backup holds whatever was displaced when you stowed."
  exit 0
fi

echo ":: ${MODE}ing: ${PACKAGES[*]}"
for pkg in "${PACKAGES[@]}"; do
  if [ "$MODE" = stow ]; then
    stow_pkg "$pkg"
  else
    copy_pkg "$pkg"
  fi
  echo "   - $pkg"
done

place_house

# qt6ct hands color_scheme_path to QFile as-is, expanding neither ~ nor $HOME,
# so it ships empty and is filled in here. apply-theme.sh rewrites it on every
# table change; this is what themes Qt before the first one. Skipped when stowed
# - the file is a link into the repo and sed would detach it.
qt6ct_conf="${XDG_CONFIG_HOME:-$HOME/.config}/qt6ct/qt6ct.conf"
if [ -f "$qt6ct_conf" ] && [ ! -L "$qt6ct_conf" ]; then
  sed -i "s|^color_scheme_path=.*|color_scheme_path=${XDG_CONFIG_HOME:-$HOME/.config}/qt6ct/colors/house.conf|" "$qt6ct_conf"
fi

# GTK on Wayland reads the icon theme from gsettings, not settings.ini, so the
# House icon theme (gold folders) has to be set there too.
if command -v gsettings >/dev/null 2>&1; then
  gsettings set org.gnome.desktop.interface icon-theme 'House-Noir' || true
fi

echo
if [ "$backed_up" -gt 0 ]; then
  echo ":: $backed_up existing file(s) were displaced and backed up to:"
  echo "   $BACKUP"
  echo
fi
echo ":: done.  Manual follow-ups:"
echo "   - restart the bar:  pkill qs; qs -p ~/.config/quickshell/house &"
if [ "$MODE" = stow ]; then
  echo "   - the repo is now load-bearing: moving or deleting it breaks the links."
  echo "     ./install.sh --unstow undoes this."
else
  echo "   - wallpapers are still read from this repo (hyprland.conf: awww img ...);"
  echo "     copy them somewhere outside it if you want that dependency gone too."
fi
# door is not handled here: the greeter's theme lives under /usr/share, not
# $HOME, so it needs sudo and its own deliberate command.
echo "   - the door (SDDM greeter) is separate - it installs system-wide:"
echo "       cd door && ./install.sh"
