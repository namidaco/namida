# by claude
"""Generates the light and dark badge chips shown at the top of README.md, with live numbers.

Values come from the GitHub api, the Discord invite api, the AUR rpc and hitsofcode.com. The chips use the same font
and icons as the README cards (see gen_readme_cards.py). A scheduled workflow runs this and publishes the output, so
the README links to fixed urls and never changes when the numbers do.

usage:
  python scripts/gen_readme_badges.py <out_dir>                       fetch the numbers and write every chip
  python scripts/gen_readme_badges.py <out_dir> --snippet <base_url>  also print the README block for the chips

GITHUB_TOKEN is used when set, which avoids the low rate limit of anonymous requests.
needs fonttools and uharfbuzz (pip install fonttools uharfbuzz)
"""
import argparse
import html
import json
import os
import re
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

from gen_readme_cards import LEXEND_DIR, Icons, TextFont

REPO = 'namidaco/namida'
SNAPSHOTS_REPO = 'namidaco/namida-snapshots'
DISCORD_INVITE = 'WeY7DTVChT'
AUR_PACKAGE = 'namida-bin'
WINGET_MANIFESTS = 'manifests/n/namidaco/Namida'

HEIGHT = 24
PAD = 8
ICON_SIZE = 13
ICON_GAP = 5
FONT_SIZE = 11.5
RADIUS = 6

_VERSION_NUMBER_REGEX = re.compile(r'\d+')

THEMES = {
    'light': dict(label_bg='#f3eee8', label_text='#6f6154', label_icon='#7f6f60', value_bg='#fbfaf8', value_text='#1f2328', border='#e4dcd2', text_opacity=0.72),
    'dark': dict(label_bg='#1f1d1b', label_text='#aaa298', label_icon='#9c948a', value_bg='#161514', value_text='#e8e4df', border='#33302c', text_opacity=0.7),
}


def main():
    parser = argparse.ArgumentParser(description='README badge chips')
    parser.add_argument('out_dir', type=Path)
    parser.add_argument('--snippet', metavar='BASE_URL', help='print the README block, with the chips served from BASE_URL')
    args = parser.parse_args()

    stats = _Stats(os.environ.get('GITHUB_TOKEN'))
    rows = _rows(stats)
    renderer = _ChipRenderer()
    args.out_dir.mkdir(parents=True, exist_ok=True)
    for row in rows:
        for chip in row:
            value = chip.fixed_value
            if chip.fetch_value:
                value = chip.fetch_value()
            for theme, colors in THEMES.items():
                svg = renderer.render(chip, value, colors)
                svg_file = args.out_dir / f'{chip.key}_{theme}.svg'
                svg_file.write_text(svg, encoding='utf-8', newline='\n')
            print('%s: %s' % (chip.key, value or chip.label))

    if args.snippet:
        base_url = args.snippet.rstrip('/')
        row_texts = ['\n'.join(_snippet(chip, base_url) for chip in row) for row in rows]
        print('<br>\n'.join(row_texts))


def _rows(stats):
    return [
        [
            _Chip('website', 'global', 'Website', 'https://namida.app'),
            _Chip('docs', 'book', 'Docs', 'https://docs.namida.app'),
            _Chip('channel', 'si:telegram', 'Channel', 'https://t.me/namida_official'),
            _Chip('chat', 'si:telegram', 'Chat', 'https://t.me/+FmdfsgKoGmM1ZGFk'),
            _Chip('discord', 'si:discord', 'Discord', f'https://discord.gg/{DISCORD_INVITE}', stats.discord_members),
            _Chip('platforms', 'monitor_mobbile', 'Platforms', '#installation', fixed_value='Android · Windows · Linux · macOS · iOS'),
        ],
        [
            _Chip('stable', 'box_tick', 'Stable', f'https://github.com/{REPO}/releases/latest', stats.stable_version),
            _Chip('beta', 'flash', 'Beta', f'https://github.com/{SNAPSHOTS_REPO}/releases/latest', stats.beta_version),
            _Chip('since_stable', 'trend_up', 'Since stable', f'https://github.com/{REPO}/commits/main', stats.commits_since_stable),
            _Chip('last_commit', 'clock', 'Last commit', f'https://github.com/{REPO}/commits/main', stats.last_commit),
            _Chip('aur', 'si:archlinux', 'AUR', f'https://aur.archlinux.org/packages/{AUR_PACKAGE}', stats.aur_version),
            _Chip('winget', 'box', 'winget', f'https://github.com/microsoft/winget-pkgs/tree/master/{WINGET_MANIFESTS}', stats.winget_version),
        ],
        [
            _Chip('stars', 'star_1', 'Stars', f'https://github.com/{REPO}/stargazers', stats.stars),
            _Chip('downloads', 'import', 'Downloads', f'https://github.com/{REPO}/releases', stats.downloads),
            _Chip('beta_downloads', 'import', 'Beta downloads', f'https://github.com/{SNAPSHOTS_REPO}/releases', stats.beta_downloads),
            _Chip('issues', 'tick_circle', 'Issues closed', f'https://github.com/{REPO}/issues', stats.issues),
            _Chip('hits_of_code', 'code_1', 'Hits-of-Code', f'https://hitsofcode.com/github/{REPO}/view?branch=main', stats.hits_of_code),
            _Chip('flutter', 'si:flutter', 'Built in', 'https://github.com/flutter/flutter', fixed_value='Flutter'),
        ],
    ]


def _snippet(chip, base_url):
    alt = html.escape(chip.label)
    return (
        f'<a href="{chip.link}"><picture><source media="(prefers-color-scheme: dark)" srcset="{base_url}/{chip.key}_dark.svg">'
        f'<img src="{base_url}/{chip.key}_light.svg" height="{HEIGHT}" alt="{alt}"></picture></a>'
    )


class _ChipRenderer:
    def __init__(self):
        self._icons = Icons()
        self._label_font = TextFont(LEXEND_DIR / 'LexendDeca-Medium.ttf')
        self._value_font = TextFont(LEXEND_DIR / 'LexendDeca-SemiBold.ttf')

    def render(self, chip, value, colors):
        baseline = HEIGHT / 2 + self._label_font.cap_height * FONT_SIZE / 2
        label_x = PAD + ICON_SIZE + ICON_GAP
        label_width = self._label_font.width(chip.label, FONT_SIZE)
        split = label_x + label_width + PAD
        icon_svg = self._icons.draw(chip.icon, PAD, (HEIGHT - ICON_SIZE) / 2, ICON_SIZE, colors['label_icon'])
        label_path = self._label_font.path(chip.label, FONT_SIZE, label_x, baseline)
        width = split
        value_svg = ''
        if value:
            value_width = self._value_font.width(value, FONT_SIZE)
            width = split + PAD + value_width + PAD
            value_path = self._value_font.path(value, FONT_SIZE, split + PAD, baseline)
            value_svg = (
                f'<rect x="{split:.2f}" width="{width - split:.2f}" height="{HEIGHT}" fill="{colors["value_bg"]}"/>'
                f'<path fill="{colors["value_text"]}" fill-opacity="{colors["text_opacity"]}" d="{value_path}"/>'
            )
        width = round(width)
        return (
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{HEIGHT}" viewBox="0 0 {width} {HEIGHT}">\n'
            f'  <clipPath id="c"><rect x=".5" y=".5" width="{width - 1}" height="{HEIGHT - 1}" rx="{RADIUS}"/></clipPath>\n'
            f'  <g clip-path="url(#c)"><rect width="{width}" height="{HEIGHT}" fill="{colors["label_bg"]}"/>{value_svg}</g>\n'
            f'  {icon_svg}\n'
            f'  <path fill="{colors["label_text"]}" fill-opacity="{colors["text_opacity"]}" d="{label_path}"/>\n'
            f'  <rect x=".5" y=".5" width="{width - 1}" height="{HEIGHT - 1}" rx="{RADIUS}" fill="none" stroke="{colors["border"]}"/>\n'
            f'</svg>\n'
        )


class _Stats:
    _TAG_SUFFIX_REGEX = re.compile(r'[-+]')

    def __init__(self, token):
        self._token = token
        self._stable_tag = None

    def discord_members(self):
        invite = self._get_json(f'https://discord.com/api/v9/invites/{DISCORD_INVITE}?with_counts=true')
        members = invite['approximate_member_count']
        return '%s members' % _compact(members)

    def stable_version(self):
        return self._get_stable_tag()

    def beta_version(self):
        release = self._github(f'repos/{SNAPSHOTS_REPO}/releases/latest')
        tag_parts = self._TAG_SUFFIX_REGEX.split(release['tag_name'])
        version = tag_parts[0].lstrip('v')
        return 'v' + version

    def aur_version(self):
        info = self._get_json(f'https://aur.archlinux.org/rpc/v5/info?arg[]={AUR_PACKAGE}')
        version = info['results'][0]['Version']
        package_version = version.rsplit('-', 1)[0]
        return 'v' + package_version

    def winget_version(self):
        entries = self._github(f'repos/microsoft/winget-pkgs/contents/{WINGET_MANIFESTS}')
        versions = [entry['name'] for entry in entries if entry['type'] == 'dir']
        latest = max(versions, key=_version_key)
        return 'v' + latest

    def last_commit(self):
        commit = self._github(f'repos/{REPO}/commits/main')
        date_text = commit['commit']['committer']['date']
        date = datetime.fromisoformat(date_text.replace('Z', '+00:00'))
        days = (datetime.now(timezone.utc) - date).days
        return _days_ago(days)

    def commits_since_stable(self):
        stable_tag = self._get_stable_tag()
        comparison = self._github(f'repos/{REPO}/compare/{stable_tag}...main')
        return '%d commits' % comparison['ahead_by']

    def issues(self):
        closed_search = self._github(f'search/issues?q=repo:{REPO}+is:issue+is:closed&per_page=1')
        opened_search = self._github(f'search/issues?q=repo:{REPO}+is:issue&per_page=1')
        closed = closed_search['total_count']
        opened = opened_search['total_count']
        return f'{closed:,} / {opened:,}'

    def hits_of_code(self):
        hits = self._get_json(f'https://hitsofcode.com/github/{REPO}/json?branch=main')
        return _compact(hits['count'])

    def stars(self):
        repo = self._github(f'repos/{REPO}')
        return _compact(repo['stargazers_count'])

    def downloads(self):
        return _compact(self._release_downloads(REPO))

    def beta_downloads(self):
        return _compact(self._release_downloads(SNAPSHOTS_REPO))

    def _get_stable_tag(self):
        if self._stable_tag is None:
            release = self._github(f'repos/{REPO}/releases/latest')
            self._stable_tag = release['tag_name']
        return self._stable_tag

    def _release_downloads(self, repo):
        total = 0
        page = 1
        while True:
            releases = self._github(f'repos/{repo}/releases?per_page=100&page={page}')
            if not releases:
                return total
            for release in releases:
                total += sum(asset['download_count'] for asset in release['assets'])
            page += 1

    def _github(self, path):
        return self._request(f'https://api.github.com/{path}', is_github=True)

    def _get_json(self, url):
        return self._request(url, is_github=False)

    def _request(self, url, is_github):
        headers = {'User-Agent': 'namida-readme-badges', 'Accept': 'application/json'}
        if is_github and self._token:
            headers['Authorization'] = f'Bearer {self._token}'
        request = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.load(response)


def _compact(number):
    if number >= 1_000_000:
        text = '%.1f' % (number / 1_000_000)
        return text.removesuffix('.0') + 'M'
    if number >= 1000:
        thousands = number / 1000
        text = '%.1f' % thousands if thousands < 100 else '%d' % thousands
        return text.removesuffix('.0') + 'k'
    return str(number)


def _version_key(version):
    numbers = _VERSION_NUMBER_REGEX.findall(version)
    return tuple(int(number) for number in numbers)


def _days_ago(days):
    if days <= 0:
        return 'today'
    if days == 1:
        return 'yesterday'
    if days < 14:
        return '%d days ago' % days
    if days < 60:
        return '%d weeks ago' % (days // 7)
    return '%d months ago' % (days // 30)


class _Chip:
    def __init__(self, key, icon, label, link, fetch_value=None, fixed_value=None):
        self.key = key
        self.icon = icon
        self.label = label
        self.link = link
        self.fetch_value = fetch_value
        self.fixed_value = fixed_value


if __name__ == '__main__':
    main()
