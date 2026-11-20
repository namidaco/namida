# by claude
"""Builds assets/fonts/broken_filled.ttf from the Iconsax bold svgs in assets/fonts/broken_filled_svgs/ and writes their
`Broken.*_filled` constants in lib/core/icon_fonts/broken_icons.dart.

Bold icons fill the center line of the outline strokes, so most come out half a stroke smaller than their outline twin
in broken.ttf. Every glyph is scaled around the grid center to the largest size that stays inside its twin's box.
Metrics come from broken.ttf so both fonts place their glyphs the same way.

New icon: copy its svg from Iconsax/Svg/All/bold, add it to ICONS with the next free code point and its outline twin's
`Broken` name, run the script. Code points of existing icons never change.

    python scripts/gen_filled_icons.py
"""

import re
from pathlib import Path

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.svgLib.path import parse_path
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parent.parent
SVGS_DIR = ROOT / 'assets/fonts/broken_filled_svgs'
FONT_PATH = ROOT / 'assets/fonts/broken_filled.ttf'
OUTLINE_FONT_PATH = ROOT / 'assets/fonts/broken.ttf'
DART_PATH = ROOT / 'lib/core/icon_fonts/broken_icons.dart'
FAMILY_NAME = 'broken_filled'

# -- (dart name, code point, svg name, outline twin)
ICONS = (
    ('dislike_filled', 0xE900, 'dislike', 'dislike'),
    ('like_filled', 0xE901, 'like-1', 'like_1'),
    ('heart_filled', 0xE902, 'heart', 'heart'),
    ('pause_circle_filled', 0xE903, 'pause-circle', 'pause_circle'),
)

ICONSAX_GRID = 24.0
CU2QU_MAX_ERROR = 1.0

DART_FILLED_BLOCK_REGEX = re.compile(
    rf"(static const String _fontFamilyFilled = '{FAMILY_NAME}';\r?\n\r?\n)"
    r"((?:  static const IconData \w+ = IconData\(0x[0-9a-f]+, fontFamily: _fontFamilyFilled\);\r?\n)*)"
)
DART_OUTLINE_ICON_REGEX = re.compile(r'static const IconData (\w+) = IconData\((0x[0-9a-f]+), fontFamily: _fontFamily\);')
SVG_PATH_REGEX = re.compile(r'<path\s[^>]*?\bd="([^"]+)"')


def read_svg_paths(svg_name):
    svg_path = SVGS_DIR / f'{svg_name}.svg'
    svg = svg_path.read_text(encoding='utf-8')
    if 'evenodd' in svg:
        raise SystemExit(f'{svg_path.name}: evenodd fill is not supported, truetype fills nonzero')
    paths = SVG_PATH_REGEX.findall(svg)
    if not paths:
        raise SystemExit(f'{svg_path.name}: no path found')
    return paths


def draw_svg(svg_paths, transform, pen):
    font_pen = TransformPen(pen, transform)
    for path_data in svg_paths:
        parse_path(path_data, font_pen)


def scaled_transform(units_per_em, ascent, scale_factor):
    units_per_grid = units_per_em / ICONSAX_GRID
    scale = units_per_grid * scale_factor
    offset = units_per_em / 2 * (1 - scale_factor)
    return (scale, 0, 0, -scale, offset, ascent - offset)


def fit_scale_factor(filled_bounds, outline_bounds, center):
    center_x, center_y = center
    filled_x_min, filled_y_min, filled_x_max, filled_y_max = filled_bounds
    outline_x_min, outline_y_min, outline_x_max, outline_y_max = outline_bounds
    side_factors = (
        (outline_x_min - center_x) / (filled_x_min - center_x),
        (outline_x_max - center_x) / (filled_x_max - center_x),
        (outline_y_min - center_y) / (filled_y_min - center_y),
        (outline_y_max - center_y) / (filled_y_max - center_y),
    )
    return min(side_factors)


def build_glyph(svg_paths, transform):
    glyph_pen = TTGlyphPen(None)
    quadratic_pen = Cu2QuPen(glyph_pen, max_err=CU2QU_MAX_ERROR)
    draw_svg(svg_paths, transform, quadratic_pen)
    return glyph_pen.glyph()


def build_font(outline_code_points):
    outline_font = TTFont(OUTLINE_FONT_PATH)
    outline_head = outline_font['head']
    units_per_em = outline_head.unitsPerEm
    hhea = outline_font['hhea']
    os2 = outline_font['OS/2']
    outline_cmap = outline_font.getBestCmap()
    outline_glyf = outline_font['glyf']
    unscaled_transform = scaled_transform(units_per_em, hhea.ascent, 1.0)
    grid_center = (units_per_em / 2, hhea.ascent - units_per_em / 2)

    glyphs = {'.notdef': TTGlyphPen(None).glyph()}
    char_map = {}
    for dart_name, code_point, svg_name, outline_name in ICONS:
        svg_paths = read_svg_paths(svg_name)
        filled_bounds_pen = BoundsPen(None)
        draw_svg(svg_paths, unscaled_transform, filled_bounds_pen)
        outline_code_point = outline_code_points[outline_name]
        outline_glyph_name = outline_cmap[outline_code_point]
        outline_bounds_pen = BoundsPen(None)
        outline_glyf[outline_glyph_name].draw(outline_bounds_pen, outline_glyf)
        scale_factor = fit_scale_factor(filled_bounds_pen.bounds, outline_bounds_pen.bounds, grid_center)
        transform = scaled_transform(units_per_em, hhea.ascent, scale_factor)
        glyph_name = f'uni{code_point:04X}'
        glyphs[glyph_name] = build_glyph(svg_paths, transform)
        char_map[code_point] = glyph_name
        print(f'  {dart_name}: x{scale_factor:.3f}')

    builder = FontBuilder(units_per_em, isTTF=True)
    builder.setupGlyphOrder(list(glyphs))
    builder.setupCharacterMap(char_map)
    builder.setupGlyf(glyphs)
    glyf = builder.font['glyf']
    # -- lsb must equal xMin, renderers shift the glyph by the difference
    metrics = {name: (units_per_em, getattr(glyf[name], 'xMin', 0)) for name in glyphs}
    builder.setupHorizontalMetrics(metrics)
    builder.setupHorizontalHeader(ascent=hhea.ascent, descent=hhea.descent, lineGap=hhea.lineGap)
    builder.setupNameTable({'familyName': FAMILY_NAME, 'styleName': 'Regular'})
    builder.setupOS2(
        sTypoAscender=os2.sTypoAscender,
        sTypoDescender=os2.sTypoDescender,
        sTypoLineGap=os2.sTypoLineGap,
        usWinAscent=os2.usWinAscent,
        usWinDescent=os2.usWinDescent,
        fsSelection=os2.fsSelection,
    )
    builder.setupPost()
    # -- fixed dates so a rerun gives the same file
    builder.updateHead(created=outline_head.created, modified=outline_head.modified)
    builder.save(FONT_PATH)


def write_dart_constants(dart, newline):
    lines = [f'  static const IconData {dart_name} = IconData(0x{code_point:x}, fontFamily: _fontFamilyFilled);{newline}' for dart_name, code_point, _, _ in ICONS]
    constants = ''.join(lines)
    new_dart, replaced_count = DART_FILLED_BLOCK_REGEX.subn(lambda m: m.group(1) + constants, dart)
    if replaced_count != 1:
        raise SystemExit(f'{DART_PATH.name}: filled icons block not found')
    with open(DART_PATH, 'w', encoding='utf-8', newline='') as f:
        f.write(new_dart)


def main():
    with open(DART_PATH, encoding='utf-8', newline='') as f:
        dart = f.read()
    newline = '\r\n' if '\r\n' in dart else '\n'
    outline_code_points = {name: int(code_point, 16) for name, code_point in DART_OUTLINE_ICON_REGEX.findall(dart)}
    build_font(outline_code_points)
    font_relative_path = FONT_PATH.relative_to(ROOT).as_posix()
    print(f'{font_relative_path}: {len(ICONS)} icons')
    write_dart_constants(dart, newline)
    dart_relative_path = DART_PATH.relative_to(ROOT).as_posix()
    print(dart_relative_path)


if __name__ == '__main__':
    main()
