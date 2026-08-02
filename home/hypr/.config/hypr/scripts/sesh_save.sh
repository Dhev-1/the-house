#!/bin/bash
# save_session.sh

mkdir -p ~/.config/hypr/sessions

hyprctl clients -j > ~/.config/hypr/sessions/clients.json
hyprctl workspaces -j > ~/.config/hypr/sessions/workspaces.json

echo "Session saved."
