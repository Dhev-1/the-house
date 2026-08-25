# Comment cleanup sweep — working brief

The instructions this sweep is running under, written down so it can be picked
up again in a later session.

## The ask

> "Can you do a sweep of the repo and cut down on all the Unnecessary Redundant
> comments."

The codebase is heavily and deliberately commented — long "why" prose in a
house/cards voice. Almost none of it is plain restatement of code, so the sweep
was scoped by asking which kinds of redundancy to go after.

## What was chosen

Three of the four options offered were selected:

1. **Restatement only** — cut comments that say what the next line already says,
   plus dead labels. Every rationale/gotcha paragraph stays.
2. **De-duplicate across games** — blocks copy-pasted verbatim across the five
   game files get written once in full; the other copies shrink to a one-line
   pointer.
3. **Compress the prose** — tighten long metaphor-heavy paragraphs into terser
   rationale. Same facts, fewer words. This does change the voice.

**Not** chosen, so leave alone:

- **Banner boxes.** The `═══ … ═══` and `// ---- … ----` section headers stay
  exactly as they are, including the three-line boxes around one-word labels
  (`BUTTON`, `IPC`, `WINDOW`). They are navigation in 1900-line files.

## Rules in practice

- **Never touch code.** Comments only — no reformatting, no renaming, no
  reordering, not even whitespace on a code line.
- **Keep anything that explains a trap**: qrc-vs-shellPath, magenta
  checkerboard fallbacks, StyledText-vs-RichText, contrast ratios, "why this
  exact hex", protocol errors. These are the reason the file is readable.
- **Cut a comment that names an anonymous element only if the element is
  obvious.** `// The inner hairline of a card face.` earns its place (it names
  an unnamed Rectangle); `// The app in this seat, or nothing if the hand is
  short.` on `hand[index] ?? null` does not.
- **Cut trailing comments that restate the property name.** `notifWidth: 300 //
  width` goes; `notifPadding: 10 // padding, horizontal_padding` stays, because
  it names the dunst keys that differ.
- **Prefer trimming the duplicate copy, not the original.** When the same point
  is made in two places, keep it where a reader meets it first and leave a
  pointer at the other.
- **Stale comments are cuttable outright.** e.g. BottomBar's "delineated by the
  border" described a border that is now `width: 0`.

## Verification harness

Every batch of edits is checked by a script that strips comments (quote-aware,
so `"file://"` and `//` inside strings survive) from a pre-sweep baseline and
from the working tree, then compares the remaining code lines. It must print
`CODE IDENTICAL - comments only` after every batch.

Baseline copy and the checker live in the session scratchpad:

    <scratchpad>/base/          pre-sweep copy of every .qml/.js/.py/.sh/.md
    <scratchpad>/check.py       the comparison

If resuming in a fresh session, re-create the baseline from git before starting
(the user runs all git commands themselves — never invoke git from the agent).

`qmllint <file>` is clean on the edited QML and is worth re-running.
`qmlformat` produces empty output on every file in this repo, edited or not, so
it is not a usable check here.

## Progress

**house/ — done.** Edited: `Config.qml`, `Launcher.qml`, `services/Apps.qml`,
`services/{LauncherPanel,ThemePanel,PowerPanel,Dock,Pit}.qml`,
`components/Toast.qml`, `ThemePicker.qml`, `Music.qml`, `ClockPopout.qml`,
`PowerMenu.qml`, `shell.qml`, `Sidebar.qml`, `ButtonTray.qml`, `BottomBar.qml`,
`scripts/apply-theme.sh`. Reviewed and left alone (already lean): `Popups.qml`,
`Border.qml`, `Bar.qml`, `Exclusions.qml`, `ServiceTray.qml`,
`components/{Workspaces,StatusIcons,Clock,ThemeButton,Tray,Chip}.qml`,
`services/{Notifications,Systemd,Player,ClockPanel}.qml`. About 100 lines cut.

**door/ — done.** Edited: `Palette.js`, `ChipStack.qml`, `Card.qml` (the
duplicated corner-index block now reads once), `Main.qml`, `Hand.qml`. Reviewed
and left alone (already lean): `Felt.qml`, `SessionPlaque.qml`, `PowerChips.qml`,
`Chip.qml`, `TestStack.qml`, `make-chips.py`, `install.sh`. About 80 lines cut.

**games/ — done for the cross-file duplication.** Blackjack.qml is canonical and
untouched; `Bones.qml`, `RideTheBus.qml`, `Poker.qml` and `roulette.qml` now
carry a one-line pointer to it for every block they had copied verbatim — `THE
ACTIVE TABLE` and its FileView notes, `THE BANK ON DISK`, the forced `text()`
read, the rebuy/top-up/pay-back notes, the chip ladder and chip drawing, and the
whole `WINDOW` block. The wrappers (`bns.qml`, `ridethebus.qml`, `poker.qml`)
point at `blackjack.qml` for the `standalone` note. A few long in-file paragraphs
were compressed in `Bones.qml`, `RideTheBus.qml` and `roulette.qml`. About 240
lines cut. The banner boxes were left exactly as they were.

The `test-*.js` harnesses were read and left alone — their comments are all
substantive. Two stale *code* references were noticed there and deliberately not
touched, since this sweep is comments only: `bjak/test-blackjack.js` reads
`blackjack.qml` (the 22-line wrapper) rather than `Blackjack.qml`, and
`pokr/test-eval.js` reads a hardcoded `/home/delta/cloon/pokr/poker.qml`.

**READMEs — partly done.**

- Top-level `README.md`: the rice table said the launcher was rofi (it is the
  hand of apps on `Super+D`); the keybind table listed `SUPER+O → firefox`,
  which is commented out in `binds.conf`. Both fixed, `Super+D` and `games/`
  added, the duplicate Notifications row folded into the shell row.
- `house/README.md`: compressed the D-Bus-name paragraph and the music-tab
  opener; cut the keybinds repeated inside the file index. The launcher section
  is still four long paragraphs on the decaying tally and could be compressed.
- `door/README.md`: **rewritten for a reader rather than for the author.** The
  "this cost an afternoon" asides are gone; the traps behind them (the
  `.pragma library` reason, SDDM's comma-splitting, what test mode cannot do)
  are stated flat in a `Developing` section at the end. Gained a `Configuring`
  section for `theme.conf` and a requirements line, neither of which existed.
- `games/*/README.md`: **paths only, no prose sweep yet.** Run and IPC commands
  moved off `~/cloon/widgames/…` (and pokr's `~/cloon/pokr/…`) onto
  `~/cloon/newdot/games/…`. The `[edge](../edge)` links pointed at a directory
  that is not in this repo; the toggle-button behaviour they describe is what
  `house/services/Pit.qml` does now, so those became the pit / `house`. Note
  this was inferred from behaviour, not from history — the pit launches each
  game as its own `qs -p` process and does *not* embed them or put them on a
  layer shell, so the "not on a layer shell yet" lines were left pointing at
  each file's own `## Next` rather than naming a destination.

**Still outstanding:**

- `home/` config files — `hyprland.conf` had its stock Hyprland boilerplate cut
  and was then stopped mid-pass; `binds.conf` and `btop.conf` have not been
  looked at.
- A redundancy pass over `games/*/README.md`. `bjak` and `rolt` carry the
  `Credits` section and the `status`-as-liveness-check paragraph near enough
  verbatim.
- `games/rolt/IMPLEMENTATION.md` has not been looked at at all.
- pokr's README still tells you to `exec-once` it and bind `SUPER+P`; the pit
  does that now. Content decision, not a cleanup one.
