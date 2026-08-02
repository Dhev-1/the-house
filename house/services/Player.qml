pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs

// The MPRIS player the music tab controls, when it is running at all.
//
// Only the configured player, not whatever happens to be playing: a video in a
// browser tab is a media player as far as MPRIS is concerned, and the tab is not
// for that.
Singleton {
    id: root

    readonly property MprisPlayer active: Mpris.players.values.find(p => {
        const want = Config.musicPlayer.toLowerCase();
        return (p.dbusName ?? "").toLowerCase().includes(want) || (p.identity ?? "").toLowerCase().includes(want);
    }) ?? null

    readonly property bool available: root.active !== null
}
