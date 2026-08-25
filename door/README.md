# The Door

An SDDM greeter where logging in is a hand of blackjack. You are a card, your
password is a bet, and pressing enter deals.

![the door](screenshot.png)

Type, and every character drops a clay chip onto a stack standing in the betting
circle. There is no row of asterisks anywhere in this theme — the stack is the
whole of the feedback. The chips fill five stacks of uneven height set out along
a shallow arc, the way chips sit around the near edge of a betting circle, and
the clay changes every three chips — red, black, blue, purple, and round again —
so how far along the password is reads off the felt without counting chips.

Press enter and the bet is pushed into the pot and two cards come out of the
shoe. Right password, they turn over ace and king: twenty-one. Wrong, and they
turn over seventeen, the house hits you with a third card, you bust, and the
table sweeps itself so you can bet again.

Gold on black, lit from directly above. The room is reduced to two colours so
that the chips are the only real colour on the screen, which puts your eye on
the bet — which is the password.

## Keys

| | |
|---|---|
| type | place a chip |
| backspace | take one back |
| enter | deal |
| escape | sweep the table and start over |
| ctrl+left / ctrl+right | change seat, when there is more than one account |
| f2 | cycle the session |

The session can also be picked from the plaque on the rail, and the power chips
— suspend, hibernate, restart, cash out — sit on the other end of it.

## Install

```sh
./install.sh          # install to /usr/share/sddm/themes/door and activate it
./install.sh --copy   # install only, leave the active theme alone
```

It takes sudo where it needs to. The active theme is set through a drop-in at
`/etc/sddm.conf.d/10-theme.conf` — delete that file to go back to the greeter
you were using before.

Requirements: SDDM with its Qt 6 greeter, and a Nerd Font for the suit glyphs
and the power icons (JetBrainsMono Nerd Font by default).

## Configuring

`theme.conf` holds the knobs worth turning without editing QML:

| key | what |
|---|---|
| `fontFamily` | the face on everything |
| `clock24h` | 24-hour clock |
| `houseName` | the name above the clock; empty uses the hostname |
| `stackHeights` | the shape of the bet — how tall each stack may get, left to right |
| `showdown` | deal the showdown hand on enter; off makes login instant and silent |

`stackHeights` is worth a word: the number of entries is the number of stacks,
and their total is the longest password the felt can report. Past it the
password still takes characters, the felt just stops reporting them. The default
`10,4,9,7,5` is deliberately uneven.

Colours are not in `theme.conf` — they live in `Palette.js`.

## It does not follow your desktop theme

The desktop inside can wear any of four tables, which
`house/scripts/apply-theme.sh` mirrors onto everything from Hyprland to the
games. The door is deliberately outside all of that:

- The greeter runs as the `sddm` user before any login, with no access to
  anyone's `~/.config`, so it could not read the active table without something
  root-writable in between.
- A login screen that followed a per-user preference would be announcing which
  user last sat down, before anyone has authenticated.

So the door has its own palette and it does not change.

## The files

| file | what |
|---|---|
| `Main.qml` | layout, the state machine, and the keyboard |
| `Palette.js` | every colour |
| `Felt.qml` | the room: cloth, lamp, lattice, vignette, rail |
| `Chip.qml` | one clay chip, face on — the power controls |
| `ChipStack.qml` | the bet, edge on. This is the password field |
| `Card.qml` | a playing card that can turn over |
| `Hand.qml` | the deal, the stagger, and the third card |
| `SessionPlaque.qml` | session picker |
| `PowerChips.qml` | suspend, hibernate, restart, cash out |
| `theme.conf` | the knobs above |
| `make-chips.py` | bakes the bet's sprites. Build-time only, not installed |

## Developing

Run it straight out of this directory, no install step in the loop:

```sh
QT_FORCE_STDERR_LOGGING=1 sddm-greeter-qt6 --test-mode --theme .
```

Keep that variable. Off a terminal Qt does not recognise, QML errors are routed
away from stderr and dropped, and a binding that throws leaves its property
`undefined` rather than defaulted — which in a size or a count renders as
nothing at all. Without the logging, a theme throwing on every frame looks like
a clean log and a hole in the table.

Two things test mode cannot do:

- **logind refuses every power action**, so `sddm.canPowerOff` and friends are
  false and the power chips do not render.
- **`sddm.login()` goes nowhere** — there is no daemon on the other end, so
  neither `loginSucceeded` nor `loginFailed` is ever emitted and the theme sits
  in the `deal` phase for good. To see a hand, force it: replace the
  `sddm.login(...)` call in `deal()` with
  `root.dealt = true; root.verdict = "win"; root.reveal()`, or `"lose"` for the
  bust.

Two things about the code that are not obvious:

- **`Palette.js` is a `.pragma library`, not a QML singleton.** A `singleton`
  line in a `qmldir` is only honoured when the directory is imported as a
  module, and an SDDM theme is a bare directory Qt imports implicitly — so the
  `qmldir` is never read and every `Palette.x` silently resolves to `undefined`.
- **SDDM splits any config value containing a comma into a list** before the
  theme sees it, so `stackHeights` arrives as a list of strings rather than
  `"10,4,9,7,5"`. `Main.qml` stringifies before parsing.

The chips in the bet are a pixel drawing rather than rectangles, and a drawing
has no colours to bind to, so the four denominations in `Palette.js` are baked
into `assets/chip-<denomination><variant>.png` ahead of time and `ChipStack.qml`
picks a file by name. The master art is `assets/chip-src.png`, one 29×14 chip in
three-quarter view. After changing `Palette.chips` or redrawing the source:

```sh
python3 make-chips.py    # needs Pillow
```

Commit the twelve files it writes — `install.sh` copies those and leaves the
script and the master behind. The three variants per denomination stop a stack
turning into vertical stripes.
