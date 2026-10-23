# by claude
"""Generates the ios & macos app icons from the launcher icons in assets/.

ios masks its own rounded square and refuses transparency, so each icon is cropped to its art and laid on the
color of its outer edge. macos draws the shape as is, so its icon keeps the transparency inside the standard margin.

    python scripts/gen_apple_icons.py
"""

import json
import re
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ICONS_ENUM = ROOT / 'lib/controller/platform/namida_channel/namida_channel_base.dart'
IOS_ASSETS = ROOT / 'ios/Runner/Assets.xcassets'
MACOS_ICONSET = ROOT / 'macos/Runner/Assets.xcassets/AppIcon.appiconset'

IOS_SIZE = 1024
# -- the art fills this much of the ios square, the rest is the edge color
IOS_ART_RATIO = 0.86
# -- macos big sur grid: the shape is 824 of 1024
MACOS_ART_RATIO = 824 / 1024
MACOS_SIZES = [16, 32, 64, 128, 256, 512, 1024]


def read_icons() -> dict[str, str]:
    text = ICONS_ENUM.read_text(encoding='utf-8')
    block = text.split('enum NamidaAppIcons {', 1)[1].split(';', 1)[0]
    return dict(re.findall(r'^\s*(\w+)\("([^"]+)"', block, re.MULTILINE))


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


def cropped_art(path: Path) -> Image.Image:
    image = Image.open(path).convert('RGBA')
    bbox = image.split()[3].getbbox()
    return image.crop(bbox) if bbox else image


def fit(art: Image.Image, side: int) -> Image.Image:
    width, height = art.size
    scale = side / max(width, height)
    return art.resize((max(1, round(width * scale)), max(1, round(height * scale))), Image.LANCZOS)


def ios_icon(art: Image.Image) -> Image.Image:
    small = fit(art, 256)
    background = edge_color(small)
    canvas = Image.new('RGBA', (IOS_SIZE, IOS_SIZE), background + (255,))
    fitted = fit(art, round(IOS_SIZE * IOS_ART_RATIO))
    offset = ((IOS_SIZE - fitted.width) // 2, (IOS_SIZE - fitted.height) // 2)
    canvas.alpha_composite(fitted, offset)
    return canvas.convert('RGB')


def write_ios_iconset(name: str, art: Image.Image) -> None:
    folder = IOS_ASSETS / f'{name}.appiconset'
    folder.mkdir(parents=True, exist_ok=True)
    for old in folder.glob('*.png'):
        old.unlink()
    ios_icon(art).save(folder / 'icon.png', optimize=True)
    contents = {
        'images': [{'filename': 'icon.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'}],
        'info': {'author': 'xcode', 'version': 1},
    }
    (folder / 'Contents.json').write_text(json.dumps(contents, indent=2) + '\n', encoding='utf-8')


def write_macos_iconset(art: Image.Image) -> None:
    MACOS_ICONSET.mkdir(parents=True, exist_ok=True)
    for old in MACOS_ICONSET.glob('*.png'):
        old.unlink()
    images = []
    for size in MACOS_SIZES:
        canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        fitted = fit(art, round(size * MACOS_ART_RATIO))
        canvas.alpha_composite(fitted, ((size - fitted.width) // 2, (size - fitted.height) // 2))
        filename = f'app_icon_{size}.png'
        canvas.save(MACOS_ICONSET / filename, optimize=True)
        for point_size, scale in ((size, 1), (size // 2, 2)):
            if point_size in (16, 32, 128, 256, 512):
                images.append({'filename': filename, 'idiom': 'mac', 'scale': f'{scale}x', 'size': f'{point_size}x{point_size}'})
    images.sort(key=lambda e: (int(e['size'].split('x')[0]), e['scale']))
    contents = {'images': images, 'info': {'author': 'xcode', 'version': 1}}
    (MACOS_ICONSET / 'Contents.json').write_text(json.dumps(contents, indent=2) + '\n', encoding='utf-8')


def main() -> None:
    icons = read_icons()
    for name, asset in icons.items():
        art = cropped_art(ROOT / asset)
        iconset_name = 'AppIcon' if name == 'namida' else name
        write_ios_iconset(iconset_name, art)
        print(f'ios {iconset_name}')
    write_macos_iconset(cropped_art(ROOT / icons['namida']))
    print('macos AppIcon')
    alternates = ' '.join(name for name in icons if name != 'namida')
    print(f'ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = "{alternates}"')


if __name__ == '__main__':
    main()
