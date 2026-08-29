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

    // Icon name -> resolved path. Quickshell.iconPath is a theme lookup, which
    // means stat()ing its way down the inherits chain, and the launcher asks for
    // up to five of them on every keystroke - on the GUI thread, at the exact
    // moment the deal animation is starting. The answer cannot change while the
    // shell is up, so it is only ever paid for once per icon.
    property var iconCache: ({})

    function icon(name: string): string {
        if (!name)
            return "";
        const hit = root.iconCache[name];
        if (hit !== undefined)
            return hit;
        const path = Quickshell.iconPath(name, true);
        root.iconCache[name] = path;
        return path;
    }

    // Desktop-entry id -> entry, for resolving the tray's slots. Built off `all`,
    // so a held app whose .desktop has gone away resolves to nothing and its slot
    // simply shows empty rather than holding an id that can no longer be played.
    readonly property var byId: {
        const m = ({});
        for (const e of root.all)
            m[e.id] = e;
        return m;
    }

    // The tray's five slots: desktop-entry ids, null where the slot is empty.
    // Fixed length on purpose - the tray is always five wide, so a hole in the
    // middle is somewhere to drop a card, not a gap to be closed up.
    property var held: [null, null, null, null, null]

    readonly property var heldEntries: root.held.map(id => id ? (root.byId[id] ?? null) : null)

    // Put an app in a slot. An app already in the tray moves rather than being
    // held twice: five slots is little enough that a duplicate costs you a real
    // one, and there is no reading of "the same app in seats 2 and 4" that helps.
    function hold(entry: var, slot: int): void {
        if (!entry || slot < 0 || slot >= root.held.length)
            return;

        const next = root.held.slice();
        for (let i = 0; i < next.length; i++)
            if (next[i] === entry.id)
                next[i] = null;
        next[slot] = entry.id;

        root.held = next;
        heldFile.setText(JSON.stringify(root.held));
    }

    function release(slot: int): void {
        if (slot < 0 || slot >= root.held.length || !root.held[slot])
            return;

        const next = root.held.slice();
        next[slot] = null;

        root.held = next;
        heldFile.setText(JSON.stringify(root.held));
    }

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
        //
        // Minus whatever is in the tray. Those five are already on screen and
        // already reachable in one keystroke, so dealing them again would spend
        // the table showing you what the corner is showing you - the hand's job
        // with nothing typed is everything else you use. Only here: a typed bet
        // is a search, and a search that hides the app you asked for because you
        // happen to hold it is a search that is wrong.
        if (q === "") {
            const held = root.held.filter(id => id);
            return root.all.filter(e => !held.includes(e.id)).sort((a, b) => root.frecency(b.id, now) - root.frecency(a.id, now) || a.name.localeCompare(b.name));
        }

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

    // The tray, beside the scorecard. Same shape of thing and the same handling
    // of a bad one - except that this is a file somebody might reasonably want to
    // write by hand, so anything that is not five slots of id-or-null is padded
    // and truncated into that rather than thrown away.
    FileView {
        id: heldFile

        path: Quickshell.statePath("held.json")
        printErrors: false

        onLoaded: {
            let raw = [];
            try {
                raw = JSON.parse(heldFile.text()) ?? [];
            } catch (e) {
                raw = [];
            }

            if (!Array.isArray(raw))
                raw = [];

            const held = [];
            for (let i = 0; i < 5; i++) {
                const id = raw[i];
                held.push(typeof id === "string" && id !== "" ? id : null);
            }

            root.held = held;
        }
    }
}
