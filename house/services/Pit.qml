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

    // Game dirs whose wrapper exists on disk, filled by the scan below.
    property var found: []

    // Which of Config.pitRepos the games were found under - the earliest one
    // with anything in it. Empty until the scan lands, which is fine: the bar
    // has no buttons to click before then.
    property string repo: ""

    // What the bar draws. The games are an optional submodule, so a checkout
    // without them shows no buttons rather than five that do nothing.
    readonly property var games: Config.pitGames.filter(g => root.found.includes(g.dir))

    function isRunning(dir: string): bool {
        return root.running.includes(dir);
    }

    // One shell pass over every wrapper under every candidate root, printing
    // "<root index> <dir>" for the ones present. Once at startup - a submodule
    // does not appear mid-session.
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
                // The first root with anything under it wins outright: the
                // games are one checkout, not a merge of several.
                const which = Math.min(...hits.map(h => parseInt(h[0], 10)));
                root.repo = Config.pitRepos[which];
                root.found = hits.filter(h => parseInt(h[0], 10) === which).map(h => h[1]);
            }
        }
    }

    // One table at a time. Over every game *found* rather than every game
    // `running` says is up - that list is a 3s tick behind, and the game dealt
    // in a moment ago is exactly the one needing shut. A `hide` at a game that
    // isn't there costs a client exiting 255. Backgrounded, so opening a game
    // doesn't wait on four of them in series.
    function closeOthers(dir: string): string {
        return root.games.filter(g => g.dir !== dir).map(g => `qs -p '${root.repo}/${g.dir}/${g.file}' ipc call '${g.target}' hide 2>/dev/null &`).join(" ");
    }

    function toggle(game: var): void {
        const wrapper = `${root.repo}/${game.dir}/${game.file}`;
        // `hide` quits a standalone game (`toggle` would only lower its cards,
        // leaving the engine resident); exit 255 with nobody to answer means it
        // wasn't running, so deal it in instead. That is also the one
        // unambiguous signal this click is an open, which is why the rest of
        // the pit is cleared on that branch and nowhere else.
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
