"""Turns the raw shots into the readme collections, docs webp files, flathub pngs and a few designs.

usage: python scripts/screenshots/compose.py [--publish] [--only readme designs docs flathub]

reads work/out/<platform>/<theme>/<id>.png and writes work/compose/{readme,docs,flathub,designs}, every folder rewritten
whole. designs are html templates rendered by a headless chromium (edge on windows) at twice their size and scaled down
after, which keeps text and edges smooth. --publish mirrors work/compose into the namida-assets checkout
(external/namida-assets/screenshots), the readme, the flathub metainfo and the docs link there, and rewrites the
metainfo's <screenshots> from FLATHUB_SHOTS. those link @main (github serves raw files with a short cache and
flathub mirrors the images at each build), the docs pin a commit themselves.

collections are the readme's phone trios, each one picks a layout (where its three phones sit) and a theme (frame,
background, status bar colors). a phone in a `clip` slot runs past the bottom edge, for pages that go on and on.

by claude
"""

import argparse
import colorsys
import json
import random
import shutil
import subprocess
import time
from pathlib import Path
from string import Template

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPTS = Path(__file__).resolve().parent
TEMPLATES = SCRIPTS / 'templates'
DEFAULT_WORK = ROOT / 'build' / 'screenshots'
ASSETS_DIR = ROOT / 'external' / 'namida-assets' / 'screenshots'
PUBLISHED_FOLDERS = ['readme', 'docs', 'flathub', 'designs']
FONTS_DIR = ROOT / 'assets' / 'fonts' / 'LexendDeca'

SCENES_PATH = SCRIPTS / 'scenes.json'
DOCS_PLATFORMS = ['android', 'windows']
# -- the docs screens map, thumbnails of the first screen of every shot
THUMB_WIDTH = 200
THUMB_MAX_RATIO = 2.3
THUMB_WEBP_QUALITY = 78
DOCS_MAX_WIDTH = 720
DOCS_WEBP_QUALITY = 82
TILE_FRACTION_DIGITS = 5
# -- `<id>.<kind>.json` files the driver writes next to each shot, merged into docs/<kind>.json: settings tiles for the
# -- docs hotspots, every visible text for the translations' screenshots (namida-translations weblate_screenshots.py)
REGION_KINDS = [('tiles', 'title'), ('texts', 'text')]
README_WEBP_QUALITY = 90
DESIGNS_WEBP_QUALITY = 90
MOSAIC_COUNT = 48
# -- the flathub listing in order, the first is its default. flathub's quality guidelines: plain app windows (no frames
# -- or text), 1000x700 or smaller (2000x1400 hidpi), mostly default (light) theme, some dark is fine, at most ~10,
# -- a caption each (one sentence, no full stop)
FLATHUB_SHOTS = [
    ('wide_home', 'light', 'Home with mixes and recent listens, next to the player'),
    ('wide_player', 'dark', 'Player with video and synced lyrics'),
    ('portrait_home', 'light', 'Phone layout in a narrow window'),
    ('wide_album', 'light', 'Album page'),
    ('wide_artist', 'light', 'Artist page with albums and singles'),
    ('wide_playlists', 'light', 'Playlists with tags'),
    ('portrait_lyrics', 'dark', 'Synced lyrics in dark mode'),
    ('wide_lyrics_editor', 'dark', 'Lyrics editor'),
    ('wide_stats', 'dark', 'Listening statistics'),
    ('wide_settings', 'light', 'Customization settings'),
]
# -- flathub wants shots taken on linux, windows ones only stand in until a linux run exists
FLATHUB_PLATFORMS = ['linux', 'windows']
FLATHUB_URL = 'https://raw.githubusercontent.com/namidaco/namida-assets/main/screenshots/flathub'
METAINFO_PATH = ROOT / 'linux' / 'packaging' / 'com.msob7y.namida.metainfo.xml.in'
README_SETTINGS = [
    'settings', 'settings_theme', 'settings_indexer', 'settings_playback', 'settings_customization', 'settings_youtube',
    'settings_extras', 'settings_backup', 'settings_advanced',
]
ACCENT_SAMPLE_SIZE = 48
ACCENT_MIN_SATURATION = 60
ACCENT_GLOW_MIN_SATURATION = 0.45
ACCENT_GLOW_MIN_VALUE = 0.9
RENDER_SCALE = 2
RENDER_WAIT_SECONDS = 60
RENDER_POLL_SECONDS = 0.2
BROWSER_CANDIDATES = [
    r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe',
    r'C:\Program Files\Microsoft\Edge\Application\msedge.exe',
    'msedge', 'chromium', 'chromium-browser', 'google-chrome',
]

# -- the android shots have no system bars, a status bar is drawn above them like the 2023 phone had, minus its icons
STATUS_BAR_TIME = '11:00'
STATUS_BAR_ICONS = (
    '<svg class="square" viewBox="0 0 24 24"><path d="M12 21.5 23.6 7C23.15 6.66 18.67 3 12 3S.85 6.66.4 7z"/></svg>'
    '<svg class="square" viewBox="0 0 24 24"><path d="M2 22h20V2z"/></svg>'
    '<svg class="battery" viewBox="0 0 28 14"><rect x="1" y="1" width="23" height="12" rx="3.5" fill="none" stroke="currentColor" stroke-width="1.6"/>'
    '<rect x="25.2" y="4.5" width="2" height="5" rx="1"/><rect x="3.2" y="3.2" width="15" height="7.6" rx="2"/></svg>'
)
STATUS_BAR_SAMPLE_ROWS = 6
STATUS_BAR_DARK_TEXT_MIN_LUMINANCE = 0.55
STATUS_BAR_DARK_TEXT = 'rgba(0, 0, 0, 0.62)'
STATUS_BAR_LIGHT_TEXT = 'rgba(255, 255, 255, 0.86)'
# -- matches the .status height in status_bar.css, 9% of the screen width
STATUS_BAR_HEIGHT_RATIO = 0.09

COLLECTION_WIDTH = 2828
COLLECTION_BOTTOM_MARGIN = 0.03
PHONE_BORDER_RATIO = 0.023
PHONE_RADIUS_RATIO = 0.06
TITLE_SIZE_RATIO = 0.04
TITLE_GAP_RATIO = 0.012
# -- a title stays within its phone, Lexend Deca letters average about this much of the font size
TITLE_MAX_WIDTH_RATIO = 0.92
TITLE_CHAR_WIDTH_EM = 0.56
# -- slots in fractions of the canvas width: left edge, top edge, width. measured from the 2023 readme collections
COLLECTION_LAYOUTS = {
    'stairs': [
        {'x': 0.021, 'top': 0.025, 'width': 0.31},
        {'x': 0.3445, 'top': 0.046, 'width': 0.31},
        {'x': 0.668, 'top': 0.067, 'width': 0.31},
    ],
    'long_middle': [
        {'x': 0.03, 'top': 0.0225, 'width': 0.2975},
        {'x': 0.3475, 'top': 0.05, 'width': 0.3075, 'clip': True},
        {'x': 0.6725, 'top': 0.025, 'width': 0.2975},
    ],
    'raised_middle': [
        {'x': 0.0325, 'top': 0.0625, 'width': 0.2875},
        {'x': 0.345, 'top': 0.0075, 'width': 0.30},
        {'x': 0.6725, 'top': 0.0625, 'width': 0.2875},
    ],
    'titled_stairs': [
        {'x': 0.011, 'top': 0.064, 'width': 0.32},
        {'x': 0.3445, 'top': 0.1125, 'width': 0.32},
        {'x': 0.678, 'top': 0.1675, 'width': 0.31},
    ],
}
COLLECTION_THEMES = {
    'light': {
        'frame_color': 'rgba(255, 255, 255, 0.96)',
        'shadow': '0 18px 46px rgba(60, 40, 90, 0.22), 0 0 0 1px rgba(0, 0, 0, 0.05)',
        'title_color': 'rgba(40, 36, 60, 0.85)',
    },
    'dark': {
        'frame_color': '#3a3b40',
        'shadow': '0 22px 60px rgba(0, 0, 0, 0.55), 0 0 0 1px rgba(255, 255, 255, 0.04)',
        'title_color': 'rgba(206, 216, 236, 0.9)',
    },
}
COLLECTIONS = {
    'collection_light_1': {
        'theme': 'light', 'layout': 'stairs', 'shots': ['readme_home', 'readme_genres', 'readme_playlists'],
        'background': 'radial-gradient(at 0% 0%, #c4bdf0 0, transparent 55%), radial-gradient(at 100% 0%, #a7d2f6 0, transparent 52%),'
                      ' radial-gradient(at 45% 100%, #f2d2ec 0, transparent 60%), #dcd7f4',
    },
    'collection_light_2': {
        'theme': 'light', 'layout': 'long_middle', 'shots': ['readme_tracks_sort', 'readme_most_played', 'readme_add_tracks'],
        'background': 'radial-gradient(at 58% 0%, #dcc3f6 0, transparent 42%), radial-gradient(at 18% 100%, #9b8cf0 0, transparent 48%), #eef0f6',
    },
    'collection_light_3': {
        'theme': 'light', 'layout': 'raised_middle', 'shots': ['readme_settings', 'readme_lyrics', 'track_menu'],
        'background': 'radial-gradient(at 0% 100%, #f4c6d3 0, transparent 55%), radial-gradient(at 100% 0%, #c6d6f7 0, transparent 55%), #efe8f3',
    },
    'collection_light_4': {
        'theme': 'light', 'layout': 'raised_middle', 'shots': ['stats_year', 'party_room', 'artists_map'],
        'background': 'radial-gradient(at 100% 100%, #bfe6dc 0, transparent 55%), radial-gradient(at 0% 0%, #f6dcc4 0, transparent 52%), #eef0ec',
    },
    'collection_dark_1': {
        'theme': 'dark', 'layout': 'raised_middle', 'shots': ['drawer', 'readme_player_dark', 'readme_equalizer'],
        'background': 'radial-gradient(ellipse at 50% 48%, #0f4c8f 0, transparent 62%), #04080f',
    },
    'collection_dark_2': {
        'theme': 'dark', 'layout': 'titled_stairs', 'shots': ['queues', 'readme_search_cleanup', 'settings_indexer_separators_dialog'],
        'titles': ['Queues', 'Search Cleanup', 'Separators'],
        'background': 'radial-gradient(at 15% 0%, #0d4a86 0, transparent 50%), radial-gradient(at 88% 100%, #0b3466 0, transparent 50%), #050912',
    },
}
# -- the first design idea for the collections, kept for when another look is wanted
IS_CASCADE_RENDERED = False
CASCADE_SIZE = (2000, 1500)


def find_browser() -> str:
    for candidate in BROWSER_CANDIDATES:
        resolved = shutil.which(candidate)
        if resolved:
            return resolved
    raise SystemExit('no chromium based browser found')


def render(browser: str, browser_dir: Path, template_name: str, values: dict, width: int, height: int, out: Path, scale: int = RENDER_SCALE):
    template_path = TEMPLATES / template_name
    template = Template(template_path.read_text(encoding='utf-8'))
    html = template.substitute(values, width=width, height=height, status_css=read_status_css(), fonts_css=build_fonts_css())
    out.parent.mkdir(parents=True, exist_ok=True)
    html_path = browser_dir / f'{out.stem}.html'
    html_path.write_text(html, encoding='utf-8')
    rendered = browser_dir / f'{out.stem}.rendered.png'
    # -- a profile per render, a launch sharing a still running instance's profile hands off to it and never screenshots
    profile_dir = browser_dir / f'profile_{out.stem}'
    command = [
        browser, '--headless=new', '--disable-gpu', '--hide-scrollbars', f'--force-device-scale-factor={scale}',
        '--allow-file-access-from-files', f'--user-data-dir={profile_dir}', f'--window-size={width},{height}',
        f'--screenshot={rendered}', html_path.as_uri(),
    ]
    rendered.unlink(missing_ok=True)
    # -- no captured pipes, leftover browser helpers keep them open and the timeout would never return
    subprocess.run(command, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=120)
    wait_for_screenshot(rendered)
    with Image.open(rendered) as image:
        final = image.convert('RGB') if scale == 1 else image.convert('RGB').resize((width, height), Image.Resampling.LANCZOS)
    final.save(out)
    print(f'design -> {out}')


def wait_for_screenshot(path: Path):
    # -- the edge launcher can return before the browser it hands off to has written the file
    deadline = time.time() + RENDER_WAIT_SECONDS
    previous_size = -1
    while time.time() < deadline:
        size = path.stat().st_size if path.exists() else -1
        if size > 0 and size == previous_size:
            return
        previous_size = size
        time.sleep(RENDER_POLL_SECONDS)
    raise SystemExit(f'the browser wrote no screenshot: {path}')


def read_status_css() -> str:
    return (TEMPLATES / 'status_bar.css').read_text(encoding='utf-8')


def build_fonts_css() -> str:
    faces = [(500, 'LexendDeca-Medium.ttf'), (600, 'LexendDeca-SemiBold.ttf')]
    return ''.join(
        f"@font-face {{ font-family: 'Lexend Deca'; font-weight: {weight}; src: url('{(FONTS_DIR / file).as_uri()}'); }}"
        for weight, file in faces
    )


def shot_path(shots_dir: Path, theme: str, shot_id: str) -> Path:
    return shots_dir / theme / f'{shot_id}.png'


def build_status_bar(png: Path) -> str:
    # -- the app's own color at the very top, so the bar continues the shot
    with Image.open(png) as image:
        rgb = image.convert('RGB')
        top = rgb.crop((0, 0, rgb.width, STATUS_BAR_SAMPLE_ROWS)).resize((1, 1), Image.Resampling.BOX)
    red, green, blue = top.getpixel((0, 0))
    luminance = (0.299 * red + 0.587 * green + 0.114 * blue) / 255
    text_color = STATUS_BAR_DARK_TEXT if luminance >= STATUS_BAR_DARK_TEXT_MIN_LUMINANCE else STATUS_BAR_LIGHT_TEXT
    style = f'background: rgb({red}, {green}, {blue}); color: {text_color};'
    return f'<div class="status" style="{style}"><span>{STATUS_BAR_TIME}</span><span class="icons">{STATUS_BAR_ICONS}</span></div>'


def render_collection(browser: str, browser_dir: Path, shots_dir: Path, name: str, collection: dict, out: Path):
    theme_name = collection['theme']
    theme = COLLECTION_THEMES[theme_name]
    slots = COLLECTION_LAYOUTS[collection['layout']]
    titles = collection.get('titles', [])
    shot_paths = [shot_path(shots_dir, theme_name, shot_id) for shot_id in collection['shots']]
    missing = [path for path in shot_paths if not path.exists()]
    if missing:
        print(f'{name} skipped, missing {", ".join(path.name for path in missing)}')
        return False
    width = COLLECTION_WIDTH
    phones = []
    bottoms = []
    for index, (slot, path) in enumerate(zip(slots, shot_paths)):
        phone_width = round(slot['width'] * width)
        border = round(phone_width * PHONE_BORDER_RATIO)
        radius = round(phone_width * PHONE_RADIUS_RATIO)
        left = round(slot['x'] * width)
        top = round(slot['top'] * width)
        screen_width = phone_width - border * 2
        with Image.open(path) as image:
            shot_ratio = image.height / image.width
        phone_height = round(screen_width * (shot_ratio + STATUS_BAR_HEIGHT_RATIO)) + border * 2
        if not slot.get('clip'):
            bottoms.append(top + phone_height)
        title = titles[index] if index < len(titles) else ''
        title_size = min(width * TITLE_SIZE_RATIO, phone_width * TITLE_MAX_WIDTH_RATIO / (len(title) * TITLE_CHAR_WIDTH_EM or 1))
        title_html = f'<div class="title" style="font-size: {round(title_size)}px;">{title}</div>' if title else ''
        phone_style = (
            f'left: {left}px; top: {top}px; width: {phone_width}px; border: {border}px solid {theme["frame_color"]};'
            f' border-radius: {radius}px; background: {theme["frame_color"]}; box-shadow: {theme["shadow"]};'
        )
        screen_style = f'border-radius: {radius - border}px;'
        phones.append(
            f'<div class="phone" style="{phone_style}">{title_html}'
            f'<div class="screen" style="{screen_style}">{build_status_bar(path)}<img src="{path.as_uri()}"></div></div>'
        )
    height = max(bottoms) + round(width * COLLECTION_BOTTOM_MARGIN)
    values = {
        'background': collection['background'],
        'phones': ''.join(phones),
        'title_color': theme['title_color'],
        'title_gap': round(width * TITLE_GAP_RATIO),
    }
    render(browser, browser_dir, 'collection.html', values, width, height, out)
    if IS_CASCADE_RENDERED:
        render_cascade(browser, browser_dir, shot_paths, out.with_name(f'{out.stem}_cascade.png'))
    return True


def render_cascade(browser: str, browser_dir: Path, shot_paths: list, out: Path):
    values = {}
    for index, path in enumerate(shot_paths):
        values[f'shot{index + 1}'] = path.as_uri()
        values[f'status{index + 1}'] = build_status_bar(path)
        values[f'color{index + 1}'] = get_accent_css(path)
    cascade_width, cascade_height = CASCADE_SIZE
    render(browser, browser_dir, 'cascade.html', values, cascade_width, cascade_height, out)


def build_mosaic(artworks_dir: Path) -> str:
    artworks = sorted(artworks_dir.glob('*.png'))
    rng = random.Random(3)
    rng.shuffle(artworks)
    picked = artworks[:MOSAIC_COUNT]
    return ''.join(f'<img src="{a.as_uri()}">' for a in picked)


def get_accent_css(png: Path) -> str:
    # -- the saturated pixels' average, the app tints its surfaces with the playing track's colors
    with Image.open(png) as image:
        small = image.convert('RGB').resize((ACCENT_SAMPLE_SIZE, ACCENT_SAMPLE_SIZE))
    hsv_pixels = small.convert('HSV').get_flattened_data()
    rgb_pixels = small.get_flattened_data()
    vivid = [rgb for rgb, hsv in zip(rgb_pixels, hsv_pixels) if hsv[1] >= ACCENT_MIN_SATURATION]
    picked = vivid or list(rgb_pixels)
    channels = [sum(c[i] for c in picked) / len(picked) / 255 for i in range(3)]
    hue, saturation, value = colorsys.rgb_to_hsv(*channels)
    # -- glows read as tints, so they stay light and colorful whatever the shot's average is
    glow_rgb = colorsys.hsv_to_rgb(hue, max(saturation, ACCENT_GLOW_MIN_SATURATION), max(value, ACCENT_GLOW_MIN_VALUE))
    red, green, blue = (round(c * 255) for c in glow_rgb)
    return f'rgb({red}, {green}, {blue})'


def reset_dir(directory: Path):
    if directory.exists():
        shutil.rmtree(directory)
    directory.mkdir(parents=True)


def save_webp(source: Path, out: Path, quality: int, max_width: int | None = None):
    out.parent.mkdir(parents=True, exist_ok=True)
    with Image.open(source) as image:
        rgb = image.convert('RGB')
    if max_width is not None and rgb.width > max_width:
        rgb = rgb.resize((max_width, round(rgb.height * max_width / rgb.width)), Image.Resampling.LANCZOS)
    rgb.save(out, 'WEBP', quality=quality, method=6)


def export_readme(browser: str, browser_dir: Path, android_shots_dir: Path, readme_dir: Path):
    reset_dir(readme_dir)
    for name, collection in COLLECTIONS.items():
        rendered = browser_dir / f'{name}.png'
        if render_collection(browser, browser_dir, android_shots_dir, name, collection, rendered):
            save_webp(rendered, readme_dir / f'{name}.webp', README_WEBP_QUALITY)
    for shot_id in README_SETTINGS:
        source = shot_path(android_shots_dir, 'light', shot_id)
        if not source.exists():
            continue
        with Image.open(source) as image:
            width, height = image.size
        status_height = round(width * STATUS_BAR_HEIGHT_RATIO)
        rendered = browser_dir / f'screen_{shot_id}.png'
        values = {'shot': source.as_uri(), 'status': build_status_bar(source)}
        # -- full pages are too tall to render twice their size, and a 1:1 copy needs no smoothing
        render(browser, browser_dir, 'screen.html', values, width, height + status_height, rendered, scale=1)
        save_webp(rendered, readme_dir / 'settings' / f'{shot_id}.webp', README_WEBP_QUALITY)
    print(f'readme -> {readme_dir}')


def export_docs(out_dir: Path, docs_dir: Path):
    reset_dir(docs_dir)
    # -- what exists per platform and theme, the docs build only places variants that are there
    index = {}
    regions = {'tiles': {}, 'texts': {}}
    for platform in DOCS_PLATFORMS:
        for png in sorted((out_dir / platform).glob('*/*.png')):
            theme = png.parent.name
            if theme == 'manual' or png.name.endswith('.device.png'):
                continue
            save_webp(png, docs_dir / platform / theme / f'{png.stem}.webp', DOCS_WEBP_QUALITY, DOCS_MAX_WIDTH)
            index.setdefault(platform, {}).setdefault(theme, []).append(png.stem)
            for kind, label_key in REGION_KINDS:
                shot_regions = read_region_fractions(png, kind, label_key)
                if shot_regions is not None:
                    regions[kind].setdefault(platform, {}).setdefault(theme, {})[png.stem] = shot_regions
    (docs_dir / 'index.json').write_text(json.dumps(index, indent=1), encoding='utf-8')
    for kind, _ in REGION_KINDS:
        (docs_dir / f'{kind}.json').write_text(json.dumps(regions[kind], ensure_ascii=False), encoding='utf-8')
    export_screens(out_dir, docs_dir)
    count = sum(len(ids) for themes in index.values() for ids in themes.values())
    print(f'{count} docs webp -> {docs_dir}')


def export_screens(out_dir: Path, docs_dir: Path):
    # -- which screen opens which, from the scenes' `parent`. variants (readme, wide, pitch black) stay out
    scenes = json.loads(SCENES_PATH.read_text(encoding='utf-8'))['scenes']
    screens = [{'id': scene['id'], 'parent': scene.get('parent')} for scene in scenes if 'variantOf' not in scene]
    (docs_dir / 'screens.json').write_text(json.dumps(screens, indent=1), encoding='utf-8')
    for screen in screens:
        for platform in DOCS_PLATFORMS:
            for png in (out_dir / platform).glob(f"*/{screen['id']}.png"):
                save_thumb(png, docs_dir / 'thumbs' / platform / png.parent.name / f"{screen['id']}.webp")


def save_thumb(source: Path, out: Path):
    out.parent.mkdir(parents=True, exist_ok=True)
    with Image.open(source) as image:
        rgb = image.convert('RGB')
    top = rgb.crop((0, 0, rgb.width, min(rgb.height, round(rgb.width * THUMB_MAX_RATIO))))
    thumb = top.resize((THUMB_WIDTH, round(top.height * THUMB_WIDTH / top.width)), Image.Resampling.LANCZOS)
    thumb.save(out, 'WEBP', quality=THUMB_WEBP_QUALITY, method=6)


def read_region_fractions(png: Path, kind: str, label_key: str) -> dict | None:
    # -- what the driver saw on the shot (`<id>.tiles.json`, `<id>.texts.json`) as fractions of it, any size the docs
    # -- or the translations show it at
    regions_path = png.with_name(f'{png.stem}.{kind}.json')
    if not regions_path.exists():
        return None
    with Image.open(png) as image:
        width, height = image.size
    raw_regions = json.loads(regions_path.read_text(encoding='utf-8'))[kind]
    fractions = [
        {
            label_key: region[label_key],
            'x': round(region['x'] / width, TILE_FRACTION_DIGITS),
            'y': round(region['y'] / height, TILE_FRACTION_DIGITS),
            'w': round(region['w'] / width, TILE_FRACTION_DIGITS),
            'h': round(region['h'] / height, TILE_FRACTION_DIGITS),
        }
        for region in raw_regions
        if region['y'] < height
    ]
    return {'ratio': round(height / width, TILE_FRACTION_DIGITS), kind: fractions}


def export_flathub(out_dir: Path, flathub_dir: Path):
    reset_dir(flathub_dir)
    platform = next(platform for platform in FLATHUB_PLATFORMS if (out_dir / platform).exists())
    for shot_id, theme, _ in FLATHUB_SHOTS:
        # -- linux has spectacle's window shot next to the in-app one, with the native shadow flathub asks for
        in_app_shot = shot_path(out_dir / platform, theme, shot_id)
        window_shot = in_app_shot.with_suffix('.device.png')
        shutil.copy2(window_shot if window_shot.exists() else in_app_shot, flathub_dir / f'{shot_id}_{theme}.png')
    print(f'flathub ({platform}) -> {flathub_dir}')


def write_metainfo_screenshots():
    metainfo = METAINFO_PATH.read_text(encoding='utf-8')
    start_tag, end_tag = '  <screenshots>\n', '  </screenshots>\n'
    start = metainfo.index(start_tag) + len(start_tag)
    end = metainfo.index(end_tag, start)
    entries = []
    for index, (shot_id, theme, caption) in enumerate(FLATHUB_SHOTS):
        opening = '    <screenshot type="default">' if index == 0 else '    <screenshot>'
        entries.append(f'{opening}\n      <image>{FLATHUB_URL}/{shot_id}_{theme}.png</image>\n      <caption>{caption}</caption>\n    </screenshot>\n')
    METAINFO_PATH.write_text(metainfo[:start] + ''.join(entries) + metainfo[end:], encoding='utf-8', newline='\n')
    print(f'metainfo screenshots -> {METAINFO_PATH}')


def export_designs(browser: str, browser_dir: Path, desktop_shots_dir: Path, artworks_dir: Path, designs_dir: Path):
    reset_dir(designs_dir)
    hero_values = {
        'mosaic': build_mosaic(artworks_dir),
        'desktop': shot_path(desktop_shots_dir, 'light', 'wide_home').as_uri(),
        'phone1': shot_path(desktop_shots_dir, 'light', 'tracks').as_uri(),
        'phone2': shot_path(desktop_shots_dir, 'light', 'stats').as_uri(),
    }
    hero = browser_dir / 'hero.png'
    render(browser, browser_dir, 'hero.html', hero_values, 2400, 1350, hero)
    save_webp(hero, designs_dir / 'hero.webp', DESIGNS_WEBP_QUALITY)
    # -- a page without random picks, both halves must show the same content
    split_values = {
        'light': shot_path(desktop_shots_dir, 'light', 'album_page').as_uri(),
        'dark': shot_path(desktop_shots_dir, 'dark', 'album_page').as_uri(),
    }
    split = browser_dir / 'split_album.png'
    render(browser, browser_dir, 'split.html', split_values, 1400, 1700, split)
    save_webp(split, designs_dir / 'split_album.webp', DESIGNS_WEBP_QUALITY)


def publish(compose_dir: Path, folders: list):
    for folder in folders:
        target = ASSETS_DIR / folder
        if target.exists():
            shutil.rmtree(target)
        shutil.copytree(compose_dir / folder, target)
    print(f'published -> {ASSETS_DIR}')


def main():
    parser = argparse.ArgumentParser(description='composes the screenshots')
    parser.add_argument('--work', default=str(DEFAULT_WORK))
    parser.add_argument('--publish', action='store_true')
    # -- readme and designs render in a chromium, `--only flathub` works without one (linux has no edge)
    parser.add_argument('--only', nargs='+', choices=PUBLISHED_FOLDERS, default=PUBLISHED_FOLDERS)
    args = parser.parse_args()

    work = Path(args.work)
    out_dir = work / 'out'
    compose_dir = work / 'compose'
    folders = args.only

    android_shots_dir = out_dir / 'android'
    desktop_shots_dir = out_dir / 'windows'
    artworks_dir = work / 'windows' / 'app' / 'files' / 'Artworks'
    if 'readme' in folders or 'designs' in folders:
        browser = find_browser()
        browser_dir = work / 'browser'
        reset_dir(browser_dir)
        if 'readme' in folders:
            export_readme(browser, browser_dir, android_shots_dir, compose_dir / 'readme')
        if 'designs' in folders:
            export_designs(browser, browser_dir, desktop_shots_dir, artworks_dir, compose_dir / 'designs')
    if 'docs' in folders:
        export_docs(out_dir, compose_dir / 'docs')
    if 'flathub' in folders:
        export_flathub(out_dir, compose_dir / 'flathub')
    if args.publish:
        publish(compose_dir, folders)
        if 'flathub' in folders:
            write_metainfo_screenshots()


if __name__ == '__main__':
    main()
