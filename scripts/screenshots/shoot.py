"""Builds a screenshots build, runs it on a freshly seeded copy of the library and collects the shots.

usage:
  python scripts/screenshots/shoot.py [--platform windows|android] [--skip-build] [--scenes scripts/screenshots/scenes.json]
  python scripts/screenshots/shoot.py --interactive

android runs on an emulator (--device, default emulator-5554) with the debug package only. the screen is set to
1080x2400 @ 420dpi like the 2023 readme phone and the app hides the system bars, compose draws a slim status bar.
with `"deviceCapture": true` in the scenes the bars stay and every scene is also captured through adb, with a clean
demo mode status bar, into <theme>/<id>.device.png.

needs `seed.py music` done first (work/library.json). the app runs portable from work/<platform>/app, never touching
the installed namida or its data. shots land in work/out/<platform>/<theme>/<id>.png.

--interactive shows the window and runs no scenes: sign in to youtube, browse the pages to cache, F12 captures the
current screen into work/out/<platform>/manual. on exit the youtube account, caches and sync/party settings are kept
in work/<platform>/keep and restored into every later run. android runs get the windows keep too, so both show the
same account and caches (the session goes into the app's internal storage, through run-as).

by claude
"""

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPTS = Path(__file__).resolve().parent
DEFAULT_WORK = ROOT / 'build' / 'screenshots'
DEFAULT_SCENES = SCRIPTS / 'scenes.json'
RUN_TIMEOUT_SECONDS = 60 * 60

DART_DEFINES = ['--dart-define=NAMIDA_SCREENSHOTS=true']
WINDOWS_BUILD_DIR = ROOT / 'build' / 'windows' / 'x64' / 'runner' / 'Profile'
ANDROID_APK = ROOT / 'build' / 'app' / 'outputs' / 'flutter-apk' / 'app-x86_64-debug.apk'
ANDROID_PACKAGE = 'com.msob7y.namida.debug'
ANDROID_ACTIVITY = f'{ANDROID_PACKAGE}/com.msob7y.namida.NamidaMainActivity'
ANDROID_DATA_DIR = f'/storage/emulated/0/Android/data/{ANDROID_PACKAGE}/files'
# -- its own folder, the emulator's Music may hold other test files
ANDROID_MUSIC_DIR = '/storage/emulated/0/Music/Library'
ANDROID_SCREEN_SIZE = '1080x2400'
ANDROID_DENSITY = '420'
ANDROID_POLL_SECONDS = 0.3
# -- demo mode: a fixed clock, full battery and signal, no notification icons
ANDROID_DEMO_COMMANDS = [
    ['clock', '-e', 'hhmm', '1100'],
    ['battery', '-e', 'level', '100', '-e', 'plugged', 'false'],
    ['network', '-e', 'wifi', 'show', '-e', 'level', '4', '-e', 'fully', 'true'],
    ['network', '-e', 'mobile', 'show', '-e', 'level', '4', '-e', 'datatype', 'lte'],
    ['notifications', '-e', 'visible', 'false'],
]

# -- what an interactive session sets up, everything else is seeded fresh on every run
KEEP_PATHS = ['Youtube', 'Youtipie', 'Namida', 'namida_settings_youtube.json', 'namida_settings_sync.json', 'namida_settings_party.json']
# -- AppDirs.YOUTIPIE_DATA (accounts, memberships, their key), android keeps it outside the data dir the runs replace
KEEP_SESSION_PATH = 'Youtipie'
ANDROID_KEEP_TMP_DIR = '/data/local/tmp/namida_screenshots_session'


def run(command: list, **kwargs):
    print('>', ' '.join(str(c) for c in command))
    subprocess.run(command, check=True, **kwargs)


def build_windows():
    flutter = shutil.which('flutter')
    run([flutter, 'build', 'windows', '--profile', '--no-pub', '--dart-define=WINDOWS_PORTABLE=true', *DART_DEFINES], cwd=ROOT)


def stage_windows(work: Path) -> Path:
    app_dir = work / 'windows' / 'app'
    if app_dir.exists():
        shutil.rmtree(app_dir)
    shutil.copytree(WINDOWS_BUILD_DIR, app_dir)
    return app_dir


def copy_paths(source_dir: Path, dest_dir: Path, names: list):
    for name in names:
        source = source_dir / name
        dest = dest_dir / name
        if source.is_dir():
            shutil.copytree(source, dest, dirs_exist_ok=True)
        elif source.is_file():
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, dest)


def seed_data(work: Path, data_dir: Path, scenes: Path, music_dir: str | None = None, keep_dir: Path | None = None, keep_paths: list = KEEP_PATHS):
    if keep_dir is not None:
        copy_paths(keep_dir, data_dir, keep_paths)
    library = json.loads((work / 'library.json').read_text(encoding='utf-8'))
    music_dir = music_dir or library['musicDir']
    seed_script = SCRIPTS / 'seed.py'
    run([sys.executable, seed_script, '--work', work, 'data', '--data-dir', data_dir, '--music-dir', music_dir])
    screenshots_dir = data_dir / 'screenshots'
    screenshots_dir.mkdir(parents=True, exist_ok=True)
    resolved_scenes = resolve_player_roles(json.loads(scenes.read_text(encoding='utf-8')), library)
    (screenshots_dir / 'scenes.json').write_text(json.dumps(resolved_scenes, ensure_ascii=False), encoding='utf-8')


def resolve_player_roles(scenes: dict, library: dict) -> dict:
    # -- `@role` tracks come from the user's `screenshots player` playlist in the order of `players`, its defaults fill the rest
    titles_by_path = {track['path']: track['title'] for track in library['tracks']}
    picked = [titles_by_path[path] for path in library.get('placement', {}).get('player', []) if path in titles_by_path]
    roles = scenes.get('players', {})
    titles = {f'@{role}': picked[index] if index < len(picked) else default for index, (role, default) in enumerate(roles.items())}
    steps = [*scenes.get('setup', []), *(step for scene in scenes['scenes'] for step in scene.get('steps', []))]
    for step in steps:
        for key, value in step.items():
            if isinstance(value, str) and value in titles:
                step[key] = titles[value]
    return scenes


def harvest_videos(work: Path, data_dir: Path):
    # -- videos fetched online during the run are reused by the next ones, a .metadata companion means unfinished
    videos_dir = work / 'videos'
    for video in (data_dir / 'Videos').glob('*.mp4'):
        is_complete = not video.with_name(f'{video.name}.metadata').exists()
        dest = videos_dir / video.name
        if is_complete and not dest.exists():
            shutil.copy2(video, dest)


def launch_and_wait(command: list, out_dir: Path) -> dict:
    started = time.time()
    process = subprocess.Popen(command)
    log_path = out_dir / 'log.txt'
    try:
        process.wait(timeout=RUN_TIMEOUT_SECONDS)
    except subprocess.TimeoutExpired:
        process.kill()
        raise SystemExit(f'timed out after {RUN_TIMEOUT_SECONDS}s, see {log_path}')
    elapsed = time.time() - started
    done_file = out_dir / 'done.json'
    if not done_file.exists():
        raise SystemExit(f'app exited after {elapsed:.0f}s without done.json, see {log_path}')
    done = json.loads(done_file.read_text(encoding='utf-8'))
    done['seconds'] = round(elapsed)
    return done


def shoot_windows(args, work: Path):
    if not args.skip_build:
        build_windows()
    app_dir = stage_windows(work)
    data_dir = app_dir / 'files'
    keep_dir = work / 'windows' / 'keep'
    seed_data(work, data_dir, Path(args.scenes), keep_dir=keep_dir)
    out_dir = data_dir / 'screenshots' / 'out'
    exe = app_dir / 'namida.exe'
    if args.interactive:
        environment = {**os.environ, 'NAMIDA_SCREENSHOTS_INTERACTIVE': '1'}
        subprocess.run([exe], env=environment)
        copy_paths(data_dir, work / 'windows' / 'keep', KEEP_PATHS)
        harvest_videos(work, data_dir)
        return None, out_dir
    done = launch_and_wait([exe], out_dir)
    harvest_videos(work, data_dir)
    return done, out_dir


def adb(device: str, *arguments, check: bool = True, capture: bool = False) -> bytes:
    adb_path = shutil.which('adb')
    command = [adb_path, '-s', device, *arguments]
    result = subprocess.run(command, check=check, capture_output=capture)
    return result.stdout if capture else b''


def adb_shell_text(device: str, command: str) -> str:
    output = adb(device, 'shell', command, check=False, capture=True)
    return output.decode('utf-8', errors='replace').strip()


ADB_PUSH_BATCH = 40


def shell_quote(path: str) -> str:
    escaped = path.replace("'", "'\\''")
    return f"'{escaped}'"


def push_tree(device: str, local_dir: Path, remote_dir: str):
    # -- adb push can't create folders inside Android/data, a shell mkdir can, then files go in batches
    local_dirs = [local_dir, *(d for d in local_dir.rglob('*') if d.is_dir())]
    remote_dirs = [remote_dir + '/' + d.relative_to(local_dir).as_posix() if d != local_dir else remote_dir for d in local_dirs]
    quoted_dirs = ' '.join(shell_quote(d) for d in remote_dirs)
    adb(device, 'shell', f'mkdir -p {quoted_dirs}')
    for directory, remote in zip(local_dirs, remote_dirs):
        files = [str(f) for f in directory.iterdir() if f.is_file()]
        for start in range(0, len(files), ADB_PUSH_BATCH):
            batch = files[start:start + ADB_PUSH_BATCH]
            adb(device, 'push', *batch, f'{remote}/')


def push_android_session(device: str, session_dir: Path):
    if not session_dir.exists():
        return
    adb(device, 'shell', 'rm', '-rf', ANDROID_KEEP_TMP_DIR)
    push_tree(device, session_dir, ANDROID_KEEP_TMP_DIR)
    copy_command = f'rm -rf files/{KEEP_SESSION_PATH} && cp -r {ANDROID_KEEP_TMP_DIR} files/{KEEP_SESSION_PATH}'
    adb(device, 'shell', f'run-as {ANDROID_PACKAGE} sh -c {shell_quote(copy_command)}')
    adb(device, 'shell', 'rm', '-rf', ANDROID_KEEP_TMP_DIR)


def prepare_android_screen(device: str):
    adb(device, 'shell', 'wm', 'size', ANDROID_SCREEN_SIZE)
    adb(device, 'shell', 'wm', 'density', ANDROID_DENSITY)
    # -- hidden system bars show a one time "viewing full screen" hint otherwise
    adb(device, 'shell', 'settings', 'put', 'secure', 'immersive_mode_confirmations', 'confirmed')
    adb(device, 'shell', 'settings', 'put', 'global', 'sysui_demo_allowed', '1')
    adb(device, 'shell', 'am', 'broadcast', '-a', 'com.android.systemui.demo', '-e', 'command', 'enter')
    for demo_command in ANDROID_DEMO_COMMANDS:
        adb(device, 'shell', 'am', 'broadcast', '-a', 'com.android.systemui.demo', '-e', 'command', *demo_command)


def push_android_music(device: str, work: Path):
    # -- the music is big, a marker of the library skips pushing an unchanged one again. file dates are in it too
    library_text = (work / 'library.json').read_text(encoding='utf-8')
    library = json.loads(library_text)
    marker = hashlib.sha1(library_text.encode('utf-8')).hexdigest()
    marker_path = f'{ANDROID_MUSIC_DIR}/.screenshots_marker'
    if adb_shell_text(device, f'cat {marker_path}') == marker:
        return
    adb(device, 'shell', 'rm', '-rf', ANDROID_MUSIC_DIR)
    adb(device, 'shell', 'mkdir', '-p', ANDROID_MUSIC_DIR)
    music_source = Path(library['musicDir'])
    for entry in music_source.iterdir():
        adb(device, 'push', str(entry), f'{ANDROID_MUSIC_DIR}/')
    adb(device, 'shell', f'echo {marker} > {marker_path}')


def run_android_capture_loop(device: str, captures_dir: Path) -> dict:
    out_dir = f'{ANDROID_DATA_DIR}/screenshots/out'
    request_path = f'{out_dir}/request.txt'
    done_path = f'{out_dir}/done.json'
    started = time.time()
    while time.time() - started < RUN_TIMEOUT_SECONDS:
        request = adb_shell_text(device, f'cat {request_path} 2>/dev/null')
        if request:
            image = adb(device, 'exec-out', 'screencap', '-p', capture=True)
            target = captures_dir / request
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(image)
            adb(device, 'shell', 'rm', '-f', request_path)
            continue
        done_text = adb_shell_text(device, f'cat {done_path} 2>/dev/null')
        if done_text:
            done = json.loads(done_text)
            done['seconds'] = round(time.time() - started)
            return done
        time.sleep(ANDROID_POLL_SECONDS)
    raise SystemExit(f'timed out after {RUN_TIMEOUT_SECONDS}s')


def shoot_android(args, work: Path):
    device = args.device
    if not args.skip_build:
        flutter = shutil.which('flutter')
        run([flutter, 'build', 'apk', '--debug', '--no-pub', '--target-platform', 'android-x64', *DART_DEFINES], cwd=ROOT)
    adb(device, 'shell', 'am', 'force-stop', ANDROID_PACKAGE)
    adb(device, 'install', '-r', '-g', str(ANDROID_APK))
    adb(device, 'shell', 'appops', 'set', ANDROID_PACKAGE, 'MANAGE_EXTERNAL_STORAGE', 'allow')
    prepare_android_screen(device)
    push_android_music(device, work)

    local_data_dir = work / 'android' / 'files'
    if local_data_dir.exists():
        shutil.rmtree(local_data_dir)
    local_data_dir.mkdir(parents=True)
    keep_dir = work / 'windows' / 'keep'
    has_keep = keep_dir.exists()
    data_keep_paths = [name for name in KEEP_PATHS if name != KEEP_SESSION_PATH]
    seed_data(work, local_data_dir, Path(args.scenes), music_dir=ANDROID_MUSIC_DIR, keep_dir=keep_dir if has_keep else None, keep_paths=data_keep_paths)
    adb(device, 'shell', 'rm', '-rf', ANDROID_DATA_DIR)
    push_tree(device, local_data_dir, ANDROID_DATA_DIR)
    if has_keep:
        push_android_session(device, keep_dir / KEEP_SESSION_PATH)

    device_captures_dir = work / 'android' / 'device'
    if device_captures_dir.exists():
        shutil.rmtree(device_captures_dir)
    adb(device, 'shell', 'am', 'start', '-n', ANDROID_ACTIVITY)
    done = run_android_capture_loop(device, device_captures_dir)
    pulled_dir = work / 'android' / 'out'
    if pulled_dir.exists():
        shutil.rmtree(pulled_dir)
    adb(device, 'pull', f'{ANDROID_DATA_DIR}/screenshots/out', str(pulled_dir))
    if device_captures_dir.exists():
        shutil.copytree(device_captures_dir, pulled_dir, dirs_exist_ok=True)
    return done, pulled_dir


def main():
    parser = argparse.ArgumentParser(description='takes the screenshots')
    parser.add_argument('--work', default=str(DEFAULT_WORK))
    parser.add_argument('--platform', default='windows', choices=['windows', 'android'])
    parser.add_argument('--device', default='emulator-5554')
    parser.add_argument('--scenes', default=str(DEFAULT_SCENES))
    parser.add_argument('--skip-build', action='store_true')
    parser.add_argument('--interactive', action='store_true')
    args = parser.parse_args()

    work = Path(args.work)
    shooters = {'windows': shoot_windows, 'android': shoot_android}
    done, out_dir = shooters[args.platform](args, work)

    collected_dir = work / 'out' / args.platform
    if done is None:
        manual_dir = out_dir / 'manual'
        if manual_dir.exists():
            shutil.copytree(manual_dir, collected_dir / 'manual', dirs_exist_ok=True)
        print(f"interactive session saved -> {work / 'windows' / 'keep'}")
        return

    # -- the full scene list replaces everything, a smaller one only its own shots
    is_full_run = Path(args.scenes).resolve() == DEFAULT_SCENES.resolve()
    if is_full_run:
        for theme_dir in collected_dir.glob('*'):
            if theme_dir.is_dir() and theme_dir.name != 'manual':
                shutil.rmtree(theme_dir)
    shutil.copytree(out_dir, collected_dir, dirs_exist_ok=True)
    shots_count = len(done['shots'])
    print(f"{shots_count} shots in {done['seconds']}s -> {collected_dir}")
    for error in done['errors']:
        print(f'error: {error}', file=sys.stderr)


if __name__ == '__main__':
    main()
