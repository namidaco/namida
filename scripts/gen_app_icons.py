# by claude
"""Generates the android, ios and macos app icons from the launcher icons in assets/.

Silhouettes have no edge of their own, so they sit on a set color instead of their edge color. Round icons that were cut from a bigger
image fill the whole shape from that image instead (on android and ios).

android: each alternate icon becomes an adaptive icon. Its background is a slight gradient made from the edge color.
Its art is cut into a circle as the foreground (full square icons fill the whole shape instead), and silhouettes stay
whole. Themed icons use the default monochrome glyph. The default icon keeps its own hand made layers.

ios: ios masks its own rounded square and refuses transparency, so each icon is laid on its background color.

macos: macos draws the shape as is, so its icon keeps the transparency inside the standard margin.

    python scripts/gen_app_icons.py
"""

import colorsys
import functools
import json
import re
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
ICONS_ENUM = ROOT / 'lib/controller/platform/namida_channel/namida_channel_base.dart'
DEFAULT_ICON = 'namida'

SILHOUETTE_BACKGROUNDS = {
    'glowy': (14, 24, 48),
    'monet': (52, 56, 92),
    'retro': (18, 14, 22),
    'space': (181, 29, 2),
}
# -- the bigger image each round asset was cut from, and the box it was cut at
FULL_BLEED_SOURCES = {
    'jellyda': ('assets/jellyda/jellyda_v2.webp', (517, 106, 1262, 851)),
}

ANDROID_RES = ROOT / 'android/app/src/main/res'
ANDROID_ADAPTIVE_DIR = ANDROID_RES / 'mipmap-anydpi-v26'
ANDROID_BACKGROUND_DIR = ANDROID_RES / 'drawable'
ANDROID_DENSITIES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
ANDROID_LAYER_DP = 108
# -- launchers show only this center part
ANDROID_VISIBLE_DP = 72
ANDROID_CIRCLE_DP = 64
ANDROID_SILHOUETTE_DP = 58
ANDROID_FULL_SQUARE_ICONS = {'cutsie'}
ANDROID_TOP_LEFT_LIGHTNESS_FACTOR = 1.1
ANDROID_BOTTOM_RIGHT_LIGHTNESS_FACTOR = 0.8
ANDROID_CIRCLE_MASK_SUPERSAMPLE = 4
ANDROID_WEBP_QUALITY = 90

IOS_ASSETS = ROOT / 'ios/Runner/Assets.xcassets'
IOS_SIZE = 1024
# -- the art fills this much of the ios square, the rest is the background color
IOS_ART_RATIO = 0.86

MACOS_ICONSET = ROOT / 'macos/Runner/Assets.xcassets/AppIcon.appiconset'
# -- macos big sur grid: the shape is 824 of 1024
MACOS_ART_RATIO = 824 / 1024
MACOS_SIZES = [16, 32, 64, 128, 256, 512, 1024]


def read_icons() -> dict[str, str]:
    text = ICONS_ENUM.read_text(encoding='utf-8')
    block = text.split('enum NamidaAppIcons {', 1)[1].split(';', 1)[0]
    return dict(re.findall(r'^\s*(\w+)\("([^"]+)"', block, re.MULTILINE))


def cropped_art(path: Path) -> Image.Image:
    image = Image.open(path).convert('RGBA')
    alpha = image.getchannel('A')
    bbox = alpha.getbbox()
    return image.crop(bbox)


def edge_color(image: Image.Image) -> tuple[int, int, int]:
    """average of the opaque pixels on the outer ring of the art."""
    width, height = image.size
    pixels = image.load()
    ring = max(2, min(width, height) // 40)
    total = [0, 0, 0]
    count = 0
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a < 200:
                continue
            is_ring = False
            for dx, dy in ((ring, 0), (-ring, 0), (0, ring), (0, -ring)):
                nx, ny = x + dx, y + dy
                if nx < 0 or ny < 0 or nx >= width or ny >= height or pixels[nx, ny][3] < 200:
                    is_ring = True
                    break
            if not is_ring:
                continue
            total[0] += r
            total[1] += g
            total[2] += b
            count += 1
    if count == 0:
        return (0, 0, 0)
    return (total[0] // count, total[1] // count, total[2] // count)


def fit(art: Image.Image, side: int) -> Image.Image:
    width, height = art.size
    scale = side / max(width, height)
    fitted_width = max(1, round(width * scale))
    fitted_height = max(1, round(height * scale))
    return art.resize((fitted_width, fitted_height), Image.LANCZOS)


def background_color(name: str, art: Image.Image) -> tuple[int, int, int]:
    silhouette_background = SILHOUETTE_BACKGROUNDS.get(name)
    if silhouette_background:
        return silhouette_background
    small = fit(art, 256)
    return edge_color(small)


def centered_offset(canvas_side: int, image: Image.Image) -> tuple[int, int]:
    return ((canvas_side - image.width) // 2, (canvas_side - image.height) // 2)


@functools.cache
def open_source(source_path: str) -> Image.Image:
    return Image.open(ROOT / source_path).convert('RGBA')


def full_bleed_square(name: str, art_ratio: float, side_px: int) -> Image.Image:
    """the square of the source image around the cut box, where the cut box takes art_ratio of the side."""
    source_path, art_box = FULL_BLEED_SOURCES[name]
    source = open_source(source_path)
    left, top, right, bottom = art_box
    center_x = (left + right) / 2
    center_y = (top + bottom) / 2
    half_side = (right - left) / art_ratio / 2
    box = (round(center_x - half_side), round(center_y - half_side), round(center_x + half_side), round(center_y + half_side))
    square = source.crop(box)
    return square.resize((side_px, side_px), Image.LANCZOS)


# ---------------- android ----------------


def android_foreground_name(name: str) -> str:
    return f'ic_launcher_{name}_foreground'


def android_background_name(name: str) -> str:
    return f'ic_launcher_{name}_background'


def android_gradient_colors(base: tuple[int, int, int]) -> tuple[tuple[int, int, int], tuple[int, int, int]]:
    normalized = (c / 255 for c in base)
    hue, lightness, saturation = colorsys.rgb_to_hls(*normalized)

    def shade(factor: float) -> tuple[int, int, int]:
        shaded_lightness = min(1.0, lightness * factor)
        rgb = colorsys.hls_to_rgb(hue, shaded_lightness, saturation)
        return tuple(round(c * 255) for c in rgb)

    return shade(ANDROID_TOP_LEFT_LIGHTNESS_FACTOR), shade(ANDROID_BOTTOM_RIGHT_LIGHTNESS_FACTOR)


def android_circle_mask(side: int) -> Image.Image:
    big_side = side * ANDROID_CIRCLE_MASK_SUPERSAMPLE
    mask = Image.new('L', (big_side, big_side), 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse((0, 0, big_side - 1, big_side - 1), fill=255)
    return mask.resize((side, side), Image.LANCZOS)


def android_foreground(name: str, art: Image.Image, layer_px: int) -> Image.Image:
    if name in FULL_BLEED_SOURCES:
        art_ratio = ANDROID_CIRCLE_DP / ANDROID_LAYER_DP
        return full_bleed_square(name, art_ratio, layer_px)

    layer = Image.new('RGBA', (layer_px, layer_px), (0, 0, 0, 0))
    if name in SILHOUETTE_BACKGROUNDS:
        silhouette_side = round(layer_px * ANDROID_SILHOUETTE_DP / ANDROID_LAYER_DP)
        fitted = fit(art, silhouette_side)
        layer.alpha_composite(fitted, centered_offset(layer_px, fitted))
        return layer

    is_full_square = name in ANDROID_FULL_SQUARE_ICONS
    side_dp = ANDROID_VISIBLE_DP if is_full_square else ANDROID_CIRCLE_DP
    side = round(layer_px * side_dp / ANDROID_LAYER_DP)
    scale = side / min(art.size)
    scaled_size = (round(art.width * scale), round(art.height * scale))
    scaled = art.resize(scaled_size, Image.LANCZOS)
    left = (scaled.width - side) // 2
    top = (scaled.height - side) // 2
    square = scaled.crop((left, top, left + side, top + side))
    if not is_full_square:
        art_alpha = square.getchannel('A')
        circle_alpha = ImageChops.multiply(art_alpha, android_circle_mask(side))
        square.putalpha(circle_alpha)
    layer.alpha_composite(square, centered_offset(layer_px, square))
    return layer


def android_hex_color(rgb: tuple[int, int, int]) -> str:
    return '#FF{:02X}{:02X}{:02X}'.format(*rgb)


def android_adaptive_xml(name: str) -> str:
    return f'''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
  <background android:drawable="@drawable/{android_background_name(name)}"/>
  <foreground android:drawable="@mipmap/{android_foreground_name(name)}"/>
  <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>
</adaptive-icon>
'''


def android_background_xml(top_left: tuple[int, int, int], bottom_right: tuple[int, int, int]) -> str:
    return f'''<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android">
  <gradient android:angle="315" android:startColor="{android_hex_color(top_left)}" android:endColor="{android_hex_color(bottom_right)}"/>
</shape>
'''


def remove_android_generated() -> None:
    for old in ANDROID_ADAPTIVE_DIR.glob('ic_launcher_*.xml'):
        old.unlink()
    for old in ANDROID_BACKGROUND_DIR.glob('ic_launcher_*_background.xml'):
        old.unlink()
    for density in ANDROID_DENSITIES:
        density_dir = ANDROID_RES / f'mipmap-{density}'
        for old in density_dir.glob('ic_launcher_*_foreground.*'):
            old.unlink()


def write_android_icon(name: str, art: Image.Image, base_color: tuple[int, int, int]) -> None:
    top_left, bottom_right = android_gradient_colors(base_color)
    background_path = ANDROID_BACKGROUND_DIR / f'{android_background_name(name)}.xml'
    background_path.write_text(android_background_xml(top_left, bottom_right), encoding='utf-8', newline='\n')
    adaptive_path = ANDROID_ADAPTIVE_DIR / f'ic_launcher_{name}.xml'
    adaptive_path.write_text(android_adaptive_xml(name), encoding='utf-8', newline='\n')
    for density, factor in ANDROID_DENSITIES.items():
        layer_px = round(ANDROID_LAYER_DP * factor)
        layer = android_foreground(name, art, layer_px)
        foreground_path = ANDROID_RES / f'mipmap-{density}' / f'{android_foreground_name(name)}.webp'
        layer.save(foreground_path, quality=ANDROID_WEBP_QUALITY, method=6)


# ---------------- ios ----------------


def ios_icon(name: str, art: Image.Image, base_color: tuple[int, int, int]) -> Image.Image:
    if name in FULL_BLEED_SOURCES:
        square = full_bleed_square(name, IOS_ART_RATIO, IOS_SIZE)
        return square.convert('RGB')

    opaque_color = base_color + (255,)
    canvas = Image.new('RGBA', (IOS_SIZE, IOS_SIZE), opaque_color)
    art_side = round(IOS_SIZE * IOS_ART_RATIO)
    fitted = fit(art, art_side)
    canvas.alpha_composite(fitted, centered_offset(IOS_SIZE, fitted))
    return canvas.convert('RGB')


def write_ios_iconset(iconset_name: str, name: str, art: Image.Image, base_color: tuple[int, int, int]) -> None:
    folder = IOS_ASSETS / f'{iconset_name}.appiconset'
    folder.mkdir(parents=True, exist_ok=True)
    for old in folder.glob('*.png'):
        old.unlink()
    icon = ios_icon(name, art, base_color)
    icon.save(folder / 'icon.png', optimize=True)
    contents = {
        'images': [{'filename': 'icon.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'}],
        'info': {'author': 'xcode', 'version': 1},
    }
    write_contents_json(folder, contents)


def write_contents_json(folder: Path, contents: dict) -> None:
    contents_text = json.dumps(contents, indent=2) + '\n'
    contents_path = folder / 'Contents.json'
    contents_path.write_text(contents_text, encoding='utf-8')


# ---------------- macos ----------------


def write_macos_iconset(art: Image.Image) -> None:
    MACOS_ICONSET.mkdir(parents=True, exist_ok=True)
    for old in MACOS_ICONSET.glob('*.png'):
        old.unlink()
    images = []
    for size in MACOS_SIZES:
        canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        art_side = round(size * MACOS_ART_RATIO)
        fitted = fit(art, art_side)
        canvas.alpha_composite(fitted, centered_offset(size, fitted))
        filename = f'app_icon_{size}.png'
        canvas.save(MACOS_ICONSET / filename, optimize=True)
        for point_size, scale in ((size, 1), (size // 2, 2)):
            if point_size in (16, 32, 128, 256, 512):
                images.append({'filename': filename, 'idiom': 'mac', 'scale': f'{scale}x', 'size': f'{point_size}x{point_size}'})
    images.sort(key=lambda e: (int(e['size'].split('x')[0]), e['scale']))
    contents = {'images': images, 'info': {'author': 'xcode', 'version': 1}}
    write_contents_json(MACOS_ICONSET, contents)


def main() -> None:
    icons = read_icons()
    remove_android_generated()
    for name, asset in icons.items():
        art = cropped_art(ROOT / asset)
        base_color = background_color(name, art)
        is_default = name == DEFAULT_ICON
        if not is_default:
            write_android_icon(name, art, base_color)
        iconset_name = 'AppIcon' if is_default else name
        write_ios_iconset(iconset_name, name, art, base_color)
        print(f'{name}: android, ios {iconset_name}')
    default_art = cropped_art(ROOT / icons[DEFAULT_ICON])
    write_macos_iconset(default_art)
    print('macos AppIcon')
    alternates = ' '.join(name for name in icons if name != DEFAULT_ICON)
    print(f'ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = "{alternates}"')


if __name__ == '__main__':
    main()
