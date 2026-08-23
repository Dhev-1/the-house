pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The shoe: every installed application, ordered for the launcher's hand.
//
// Quickshell already parses the desktop files (DesktopEntries), so this is
// only two things it doesn't do: score an entry against what has been typed,
// and remember what actually gets played. Both are here rather than in
// Launcher.qml so the overlay stays a drawing of a hand and nothing else.
Singleton {
    id: root

    // Everything on the table. noDisplay entries are the ones the spec says to
    // keep out of menus - .desktop files that exist to own a MIME type or a
    // startup hook, not to be launched - so they are not in the shoe at all.
    readonly property var all: DesktopEntries.applications.values.filter(e => !e.noDisplay)

    // Desktop-entry id -> how many times it has been dealt in from here. Breaks
    // ties between equal matches and, with nothing typed, is the whole order:
    // an empty bet deals the house regulars. Persisted below.
    property var plays: ({})

    function timesPlayed(id: string): int {
        return root.plays[id] ?? 0;
    }

    // How well one entry answers `q`, which is already trimmed and lowercased.
    // 0 means it is not in the hand at all.
    //
    // The ladder is deliberately coarse - name beats keyword beats blurb, and
    // ties inside a rung fall through to play count below. A fuzzy subsequence
    // match ("frfx" -> firefox) is not in here: with five seats on the table,
    // loose matching mostly costs you the card you meant to be looking at.
    function score(e: var, q: string): int {
        const name = (e.name ?? "").toLowerCase();
        if (name === q)
            return 100;
        if (name.startsWith(q))
            return 80;
        // A word start inside the name - "code" in "Visual Studio Code".
        if (name.includes(" " + q))
            return 65;
        if (name.includes(q))
            return 50;
        if ((e.genericName ?? "").toLowerCase().includes(q))
            return 35;
        // The binary, not the whole Exec line: matching the full string means
        // typing "u" hits everything launched with a --url flag.
        if ((e.command?.[0] ?? "").toLowerCase().includes(q))
            return 30;
        if ((e.keywords ?? []).some(k => k.toLowerCase().includes(q)))
            return 25;
        if ((e.comment ?? "").toLowerCase().includes(q))
            return 10;
        return 0;
    }

    // The whole shoe for a bet, best first - the launcher deals the top few off
    // it and reports the rest as the count still in the shoe.
    //
    // Sorting the full list rather than stopping at five is not the expensive
    // half; scoring is, and that has to touch every entry either way. A couple
    // of thousand desktop files is milliseconds, and it runs per keystroke on a
    // string that is usually two characters long.
    function deal(query: string): var {
        const q = query.trim().toLowerCase();

        // Nothing typed: the regulars, then everyone else alphabetically. This
        // is the state the launcher opens in, so it opens on the five apps you
        // actually use rather than on whatever sorts first.
        if (q === "")
            return root.all.slice().sort((a, b) => root.timesPlayed(b.id) - root.timesPlayed(a.id) || a.name.localeCompare(b.name));

        return root.all.map(e => ({
                    entry: e,
                    score: root.score(e, q)
                })).filter(m => m.score > 0).sort((a, b) => b.score - a.score || root.timesPlayed(b.entry.id) - root.timesPlayed(a.entry.id) || a.entry.name.localeCompare(b.entry.name)).map(m => m.entry);
    }

    // Deal one in: count the hand, then hand off to the desktop entry, which
    // knows about Terminal=true and the field codes we would otherwise have to
    // strip out of Exec ourselves.
    function play(entry: var): void {
        const next = Object.assign({}, root.plays);
        next[entry.id] = (next[entry.id] ?? 0) + 1;
        root.plays = next;
        playsFile.setText(JSON.stringify(root.plays));
        entry.execute();
    }

    // The scorecard, in quickshell's per-shell state dir alongside theme.json.
    // No watchChanges: nothing else writes this, and every write here is our
    // own, so watching it would only be a reload of what we just said.
    //
    // A missing file is first run, not an error, and a corrupt one is a
    // scorecard - losing it costs the ordering of an empty bet and nothing
    // else, so both fall back to an empty tally rather than complaining.
    FileView {
        id: playsFile

        path: Quickshell.statePath("plays.json")
        printErrors: false

        onLoaded: {
            try {
                root.plays = JSON.parse(playsFile.text()) ?? ({});
            } catch (e) {
                root.plays = ({});
            }
        }
    }
}
