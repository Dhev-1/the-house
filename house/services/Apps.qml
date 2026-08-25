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

    // Desktop-entry id -> { n, t }: the tally `n` as it stood at epoch-millis `t`.
    // Breaks ties between equal matches and, with nothing typed, is the whole
    // order. Persisted below.
    property var plays: ({})

    // How long a play takes to be worth half of what it was. A week: long enough
    // to survive a weekend away from the machine, short enough that a fortnight
    // of not touching something drops it back into the pack.
    readonly property real halfLife: 7 * 24 * 60 * 60 * 1000

    // What a play from `dt` milliseconds ago is worth now - the reason the tally
    // is a pair and not an integer. A straight count never forgets: the editor
    // you lived in last spring would outrank the one you open every morning until
    // you had out-clicked your own history.
    function decay(dt: real): real {
        return Math.pow(0.5, dt / root.halfLife);
    }

    // The tally for one entry, seen from `now`. Exponential decay composes, so
    // decaying the running total forward from the last play is exactly the sum of
    // every individual play decayed from its own stamp - the pair loses nothing.
    function frecency(id: string, now: real): real {
        const p = root.plays[id];
        if (!p)
            return 0;
        return p.n * root.decay(now - p.t);
    }

    // How well one entry answers `q`, which is already trimmed and lowercased.
    // 0 means it is not in the hand at all.
    //
    // The ladder is deliberately coarse - name beats keyword beats blurb, and
    // ties inside a rung fall through to the tally below. A fuzzy subsequence
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
    // half; scoring is, and it touches every entry either way. A couple of
    // thousand desktop files is milliseconds.
    //
    // One clock reading for the whole deal: a sort whose ordering shifts
    // underneath it has no defined answer.
    function deal(query: string): var {
        const q = query.trim().toLowerCase();
        const now = Date.now();

        // Nothing typed: the regulars, then everyone else alphabetically. This
        // is the state the launcher opens in, so it opens on the five apps you
        // actually use rather than on whatever sorts first.
        if (q === "")
            return root.all.slice().sort((a, b) => root.frecency(b.id, now) - root.frecency(a.id, now) || a.name.localeCompare(b.name));

        return root.all.map(e => ({
                    entry: e,
                    score: root.score(e, q)
                })).filter(m => m.score > 0).sort((a, b) => b.score - a.score || root.frecency(b.entry.id, now) - root.frecency(a.entry.id, now) || a.entry.name.localeCompare(b.entry.name)).map(m => m.entry);
    }

    // Deal one in: bring the old tally forward to now, add the play happening
    // this instant, then hand off to the desktop entry - which knows about
    // Terminal=true and the Exec field codes we would otherwise strip ourselves.
    function play(entry: var): void {
        const now = Date.now();
        const p = root.plays[entry.id];
        const next = Object.assign({}, root.plays);
        next[entry.id] = {
            n: (p ? p.n * root.decay(now - p.t) : 0) + 1,
            t: now
        };
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
            let raw = ({});
            try {
                raw = JSON.parse(playsFile.text()) ?? ({});
            } catch (e) {
                raw = ({});
            }

            // Scorecards written before the tally learned to forget are a plain
            // id -> count with nothing to decay from. Stamping them as of now
            // keeps the regulars you already had, ageing from this run on.
            // Anything of neither shape is not a tally we wrote.
            const now = Date.now();
            const plays = ({});
            let rewrite = false;
            for (const id in raw) {
                const p = raw[id];
                if (typeof p === "number") {
                    plays[id] = {
                        n: p,
                        t: now
                    };
                    rewrite = true;
                } else if (p && typeof p.n === "number" && typeof p.t === "number") {
                    plays[id] = p;
                } else {
                    rewrite = true;
                }
            }

            root.plays = plays;
            // Once, on the run that finds an old file, so the stamp above is the
            // upgrade and not whenever the shell last restarted.
            if (rewrite)
                playsFile.setText(JSON.stringify(root.plays));
        }
    }
}
