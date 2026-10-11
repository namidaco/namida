"""Bundles the built docs site into assets/docs.tar.xz, served offline by the app.

usage: python scripts/bundle_docs.py [path/to/namida_docs/site]
build the site first with `npm run build` inside namida_docs.

by claude
"""

import io
import lzma
import re
import subprocess
import sys
import tarfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'assets' / 'docs.tar.xz'
DEFAULT_SITE = ROOT.parent / 'namida_docs' / 'site'

# -- unused (mermaid, other themes), online only (ai, analytics, llms, okf) or never shown in a webview (favicon)
EXCLUDED_DIRS = {'okf'}
EXCLUDED_FILES = {
    'assets/js/init-mermaid.js', 'assets/js/docmd-ai.js', 'assets/css/docmd-ai.css', 'assets/js/goatcounter.js',
    'assets/css/docmd-theme-retro.css', 'assets/css/docmd-theme-ruby.css', 'assets/css/docmd-theme-sky.css',
    'assets/favicon.ico', 'assets/css/index.ts', 'llms.txt', 'llms-full.txt', 'llms.json', 'sitemap.xml', 'robots.txt', '.nojekyll',
}
EXCLUDED_REF_REGEX = re.compile(r'<script\b[^>]*(?:docmd-ai|goatcounter)\.js[^>]*>\s*</script>|<link\b[^>]*(?:docmd-ai\.css|favicon\.ico)[^>]*>')

ONLINE_DOCS_URL = 'https://docs.namida.app'
NOT_FOUND_PAGE = '404.html'
BANNER_ANCHOR = '<header class="summer-topbar"'
BODY_CLASS_PREFIX = '<body class="'
WARNING_ICON = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3"/><path d="M12 9v4"/><path d="M12 17h.01"/></svg>'
EXTERNAL_ICON = '<svg class="summer-banner__link-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M7 7h10v10"/><path d="M7 17 17 7"/></svg>'

# -- solid xz shares the sidebar every page repeats, ~3x smaller than a zip
XZ_PRESET = 9 | lzma.PRESET_EXTREME


def is_excluded(relative_path: str) -> bool:
    if relative_path in EXCLUDED_FILES:
        return True
    top_dir = relative_path.split('/', 1)[0]
    return top_dir in EXCLUDED_DIRS


def get_snapshot_date(site: Path) -> str | None:
    docs_repo = site.parent
    try:
        result = subprocess.run(['git', '-C', str(docs_repo), 'log', '-1', '--format=%cs'], capture_output=True, text=True, check=True)
    except (OSError, subprocess.CalledProcessError):
        return None
    return result.stdout.strip() or None


def build_offline_banner(snapshot_date: str | None) -> str:
    copy_text = f'Offline copy from {snapshot_date}' if snapshot_date else 'Offline copy'
    # -- docs navigate without reloading, so the online url is read from the current location on click
    open_online_script = f"this.href='{ONLINE_DOCS_URL}'+location.pathname+location.hash"
    return (
        '<div class="summer-banner summer-banner--warning" role="region" aria-label="Offline docs">'
        '<div class="summer-banner__inner">'
        f'<span class="summer-banner__icon" aria-hidden="true">{WARNING_ICON}</span>'
        f'<span class="summer-banner__text">{copy_text}, may be outdated.</span>'
        f'<a class="summer-banner__link" href="{ONLINE_DOCS_URL}/" target="_blank" rel="noopener" onclick="{open_online_script}">Open online{EXTERNAL_ICON}</a>'
        '</div>'
        '</div>'
    )


def add_offline_banner(html: str, relative_path: str, offline_banner: str) -> str:
    if BANNER_ANCHOR not in html:
        sys.exit(f'{relative_path} has no `{BANNER_ANCHOR}` to put the offline banner before, did the docs template change?')
    with_body_class = html.replace(BODY_CLASS_PREFIX, f'{BODY_CLASS_PREFIX}has-banner ', 1)
    return with_body_class.replace(BANNER_ANCHOR, offline_banner + BANNER_ANCHOR, 1)


def read_content(path: Path, relative_path: str, offline_banner: str) -> bytes:
    if not relative_path.endswith('.html'):
        return path.read_bytes()
    html = path.read_text(encoding='utf-8')
    html = EXCLUDED_REF_REGEX.sub('', html)
    if relative_path != NOT_FOUND_PAGE:
        html = add_offline_banner(html, relative_path, offline_banner)
    return html.encode('utf-8')


def main():
    site = DEFAULT_SITE
    if len(sys.argv) > 1:
        site = Path(sys.argv[1])
    if not (site / 'index.html').is_file():
        sys.exit(f'no built site at {site}, run `npm run build` in namida_docs first')

    snapshot_date = get_snapshot_date(site)
    offline_banner = build_offline_banner(snapshot_date)
    files = sorted(p for p in site.rglob('*') if p.is_file())
    count = 0
    with tarfile.open(OUT, 'w:xz', preset=XZ_PRESET, format=tarfile.GNU_FORMAT) as tf:
        for path in files:
            relative_path = path.relative_to(site).as_posix()
            if is_excluded(relative_path):
                continue
            content = read_content(path, relative_path, offline_banner)
            # -- no mtime/owner, the archive stays identical between builds of the same content
            info = tarfile.TarInfo(relative_path)
            info.size = len(content)
            content_stream = io.BytesIO(content)
            tf.addfile(info, content_stream)
            count += 1

    out_relative = OUT.relative_to(ROOT)
    size_kb = OUT.stat().st_size / 1024
    print(f'{count} files -> {out_relative} ({size_kb:.0f} KB)')


if __name__ == '__main__':
    main()
