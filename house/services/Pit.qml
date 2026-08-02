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

    function isRunning(dir: string): bool {
        return root.running.includes(dir);
    }

    function toggle(game: var): void {
        const wrapper = `${Config.pitRepo}/${game.dir}/${game.file}`;
        // `hide` quits every game when standalone (`toggle` only lowers some
        // of their cards, leaving the engine resident); exit 255 with no
        // process to answer means it wasn't running, so deal it in instead.
        Quickshell.execDetached(["sh", "-c", `qs -p '${wrapper}' ipc call '${game.target}' hide 2>/dev/null || qs -p '${wrapper}'`]);
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
