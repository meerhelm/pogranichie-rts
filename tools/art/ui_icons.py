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
