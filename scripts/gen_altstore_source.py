# by claude
"""Writes the AltStore / SideStore source for the iOS build, so users get notified of new versions.

Everything a sideloading app checks against the ipa is read from the signed app itself, a mismatch fails the install
there: version, build & privacy strings from its Info.plist, entitlements from the signatures of the app and of every
app extension it ships.

    python scripts/gen_altstore_source.py --app Payload/Runner.app --ipa Namida.ipa \
        --download-url https://.../Namida.ipa --out altstore-source.json
"""

import argparse
import glob
import json
import os
import plistlib
import subprocess
from datetime import datetime, timezone

APP_DESCRIPTION = (
    'A beautiful and feature-rich music & video player, with YouTube support built in.\n\n'
    'Beta build for sideloading, it re-signs with your own Apple ID every 7 days.'
)
REPO_URL = 'https://github.com/namidaco/namida'
ICON_URL = 'https://raw.githubusercontent.com/namidaco/namida/main/assets/namida_icon.png'
TINT_COLOR = '9a7ad1'


def read_plist(path: str) -> dict:
    with open(path, 'rb') as f:
        return plistlib.load(f)


def read_signed_entitlements(bundle: str) -> dict:
    result = subprocess.run(['codesign', '-d', '--entitlements', '-', '--xml', bundle], stdout=subprocess.PIPE, check=True)
    entitlements_xml = result.stdout
    if not entitlements_xml:
        return {}
    return plistlib.loads(entitlements_xml)


def collect_entitlements(app: str) -> list[str]:
    extensions = sorted(glob.glob(os.path.join(app, 'PlugIns', '*.appex')))
    bundles = [app, *extensions]
    keys = set()
    for bundle in bundles:
        keys.update(read_signed_entitlements(bundle).keys())
    return sorted(keys)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--app', required=True, help='the signed Runner.app inside the ipa')
    parser.add_argument('--ipa', required=True)
    parser.add_argument('--download-url', required=True)
    parser.add_argument('--out', required=True)
    args = parser.parse_args()

    info = read_plist(os.path.join(args.app, 'Info.plist'))
    privacy = {key: value for key, value in info.items() if key.startswith('NS') and key.endswith('UsageDescription')}

    version = {
        'version': info['CFBundleShortVersionString'],
        'buildVersion': info['CFBundleVersion'],
        'date': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
        'localizedDescription': f'Beta {info["CFBundleShortVersionString"]} ({info["CFBundleVersion"]}), see the release notes on GitHub.',
        'downloadURL': args.download_url,
        'size': os.path.getsize(args.ipa),
        'minOSVersion': info.get('MinimumOSVersion', '15.0'),
    }
    app = {
        'name': 'Namida',
        'bundleIdentifier': info['CFBundleIdentifier'],
        'developerName': 'namidaco',
        'subtitle': 'Music & video player',
        'localizedDescription': APP_DESCRIPTION,
        'iconURL': ICON_URL,
        'tintColor': TINT_COLOR,
        'category': 'entertainment',
        'screenshots': [],
        'versions': [version],
        'appPermissions': {
            'entitlements': collect_entitlements(args.app),
            'privacy': privacy,
        },
    }
    source = {
        'name': 'Namida',
        'identifier': 'com.msob7y.namida.source',
        'subtitle': 'Namida beta builds',
        'description': APP_DESCRIPTION,
        'iconURL': ICON_URL,
        'website': REPO_URL,
        'tintColor': TINT_COLOR,
        'apps': [app],
        'news': [],
    }
    with open(args.out, 'w', encoding='utf-8') as f:
        json.dump(source, f, indent=2, ensure_ascii=False)
        f.write('\n')
    print(json.dumps(version, indent=2))


if __name__ == '__main__':
    main()
