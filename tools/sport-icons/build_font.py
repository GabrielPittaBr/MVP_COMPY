"""Gera a fonte de ícones das modalidades novas (CompySportIcons) e os SVGs.

Os ícones são desenhados na grade 24x24 dos Material Icons, com preenchimento
sólido. As bolas de futebol e de vôlei vêm dos próprios Material Icons
(`sports_soccer` e `sports_volleyball`, licença Apache 2.0), lidos da fonte
que acompanha o SDK do Flutter. O resto é geometria simples: círculos, elipses,
retângulos e traços convertidos em contorno.

Uso (a partir da raiz do repositório):

    python -m venv .venv-icons
    .venv-icons/Scripts/python -m pip install -r tools/sport-icons/requirements.txt
    .venv-icons/Scripts/python tools/sport-icons/build_font.py

Saídas:
    assets/fonts/CompySportIcons.otf   fonte registrada no pubspec.yaml
    tools/sport-icons/svg/<nome>.svg   um SVG por ícone, para reuso e revisão

Os code points ficam fixos em ICONS: trocar um deles quebra o
`CompySportIcons` em `lib/core/theme/compy_sport_icons.dart`.
"""

from __future__ import annotations

import argparse
import math
import shutil
import subprocess
from pathlib import Path as FsPath

from fontTools.fontBuilder import FontBuilder
from fontTools.misc.timeTools import timestampFromString
from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.t2CharStringPen import T2CharStringPen
from fontTools.pens.transformPen import TransformPen
from fontTools.svgLib.path import parse_path
from fontTools.ttLib import TTFont
from pathops import LineCap, LineJoin, Path, PathOp, op

ROOT = FsPath(__file__).resolve().parents[2]
FONT_OUT = ROOT / "assets" / "fonts" / "CompySportIcons.otf"
SVG_OUT = FsPath(__file__).resolve().parent / "svg"

FAMILY = "CompySportIcons"
UPM = 512  # mesma métrica da MaterialIcons: em de 512, ascent 512, descent 0
GRID = 24
SCALE = UPM / GRID

# Data fixa: a fonte gerada não muda de bytes se o desenho não mudar.
FIXED_TIMESTAMP = timestampFromString("Sat Oct 31 00:00:00 2026")

# Code points dos Material Icons usados como base.
MATERIAL_SOCCER = 0xE5F2
MATERIAL_VOLLEYBALL = 0xE5F4

KAPPA = 0.5522847498  # aproximação de quarto de círculo por cúbica


# ─────────────────────────────────────────────────────────────────────────────
# Primitivas (coordenadas SVG: origem no canto superior esquerdo, y para baixo)
# ─────────────────────────────────────────────────────────────────────────────


def ellipse(cx: float, cy: float, rx: float, ry: float, angle_deg: float = 0) -> Path:
    path = Path()
    pen = path.getPen()
    k_x, k_y = rx * KAPPA, ry * KAPPA
    a = math.radians(angle_deg)
    cos_a, sin_a = math.cos(a), math.sin(a)

    def p(x: float, y: float) -> tuple[float, float]:
        return (cx + x * cos_a - y * sin_a, cy + x * sin_a + y * cos_a)

    pen.moveTo(p(rx, 0))
    pen.curveTo(p(rx, k_y), p(k_x, ry), p(0, ry))
    pen.curveTo(p(-k_x, ry), p(-rx, k_y), p(-rx, 0))
    pen.curveTo(p(-rx, -k_y), p(-k_x, -ry), p(0, -ry))
    pen.curveTo(p(k_x, -ry), p(rx, -k_y), p(rx, 0))
    pen.closePath()
    return path


def circle(cx: float, cy: float, r: float) -> Path:
    return ellipse(cx, cy, r, r)


def svg_path(d: str) -> Path:
    path = Path()
    parse_path(d, path.getPen())
    return path


def stroke(d: str, width: float) -> Path:
    """Traço de espessura [width], pontas e junções arredondadas, já em contorno."""
    path = svg_path(d)
    path.stroke(width, LineCap.ROUND_CAP, LineJoin.ROUND_JOIN, 4)
    # O Skia desenha as pontas redondas como cônicas, que as operações
    # booleanas e a fonte não aceitam.
    path.convertConicsToQuads(0.01)
    return path


def transformed(path: Path, matrix: tuple[float, ...]) -> Path:
    out = Path()
    path.draw(TransformPen(out.getPen(), matrix))
    return out


def union(*paths: Path) -> Path:
    result = paths[0]
    for other in paths[1:]:
        result = op(result, other, PathOp.UNION, fix_winding=True)
    return result


def minus(base: Path, *holes: Path) -> Path:
    result = base
    for hole in holes:
        result = op(result, hole, PathOp.DIFFERENCE, fix_winding=True)
    return result


def material_glyph(codepoint: int, scale: float, cx: float, cy: float) -> Path:
    """Glifo dos Material Icons, reescalado em torno do centro da grade e
    levado para (cx, cy)."""
    font = TTFont(_material_font_path())
    glyph_set = font.getGlyphSet()
    name = font.getBestCmap()[codepoint]
    out = Path()
    # Fonte (y para cima, em 512) → SVG (y para baixo, em 24), já centrado em
    # (12, 12); depois escala e desloca para (cx, cy).
    s = scale / SCALE
    matrix = (s, 0, 0, -s, cx - 12 * scale, cy + 12 * scale)
    glyph_set[name].draw(TransformPen(out.getPen(), matrix))
    out.simplify(fix_winding=True)
    return out


_MATERIAL_FONT: FsPath | None = None


def _material_font_path() -> FsPath:
    global _MATERIAL_FONT
    if _MATERIAL_FONT is None:
        flutter = shutil.which("flutter")
        if flutter is None:
            raise SystemExit("flutter não está no PATH: preciso da MaterialIcons do SDK.")
        sdk = FsPath(flutter).resolve().parent.parent
        candidate = sdk / "bin" / "cache" / "artifacts" / "material_fonts" / "materialicons-regular.otf"
        if not candidate.exists():
            # O cache só existe depois de um `flutter precache`/`flutter run`.
            subprocess.run([flutter, "precache", "--no-android", "--no-ios"], check=True)
        _MATERIAL_FONT = candidate
    return _MATERIAL_FONT


# ─────────────────────────────────────────────────────────────────────────────
# Ícones
# ─────────────────────────────────────────────────────────────────────────────

# Onda de areia: a marca comum dos esportes de areia, embaixo do símbolo.
SAND_WAVE = "M3 20 Q5.25 18 7.5 20 T12 20 T16.5 20 T21 20"
SAND_WAVE_WIDTH = 2

# Símbolo principal dos esportes de areia: bola com raio 7 em (12, 9).
SAND_BALL_SCALE = 0.7
SAND_BALL_CENTER = (12, 9)


def sand_wave() -> Path:
    return stroke(SAND_WAVE, SAND_WAVE_WIDTH)


def icon_volei_de_praia() -> Path:
    return union(material_glyph(MATERIAL_VOLLEYBALL, SAND_BALL_SCALE, *SAND_BALL_CENTER), sand_wave())


def icon_futebol_de_areia() -> Path:
    return union(material_glyph(MATERIAL_SOCCER, SAND_BALL_SCALE, *SAND_BALL_CENTER), sand_wave())


def net(top: float, bottom: float, left: float = 3, right: float = 21) -> Path:
    """Rede esticada entre dois postes: faixa grossa em cima, malha embaixo.

    Os postes passam um pouco acima da faixa, que é o que separa "rede" de
    "banco" ou "cerca" nos tamanhos pequenos.
    """
    post = 1.6
    rope = 1.8
    bar = 1.2
    parts = [
        svg_path(f"M{left} {top - 1.5} H{left + post} V{bottom} H{left} Z"),  # poste esq.
        svg_path(f"M{right - post} {top - 1.5} H{right} V{bottom} H{right - post} Z"),  # poste dir.
        svg_path(f"M{left} {top} H{right} V{top + rope} H{left} Z"),  # faixa
        svg_path(f"M{left} {bottom - bar} H{right} V{bottom} H{left} Z"),  # borda de baixo
    ]
    # Malha: barras verticais entre os postes.
    inner_left, inner_right = left + post, right - post
    count = 3
    step = (inner_right - inner_left) / (count + 1)
    for i in range(1, count + 1):
        x = inner_left + step * i
        parts.append(svg_path(f"M{x - bar / 2} {top} H{x + bar / 2} V{bottom} H{x - bar / 2} Z"))
    return union(*parts)


def icon_futevolei() -> Path:
    # Bola de futebol sobre a rede: é o que separa o futevôlei do futebol de
    # areia (bola + onda) e do vôlei de praia (bola de vôlei + onda).
    ball = material_glyph(MATERIAL_SOCCER, 0.45, 12, 5.5)  # raio 4,5, y de 1 a 10
    return union(ball, net(top=12, bottom=16.5), sand_wave())


def racket(face_center: tuple[float, float], rx: float, ry: float, handle_end: tuple[float, float],
           handle_width: float, holes: list[tuple[float, float]], hole_r: float) -> Path:
    """Raquete de face sólida e furada (beach tennis, padel).

    A face é uma elipse com o eixo [ry] alinhado ao cabo. [holes] são
    deslocamentos na face "em pé": x na largura, y no comprimento, com y
    negativo apontando para a ponta da raquete.
    """
    cx, cy = face_center
    hx, hy = handle_end
    dx, dy = hx - cx, hy - cy
    length = math.hypot(dx, dy)
    ux, uy = dx / length, dy / length  # direção do cabo
    px, py = -uy, ux  # perpendicular
    angle = math.degrees(math.atan2(-ux, uy))  # leva o eixo ry até o cabo
    face = ellipse(cx, cy, rx, ry, angle)
    # Cabo: do centro da face até a ponta, em traço arredondado.
    handle = stroke(f"M{cx} {cy} L{hx} {hy}", handle_width)
    # Garganta: triângulo que liga a face ao cabo, como nas raquetes reais.
    base_dist = ry * 0.55
    tip_dist = ry + 2.2
    half = rx * 0.75
    bx, by = cx + ux * base_dist, cy + uy * base_dist
    tx, ty = cx + ux * tip_dist, cy + uy * tip_dist
    throat = svg_path(
        f"M{bx + px * half} {by + py * half} L{tx} {ty} L{bx - px * half} {by - py * half} Z"
    )
    body = union(face, handle, throat)
    # Furos: x ao longo da perpendicular, y ao longo do cabo.
    hole_paths = [circle(cx + px * x + ux * y, cy + py * x + uy * y, hole_r) for x, y in holes]
    return minus(body, *hole_paths)


def icon_beach_tennis() -> Path:
    body = racket((14.2, 7.2), rx=4.3, ry=5.0, handle_end=(5.6, 15.8), handle_width=2.2,
                  holes=[(-1.5, -1.6), (1.5, -1.6), (0, 0.9)], hole_r=0.8)
    ball = circle(5.2, 4.6, 2.1)
    return union(body, ball, sand_wave())


def icon_padel() -> Path:
    # Duas raquetes cruzadas e a bola em cima. Uma raquete só com a bola
    # embaixo ficava com a mesma silhueta do tênis de mesa (`sports_tennis`)
    # no pin do mapa.
    holes = [(-1.3, -1.5), (1.3, -1.5), (-1.3, 1.1), (1.3, 1.1)]
    left = racket((7.2, 8.6), rx=3.9, ry=4.6, handle_end=(18.6, 21), handle_width=2.2,
                  holes=holes, hole_r=0.7)
    right = racket((16.8, 8.6), rx=3.9, ry=4.6, handle_end=(5.4, 21), handle_width=2.2,
                   holes=holes, hole_r=0.7)
    ball = circle(12, 2.9, 1.8)
    return union(left, right, ball)


def icon_tenis() -> Path:
    ball = circle(12, 12, 10)
    seam_width = 1.8
    # Costuras: arcos de círculos centrados fora da bola, um de cada lado.
    left_seam = minus(circle(-1, 12, 10.5 + seam_width / 2), circle(-1, 12, 10.5 - seam_width / 2))
    right_seam = minus(circle(25, 12, 10.5 + seam_width / 2), circle(25, 12, 10.5 - seam_width / 2))
    return minus(ball, left_seam, right_seam)


# Nome do glifo → (code point, construtor). Os code points não mudam depois de
# publicados: `CompySportIcons` depende deles.
ICONS: dict[str, tuple[int, callable]] = {
    "beach_tennis": (0xE800, icon_beach_tennis),
    "futevolei": (0xE801, icon_futevolei),
    "volei_de_praia": (0xE802, icon_volei_de_praia),
    "futebol_de_areia": (0xE803, icon_futebol_de_areia),
    "padel": (0xE804, icon_padel),
    "tenis": (0xE805, icon_tenis),
}


# ─────────────────────────────────────────────────────────────────────────────
# Saída
# ─────────────────────────────────────────────────────────────────────────────


def write_svg(name: str, path: Path, out_dir: FsPath) -> None:
    pen = SVGPathPen(None, ntos=lambda v: f"{v:.3f}".rstrip("0").rstrip("."))
    path.draw(pen)
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / f"{name}.svg").write_text(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24">'
        f'<path d="{pen.getCommands()}"/></svg>\n',
        encoding="utf-8",
    )


def build_font(glyphs: dict[str, tuple[int, Path]], out: FsPath) -> None:
    # SVG (y para baixo, grade 24) → fonte (y para cima, em 512).
    to_font = (SCALE, 0, 0, -SCALE, 0, UPM)
    order = [".notdef", *glyphs]
    char_strings = {}
    metrics = {}

    notdef = T2CharStringPen(UPM, None)
    char_strings[".notdef"] = notdef.getCharString()
    metrics[".notdef"] = (UPM, 0)

    for name, (_, path) in glyphs.items():
        pen = T2CharStringPen(UPM, None)
        path.draw(TransformPen(pen, to_font))
        char_strings[name] = pen.getCharString()
        bounds = BoundsPen(None)
        path.draw(TransformPen(bounds, to_font))
        metrics[name] = (UPM, round(bounds.bounds[0]))

    fb = FontBuilder(UPM, isTTF=False)
    fb.setupGlyphOrder(order)
    fb.setupCharacterMap({cp: name for name, (cp, _) in glyphs.items()})
    fb.setupCFF(FAMILY, {"FullName": FAMILY, "FamilyName": FAMILY, "Weight": "Regular"},
                char_strings, {})
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=UPM, descent=0)
    fb.setupNameTable({
        "familyName": FAMILY,
        "styleName": "Regular",
        "copyright": "COMPY. Bolas de futebol e de volei derivadas dos Material Icons (Google).",
        "licenseDescription": "Material Icons: Apache License 2.0.",
        "licenseInfoURL": "https://www.apache.org/licenses/LICENSE-2.0",
    })
    fb.setupOS2(sTypoAscender=UPM, sTypoDescender=0, sTypoLineGap=0,
                usWinAscent=UPM, usWinDescent=0)
    fb.setupPost()
    fb.font["head"].created = FIXED_TIMESTAMP
    fb.font["head"].modified = FIXED_TIMESTAMP
    fb.font.recalcTimestamp = False
    out.parent.mkdir(parents=True, exist_ok=True)
    fb.save(str(out))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--font", type=FsPath, default=FONT_OUT)
    parser.add_argument("--svg-dir", type=FsPath, default=SVG_OUT)
    args = parser.parse_args()

    glyphs: dict[str, tuple[int, Path]] = {}
    for name, (codepoint, build) in ICONS.items():
        path = build()
        path.simplify(fix_winding=True)
        glyphs[name] = (codepoint, path)
        write_svg(name, path, args.svg_dir)

    build_font(glyphs, args.font)
    # ASCII puro: o console do Windows (cp1252) não imprime seta nem acento.
    print(f"{len(glyphs)} icones -> {args.font}")


if __name__ == "__main__":
    main()
