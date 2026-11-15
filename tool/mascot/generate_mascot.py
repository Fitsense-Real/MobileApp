"""Generates Kapi, the Kora capybara, as one SVG per expression.

All expressions share the same geometry (head, body, snout, ears, lime) and
only change eyes, brows, mouth, arms and a small prop, so the character stays
consistent. Colours come from the app (lib/shared/widgets/kora_ui.dart and
lib/shared/constants/app_colors.dart); the extra tones are lighter/darker
steps of sage and lime.

    python3 tool/mascot/generate_mascot.py   # writes assets/images/mascot/
"""
from pathlib import Path

# Official Kora palette
FOREST = "#0F2E25"   # Kora.forest / AppColors.primaryDark
LIME = "#D9FF59"     # Kora.lime / AppColors.primary
IVORY = "#F7F5ED"    # Kora.ivory / AppColors.lightBackground
SAGE = "#7A9A7E"     # Kora.sage / AppColors.secondary
MUTED = "#5E7865"    # Kora.muted / AppColors.lightTextSecondary
LIME_SOFT = "#F0F6D4"  # AppColors.primarySoft
# Depth steps derived from the palette
SAGE_LIGHT = "#A3BCA6"
SAGE_PALE = "#C9D8C9"
LIME_DEEP = "#B6DB2E"

OUT = Path(__file__).resolve().parents[2] / "assets" / "images" / "mascot"


def lime_on_head():
    return f"""
  <g transform="translate(100 34)">
    <ellipse cx="0" cy="6" rx="21" ry="5" fill="{MUTED}" opacity=".35"/>
    <circle cx="0" cy="-6" r="20" fill="{LIME}"/>
    <circle cx="0" cy="-6" r="14" fill="none" stroke="{LIME_DEEP}" stroke-width="2"/>
    <path d="M0 -20 V8 M-14 -6 H14 M-10 -16 L10 4 M10 -16 L-10 4" stroke="{LIME_DEEP}" stroke-width="2" stroke-linecap="round"/>
    <circle cx="0" cy="-6" r="3" fill="{LIME_SOFT}"/>
    <path d="M6 -25 C14 -36 26 -34 30 -28 C22 -24 14 -22 6 -25 Z" fill="{FOREST}"/>
  </g>"""


def base(arms_back="", arms_front="", body_extra=""):
    return f"""
  <ellipse cx="100" cy="190" rx="62" ry="7" fill="{FOREST}" opacity=".12"/>
  {arms_back}
  <path d="M42 120 C42 92 66 80 100 80 C134 80 158 92 158 120 L162 158 C164 178 146 188 100 188 C54 188 36 178 38 158 Z" fill="{SAGE}"/>
  <path d="M70 128 C70 112 84 106 100 106 C116 106 130 112 130 128 L132 160 C132 174 118 180 100 180 C82 180 68 174 68 160 Z" fill="{SAGE_LIGHT}"/>
  {body_extra}
  <ellipse cx="74" cy="184" rx="16" ry="7" fill="{MUTED}"/>
  <ellipse cx="126" cy="184" rx="16" ry="7" fill="{MUTED}"/>
  <ellipse cx="62" cy="46" rx="9" ry="8" fill="{MUTED}"/>
  <ellipse cx="62" cy="47" rx="4" ry="3.5" fill="{SAGE_PALE}"/>
  <ellipse cx="138" cy="46" rx="9" ry="8" fill="{MUTED}"/>
  <ellipse cx="138" cy="47" rx="4" ry="3.5" fill="{SAGE_PALE}"/>
  <path d="M48 76 C48 52 66 40 100 40 C134 40 152 52 152 76 L152 98 C152 118 134 126 100 126 C66 126 48 118 48 98 Z" fill="{SAGE}"/>
  <rect x="62" y="74" width="76" height="50" rx="24" fill="{SAGE_LIGHT}"/>
  <ellipse cx="89" cy="88" rx="3" ry="5" fill="{FOREST}" transform="rotate(25 89 88)"/>
  <ellipse cx="111" cy="88" rx="3" ry="5" fill="{FOREST}" transform="rotate(-25 111 88)"/>
  {arms_front}"""


def eyes(kind):
    if kind == "open":
        return f"""
  <circle cx="76" cy="60" r="5.5" fill="{FOREST}"/><circle cx="78" cy="58" r="1.9" fill="{IVORY}"/>
  <circle cx="124" cy="60" r="5.5" fill="{FOREST}"/><circle cx="126" cy="58" r="1.9" fill="{IVORY}"/>"""
    if kind == "happy":
        return f"""
  <path d="M69 62 Q76 54 83 62" fill="none" stroke="{FOREST}" stroke-width="5" stroke-linecap="round"/>
  <path d="M117 62 Q124 54 131 62" fill="none" stroke="{FOREST}" stroke-width="5" stroke-linecap="round"/>"""
    if kind == "calm":
        return f"""
  <path d="M69 60 Q76 66 83 60" fill="none" stroke="{FOREST}" stroke-width="5" stroke-linecap="round"/>
  <path d="M117 60 Q124 66 131 60" fill="none" stroke="{FOREST}" stroke-width="5" stroke-linecap="round"/>"""
    if kind == "worried":
        return f"""
  <circle cx="76" cy="62" r="5" fill="{FOREST}"/><circle cx="77.6" cy="60.4" r="1.7" fill="{IVORY}"/>
  <circle cx="124" cy="62" r="5" fill="{FOREST}"/><circle cx="125.6" cy="60.4" r="1.7" fill="{IVORY}"/>
  <path d="M67 49 L83 53" stroke="{FOREST}" stroke-width="4.5" stroke-linecap="round"/>
  <path d="M133 49 L117 53" stroke="{FOREST}" stroke-width="4.5" stroke-linecap="round"/>"""
    raise ValueError(kind)


def mouth(kind):
    if kind == "smile":
        return f'<path d="M90 106 Q100 114 110 106" fill="none" stroke="{FOREST}" stroke-width="3.5" stroke-linecap="round"/>'
    if kind == "open":
        return f'<path d="M88 103 Q100 120 112 103 Z" fill="{FOREST}"/><path d="M94 110 Q100 115 106 110" fill="none" stroke="{LIME}" stroke-width="3" stroke-linecap="round"/>'
    if kind == "neutral":
        return f'<path d="M93 108 H107" stroke="{FOREST}" stroke-width="3.5" stroke-linecap="round"/>'
    if kind == "wobbly":
        return f'<path d="M89 110 Q94.5 104 100 110 Q105.5 116 111 110" fill="none" stroke="{FOREST}" stroke-width="3.5" stroke-linecap="round"/>'
    raise ValueError(kind)


def cheeks():
    return f'<ellipse cx="58" cy="76" rx="6" ry="4" fill="{LIME}" opacity=".6"/><ellipse cx="142" cy="76" rx="6" ry="4" fill="{LIME}" opacity=".6"/>'


def arm(d):
    return f'<path d="{d}" fill="none" stroke="{SAGE}" stroke-width="18" stroke-linecap="round"/>'


ARM_REST_L = arm("M56 130 Q48 150 60 162")
ARM_REST_R = arm("M144 130 Q152 150 140 162")
PAW_REST = f'<circle cx="62" cy="163" r="9" fill="{MUTED}"/><circle cx="138" cy="163" r="9" fill="{MUTED}"/>'

EXPRESSIONS = {
    # Bienvenida: saluda con la pata derecha en alto.
    "welcome": dict(
        back=arm("M148 126 Q170 104 172 78"),
        front=ARM_REST_L + f'<circle cx="62" cy="163" r="9" fill="{MUTED}"/><circle cx="172" cy="74" r="10" fill="{MUTED}"/>'
        + f'<path d="M182 58 q6 4 4 12 M188 50 q9 6 6 18" fill="none" stroke="{LIME_DEEP}" stroke-width="3" stroke-linecap="round"/>',
        eyes="happy", mouth="open", cheeks=True),
    # Explicacion: senala hacia un lado (donde el tour resalta algo).
    "explain": dict(
        back="",
        front=ARM_REST_L + f'<circle cx="62" cy="163" r="9" fill="{MUTED}"/>' + arm("M146 134 Q166 132 178 112")
        + f'<circle cx="179" cy="108" r="10" fill="{MUTED}"/>'
        + f'<path d="M188 90 l6 -6 M194 104 h8 M184 80 l2 -8" stroke="{LIME_DEEP}" stroke-width="3" stroke-linecap="round"/>',
        eyes="open", mouth="smile", cheeks=False),
    # Motivacion: ambos brazos arriba, pequeno destello.
    "motivate": dict(
        back=arm("M54 124 Q34 100 36 76") + arm("M146 124 Q166 100 164 76"),
        front=f'<circle cx="36" cy="72" r="10" fill="{MUTED}"/><circle cx="164" cy="72" r="10" fill="{MUTED}"/>',
        eyes="happy", mouth="open", cheeks=True),
    # Espera: ojos tranquilos y burbuja de puntos (sin porcentajes).
    "waiting": dict(
        back="",
        front=ARM_REST_L + ARM_REST_R + PAW_REST
        + f'<g transform="translate(160 26)"><rect x="-6" y="-14" width="44" height="26" rx="13" fill="{IVORY}" stroke="{SAGE_PALE}" stroke-width="2"/>'
        + f'<circle cx="5" cy="-1" r="3.5" fill="{SAGE}"/><circle cx="16" cy="-1" r="3.5" fill="{SAGE}"/><circle cx="27" cy="-1" r="3.5" fill="{SAGE}"/></g>',
        eyes="calm", mouth="smile", cheeks=False),
    # Exito: brazos arriba, ojos felices y destellos lima.
    "success": dict(
        back=arm("M54 124 Q34 100 36 76") + arm("M146 124 Q166 100 164 76"),
        front=f'<circle cx="36" cy="72" r="10" fill="{MUTED}"/><circle cx="164" cy="72" r="10" fill="{MUTED}"/>'
        + "".join(f'<path d="M{x} {y} l3 -9 l3 9 l9 3 l-9 3 l-3 9 l-3 -9 l-9 -3 Z" fill="{LIME_DEEP}"/>' for x, y in [(18, 40), (172, 36), (178, 100)]),
        eyes="happy", mouth="open", cheeks=True),
    # Error o dificultad: pata en la cabeza, cejas preocupadas, gota.
    "error": dict(
        back="",
        front=ARM_REST_L + f'<circle cx="62" cy="163" r="9" fill="{MUTED}"/>' + arm("M146 128 Q170 108 150 60")
        + f'<circle cx="148" cy="58" r="10" fill="{MUTED}"/><path d="M38 40 q-9 14 0 20 q9 -6 0 -20 Z" fill="{IVORY}" stroke="{SAGE}" stroke-width="2.5"/>',
        eyes="worried", mouth="wobbly", cheeks=False),
}


def svg(name, spec):
    body = base(spec["back"], spec["front"])
    face = eyes(spec["eyes"]) + mouth(spec["mouth"]) + (cheeks() if spec["cheeks"] else "")
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200" role="img" aria-label="Kapi, {name}">'
            f'{body}{face}{lime_on_head()}\n</svg>\n')


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for name, spec in EXPRESSIONS.items():
        (OUT / f"kapi_{name}.svg").write_text(svg(name, spec), encoding="utf-8")
        print("wrote", OUT / f"kapi_{name}.svg")
