# by claude
"""Generates the light and dark card images used in README.md, as collapsible section headers and as link cards.

GitHub keeps a <picture> inside <summary> clickable (a bare <img> gets wrapped in a link that opens the image), and
swaps the light and dark image with the GitHub theme. Text is drawn as shapes with the app's Lexend Deca font, so it
looks the same everywhere. Icons are either glyphs of the app's icon font (Broken.<icon> in
lib/core/icon_fonts/broken_icons.dart) or brand logos written as si:<name>, read from some stuff/summaries/brands/
(simple-icons svgs, https://simpleicons.org).

usage:
  python scripts/gen_readme_cards.py                                          regenerate every card in the manifest
  python scripts/gen_readme_cards.py add <key> "<title>" <icon> [--level 2] [--open] [--anchor <name>]
                                                                              add or update a section card, print its snippet
  python scripts/gen_readme_cards.py link <key> "<title>" <icon> <url> [--subtitle "<text>"] [--level 2] [--width <n>] [--color <hex>]
                                                                              add or update a link card, print its snippet
  python scripts/gen_readme_cards.py store <key> "<name>" <icon> <url> --color <hex> [--caption "<text>"] [--beta]
                                                                              add or update a "get it on" store badge, print its snippet
  python scripts/gen_readme_cards.py snippet <key> [--open] [--anchor <name>] [--url <url>]
                                                                              print the README snippet of a card

needs fonttools and uharfbuzz (pip install fonttools uharfbuzz)
"""
import argparse
import colorsys
import html
import json
import re
from pathlib import Path

import uharfbuzz as hb
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / 'some stuff' / 'summaries'
MANIFEST = OUT_DIR / 'cards.json'
README_DIR = './some%20stuff/summaries'
LEXEND_DIR = ROOT / 'assets' / 'fonts' / 'LexendDeca'

SECTION_ARROW_ICON = 'arrow_down_2'
LINK_ARROW_ICON = 'export_1'
LINK_ANCHOR_ARROW_ICON = 'arrow_square_down'

LEVELS = {
    1: dict(width=640, height=58, gap=10, radius=12, pad=11, tile=36, tile_radius=9, icon=22, title=21, subtitle=16, line_gap=7),
    2: dict(width=560, height=46, gap=8, radius=10, pad=8, tile=30, tile_radius=8, icon=18, title=17, subtitle=14, line_gap=5),
}

SECTION_THEMES = {
    'light': dict(bg='#f7f7f6', border='#dcdad6', title='#22211f', subtitle='#64615c', tile='#463e35', icon='#ebe0d3', arrow='#64615c', text_opacity=1),
    'dark': dict(bg='#19191a', border='#3a3938', title='#f2f1ef', subtitle='#9c9994', tile='#4d4741', icon='#e3d9cd', arrow='#9c9994', text_opacity=1),
}

LINK_THEMES = {
    'light': dict(SECTION_THEMES['light'], text_opacity=0.8),
    'dark': dict(SECTION_THEMES['dark'], text_opacity=0.75),
}

LINK_EXTRA_HEIGHT = 6
LINK_TEXT_GAP = 12
LINK_ARROW_GAP = 28

STYLES = {
    'section': dict(themes=SECTION_THEMES, display_scale=0.68, text_scale=0.68, title_only_text_scale=0.68, arrow_icon=SECTION_ARROW_ICON),
    'link': dict(themes=LINK_THEMES, display_scale=0.68, text_scale=0.6, title_only_text_scale=0.65, arrow_icon=LINK_ARROW_ICON),
}

STORE_KIND = 'store'
STORE = dict(
    width=564, height=168, display_height=50, radius=24, border=3, tile=112, tile_radius=28, icon=68, text_gap=30, edge=28,
    caption=28, name=72, line_gap=22, pill_height=40, pill_text=24, pill_pad=16,
)
STORE_COLORS = dict(caption='#d4d4d4', name='#ffffff', pill='#f5a623', pill_text='#1c1a18')
STORE_BG_MIX = 0.14
STORE_BORDER_MIX = 0.45
BRAND_SATURATION = 0.7
BRAND_BG_MIX = 0.05
BRAND_BORDER_MIX = 0.35
BRAND_THEMES = {
    'light': dict(bg='#f6f8fa', title='#1f2328', subtitle='#59636e', arrow='#59636e'),
    'dark': dict(bg='#161b22', title='#e6edf3', subtitle='#8d96a0', arrow='#8d96a0'),
}
ON_BRAND_LIGHT = '#ffffff'
ON_BRAND_DARK = '#1a1a1a'


def main():
    section_options = argparse.ArgumentParser(add_help=False)
    section_options.add_argument('--open', action='store_true', help='starts expanded')
    section_options.add_argument('--anchor', help='link target, for cards that replace a heading')
    parser = argparse.ArgumentParser(description='README cards')
    commands = parser.add_subparsers(dest='command')
    add = commands.add_parser('add', parents=[section_options])
    add.add_argument('key')
    add.add_argument('title')
    add.add_argument('icon')
    add.add_argument('--level', type=int, default=1, choices=LEVELS)
    link = commands.add_parser('link')
    link.add_argument('key')
    link.add_argument('title')
    link.add_argument('icon')
    link.add_argument('url')
    link.add_argument('--subtitle')
    link.add_argument('--level', type=int, default=1, choices=LEVELS)
    link.add_argument('--width', type=int, help='fixed width instead of fitting the text')
    link.add_argument('--color', help='brand color for the icon tile, instead of the namida one')
    store = commands.add_parser('store')
    store.add_argument('key')
    store.add_argument('title')
    store.add_argument('icon')
    store.add_argument('url')
    store.add_argument('--caption', default='GET IT ON')
    store.add_argument('--color', required=True, help='brand color of the source')
    store.add_argument('--beta', action='store_true', help='adds the BETA pill')
    snippet = commands.add_parser('snippet', parents=[section_options])
    snippet.add_argument('key')
    snippet.add_argument('--url', help='link card target other than its saved one')
    args = parser.parse_args()

    cards = {}
    if MANIFEST.exists():
        manifest_text = MANIFEST.read_text(encoding='utf-8')
        cards = json.loads(manifest_text)
    renderer = _CardRenderer()

    if args.command == 'snippet':
        card = cards[args.key]
        snippet_text = renderer.snippet(args.key, card, is_open=args.open, anchor=args.anchor, url=args.url)
        print(snippet_text)
        return

    if args.command in ('add', 'link', STORE_KIND):
        is_section = args.command == 'add'
        if args.command == STORE_KIND:
            card = dict(kind=STORE_KIND, title=args.title, icon=args.icon, url=args.url, color=args.color, caption=args.caption, beta=args.beta)
        else:
            card = dict(title=args.title, icon=args.icon, level=args.level)
        if args.command == 'link':
            card.update(kind='link', url=args.url, subtitle=args.subtitle, width=args.width, color=args.color)
        renderer.write(args.key, card)
        cards[args.key] = card
        manifest_text = json.dumps(cards, indent=2)
        MANIFEST.write_text(manifest_text + '\n', encoding='utf-8', newline='\n')
        is_open = is_section and args.open
        anchor = args.anchor if is_section else None
        snippet_text = renderer.snippet(args.key, card, is_open=is_open, anchor=anchor, url=None)
        print(snippet_text)
        return

    for key, card in cards.items():
        renderer.write(key, card)
    out_dir_relative = OUT_DIR.relative_to(ROOT)
    print('generated %d cards in %s' % (len(cards), out_dir_relative))


class _CardRenderer:
    def __init__(self):
        self._icons = Icons()
        self._title_font = TextFont(LEXEND_DIR / 'LexendDeca-SemiBold.ttf')
        self._subtitle_font = TextFont(LEXEND_DIR / 'LexendDeca-Regular.ttf')

    def write(self, key, card):
        OUT_DIR.mkdir(parents=True, exist_ok=True)
        if card.get('kind') == STORE_KIND:
            svg_file = OUT_DIR / f'{key}.svg'
            svg_file.write_text(self._render_store(card), encoding='utf-8', newline='\n')
            return
        style = self._style_of(card)
        brand = card.get('color')
        for theme, colors in style['themes'].items():
            if brand:
                colors = _brand_theme(brand, colors, BRAND_THEMES[theme])
            svg = self._render(card, colors)
            svg_file = OUT_DIR / f'{key}_{theme}.svg'
            svg_file.write_text(svg, encoding='utf-8', newline='\n')

    def snippet(self, key, card, is_open, anchor, url):
        if card.get('kind') == STORE_KIND:
            alt = html.escape(card['title'])
            href = url or card['url']
            return f'<a href="{href}"><img src="{README_DIR}/{key}.svg" height="{STORE["display_height"]}" alt="{alt}"></a>'
        style = self._style_of(card)
        width = self._layout(card)['width']
        display_width = round(width * style['display_scale'])
        alt = html.escape(card['title'])
        picture = (
            f'<picture><source media="(prefers-color-scheme: dark)" srcset="{README_DIR}/{key}_dark.svg">'
            f'<img src="{README_DIR}/{key}_light.svg" width="{display_width}" align="absmiddle" alt="{alt}"></picture>'
        )
        if card.get('kind') == 'link':
            href = url or card['url']
            return f'<a href="{href}">{picture}</a>'
        open_attribute = ' open' if is_open else ''
        anchor_line = f'<a name="{anchor}"></a>\n' if anchor else ''
        return f'{anchor_line}<details{open_attribute}>\n<summary>{picture}</summary>'

    def _layout(self, card):
        level = LEVELS[card.get('level', 1)]
        tile = level['tile']
        icon_size = level['icon']
        if card.get('kind') != 'link':
            card_height = level['height']
            tile_x = level['pad']
            text_x = tile_x * 2 + tile + 4
            width = level['width']
            return dict(
                width=width, card_height=card_height, card_radius=level['radius'], tile_x=tile_x, tile_radius=level['tile_radius'],
                text_x=text_x, arrow_x=width - tile_x - 6 - icon_size,
            )

        card_height = level['height'] + LINK_EXTRA_HEIGHT
        card_radius = card_height / 2
        tile_x = card_radius - tile / 2
        text_x = tile_x + tile + LINK_TEXT_GAP
        width = card.get('width')
        if not width:
            title_size, subtitle_size = self._text_sizes(card, level)
            title_width = self._title_font.width(card['title'], title_size)
            subtitle = card.get('subtitle')
            subtitle_width = 0
            if subtitle:
                subtitle_width = self._subtitle_font.width(subtitle, subtitle_size)
            text_end = text_x + max(title_width, subtitle_width)
            width = round(text_end + LINK_ARROW_GAP + card_radius + icon_size / 2)
        return dict(
            width=width, card_height=card_height, card_radius=card_radius, tile_x=tile_x, tile_radius=tile / 2,
            text_x=text_x, arrow_x=width - card_radius - icon_size / 2,
        )

    def _render(self, card, colors):
        level = LEVELS[card.get('level', 1)]
        layout = self._layout(card)
        width = layout['width']
        card_height = layout['card_height']
        gap = level['gap']
        height = card_height + gap * 2
        mid = gap + card_height / 2
        tile = level['tile']
        icon_size = level['icon']
        tile_x = layout['tile_x']
        tile_y = mid - tile / 2
        icon_offset = (tile - icon_size) / 2
        text_x = layout['text_x']
        text_opacity = colors['text_opacity']
        style = self._style_of(card)

        title_size, subtitle_size = self._text_sizes(card, level)
        title_cap = self._title_font.cap_height * title_size
        subtitle = card.get('subtitle')
        if subtitle:
            subtitle_cap = self._subtitle_font.cap_height * subtitle_size
            block_height = title_cap + level['line_gap'] + subtitle_cap
            title_baseline = mid - block_height / 2 + title_cap
            subtitle_baseline = title_baseline + level['line_gap'] + subtitle_cap
        else:
            title_baseline = mid + title_cap / 2

        icon_svg = self._icons.draw(card['icon'], tile_x + icon_offset, tile_y + icon_offset, icon_size, colors['icon'])
        title_path = self._title_font.path(card['title'], title_size, text_x, title_baseline)
        arrow_icon = style['arrow_icon']
        if card.get('url', '').startswith('#'):
            arrow_icon = LINK_ANCHOR_ARROW_ICON
        arrow_svg = self._icons.draw(arrow_icon, layout['arrow_x'], mid - icon_size / 2, icon_size, colors['arrow'])
        parts = [
            f'<rect x="1" y="{gap + 1}" width="{width - 2}" height="{card_height - 2}" rx="{layout["card_radius"] - 1:g}" '
            f'fill="{colors["bg"]}" stroke="{colors["border"]}" stroke-width="1.5"/>',
            f'<rect x="{tile_x:g}" y="{tile_y:g}" width="{tile}" height="{tile}" rx="{layout["tile_radius"]:g}" fill="{colors["tile"]}"/>',
            icon_svg,
            f'<path fill="{colors["title"]}" fill-opacity="{text_opacity}" d="{title_path}"/>',
        ]
        if subtitle:
            subtitle_path = self._subtitle_font.path(subtitle, subtitle_size, text_x, subtitle_baseline)
            parts.append(f'<path fill="{colors["subtitle"]}" fill-opacity="{text_opacity}" d="{subtitle_path}"/>')
        parts.append(arrow_svg)
        body = '\n  '.join(parts)
        return f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">\n  {body}\n</svg>\n'

    def _render_store(self, card):
        width = STORE['width']
        height = STORE['height']
        brand = _soften(card['color'])
        colors = dict(
            STORE_COLORS, tile=brand, icon=_on_brand(brand), bg=_mix(brand, '#000000', STORE_BG_MIX), border=_mix(brand, '#000000', STORE_BORDER_MIX),
        )
        font = self._title_font
        tile = STORE['tile']
        tile_xy = (height - tile) / 2
        icon_size = STORE['icon']
        icon_xy = tile_xy + (tile - icon_size) / 2
        text_x = tile_xy + tile + STORE['text_gap']
        text_end = width - STORE['edge']

        name = card['title']
        name_size = STORE['name']
        name_width = font.width(name, name_size)
        if name_width > text_end - text_x:
            name_size *= (text_end - text_x) / name_width
        caption_cap = font.cap_height * STORE['caption']
        name_cap = font.cap_height * name_size
        block_height = caption_cap + STORE['line_gap'] + name_cap
        caption_baseline = height / 2 - block_height / 2 + caption_cap
        name_baseline = caption_baseline + STORE['line_gap'] + name_cap

        inset = STORE['border'] / 2
        parts = [
            f'<rect x="{inset:g}" y="{inset:g}" width="{width - inset * 2:g}" height="{height - inset * 2:g}" rx="{STORE["radius"]}" '
            f'fill="{colors["bg"]}" stroke="{colors["border"]}" stroke-width="{STORE["border"]}"/>',
            f'<rect x="{tile_xy:g}" y="{tile_xy:g}" width="{tile}" height="{tile}" rx="{STORE["tile_radius"]}" fill="{colors["tile"]}"/>',
            self._icons.draw(card['icon'], icon_xy, icon_xy, icon_size, colors['icon']),
            f'<path fill="{colors["caption"]}" d="{font.path(card["caption"], STORE["caption"], text_x, caption_baseline)}"/>',
            f'<path fill="{colors["name"]}" d="{font.path(name, name_size, text_x, name_baseline)}"/>',
        ]
        if card.get('beta'):
            pill_height = STORE['pill_height']
            pill_text_cap = font.cap_height * STORE['pill_text']
            pill_width = font.width('BETA', STORE['pill_text']) + STORE['pill_pad'] * 2
            pill_x = text_end - pill_width
            pill_y = caption_baseline - caption_cap / 2 - pill_height / 2
            pill_baseline = pill_y + pill_height / 2 + pill_text_cap / 2
            parts.append(
                f'<rect x="{pill_x:g}" y="{pill_y:g}" width="{pill_width:g}" height="{pill_height}" rx="{pill_height / 2:g}" fill="{colors["pill"]}"/>'
            )
            parts.append(f'<path fill="{colors["pill_text"]}" d="{font.path("BETA", STORE["pill_text"], pill_x + STORE["pill_pad"], pill_baseline)}"/>')
        body = '\n  '.join(parts)
        return f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">\n  {body}\n</svg>\n'

    def _text_sizes(self, card, level):
        style = self._style_of(card)
        text_scale = style['text_scale'] if card.get('subtitle') else style['title_only_text_scale']
        text_factor = text_scale / style['display_scale']
        return level['title'] * text_factor, level['subtitle'] * text_factor

    @staticmethod
    def _style_of(card):
        return STYLES[card.get('kind', 'section')]


def _brand_theme(brand, colors, neutral):
    soft = _soften(brand)
    branded = dict(colors, **neutral)
    branded.update(tile=soft, icon=_on_brand(soft), bg=_mix(soft, neutral['bg'], BRAND_BG_MIX), border=_mix(soft, neutral['bg'], BRAND_BORDER_MIX))
    return branded


def _soften(color):
    red, green, blue = (int(color[i:i + 2], 16) / 255 for i in (1, 3, 5))
    hue, lightness, saturation = colorsys.rgb_to_hls(red, green, blue)
    channels = colorsys.hls_to_rgb(hue, lightness, saturation * BRAND_SATURATION)
    return '#' + ''.join('%02x' % round(channel * 255) for channel in channels)


def _mix(color, base, amount):
    channels = [int(color[i:i + 2], 16) * amount + int(base[i:i + 2], 16) * (1 - amount) for i in (1, 3, 5)]
    return '#' + ''.join('%02x' % round(channel) for channel in channels)


def _on_brand(color):
    red, green, blue = (int(color[i:i + 2], 16) / 255 for i in (1, 3, 5))
    luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
    return ON_BRAND_DARK if luminance > 0.6 else ON_BRAND_LIGHT


class TextFont:
    def __init__(self, file):
        font_data = file.read_bytes()
        self._hb_font = hb.Font(hb.Face(font_data))
        font = TTFont(file)
        self._glyphs = font.getGlyphSet()
        self._glyph_order = font.getGlyphOrder()
        self._upm = font['head'].unitsPerEm
        self.cap_height = font['OS/2'].sCapHeight / self._upm

    def width(self, text, size):
        _, positions = self._shape(text)
        advance = sum(position.x_advance for position in positions)
        return advance * size / self._upm

    def path(self, text, size, x, baseline):
        infos, positions = self._shape(text)
        scale = size / self._upm
        pen = SVGPathPen(self._glyphs)
        cursor = 0
        for info, position in zip(infos, positions):
            glyph_name = self._glyph_order[info.codepoint]
            glyph_x = x + (cursor + position.x_offset) * scale
            glyph_y = baseline - position.y_offset * scale
            glyph_pen = TransformPen(pen, (scale, 0, 0, -scale, glyph_x, glyph_y))
            self._glyphs[glyph_name].draw(glyph_pen)
            cursor += position.x_advance
        return pen.getCommands()

    def _shape(self, text):
        buffer = hb.Buffer()
        buffer.add_str(text)
        buffer.guess_segment_properties()
        hb.shape(self._hb_font, buffer, {'kern': True, 'liga': True})
        return buffer.glyph_infos, buffer.glyph_positions


class Icons:
    BROKEN_DART = ROOT / 'lib' / 'core' / 'icon_fonts' / 'broken_icons.dart'
    BROKEN_FONT = ROOT / 'assets' / 'fonts' / 'broken.ttf'
    BRANDS_DIR = OUT_DIR / 'brands'
    BRAND_PREFIX = 'si:'
    _BROKEN_REGEX = re.compile(r'IconData (\w+) = IconData\(0x([0-9a-f]+), fontFamily: _fontFamily\)')
    _BRAND_PATH_REGEX = re.compile(r'<path d="([^"]+)"')

    def __init__(self):
        dart = self.BROKEN_DART.read_text(encoding='utf-8')
        self._codepoints = {name: int(code, 16) for name, code in self._BROKEN_REGEX.findall(dart)}
        font = TTFont(self.BROKEN_FONT)
        hhea = font['hhea']
        self._glyphs = font.getGlyphSet()
        self._cmap = font.getBestCmap()
        self._ascent = hhea.ascent
        self._em_height = hhea.ascent - hhea.descent
        self._paths = {}

    def draw(self, spec, x, y, size, color):
        path = self._path(spec)
        if spec.startswith(self.BRAND_PREFIX):
            transform = 'translate(%g %g) scale(%g)' % (x, y, size / 24)
        else:
            scale = size / self._em_height
            transform = 'translate(%g %g) scale(%g %g) translate(0 %g)' % (x, y, scale, -scale, -self._ascent)
        return f'<path transform="{transform}" fill="{color}" d="{path}"/>'

    def _path(self, spec):
        cached = self._paths.get(spec)
        if cached is not None:
            return cached
        if spec.startswith(self.BRAND_PREFIX):
            brand_name = spec[len(self.BRAND_PREFIX):]
            brand_file = self.BRANDS_DIR / f'{brand_name}.svg'
            if not brand_file.exists():
                raise SystemExit('missing brand icon %s.svg in %s' % (brand_name, self.BRANDS_DIR))
            brand_svg = brand_file.read_text(encoding='utf-8')
            brand_match = self._BRAND_PATH_REGEX.search(brand_svg)
            path = brand_match.group(1)
        else:
            codepoint = self._codepoints.get(spec)
            if codepoint is None:
                raise SystemExit('unknown icon Broken.%s' % spec)
            glyph_name = self._cmap[codepoint]
            pen = SVGPathPen(self._glyphs)
            self._glyphs[glyph_name].draw(pen)
            path = pen.getCommands()
        self._paths[spec] = path
        return path


if __name__ == '__main__':
    main()
