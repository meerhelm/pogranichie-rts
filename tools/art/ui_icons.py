"""Hand-drawn SVG icons for the HUD buttons that have no model to render: orders, techs,
ages and spells. Each icon is a 128×128 tile (drawn on a 64×64 grid): a plate in the colour of
its group with a light from the upper left, and a glyph in the style of the top bar icons
(warm colours with a dark outline). Building and unit tiles come from the sprites
(tools/art/icons.py, tools/art/portraits.py). The list of all icons with what each shows is
docs/07-ui-icons.md.

    python3 -m tools.art.ui_icons      # writes ui/icons/{orders,techs,ages,spells}/*.svg
"""

import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "ui", "icons")

D = "#1e130a"  # outline
P = "#ead9b0"  # parchment
G = "#d9a640"  # gold, bronze
S = "#c4ccd4"  # steel
SD = "#8a949e"  # steel in shade
W = "#9a6a3a"  # wood
WD = "#6b4524"  # dark wood
R = "#b8322a"  # red cloth
GR = "#6f9a4a"  # green
WH = "#d9b84a"  # wheat
FL = "#f0a030"  # flame

## Plate colours (top, bottom) per group.
PLATES = {
    "orders": ("#5a4230", "#24180e"),
    "techs": ("#2f4566", "#121a2a"),
    "ages": ("#6a2a24", "#2a100e"),
    "spells": ("#3f3060", "#160f24"),
}

O = f'stroke="{D}" stroke-width="2.2" stroke-linejoin="round" stroke-linecap="round"'


def _sword(rot: float) -> str:
    return (
        f'<g transform="rotate({rot} 32 32)" {O}>'
        f'<path d="M30 44 L30 12 L32 7 L34 12 L34 44 Z" fill="{S}"/>'
        f'<rect x="23" y="43" width="18" height="4" rx="1.5" fill="{G}"/>'
        f'<rect x="30.5" y="47" width="3" height="8" fill="{WD}"/>'
        f'<circle cx="32" cy="57" r="2.6" fill="{G}"/></g>'
    )


def _dots(points: list[tuple[int, int]], arrow: bool = True) -> str:
    out = "".join(f'<circle cx="{x}" cy="{y}" r="4.6" fill="{S}" {O}/>' for x, y in points)
    if arrow:
        out += (
            f'<path d="M56 14 L56 4 M51 9 L56 4 L61 9" fill="none" stroke="{D}" stroke-width="4.5" '
            f'stroke-linecap="round" stroke-linejoin="round"/>'
            f'<path d="M56 14 L56 4 M51 9 L56 4 L61 9" fill="none" stroke="{G}" stroke-width="2" '
            f'stroke-linecap="round" stroke-linejoin="round"/>'
        )
    return out


def _thick(d: str, color: str, width: float = 5.0) -> str:
    """A line drawn with a dark outline: a wide dark stroke under a narrower coloured one."""
    return (
        f'<path d="{d}" fill="none" stroke="{D}" stroke-width="{width + 3}" stroke-linecap="round" '
        f'stroke-linejoin="round"/>'
        f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linecap="round" '
        f'stroke-linejoin="round"/>'
    )


def _horse_head(x: float = 0, y: float = 0, fill: str = W, mane: str = WD) -> str:
    return (
        f'<g transform="translate({x} {y})" {O}>'
        f'<path d="M18 58 L22 36 Q20 22 28 13 L31 6 L34 12 Q45 16 50 28 L55 38 Q56 45 49 45 '
        f'L41 41 Q37 48 38 58 Z" fill="{fill}"/>'
        f'<path d="M28 13 Q20 22 22 36 L18 58 L14 58 L17 36 Q15 22 24 12 Z" fill="{mane}"/>'
        f'<circle cx="38" cy="22" r="2" fill="{D}" stroke="none"/></g>'
    )


def _paw(x: float, y: float, rot: float, s: float = 1.0, fill: str = P) -> str:
    """A wolf's paw print (a pad and four toes) at (x, y), pointing up turned by `rot` degrees."""
    toes = "".join(f'<ellipse cx="{tx}" cy="{ty}" rx="1.5" ry="2" fill="{fill}" stroke="{D}" stroke-width="0.8"/>'
                   for tx, ty in ((-3.2, -2.6), (-1.1, -4.6), (1.1, -4.6), (3.2, -2.6)))
    return (f'<g transform="translate({x} {y}) rotate({rot}) scale({s})">'
            f'<path d="M-3 2 Q-3 -1.5 0 -1.5 Q3 -1.5 3 2 Q0 4 -3 2 Z" fill="{fill}" stroke="{D}" stroke-width="0.8"/>'
            f"{toes}</g>")


def _fir(x: float, base: float, h: float, fill: str = "#24361f") -> str:
    """A dark fir: three stacked triangles on a short trunk."""
    w = h * 0.42
    tiers = "".join(f'<path d="M{x} {base - h + k * h * 0.22} L{x + w * (0.6 + 0.2 * k)} {base - h * (0.45 - 0.2 * k)} '
                    f'L{x - w * (0.6 + 0.2 * k)} {base - h * (0.45 - 0.2 * k)} Z" fill="{fill}" {O}/>'
                    for k in range(3))
    return f'<rect x="{x - 1.2}" y="{base - h * 0.08}" width="2.4" height="{h * 0.1}" fill="{WD}"/>' + tiers


def _cross(cx: float, cy: float, s: float, fill: str) -> str:
    a, b = s, s * 0.3
    return (
        f'<path d="M{cx - b} {cy - a} H{cx + b} V{cy - b} H{cx + a} V{cy + b} H{cx + b} '
        f'V{cy + a} H{cx - b} V{cy + b} H{cx - a} V{cy - b} H{cx - b} Z" fill="{fill}" {O}/>'
    )


GLYPHS: dict[str, dict[str, str]] = {
    "orders": {
        # Stop: an open hand raised.
        "stop": (
            f'<g {O} fill="{P}">'
            f'<rect x="19.5" y="15" width="6" height="22" rx="3"/>'
            f'<rect x="26" y="9" width="6" height="26" rx="3"/>'
            f'<rect x="32.5" y="10" width="6" height="26" rx="3"/>'
            f'<rect x="39" y="15" width="6" height="22" rx="3"/>'
            f'<rect x="10" y="32" width="6" height="16" rx="3" transform="rotate(-38 13 40)"/>'
            f'<path d="M19 30 H45 V44 Q45 56 32 56 Q19 56 19 44 Z"/></g>'
        ),
        # Aggressive: two swords crossed.
        "aggressive": _sword(40) + _sword(-40),
        # Defensive: a round shield with a boss.
        "defensive": (
            f'<circle cx="32" cy="32" r="23" fill="{W}" {O}/>'
            f'<circle cx="32" cy="32" r="23" fill="none" stroke="{G}" stroke-width="3"/>'
            f'<path d="M20 14 L20 50 M32 9 L32 55 M44 14 L44 50" stroke="{WD}" stroke-width="1.5"/>'
            f'<circle cx="32" cy="32" r="7" fill="{S}" {O}/>'
        ),
        # Stand ground: a banner pole driven into a mound.
        "stand_ground": (
            f'<ellipse cx="32" cy="54" rx="20" ry="5.5" fill="#6b5a3a" {O}/>'
            f'<rect x="30" y="8" width="4" height="47" fill="{WD}" {O}/>'
            f'<path d="M34 10 L54 15 L46 20 L54 25 L34 30 Z" fill="{R}" {O}/>'
            f'<circle cx="32" cy="7" r="3" fill="{G}" {O}/>'
        ),
        # Formations: dots for men, an arrow for the front.
        "line": _dots([(x, y) for y in (30, 42) for x in (10, 21, 32, 43, 54)]),
        "column": _dots([(x, y) for y in (14, 24, 34, 44, 54) for x in (25, 39)]),
        "wedge": _dots([(32, 14), (25, 25), (39, 25), (18, 36), (32, 36), (46, 36),
                        (11, 48), (25, 48), (39, 48), (53, 48)]),
        # Lithuanian retreat: run back, then turn on the chasers.
        "retreat": (
            _thick("M52 18 H24 Q10 18 10 32 Q10 46 24 46 H40", G, 5)
            + f'<path d="M38 37 L50 46 L38 55 Z" fill="{G}" {O}/>'
            + f'<path d="M50 24 H58 M48 30 H56" stroke="{P}" stroke-width="2.5" stroke-linecap="round"/>'
        ),
        # Tabor: four wagons drawn up in a ring, seen from above, chained to each other.
        "tabor": (
            f'<circle cx="32" cy="32" r="15" fill="#6b5a3a" opacity="0.6"/>'
            + "".join(
                f'<g transform="rotate({a} 32 32)">'
                f'<rect x="20" y="6" width="5" height="3.5" rx="1" fill="{D}"/>'
                f'<rect x="39" y="6" width="5" height="3.5" rx="1" fill="{D}"/>'
                f'<rect x="20" y="17.5" width="5" height="3.5" rx="1" fill="{D}"/>'
                f'<rect x="39" y="17.5" width="5" height="3.5" rx="1" fill="{D}"/>'
                f'<rect x="18" y="8.5" width="28" height="10.5" rx="1.5" fill="{W}" {O}/>'
                f'<rect x="22" y="9.5" width="18" height="8.5" rx="3.5" fill="{P}" {O}/>'
                f'<path d="M46 14 L52 14" stroke="{SD}" stroke-width="2" stroke-linecap="round"/>'
                "</g>"
                for a in (0, 90, 180, 270)
            )
        ),
        # Turn around: an arrow turned back.
        "turn": (
            _thick("M16 44 Q12 16 32 14 Q52 14 50 38", G, 5)
            + f'<path d="M41 36 L50 50 L59 36 Z" fill="{G}" {O}/>'
            + f'<path d="M9 50 L16 38 L23 50 Z" fill="{S}" {O}/>'
        ),
        # Dismount: a horseshoe and an arrow down.
        "dismount": (
            _thick("M20 8 V22 Q20 34 32 34 Q44 34 44 22 V8", S, 7)
            + "".join(f'<circle cx="{x}" cy="{y}" r="1.3" fill="{D}"/>' for x, y in
                      ((20, 13), (20, 20), (44, 13), (44, 20)))
            + _thick("M32 40 V56", G, 4)
            + f'<path d="M24 50 L32 60 L40 50 Z" fill="{G}" {O}/>'
        ),
        # Take apart: a hammer and a crowbar over a plank.
        "take_apart": (
            f'<rect x="8" y="44" width="48" height="10" rx="2" fill="{W}" {O}/>'
            f'<path d="M14 49 H50" stroke="{WD}" stroke-width="1.2"/>'
            f'<g transform="rotate(-40 32 30)" {O}>'
            f'<rect x="30" y="16" width="5" height="34" rx="2" fill="{W}"/>'
            f'<rect x="22" y="9" width="21" height="9" rx="2" fill="{S}"/></g>'
            + _thick("M18 12 Q12 12 13 18 L44 46", SD, 4)
        ),
    },
    "techs": {
        # Watchmen: a watchful eye.
        "t_watch": (
            f'<path d="M6 32 Q32 8 58 32 Q32 56 6 32 Z" fill="{P}" {O}/>'
            f'<circle cx="32" cy="32" r="10" fill="#5d86c4" {O}/>'
            f'<circle cx="32" cy="32" r="4" fill="{D}"/>'
            f'<circle cx="28.5" cy="28.5" r="2" fill="#ffffff"/>'
            f'<path d="M32 4 V10 M14 10 L18 15 M50 10 L46 15" stroke="{G}" stroke-width="2.5" '
            f'stroke-linecap="round"/>'
        ),
        # Horse collar: a padded collar with its wooden hames.
        "t_horse_collar": (
            f'<path fill-rule="evenodd" d="M32 6 Q52 8 52 34 Q52 58 32 58 Q12 58 12 34 Q12 8 32 6 Z '
            f'M32 18 Q22 19 22 36 Q22 48 32 48 Q42 48 42 36 Q42 19 32 18 Z" fill="{WD}" {O}/>'
            + _thick("M18 14 Q8 34 18 54", G, 3.5)
            + _thick("M46 14 Q56 34 46 54", G, 3.5)
            + f'<circle cx="32" cy="7" r="3.5" fill="none" stroke="{S}" stroke-width="2.5"/>'
        ),
        # Forestry: a hive cut into a trunk, bees about it, a crown of leaves.
        "t_gdl_forest": (
            f'<ellipse cx="32" cy="14" rx="22" ry="11" fill="{GR}" {O}/>'
            f'<rect x="23" y="18" width="18" height="40" fill="{W}" {O}/>'
            f'<ellipse cx="32" cy="38" rx="5" ry="8" fill="{D}"/>'
            f'<rect x="24" y="31" width="16" height="3" fill="{WD}"/>'
            + "".join(
                f'<g transform="translate({x} {y})"><ellipse rx="3.6" ry="2.6" fill="{WH}" {O}/>'
                f'<path d="M-1 -2.4 V2.4" stroke="{D}" stroke-width="1.3"/></g>'
                for x, y in ((50, 34), (13, 42), (52, 50))
            )
        ),
        # Three-field system: one field in three strips (winter grain, spring grain, fallow).
        "t_three_field": (
            f'<path d="M8 20 L22 12 L22 50 L8 58 Z" fill="{WH}" {O}/>'
            f'<path d="M22 12 L40 12 L40 50 L22 50 Z" fill="{GR}" {O}/>'
            f'<path d="M40 12 L56 20 L56 58 L40 50 Z" fill="#7a5a3a" {O}/>'
            + "".join(f'<path d="M{x} 48 V30" stroke="#9a7a20" stroke-width="1.4"/>' for x in (12, 16, 20))
            + "".join(f'<path d="M{x} 46 V36" stroke="#3f6a2a" stroke-width="1.4"/>' for x in (26, 31, 36))
        ),
        # Two-man saw: a long blade with a handle at each end.
        "t_saw": (
            f'<path d="M12 24 L52 24 L52 32 L50 36 L47 32 L44 36 L41 32 L38 36 L35 32 L32 36 L29 32 '
            f'L26 36 L23 32 L20 36 L17 32 L14 36 L12 32 Z" fill="{S}" {O}/>'
            f'<rect x="4" y="14" width="8" height="30" rx="3" fill="{W}" {O}/>'
            f'<rect x="52" y="14" width="8" height="30" rx="3" fill="{W}" {O}/>'
            f'<path d="M16 50 Q32 58 48 50" fill="none" stroke="{P}" stroke-width="2" '
            f'stroke-dasharray="3 3"/>'
        ),
        # Zaseka craft: felled trunks crossed, an axe on them.
        "t_gdl_zaseka": (
            f'<g {O}><rect x="6" y="34" width="52" height="9" rx="4.5" fill="{W}" '
            f'transform="rotate(-18 32 38)"/>'
            f'<rect x="6" y="34" width="52" height="9" rx="4.5" fill="{WD}" transform="rotate(18 32 38)"/>'
            f'<circle cx="9" cy="47" r="5" fill="{GR}"/><circle cx="56" cy="47" r="5" fill="{GR}"/></g>'
            f'<g transform="rotate(25 32 20)" {O}><rect x="30" y="6" width="4" height="26" rx="1.5" '
            f'fill="{W}"/><path d="M34 8 Q46 8 46 18 Q40 16 34 17 Z" fill="{S}"/></g>'
        ),
        # Bloomery: a clay furnace with fire and the iron bloom before it.
        "t_bloomery": (
            f'<path d="M20 58 L24 18 L40 18 L44 58 Z" fill="#a0603a" {O}/>'
            f'<path d="M27 58 L27 46 Q32 40 37 46 L37 58 Z" fill="{FL}" {O}/>'
            f'<path d="M26 18 Q24 10 30 6 Q30 12 34 10 Q32 4 38 4 Q42 12 38 18 Z" fill="{FL}" {O}/>'
            f'<ellipse cx="52" cy="54" rx="7" ry="5" fill="#4a4a50" {O}/>'
            f'<path d="M22 30 H42 M21 42 H43" stroke="#7a4a2a" stroke-width="1.5"/>'
        ),
        # Assaying: scales weighing a silver coin.
        "t_assay": (
            f'<rect x="30" y="10" width="4" height="42" fill="{G}" {O}/>'
            f'<rect x="20" y="52" width="24" height="5" rx="2" fill="{G}" {O}/>'
            + _thick("M10 16 H54", G, 3)
            + f'<path d="M10 16 L4 34 M10 16 L16 34 M54 16 L48 34 M54 16 L60 34" stroke="{D}" '
            f'stroke-width="1.3"/>'
            f'<path d="M2 34 H18 Q10 42 2 34 Z" fill="{G}" {O}/>'
            f'<path d="M46 34 H62 Q54 42 46 34 Z" fill="{G}" {O}/>'
            f'<ellipse cx="10" cy="31" rx="6" ry="3" fill="{S}" {O}/>'
        ),
        # Herbalism: a bundle of herbs tied with red thread.
        "t_gdl_herbs": (
            _thick("M32 58 L32 12", "#4f7a32", 3)
            + _thick("M32 58 L18 16", "#4f7a32", 3)
            + _thick("M32 58 L46 16", "#4f7a32", 3)
            + "".join(
                f'<ellipse cx="{x}" cy="{y}" rx="4" ry="7" fill="{GR}" {O} '
                f'transform="rotate({a} {x} {y})"/>'
                for x, y, a in ((32, 10, 0), (17, 14, -20), (47, 14, 20), (25, 26, -40), (39, 26, 40))
            )
            + f'<circle cx="32" cy="18" r="3" fill="#c8a0e0" {O}/>'
            + f'<rect x="26" y="40" width="12" height="5" rx="1" fill="{R}" {O}/>'
        ),
        # Faceted arrowheads: a big faceted head on its shaft.
        "t_arrows": (
            _thick("M10 54 L36 28", W, 3)
            + f'<path d="M10 54 L4 52 L8 58 Z M10 54 L12 60 L6 56 Z" fill="{P}" {O}/>'
            f'<path d="M32 32 L38 18 L56 8 L46 26 Z" fill="{S}" {O}/>'
            f'<path d="M38 18 L46 26 M56 8 L40 24" stroke="{SD}" stroke-width="1.5"/>'
        ),
        # Horse armour: a horse's head under a steel chanfron.
        "t_cav_armor_1": (
            _horse_head()
            + f'<path d="M31 9 Q44 15 50 28 L54 38 Q54 43 49 43 L44 41 Q38 30 30 18 Z" fill="{S}" {O}/>'
            + f'<path d="M30 18 L22 30 L28 32 Z" fill="{SD}" {O}/>'
        ),
        # Mail shirts: a short-sleeved tunic of rings.
        "t_inf_armor_1": (
            f'<path d="M22 8 L42 8 L56 18 L50 30 L44 26 L44 58 L20 58 L20 26 L14 30 L8 18 Z" '
            f'fill="{S}" {O}/>'
            + "".join(f'<path d="M20 {y} Q24 {y + 3} 28 {y} Q32 {y + 3} 36 {y} Q40 {y + 3} 44 {y}" '
                      f'fill="none" stroke="{SD}" stroke-width="1.2"/>' for y in range(16, 56, 5))
            + f'<path d="M26 8 Q32 14 38 8" fill="none" stroke="{D}" stroke-width="2"/>'
        ),
        # Armourer: an anvil, a sword on it, sparks.
        "t_weapons_1": (
            f'<path d="M8 30 H50 Q56 30 58 24 L58 32 Q56 38 46 38 L42 38 L44 50 L50 56 L14 56 L20 50 '
            f'L22 38 L14 38 Q8 36 8 30 Z" fill="#5a5f66" {O}/>'
            f'<path d="M6 24 L44 24 L50 26 L44 28 L6 28 Z" fill="{S}" {O}/>'
            f'<rect x="10" y="20" width="3" height="12" fill="{G}" {O}/>'
            f'<path d="M46 8 L50 16 M54 10 L52 18 M40 12 L46 18" stroke="{FL}" stroke-width="2.5" '
            f'stroke-linecap="round"/>'
        ),
        # Great studs: two horses' heads.
        "t_to_great_stud": (
            _horse_head(-8, 4, "#c9a070", "#8a6040")
            + _horse_head(8, 0, W, WD)
        ),
        # Reliquary: a gilded casket with a cross and a glow.
        "t_to_reliquary": (
            f'<circle cx="32" cy="30" r="24" fill="#f0d070" opacity="0.25"/>'
            f'<path d="M12 34 L32 20 L52 34 Z" fill="{G}" {O}/>'
            f'<rect x="14" y="34" width="36" height="20" fill="{G}" {O}/>'
            f'<path d="M20 40 H44 M20 48 H44" stroke="#9a6a20" stroke-width="1.5"/>'
            f'<circle cx="32" cy="44" r="3" fill="{R}" {O}/>'
            + _cross(32, 12, 7, G)
        ),
        # Tabor craft: wagons chained in a ring, seen from above.
        "t_pl_tabor": (
            f'<circle cx="32" cy="32" r="20" fill="none" stroke="{S}" stroke-width="2" '
            f'stroke-dasharray="2 2"/>'
            + "".join(
                f'<g transform="rotate({a} 32 32)"><rect x="25" y="5" width="14" height="10" rx="1.5" '
                f'fill="{W}" {O}/><path d="M25 8 H39" stroke="{WD}" stroke-width="1.5"/>'
                f'<circle cx="25" cy="15" r="2.4" fill="{WD}" {O}/><circle cx="39" cy="15" r="2.4" '
                f'fill="{WD}" {O}/></g>'
                for a in range(0, 360, 60)
            )
            + f'<circle cx="32" cy="32" r="5" fill="{R}" {O}/>'
        ),
        # Salt statute: a heap of salt and a charter with a red seal.
        "t_pl_salt_statute": (
            f'<path d="M4 58 Q18 30 30 32 Q40 30 52 58 Z" fill="#eef2f4" {O}/>'
            f'<path d="M14 50 L18 46 M26 44 L30 40 M36 50 L40 46" stroke="#b8c4cc" stroke-width="1.5"/>'
            f'<path d="M30 6 H56 V36 Q50 32 44 36 Q38 40 30 36 Z" fill="{P}" {O}/>'
            f'<path d="M35 14 H51 M35 20 H51 M35 26 H46" stroke="#7a5a3a" stroke-width="1.5"/>'
            f'<circle cx="50" cy="38" r="5" fill="{R}" {O}/>'
        ),
        # Procession: a church banner on a cross-bar staff between two candles.
        "t_pl_procession": (
            f'<rect x="30" y="8" width="4" height="52" fill="{WD}" {O}/>'
            f'<rect x="16" y="12" width="32" height="3" fill="{G}" {O}/>'
            f'<path d="M18 15 H46 V40 L32 48 L18 40 Z" fill="#f0e6c8" {O}/>'
            + _cross(32, 28, 7, R)
            + "".join(
                f'<rect x="{x}" y="34" width="5" height="22" fill="#f0e6c8" {O}/>'
                f'<path d="M{x + 2.5} 33 Q{x - 0.5} 28 {x + 2.5} 23 Q{x + 5.5} 28 {x + 2.5} 33 Z" '
                f'fill="{FL}" {O}/>'
                for x in (6, 53)
            )
        ),
    },
    "ages": {
        # Appanage: a small stockaded holding.
        "age_udel": (
            "".join(
                f'<path d="M{x} 58 V{24 + (i % 2) * 4} L{x + 3.5} {18 + (i % 2) * 4} L{x + 7} '
                f'{24 + (i % 2) * 4} V58 Z" fill="{W if i % 2 else WD}" {O}/>'
                for i, x in enumerate(range(7, 57, 7))
            )
            + f'<path d="M5 40 H59" stroke="{D}" stroke-width="2.5"/>'
        ),
        # Banner: a war banner (khorugv) on its pole.
        "age_khorugv": (
            f'<rect x="12" y="6" width="4" height="54" fill="{WD}" {O}/>'
            f'<path d="M16 10 H54 V40 L44 34 L35 42 L26 34 L16 40 Z" fill="{R}" {O}/>'
            f'<path d="M16 10 H54" stroke="{G}" stroke-width="3"/>'
            f'<circle cx="35" cy="22" r="6" fill="{G}" {O}/>'
            f'<circle cx="14" cy="5" r="3" fill="{G}" {O}/>'
        ),
        # Realm: the orb (держава) under a cross.
        "age_derzhava": (
            f'<circle cx="32" cy="38" r="19" fill="{G}" {O}/>'
            f'<path d="M13 38 H51" stroke="{D}" stroke-width="2"/>'
            f'<path d="M14 36 H50 V40 H14 Z" fill="{R}"/>'
            f'<path d="M32 19 V57" stroke="{D}" stroke-width="2"/>'
            f'<circle cx="25" cy="30" r="3.5" fill="#ffe9a0"/>'
            + _cross(32, 11, 7, G)
        ),
    },
    "spells": {
        # Wolf Trail: a pale path winding through dark firs, wolf tracks along it.
        "sp_wolf_path": (
            _fir(9, 40, 30) + _fir(55, 36, 30) + _fir(19, 22, 18, "#1c2a18") + _fir(46, 20, 16, "#1c2a18")
            + f'<path d="M18 64 Q34 52 27 41 Q21 31 32 22 Q38 16 35 9 L39 9 Q43 17 37 23 Q29 31 35 41 '
            f'Q43 53 36 64 Z" fill="#a49c78" opacity="0.45"/>'
            + "".join(_paw(x, y, r, sc) for x, y, r, sc in
                      ((24, 58, 25, 0.8), (33, 50, -5, 0.72), (27, 41, -20, 0.64), (33, 33, -30, 0.58),
                       (31, 25, 20, 0.52), (37, 18, 15, 0.46), (36, 12, -10, 0.4)))
            + f'<circle cx="52" cy="9" r="4" fill="#e8e2c4" opacity="0.85"/>'
        ),
        # Bog mist: reeds and bands of mist over the bog.
        "sp_bog_mist": (
            f'<ellipse cx="32" cy="56" rx="26" ry="5" fill="#3f5a3a" {O}/>'
            + "".join(_thick(f"M{x} 56 Q{x + 2} 36 {x + 4} {h}", "#7a8a4a", 2) for x, h in
                      ((14, 22), (20, 14), (42, 18), (48, 26)))
            + "".join(_thick(f"M{a} {y} Q{(a + b) / 2} {y - 6} {b} {y}", "#c8d8c8", 4) for a, b, y in
                      ((6, 40, 44), (22, 58, 34), (8, 36, 24)))
        ),
        # Exorcism: a shining cross, dark wisps fleeing it.
        "sp_exorcism": (
            "".join(f'<path d="M32 30 L{x} {y}" stroke="#ffe9a0" stroke-width="2" opacity="0.8"/>'
                    for x, y in ((6, 6), (58, 6), (6, 54), (58, 54), (32, 2), (2, 30), (62, 30)))
            + _cross(32, 30, 16, "#f0e0b0")
            + "".join(_thick(f"M{x} {y} q4 -6 0 -10 q-4 -4 2 -8", "#4a3a5a", 2.5) for x, y in
                      ((8, 58), (54, 60)))
        ),
        # Relic in the ranks: a processional cross held high over the men, glowing.
        "sp_relic": (
            f'<circle cx="32" cy="18" r="16" fill="#f0d070" opacity="0.3"/>'
            f'<rect x="30" y="20" width="4" height="40" fill="{WD}" {O}/>'
            + _cross(32, 16, 11, G)
            + f'<circle cx="32" cy="16" r="3" fill="{R}" {O}/>'
            + "".join(f'<circle cx="{x}" cy="54" r="5" fill="{S}" {O}/>' for x in (12, 22, 42, 52))
        ),
        # An icon before the army: a gilded icon board with a haloed face on a staff over the
        # men, glowing.
        "sp_icon": (
            f'<circle cx="32" cy="20" r="18" fill="#f0d070" opacity="0.3"/>'
            f'<rect x="30" y="34" width="4" height="26" fill="{WD}" {O}/>'
            f'<path d="M19 36 V12 Q32 2 45 12 V36 Z" fill="{G}" {O}/>'
            f'<path d="M23 33 V14 Q32 7 41 14 V33 Z" fill="#7a3a2a"/>'
            f'<circle cx="32" cy="18" r="6.5" fill="#f0d070" {O}/>'
            f'<circle cx="32" cy="19" r="3.5" fill="#d8b890"/>'
            f'<path d="M26 33 Q32 23 38 33 Z" fill="#2a4a7a"/>'
            + "".join(f'<circle cx="{x}" cy="56" r="5" fill="{S}" {O}/>' for x in (10, 20, 44, 54))
        ),
        # Perkūnas's Wrath: a dark storm cloud, a lightning bolt and slanting rain.
        "sp_perkunas": (
            "".join(f'<path d="M{x} {y} l-4 9" stroke="#8fb4d8" stroke-width="1.8" opacity="0.8"/>'
                    for x, y in ((12, 34), (20, 42), (46, 36), (54, 44), (40, 50), (16, 52)))
            + f'<path d="M34 26 L24 44 H32 L26 60 L44 36 H35 L41 26 Z" fill="#ffe27a" {O}/>'
            + "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="#4a4e60" {O}/>' for x, y, r in
                      ((18, 20, 10), (32, 15, 12), (46, 20, 10)))
            + f'<rect x="10" y="20" width="44" height="10" rx="5" fill="#4a4e60"/>'
        ),
        # Bogurodzica: an open hymn book with neumes on it, singing light rising from it.
        "sp_bogurodzica": (
            f'<circle cx="32" cy="22" r="18" fill="#f0d070" opacity="0.3"/>'
            + "".join(_thick(f"M{x} 26 Q{x + 4} 14 {x} 6", "#ffe9a0", 1.6) for x in (22, 32, 42))
            + f'<path d="M4 34 Q18 28 32 36 Q46 28 60 34 L60 56 Q46 50 32 58 Q18 50 4 56 Z" '
            f'fill="{P}" {O}/>'
            f'<path d="M32 36 V58" stroke="{D}" stroke-width="2"/>'
            + "".join(f'<rect x="{x}" y="{y}" width="3" height="3" fill="{R}"/>' for x, y in
                      ((10, 41), (15, 39), (20, 43), (39, 41), (44, 44), (50, 40)))
            + f'<path d="M8 48 Q18 44 28 49 M36 49 Q46 44 56 48" fill="none" stroke="#7a5a3a" '
            f'stroke-width="1.2"/>'
        ),
        # Banner blessing: a banner sprinkled with holy water, a small cross shining above.
        "sp_banner_blessing": (
            f'<rect x="14" y="8" width="4" height="52" fill="{WD}" {O}/>'
            f'<path d="M18 14 H50 V40 L42 34 L34 42 L26 34 L18 40 Z" fill="{R}" {O}/>'
            f'<path d="M18 14 H50" stroke="{G}" stroke-width="3"/>'
            + _cross(34, 26, 6, "#f0e0b0")
            + "".join(f'<path d="M{x} {y} q3 4 0 7 q-3 -3 0 -7 Z" fill="#bfe0ff" stroke="{D}" '
                      f'stroke-width="0.8"/>' for x, y in ((50, 45), (40, 49), (56, 53), (30, 51)))
        ),
        # The pact: a charter signed in blood, a dark wisp curling from its seal.
        "sp_pact": (
            f'<path d="M12 10 H48 Q54 10 54 16 V58 H18 Q12 58 12 52 Z" fill="{P}" {O}/>'
            f'<path d="M18 18 H48 M18 25 H48 M18 32 H42" stroke="#7a5a3a" stroke-width="1.5"/>'
            f'<path d="M20 44 Q26 38 30 44 T40 44" fill="none" stroke="#8a1a14" stroke-width="2"/>'
            f'<circle cx="44" cy="50" r="6" fill="#6a1410" {O}/>'
            + _thick("M44 44 Q38 34 46 28 Q54 22 48 12", "#3a2a4a", 2.5)
        ),
    },
}


def svg(group: str, glyph: str) -> str:
    top, bottom = PLATES[group]
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 64 64">'
        f'<defs><linearGradient id="p" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{top}"/>'
        f'<stop offset="1" stop-color="{bottom}"/></linearGradient>'
        '<radialGradient id="l" cx="0.3" cy="0.2" r="0.7"><stop offset="0" stop-color="#ffecbe" '
        'stop-opacity="0.28"/><stop offset="1" stop-color="#ffecbe" stop-opacity="0"/></radialGradient></defs>'
        '<rect width="64" height="64" fill="url(#p)"/><rect width="64" height="64" fill="url(#l)"/>'
        f"{glyph}</svg>\n"
    )


def main() -> None:
    for group, glyphs in GLYPHS.items():
        folder = os.path.join(OUT, group)
        os.makedirs(folder, exist_ok=True)
        for name, glyph in glyphs.items():
            with open(os.path.join(folder, name + ".svg"), "w") as fh:
                fh.write(svg(group, glyph))


if __name__ == "__main__":
    main()
