# The Door

An SDDM greeter. Logging in is a hand of blackjack: you are a card, your
password is a bet, and pressing enter deals.

Type, and every character drops a clay chip onto a stack standing in the
betting circle — there is no row of asterisks anywhere in this theme, the stack
is the whole of the feedback. The chips fill five stacks of uneven height — ten,
four, nine, seven, five — set out along a shallow circular arc, the way chips
sit around the near edge of a betting circle; past thirty-five characters the
bet stops changing. The clay changes every three chips — red, black, blue,
purple, and round again — so how far along the password is reads off the felt
without counting chips.

Press enter and the bet is pushed into the pot and
two cards come out of the shoe. Right password, they turn over ace and king:
twenty-one. Wrong, and they turn over seventeen, the house hits you with a
third card, you bust, and the table sweeps itself so you can bet again.

Gold on black, lit from directly above. The room is reduced to two colours so
that the chips are the only real colour on the screen, which puts your eye on
the bet — which is the password.

## Not connected to the tables

The desktop inside can wear any of four tables (Noir, Felt, Vegas, Daylight
Robbery) and `house/scripts/apply-theme.sh` mirrors the active one onto
Hyprland, kitty, rofi, btop, GTK and the games. This theme is deliberately
outside all of that, for two reasons:

- The greeter runs as the `sddm` user before any login, with no access to
  anyone's `~/.config`, so it could not read the active table without something
  root-writable in between.
- A login screen that followed a per-user preference would be announcing which
  user last sat down, before anyone has authenticated.

So the door has its own palette, in `Palette.js`, and it does not change.

## Install

```sh
./install.sh          # install to /usr/share/sddm/themes/door and activate
./install.sh --copy   # install only, leave the active theme alone
```

It uses sudo where it needs to. The active theme is set through a drop-in at
`/etc/sddm.conf.d/10-theme.conf`; delete that file to go back.

## Working on it

```sh
sddm-greeter-qt6 --test-mode --theme /home/delta/cloon/newdot/door
```

Reads straight from this directory, so there is no install step in the loop.
Two things to know about test mode:

- **logind refuses every power action**, so `sddm.canPowerOff` and friends are
  all false and the power chips on the rail do not render. They are not broken.
- **`sddm.login()` goes nowhere at all.** There is no daemon on the other end —
  the greeter logs `QLocalSocket::connectToServer: Invalid name` at startup and
  `QIODevice::write (QLocalSocket): device not open` when you press enter — so
  neither `loginSucceeded` nor `loginFailed` is ever emitted. `verdict` stays
  empty, `reveal()` returns early every time, and the theme sits in the `deal`
  phase for good: bet pushed into the pot, two cards face down, no turn-over, no
  bust, no sweep. Escape cannot rescue it either, because the key handler is
  `enabled: root.phase === "bet"`. Kill the greeter and start it again.

  So **neither hand is reachable in test mode**, winning or losing. To see one,
  force it: temporarily replace the `sddm.login(...)` call in `deal()` with
  `root.dealt = true; root.verdict = "win"; root.reveal()` — or `"lose"` for the
  bust.

QML errors go to Qt's logging, which off a terminal it does not recognise gets
routed away from stderr and silently dropped. Run it as

```sh
QT_FORCE_STDERR_LOGGING=1 sddm-greeter-qt6 --test-mode --theme .
```

or you will get an empty log for a theme that is throwing on every frame. A
binding that throws leaves its property `undefined` rather than defaulted, and
`undefined` in a size or a count renders as nothing at all — no warning, no
missing-file message, just a piece of the table that is not there. Without that
variable the only symptom is the hole.

One trap worth knowing, since it costs an afternoon: **SDDM splits any value
containing a comma into a list** before the theme sees it. `stackHeights` comes
back as a list of strings with no `.split` on it, not as `"10,4,9,7,5"`, which
is why `Main.qml` stringifies before parsing.

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
sit on the other end of it.

## The files

| file | what |
|---|---|
| `Main.qml` | layout, the state machine, and the keyboard |
| `Palette.js` | every colour, and the reason it is a `.js` and not a singleton |
| `Felt.qml` | the room: cloth, lamp, lattice, vignette, rail |
| `Chip.qml` | one clay chip, face on — the power controls |
| `ChipStack.qml` | the bet, edge on. This is the password field |
| `Card.qml` | a playing card that can turn over |
| `Hand.qml` | the deal, the stagger, and the third card |
| `SessionPlaque.qml` | session picker |
| `PowerChips.qml` | suspend, hibernate, restart, cash out |
| `theme.conf` | the handful of knobs worth turning without editing qml |
| `make-chips.py` | bakes the bet's sprites. Build-time only, not installed |

The chips in the bet are a pixel drawing, not rectangles, and a drawing has no
colours to bind to. So the four denominations in `Palette.js` are baked into
`assets/chip-<denomination><variant>.png` ahead of time, and `ChipStack.qml`
just picks a file by name. The master art is `assets/chip-src.png`, one 29×14
chip in three-quarter view.

    python3 door/make-chips.py    # needs Pillow

Re-run it after changing `Palette.chips` or redrawing the source, and commit the
twelve files it writes — `install.sh` copies those and leaves the script and the
master behind. The three variants per denomination exist so a stack does not
turn into vertical stripes; the script's docstring explains that at length.

`Palette.js` is a `.pragma library` rather than the QML singleton it obviously
wants to be. A `singleton` line in a `qmldir` is only honoured when the
directory is imported as a module, and an SDDM theme is a bare directory that Qt
imports implicitly — so the `qmldir` is never read, every `Palette.x` resolves to
`undefined`, and because that raises no error you get a screen of default-white
rectangles and default-black text with a completely clean log. That is a full
afternoon if you do not know it, so: it is a `.js`, on purpose.
