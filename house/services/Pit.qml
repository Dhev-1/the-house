pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// The pit boss: knows which games in Config.pitGames are up and starts or
// stops them. Each game is its own quickshell process (qs -p <wrapper>), so a
// closed game costs nothing - the toggle is "tell it to quit over IPC, and if
// nobody answers, launch it".
Singleton {
    id: root

    // Game dirs (Config.pitGames[].dir) with a live process, refreshed by the
    // poll below.
    property var running: []

    // Game dirs whose wrapper actually exists on disk, filled by the scan
    // below. Empty until it lands, which is the honest answer: nothing is
    // launchable yet.
    property var found: []

    // Which of Config.pitRepos the games were actually found under - the
    // earliest one with anything in it. Empty until the scan lands; toggle()
    // can't fire before then anyway, because the bar has no buttons to click.
    property string repo: ""

    // What the bar draws. The games are an optional submodule, so a checkout
    // without them shows no buttons at all rather than five that do nothing.
    readonly property var games: Config.pitGames.filter(g => root.found.includes(g.dir))

    function isRunning(dir: string): bool {
        return root.running.includes(dir);
    }

    // One shell pass over every wrapper under every candidate root, printing
    // "<root index> <dir>" for the ones that are there. Runs once at startup:
    // a submodule does not appear mid-session, and re-checking on a timer
    // would be a stat per game per tick for nothing.
    Process {
        id: scan

        running: true
        command: ["sh", "-c", Config.pitRepos.map((r, i) => Config.pitGames.map(g => `[ -f '${r}/${g.dir}/${g.file}' ] && echo '${i} ${g.dir}'`).join("\n")).join("\n") + "\nexit 0"]

        stdout: StdioCollector {
            onStreamFinished: {
                const hits = this.text.trim().split("\n").filter(l => l.length > 0).map(l => l.split(" "));
                if (hits.length === 0) {
                    root.repo = "";
                    root.found = [];
                    return;
                }
                // The first root with anything under it wins outright - the
                // games are one checkout, not a merge of several, so a partial
                // hit on an earlier root should not pull dirs off a later one.
                const which = Math.min(...hits.map(h => parseInt(h[0], 10)));
                root.repo = Config.pitRepos[which];
                root.found = hits.filter(h => parseInt(h[0], 10) === which).map(h => h[1]);
            }
        }
    }

    // One table at a time. The games all deal into the same bottom-right
    // corner, so two of them up at once is two cards stacked on the same spot
    // - and the pit only ever meant one of them to be live anyway.
    //
    // Over every game that can be *found* rather than every game `running`
    // says is up: that list is a 3s tick behind, so a game dealt in a moment
    // ago may not be in it yet, and it is exactly the one that needs shutting.
    // A `hide` at a game that isn't there costs a client that exits 255 into
    // /dev/null. Backgrounded, so opening a game doesn't wait on four of them
    // in series - the ones that are up go down in their own time.
    function closeOthers(dir: string): string {
        return root.games.filter(g => g.dir !== dir).map(g => `qs -p '${root.repo}/${g.dir}/${g.file}' ipc call '${g.target}' hide 2>/dev/null &`).join(" ");
    }

    function toggle(game: var): void {
        const wrapper = `${root.repo}/${game.dir}/${game.file}`;
        // `hide` quits every game when standalone (`toggle` only lowers some
        // of their cards, leaving the engine resident); exit 255 with no
        // process to answer means it wasn't running, so deal it in instead.
        //
        // Which is also what tells a close from an open, and it is worth being
        // the thing that decides: `running` would be a guess at this point, and
        // guessing wrong here clears the pit on a click that only meant to shut
        // one game. Nobody answering is the one unambiguous signal that this
        // click is an open - so the rest of the pit is cleared there, on that
        // branch, and nowhere else.
        Quickshell.execDetached(["sh", "-c", `qs -p '${wrapper}' ipc call '${game.target}' hide 2>/dev/null || { ${root.closeOthers(game.dir)} qs -p '${wrapper}'; }`]);
        // Poke the poll so the button lights without waiting a full tick.
        relight.restart();
    }

    // Which game processes exist, by matching their config paths in the qs
    // command lines. One pgrep for all of them.
    Process {
        id: poll

        command: ["pgrep", "-fa", "qs -p"]
        stdout: StdioCollector {
            onStreamFinished: {
                const up = [];
                for (const g of Config.pitGames)
                    if (this.text.includes(`${g.dir}/${g.file}`))
                        up.push(g.dir);
                root.running = up;
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: poll.running = true
    }

    // A quick double-check shortly after a toggle, so the light tracks the
    // click rather than the poll cadence.
    Timer {
        id: relight

        interval: 700
        onTriggered: poll.running = true
    }
}
