.pragma library

// The door's palette: gold on black, and deliberately not one of the four
// tables in house/Config.qml. The greeter runs as the `sddm` user with no
// access to anyone's ~/.config, and a login screen following a per-user
// preference would announce who last sat down before anyone authenticates.
//
// A .js library rather than a QML singleton, which does not work here: a
// `singleton` line in a qmldir is only honoured when the directory is imported
// as a module, and an SDDM theme is a bare directory Qt imports implicitly. The
// qmldir is never consulted, so every `Palette.x` silently resolves to
// undefined - white Rectangles and black Text, with no error at all.

// --- the room -----------------------------------------------------------------
// tableDeep is the cloth away from the lamp, tableLit what the cone lands on -
// warmer rather than lighter, since the lamp is gold. Felt.qml gradients between
// the two, so the background is never a flat rectangle.
var tableDeep = "#0a0908";
var tableLit = "#241d13";
var tableLine = "#3a2f18"; // the lattice printed on the cloth, barely there

var rail = "#141110"; // lacquer, the padded edge you lean on
var railLit = "#2a2320";
var railShadow = "#040303";

// --- the fittings -------------------------------------------------------------
var gold = "#d9a92e";
var goldDim = "#8a6d1e"; // hairlines, inactive plaques
var goldBright = "#f4dd97"; // the lit edge of a bevel

// --- card stock ---------------------------------------------------------------
var ivory = "#f2ead6";
var ivoryDim = "#cfc7b4";
var cardInk = "#14100f";
var cardRed = "#b3241f";
var cardBack = "#171310"; // black, gold-latticed
var cardBackLine = "#6b5320";

// --- type ---------------------------------------------------------------------
var text = "#f2ead6";
var muted = "#8d8375"; // warm grey, never a neutral one
var hot = "#cf3b32"; // caps lock, bust, swept

// --- the chips ----------------------------------------------------------------
// Red, black, blue, purple - four denominations, one per stack of the bet, and
// deliberately none of the room's own colours: a gold chip is the colour of the
// plaques it sits among, an ivory one the colour of the type.
//
// The bet climbs through these three chips to a colour, so the clay at the top
// says roughly how long the password is. Each entry: the clay body, the inlay
// let into the edge spots, and an ink that reads on the body.
var chips = [
    {
        body: "#b3282a",
        spot: "#ece4d0",
        ink: "#f7ece9",
        value: "5"
    },      // red, ivory spots
    {
        body: "#131110",
        spot: "#ffffff",
        ink: "#ffffff",
        value: "25"
    },     // black, white spots. Flat white rather than ivory: this is the only
           // chip darker than the cloth, so the spots do the whole job of
           // separating it from the felt.
    {
        body: "#22508a",
        spot: "#ece4d0",
        ink: "#dce6f2",
        value: "100"
    },    // blue, ivory spots
    {
        body: "#6a3287",
        spot: "#ece4d0",
        ink: "#ecdcf4",
        value: "500"
    }     // purple, ivory spots
];

// --- court stock --------------------------------------------------------------
// Seat cards are printed in the room's colours - black stock, gold rule, white
// figures - so they never get confused with the pale cards out of the shoe.
var courtStock = "#171310";
var courtFigure = "#ffffff";

// The power chips on the rail wear house colours rather than a denomination -
// they are not part of the bet and must not read as part of it.
var powerChip = {
    body: "#251e17",
    spot: "#6b5320",
    ink: "#d9a92e"
};

var powerChipHot = {
    body: "#3d1512",
    spot: "#cf3b32",
    ink: "#f4d8d4"
};

// alpha("#rrggbb", 0.55) -> "#8crrggbb", a form Qt parses directly. Qt.rgba()
// would need a QML context this library does not have.
function alpha(hex, a) {
    var v = Math.round(Math.max(0, Math.min(1, a)) * 255);
    var h = v.toString(16);
    if (h.length < 2)
        h = "0" + h;
    return "#" + h + hex.substring(1);
}
