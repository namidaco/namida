"""Reshoots everything in one go, skipping the steps already in place.

usage: python scripts/screenshots/reshoot.py [--platforms windows android] [--skip-build] [--reseed] [--no-publish] [--docs]

the first run also needs --music-dir (and --android-root when a playlist holds android sd card paths), they are kept in
work/reshoot.json for the next ones.

steps, in order:
  1. music: seed.py music when the work dir has none, a screenshots playlist changed since, or --reseed.
  2. builds: windows and android (--skip-build reuses the last ones).
  3. youtube session: shoot.py --interactive when none is kept, sign in there and close the window.
  4. seed_youtube.py, every run (it only rewrites the curated caches).
  5. the signed out work dir: library, videos and the keep without its session, refreshed every run.
  6. videos the scenes need (scenes.json `cachedVideos`) missing from work/videos: played signed out until cached.
  7. each platform: the full scene list, then the online scenes signed out, merged into work/out.
  8. compose.py --publish (readme, docs and designs). flathub needs a linux run, see docs_internal/screenshots.md.

by claude
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

import seed
from shoot import ANDROID_PACKAGE, DEFAULT_SCENES, DEFAULT_WORK, KEEP_SESSION_PATH, ROOT

SCRIPTS = Path(__file__).resolve().parent
DEFAULT_SIGNED_OUT_WORK = ROOT / '.screenshots_signedout'
DEFAULT_PLAYLIST = Path.home() / '.namida' / 'Playlists' / 'screenshots.json'
DEFAULT_AVD = 'Pixel_9_Pro_XL'
DEFAULT_DEVICE = 'emulator-5554'
CONFIG_FILENAME = 'reshoot.json'
DOCS_REPO = ROOT.parent / 'namida_docs'
EMULATOR_BOOT_TIMEOUT_SECONDS = 300
COMPOSED_FOLDERS = ['readme', 'docs', 'designs']


def run(command: list, **kwargs):
    print('>', ' '.join(str(c) for c in command), flush=True)
    subprocess.run(command, check=True, **kwargs)


def shoot(*arguments):
    run([sys.executable, SCRIPTS / 'shoot.py', *arguments], cwd=ROOT)


def load_config(work: Path, args) -> dict:
    config_path = work / CONFIG_FILENAME
    config = json.loads(config_path.read_text(encoding='utf-8')) if config_path.exists() else {}
    overrides = {'playlist': args.playlist, 'musicDir': args.music_dir, 'androidRoot': args.android_root, 'avd': args.avd, 'device': args.device}
    config.update({key: value for key, value in overrides.items() if value})
    config.setdefault('playlist', str(DEFAULT_PLAYLIST))
    config.setdefault('avd', DEFAULT_AVD)
    config.setdefault('device', DEFAULT_DEVICE)
    work.mkdir(parents=True, exist_ok=True)
    config_path.write_text(json.dumps(config, indent=2), encoding='utf-8')
    return config


def screenshots_playlists(config: dict) -> list:
    playlist = Path(config['playlist'])
    names = [*seed.PLACEMENT_PLAYLISTS.values(), seed.VISUALS_PLAYLIST]
    return [playlist, *(playlist.with_name(f'{name}.json') for name in names)]


def seed_music(work: Path, config: dict, reseed: bool):
    library_path = work / 'library.json'
    if library_path.exists() and not reseed:
        seeded_at = library_path.stat().st_mtime
        changed = [p.name for p in screenshots_playlists(config) if p.exists() and p.stat().st_mtime > seeded_at]
        if not changed:
            print('music: up to date')
            return
        print(f'music: {", ".join(changed)} changed')
    music_dir = config.get('musicDir')
    if not music_dir:
        raise SystemExit('the first run needs --music-dir (where the copied music goes, outside the real library)')
    command = [sys.executable, SCRIPTS / 'seed.py', '--work', work, 'music', '--playlist', config['playlist'], '--music-dir', music_dir]
    android_root = config.get('androidRoot')
    if android_root:
        command += ['--android-root', android_root]
    run(command, cwd=ROOT)


def build(platforms: list):
    flutter = shutil.which('flutter')
    run([flutter, 'build', 'windows', '--profile', '--no-pub', '--dart-define=WINDOWS_PORTABLE=true', '--dart-define=NAMIDA_SCREENSHOTS=true'], cwd=ROOT)
    if 'android' in platforms:
        run([flutter, 'build', 'apk', '--debug', '--no-pub', '--target-platform', 'android-x64', '--dart-define=NAMIDA_SCREENSHOTS=true'], cwd=ROOT)


def ensure_youtube_session(work: Path):
    if (work / 'windows' / 'keep' / KEEP_SESSION_PATH).exists():
        print('youtube session: kept')
        return
    print('youtube session: none kept, sign in to youtube (and patreon) in the window that opens, then close it')
    shoot('--work', work, '--skip-build', '--interactive')


def refresh_signed_out_work(work: Path, signed_out: Path):
    signed_out.mkdir(exist_ok=True)
    shutil.copy2(work / 'library.json', signed_out / 'library.json')
    shutil.copytree(work / 'videos', signed_out / 'videos', dirs_exist_ok=True)
    keep = work / 'windows' / 'keep'
    signed_out_keep = signed_out / 'windows' / 'keep'
    if signed_out_keep.exists():
        shutil.rmtree(signed_out_keep)
    # -- the session folder only, youtube's own caches stay
    shutil.copytree(keep, signed_out_keep, ignore=lambda directory, names: [KEEP_SESSION_PATH] if Path(directory) == keep else [])


def scenes_config() -> dict:
    return json.loads(DEFAULT_SCENES.read_text(encoding='utf-8'))


def write_scenes(path: Path, scenes: list, keep_setup: bool = True):
    config = scenes_config()
    subset = {key: value for key, value in config.items() if key != 'scenes'}
    if not keep_setup:
        subset['setup'] = []
    subset['scenes'] = scenes
    path.write_text(json.dumps(subset, ensure_ascii=False), encoding='utf-8')


def cache_videos(work: Path, signed_out: Path):
    wanted = scenes_config().get('cachedVideos', [])
    missing = [video_id for video_id in wanted if not any((work / 'videos').glob(f'{video_id}_*.mp4'))]
    if not missing:
        print('cached videos: all there')
        return
    print(f'cached videos: playing {", ".join(missing)} signed out until cached')
    cache_scenes = [
        {
            'id': f'cache_{video_id}', 'platforms': ['windows'], 'themes': ['light'],
            'steps': [{'do': 'online'}, {'do': 'dismissMiniplayer'}, {'do': 'ytPlay', 'id': video_id, 'seek': 0}, {'do': 'waitVideoCached', 'id': video_id}],
        }
        for video_id in missing
    ]
    scenes_path = signed_out / 'scenes_cache.json'
    write_scenes(scenes_path, cache_scenes, keep_setup=False)
    shoot('--work', signed_out, '--skip-build', '--scenes', scenes_path)
    for shot in (signed_out / 'out' / 'windows').glob('*/cache_*'):
        shot.unlink()
    for video_id in missing:
        cached = list((signed_out / 'videos').glob(f'{video_id}_*.mp4'))
        if not cached:
            raise SystemExit(f'{video_id} did not get cached, see {signed_out}/out/windows/log.txt')
        for video in cached:
            shutil.copy2(video, work / 'videos' / video.name)


def ensure_emulator(config: dict):
    device = config['device']
    adb = shutil.which('adb')
    devices = subprocess.run([adb, 'devices'], capture_output=True, text=True).stdout
    if f'{device}\tdevice' in devices:
        return
    sdk = Path(os.environ.get('ANDROID_SDK_ROOT') or os.environ.get('ANDROID_HOME') or Path(adb).resolve().parent.parent)
    emulator = sdk / 'emulator' / 'emulator.exe'
    print(f'emulator: booting {config["avd"]}')
    subprocess.Popen([emulator, '-avd', config['avd'], '-no-audio', '-no-snapshot-save', '-no-boot-anim'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    deadline = time.time() + EMULATOR_BOOT_TIMEOUT_SECONDS
    while time.time() < deadline:
        booted = subprocess.run([adb, '-s', device, 'shell', 'getprop', 'sys.boot_completed'], capture_output=True, text=True).stdout.strip()
        if booted == '1':
            return
        time.sleep(3)
    raise SystemExit(f'{config["avd"]} did not boot as {device}')


def adb_shell(device: str, command: str):
    run([shutil.which('adb'), '-s', device, 'shell', command])


def merge_online_shots(signed_out: Path, work: Path, platform: str, online_ids: set):
    source = signed_out / 'out' / platform
    target = work / 'out' / platform
    for shot in source.glob('*/*'):
        if shot.name.split('.')[0] in online_ids:
            (target / shot.parent.name).mkdir(parents=True, exist_ok=True)
            shutil.copy2(shot, target / shot.parent.name / shot.name)


def shoot_platform(platform: str, work: Path, signed_out: Path, config: dict, online_scenes_path: Path, online_ids: set):
    device_args = ['--device', config['device']] if platform == 'android' else []
    shoot('--platform', platform, '--work', work, '--skip-build', *device_args)
    if platform == 'android':
        device = config['device']
        adb_shell(device, f'am force-stop {ANDROID_PACKAGE}')
        adb_shell(device, f"run-as {ANDROID_PACKAGE} sh -c 'rm -rf files/{KEEP_SESSION_PATH}'")
    platform_out = signed_out / 'out' / platform
    if platform_out.exists():
        shutil.rmtree(platform_out)
    shoot('--platform', platform, '--work', signed_out, '--skip-build', '--scenes', online_scenes_path, *device_args)
    merge_online_shots(signed_out, work, platform, online_ids)


def reset_emulator_screen(device: str):
    adb_shell(device, 'wm size reset')
    adb_shell(device, 'wm density reset')
    adb_shell(device, 'am broadcast -a com.android.systemui.demo -e command exit')


def check_docs():
    if not DOCS_REPO.exists():
        return
    npm = shutil.which('npm')
    result = subprocess.run([npm, 'run', 'build'], cwd=DOCS_REPO, capture_output=True, text=True, encoding='utf-8', errors='replace')
    summary = [line for line in result.stdout.splitlines() if 'docs-shots' in line]
    print('\n'.join(summary) or result.stdout[-2000:])


def main():
    parser = argparse.ArgumentParser(description='reshoots everything, skipping the steps already in place')
    parser.add_argument('--work', default=str(DEFAULT_WORK))
    parser.add_argument('--signed-out-work', default=str(DEFAULT_SIGNED_OUT_WORK))
    parser.add_argument('--platforms', nargs='+', default=['windows', 'android'], choices=['windows', 'android'])
    parser.add_argument('--playlist', help=f'the screenshots playlist, default {DEFAULT_PLAYLIST}')
    parser.add_argument('--music-dir', help='where the copied music goes, kept for the next runs')
    parser.add_argument('--android-root', help='where an android sd card path lives on this machine, kept for the next runs')
    parser.add_argument('--avd', help=f'the emulator to boot when none is connected, default {DEFAULT_AVD}')
    parser.add_argument('--device', help=f'default {DEFAULT_DEVICE}')
    parser.add_argument('--reseed', action='store_true', help='copy the music again even when no playlist changed')
    parser.add_argument('--skip-build', action='store_true')
    parser.add_argument('--no-publish', action='store_true')
    parser.add_argument('--docs', action='store_true', help='build namida_docs after publishing and print its shots line')
    args = parser.parse_args()

    work = Path(args.work)
    signed_out = Path(args.signed_out_work)
    platforms = args.platforms
    config = load_config(work, args)

    seed_music(work, config, args.reseed)
    if not args.skip_build:
        build(platforms)
    ensure_youtube_session(work)
    run([sys.executable, SCRIPTS / 'seed_youtube.py', '--work', work], cwd=ROOT)
    refresh_signed_out_work(work, signed_out)
    cache_videos(work, signed_out)

    online_scenes = [scene for scene in scenes_config()['scenes'] if any(step.get('do') == 'online' for step in scene['steps'])]
    online_ids = {scene['id'] for scene in online_scenes}
    online_scenes_path = signed_out / 'scenes_online.json'
    write_scenes(online_scenes_path, online_scenes)
    if 'android' in platforms:
        ensure_emulator(config)
    for platform in platforms:
        shoot_platform(platform, work, signed_out, config, online_scenes_path, online_ids)
    if 'android' in platforms:
        reset_emulator_screen(config['device'])

    publish_args = [] if args.no_publish else ['--publish']
    run([sys.executable, SCRIPTS / 'compose.py', '--work', work, *publish_args, '--only', *COMPOSED_FOLDERS], cwd=ROOT)
    if args.docs:
        check_docs()


if __name__ == '__main__':
    main()
