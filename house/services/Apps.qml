pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The shoe: every installed application, ordered for the launcher's hand.
//
// Quickshell already parses the desktop files, so this is only the two things
// it doesn't do - score an entry against what has been typed, and remember what
// gets played. Both here rather than in Launcher.qml, which stays a drawing.
Singleton {
    id: root

    // noDisplay entries are the ones the spec says to keep out of menus -
    // .desktop files owning a MIME type or a startup hook rather than something
    // to launch - so they are not in the shoe at all.
    readonly property var all: DesktopEntries.applications.values.filter(e => !e.noDisplay)

    // Icon name -> resolved path. Quickshell.iconPath stat()s its way down the
    // theme's inherits chain, and the launcher asks for five of them per
    // keystroke on the GUI thread, as the deal animation starts. The answer
    // cannot change while the shell is up, so it is paid for once per icon.
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

    // Desktop-entry id -> entry, for the tray's slots. Built off `all`, so a
    // held app whose .desktop has gone away resolves to nothing and its slot
    // shows empty rather than holding an unplayable id.
    readonly property var byId: {
        const m = ({});
        for (const e of root.all)
            m[e.id] = e;
        return m;
    }

    // The tray's five slots, null where empty. Fixed length on purpose: a hole
    // in the middle is somewhere to drop a card, not a gap to close up.
    property var held: [null, null, null, null, null]

    readonly property var heldEntries: root.held.map(id => id ? (root.byId[id] ?? null) : null)

    // Put an app in a slot. One already in the tray moves rather than being
    // held twice - with five slots a duplicate costs a real one.
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

    // How long a play takes to be worth half of what it was.
    readonly property real halfLife: 7 * 24 * 60 * 60 * 1000

    // What a play from `dt` ago is worth now - the reason the tally is a pair
    // and not an integer. A straight count never forgets, so the editor you
    // lived in last spring outranks the one you open every morning.
    function decay(dt: real): real {
        return Math.pow(0.5, dt / root.halfLife);
    }

    // The tally for one entry, seen from `now`. Exponential decay composes, so
    // decaying the running total forward from the last play is exactly the sum
    // of every play decayed from its own stamp - the pair loses nothing.
    function frecency(id: string, now: real): real {
        const p = root.plays[id];
        if (!p)
            return 0;
        return p.n * root.decay(now - p.t);
    }

    // How well one entry answers `q`, already trimmed and lowercased; 0 means
    // not in the hand at all. Deliberately coarse - name beats keyword beats
    // blurb, and ties fall through to the tally. No fuzzy subsequence match
    // ("frfx" -> firefox): with five seats, loose matching costs a real card.
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

    // The whole shoe for a bet, best first. Sorting the full list rather than
    // stopping at five is not the expensive half - scoring is, and it touches
    // every entry either way. One clock reading for the whole deal: a sort
    // whose ordering shifts underneath it has no defined answer.
    function deal(query: string): var {
        const q = query.trim().toLowerCase();
        const now = Date.now();

        // Nothing typed: the regulars, then everyone else alphabetically, minus
        // whatever is in the tray - those five are already on screen and one
        // keystroke away. Only here: a typed bet is a search, and one that hides
        // the app you asked for because you hold it is wrong.
        if (q === "") {
            const held = root.held.filter(id => id);
            return root.all.filter(e => !held.includes(e.id)).sort((a, b) => root.frecency(b.id, now) - root.frecency(a.id, now) || a.name.localeCompare(b.name));
        }

        return root.all.map(e => ({
                    entry: e,
                    score: root.score(e, q)
                })).filter(m => m.score > 0).sort((a, b) => b.score - a.score || root.frecency(b.entry.id, now) - root.frecency(a.entry.id, now) || a.entry.name.localeCompare(b.entry.name)).map(m => m.entry);
    }

    // Bring the old tally forward to now, add this play, then hand off to the
    // desktop entry - which knows about Terminal=true and the Exec field codes.
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

    // The scorecard, alongside theme.json. No watchChanges: every write here is
    // our own. A missing or corrupt file falls back to an empty tally rather
    // than complaining - losing it costs the ordering of an empty bet.
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
            // id -> count with nothing to decay from; stamping them as of now
            // keeps the regulars, ageing from this run on.
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
            // Once, on the run that finds an old file, so the stamp above is
            // the upgrade rather than whenever the shell last restarted.
            if (rewrite)
                playsFile.setText(JSON.stringify(root.plays));
        }
    }

    // The tray, beside the scorecard. Somebody might reasonably write this one
    // by hand, so anything that is not five slots of id-or-null is padded and
    // truncated into that rather than thrown away.
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
