"""Builds a screenshots build, runs it on a freshly seeded copy of the library and collects the shots.

usage:
  python scripts/screenshots/shoot.py [--platform windows|linux|android] [--skip-build] [--scenes scripts/screenshots/scenes.json]
  python scripts/screenshots/shoot.py --interactive

android runs on an emulator (--device, default emulator-5554) with the debug package only. the screen is set to
1080x2400 @ 420dpi like the 2023 readme phone and the app hides the system bars, compose draws a slim status bar.
with `"deviceCapture": true` in the scenes the bars stay and every scene is also captured through adb, with a clean
demo mode status bar, into <theme>/<id>.device.png.

linux only shoots the flathub scenes (compose.FLATHUB_SHOTS), inside a headless kwin with its own session bus, where
the app is the only window. the screen scale is the linux pixelRatio, a scene's `window.scale` overrides it, each scale
is one session. `deviceCapture` (on for linux in scenes.json) has spectacle take each one as a window
shot with the native shadow, into <theme>/<id>.device.png. the app's HOME is work/linux/home.

the music dir is library.json's when this machine has it, else work/music, `--music-dir` for anything else (a library
seeded on one OS is shot on another).

needs `seed.py music` done first (work/library.json). the app runs portable from work/<platform>/app, never touching
the installed namida or its data. shots land in work/out/<platform>/<theme>/<id>.png.

--interactive shows the window and runs no scenes: sign in to youtube, browse the pages to cache, F12 captures the
current screen into work/out/<platform>/manual. on exit the youtube account, caches and sync/party settings are kept
in work/<platform>/keep and restored into every later run. android and linux runs without a keep of their own get the
windows keep, so all show the same account and caches (android puts the session into the app's internal storage,
through run-as).

by claude
"""

import argparse
import hashlib
import json
import os
import shlex
import shutil
import subprocess
import sys
import time
from pathlib import Path

from compose import FLATHUB_SHOTS


ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPTS = Path(__file__).resolve().parent
DEFAULT_WORK = ROOT / 'build' / 'screenshots'
DEFAULT_SCENES = SCRIPTS / 'scenes.json'
RUN_TIMEOUT_SECONDS = 60 * 60

DART_DEFINES = ['--dart-define=NAMIDA_SCREENSHOTS=true']
WINDOWS_BUILD_DIR = ROOT / 'build' / 'windows' / 'x64' / 'runner' / 'Profile'
LINUX_BUILD_DIR = ROOT / 'build' / 'linux' / 'x64' / 'profile' / 'bundle'
LINUX_APP_ID = 'com.msob7y.namida'
# -- pixels, roomy for the biggest window at the smallest scale plus its shadow. flathub allows 2000x1400 for hidpi, the
# -- scenes pick window size and scale to fill it (more content than 1000x700 at 2)
LINUX_SCREEN_SIZE = (2400, 1800)
LINUX_OUTPUT = 'Virtual-0'
LINUX_SOCKET = 'wayland-namida-screenshots'
# -- the cgroup holds whatever the session bus activated (portals), stopping it ends them all
LINUX_SCOPE = 'namida-screenshots.scope'
LINUX_SESSION_WAIT_SECONDS = 30
# -- these follow HOME then, so nothing reads or writes the user's own config, data and caches
LINUX_HOME_FOLLOWING_VARIABLES = ['XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_CACHE_HOME', 'XDG_STATE_HOME', 'FLATPAK_ID']
LINUX_SESSION_SCRIPT = '''#!/bin/sh
printf '%s' "$DBUS_SESSION_BUS_ADDRESS" > {bus_file}
kscreen-doctor output.{output}.scale.{scale} > /dev/null
exec {exe}
'''
ANDROID_APK = ROOT / 'build' / 'app' / 'outputs' / 'flutter-apk' / 'app-x86_64-debug.apk'
ANDROID_PACKAGE = 'com.msob7y.namida.debug'
ANDROID_ACTIVITY = f'{ANDROID_PACKAGE}/com.msob7y.namida.NamidaMainActivity'
ANDROID_DATA_DIR = f'/storage/emulated/0/Android/data/{ANDROID_PACKAGE}/files'
# -- its own folder, the emulator's Music may hold other test files
ANDROID_MUSIC_DIR = '/storage/emulated/0/Music/Library'
ANDROID_SCREEN_SIZE = '1080x2400'
ANDROID_DENSITY = '420'
CAPTURE_POLL_SECONDS = 0.3
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


def build_desktop(platform: str, *extra_defines):
    flutter = shutil.which('flutter')
    run([flutter, 'build', platform, '--profile', '--no-pub', *extra_defines, *DART_DEFINES], cwd=ROOT)


def stage_app(build_dir: Path, app_dir: Path) -> Path:
    if app_dir.exists():
        shutil.rmtree(app_dir)
    shutil.copytree(build_dir, app_dir)
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


def read_library(work: Path) -> dict:
    return json.loads((work / 'library.json').read_text(encoding='utf-8'))


def seed_data(work: Path, data_dir: Path, scenes: Path, music_dir: str, keep_dir: Path | None = None, keep_paths: list = KEEP_PATHS, shots: list | None = None) -> dict:
    if keep_dir is not None:
        copy_paths(keep_dir, data_dir, keep_paths)
    library = read_library(work)
    seed_script = SCRIPTS / 'seed.py'
    run([sys.executable, seed_script, '--work', work, 'data', '--data-dir', data_dir, '--music-dir', music_dir])
    screenshots_dir = data_dir / 'screenshots'
    screenshots_dir.mkdir(parents=True, exist_ok=True)
    resolved_scenes = resolve_player_roles(json.loads(scenes.read_text(encoding='utf-8')), library)
    if shots is not None:
        resolved_scenes = select_shots(resolved_scenes, shots)
    write_scenes(data_dir, resolved_scenes)
    return resolved_scenes


def write_scenes(data_dir: Path, scenes: dict):
    (data_dir / 'screenshots' / 'scenes.json').write_text(json.dumps(scenes, ensure_ascii=False), encoding='utf-8')


def select_shots(scenes: dict, shots: list) -> dict:
    # -- only these (id, theme, ...) shots the scene file has, each scene runs in just the themes asked for it
    themes_by_id = {}
    for shot_id, theme, *_ in shots:
        themes_by_id.setdefault(shot_id, []).append(theme)
    scenes['scenes'] = [{**scene, 'themes': themes_by_id[scene['id']]} for scene in scenes['scenes'] if scene['id'] in themes_by_id]
    return with_used_themes(scenes)


def with_used_themes(scenes: dict) -> dict:
    # -- a theme pass without scenes still switches and settles
    used_themes = {theme for scene in scenes['scenes'] for theme in scene.get('themes', scenes.get('sceneThemes', scenes['themes']))}
    return {**scenes, 'themes': [theme for theme in scenes['themes'] if theme in used_themes]}


def split_by_linux_scale(scenes: dict) -> dict:
    # -- the screen scale is the session's, so each scale runs alone with an in-app pixelRatio to match
    overrides = scenes.get('platformOverrides', {})
    linux_overrides = overrides.get('linux', {})
    default_scale = linux_overrides.get('pixelRatio', scenes.get('pixelRatio', 2.0))
    default_window = scenes.get('window') or {}
    scenes_by_scale = {}
    for scene in scenes['scenes']:
        scale = (scene.get('window') or default_window).get('scale', default_scale)
        scenes_by_scale.setdefault(scale, []).append(scene)
    return {
        scale: with_used_themes({**scenes, 'scenes': scale_scenes, 'platformOverrides': {**overrides, 'linux': {**linux_overrides, 'pixelRatio': scale}}})
        for scale, scale_scenes in scenes_by_scale.items()
    }


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


def run_capture_loop(out_dir: str, read_text, remove, capture, captures_dir: Path, is_running=lambda: True) -> dict:
    # -- the driver asks for each host capture with a request file and waits until it's gone
    request_path = f'{out_dir}/request.txt'
    done_path = f'{out_dir}/done.json'
    started = time.time()
    while time.time() - started < RUN_TIMEOUT_SECONDS:
        request = read_text(request_path)
        if request:
            target = captures_dir / request
            target.parent.mkdir(parents=True, exist_ok=True)
            capture(target)
            remove(request_path)
            continue
        # -- checked before reading done.json, so an app that wrote it and exited in between still counts as done
        was_running = is_running()
        done_text = read_text(done_path)
        if done_text:
            done = json.loads(done_text)
            done['seconds'] = round(time.time() - started)
            return done
        if not was_running:
            raise SystemExit(f'app exited after {time.time() - started:.0f}s without done.json, see {out_dir}/log.txt')
        time.sleep(CAPTURE_POLL_SECONDS)
    raise SystemExit(f'timed out after {RUN_TIMEOUT_SECONDS}s')


def shoot_windows(args, work: Path):
    if not args.skip_build:
        build_desktop('windows', '--dart-define=WINDOWS_PORTABLE=true')
    app_dir = stage_app(WINDOWS_BUILD_DIR, work / 'windows' / 'app')
    data_dir = app_dir / 'files'
    keep_dir = work / 'windows' / 'keep'
    seed_data(work, data_dir, Path(args.scenes), local_music_dir(work, args.music_dir), keep_dir=keep_dir)
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


def local_music_dir(work: Path, override: str | None) -> str:
    if override:
        return override
    # -- library.json keeps the dir of the machine that seeded it, another OS reads the same music from work/music
    library = read_library(work)
    first_track = library['tracks'][0]['path']
    for candidate in (Path(library['musicDir']), work / 'music'):
        if (candidate / first_track).is_file():
            return str(candidate.resolve())
    raise SystemExit('the seeded music is in neither library.json\'s dir nor work/music, pass --music-dir')


def read_text_if_exists(path: str) -> str:
    try:
        return Path(path).read_text(encoding='utf-8')
    except FileNotFoundError:
        return ''


def stop_linux_scope():
    subprocess.run(['systemctl', '--user', 'stop', LINUX_SCOPE], stderr=subprocess.DEVNULL)


def run_linux_session(work: Path, exe: Path, environment: dict, out_dir: Path, scale: float) -> dict:
    session_dir = work / 'linux'
    bus_file = session_dir / 'bus.txt'
    bus_file.unlink(missing_ok=True)
    # -- a previous session's, the capture loop would take it as this one's end
    for leftover in ('done.json', 'request.txt'):
        (out_dir / leftover).unlink(missing_ok=True)
    session_script = session_dir / 'session.sh'
    script = LINUX_SESSION_SCRIPT.format(bus_file=shlex.quote(str(bus_file)), output=LINUX_OUTPUT, scale=scale, exe=shlex.quote(str(exe)))
    session_script.write_text(script, encoding='utf-8', newline='\n')
    session_script.chmod(0o755)
    # -- DISPLAY/WAYLAND_DISPLAY of the user's desktop would also reach whatever the session bus activates
    session_environment = {**environment, 'WAYLAND_DISPLAY': LINUX_SOCKET, 'GDK_BACKEND': 'wayland'}
    session_environment.pop('DISPLAY', None)
    width, height = LINUX_SCREEN_SIZE
    kwin = [
        'kwin_wayland', '--virtual', '--no-lockscreen', '--width', str(width), '--height', str(height),
        '--socket', LINUX_SOCKET, '--exit-with-session', str(session_script),
    ]
    stop_linux_scope()
    with (session_dir / 'kwin.log').open('wb') as kwin_log:
        process = subprocess.Popen(
            ['systemd-run', '--user', '--scope', '--quiet', f'--unit={LINUX_SCOPE}', '--', 'dbus-run-session', '--', *kwin],
            env=session_environment, stdout=kwin_log, stderr=subprocess.STDOUT,
        )
        try:
            waited = 0.0
            while not bus_file.exists() and process.poll() is None and waited < LINUX_SESSION_WAIT_SECONDS:
                time.sleep(CAPTURE_POLL_SECONDS)
                waited += CAPTURE_POLL_SECONDS
            bus_address = read_text_if_exists(str(bus_file))
            if not bus_address:
                raise SystemExit(f'the headless kwin session never started, see {session_dir / "kwin.log"}')
            capture_environment = {**session_environment, 'DBUS_SESSION_BUS_ADDRESS': bus_address}

            def capture(target: Path):
                spectacle = ['spectacle', '--background', '--nonotify', '--activewindow', '--output', str(target)]
                subprocess.run(spectacle, env=capture_environment, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

            return run_capture_loop(
                out_dir.as_posix(), read_text_if_exists, lambda path: Path(path).unlink(missing_ok=True), capture, out_dir,
                is_running=lambda: process.poll() is None,
            )
        finally:
            stop_linux_scope()
            process.wait()


def shoot_linux(args, work: Path):
    if not args.skip_build:
        build_desktop('linux')
    app_dir = stage_app(LINUX_BUILD_DIR, work / 'linux' / 'app')
    home_dir = work / 'linux' / 'home'
    if home_dir.exists():
        shutil.rmtree(home_dir)
    data_dir = home_dir / '.namida'
    # -- AppDirs.ROOT_DIR (path_provider's support dir), the youtube session lives there
    root_dir = home_dir / '.local' / 'share' / LINUX_APP_ID
    linux_keep_dir = work / 'linux' / 'keep'
    keep_dir = linux_keep_dir if linux_keep_dir.exists() else work / 'windows' / 'keep'
    data_keep_paths = [name for name in KEEP_PATHS if name != KEEP_SESSION_PATH]
    shots = None if args.interactive else FLATHUB_SHOTS
    scenes = seed_data(work, data_dir, Path(args.scenes), local_music_dir(work, args.music_dir), keep_dir=keep_dir, keep_paths=data_keep_paths, shots=shots)
    copy_paths(keep_dir, root_dir, [KEEP_SESSION_PATH])
    environment = {key: value for key, value in os.environ.items() if key not in LINUX_HOME_FOLLOWING_VARIABLES}
    environment['HOME'] = str(home_dir)
    out_dir = data_dir / 'screenshots' / 'out'
    exe = app_dir / 'namida'
    if args.interactive:
        # -- on the user's desktop, the headless session takes no input
        subprocess.run([exe], env={**environment, 'NAMIDA_SCREENSHOTS_INTERACTIVE': '1'})
        copy_paths(data_dir, linux_keep_dir, data_keep_paths)
        copy_paths(root_dir, linux_keep_dir, [KEEP_SESSION_PATH])
        harvest_videos(work, data_dir)
        return None, out_dir
    done = {'shots': [], 'errors': [], 'seconds': 0}
    for scale, scale_scenes in split_by_linux_scale(scenes).items():
        write_scenes(data_dir, scale_scenes)
        session_done = run_linux_session(work, exe, environment, out_dir, scale)
        for key in done:
            done[key] += session_done[key]
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


def push_android_music(device: str, work: Path, music_source: Path):
    # -- the music is big, a marker of the library skips pushing an unchanged one again. file dates are in it too
    library_text = (work / 'library.json').read_text(encoding='utf-8')
    marker = hashlib.sha1(library_text.encode('utf-8')).hexdigest()
    marker_path = f'{ANDROID_MUSIC_DIR}/.screenshots_marker'
    if adb_shell_text(device, f'cat {marker_path}') == marker:
        return
    adb(device, 'shell', 'rm', '-rf', ANDROID_MUSIC_DIR)
    adb(device, 'shell', 'mkdir', '-p', ANDROID_MUSIC_DIR)
    for entry in music_source.iterdir():
        adb(device, 'push', str(entry), f'{ANDROID_MUSIC_DIR}/')
    adb(device, 'shell', f'echo {marker} > {marker_path}')


def run_android_capture_loop(device: str, captures_dir: Path) -> dict:
    return run_capture_loop(
        f'{ANDROID_DATA_DIR}/screenshots/out',
        lambda path: adb_shell_text(device, f'cat {path} 2>/dev/null'),
        lambda path: adb(device, 'shell', 'rm', '-f', path),
        lambda target: target.write_bytes(adb(device, 'exec-out', 'screencap', '-p', capture=True)),
        captures_dir,
    )


def shoot_android(args, work: Path):
    device = args.device
    if not args.skip_build:
        flutter = shutil.which('flutter')
        run([flutter, 'build', 'apk', '--debug', '--no-pub', '--target-platform', 'android-x64', *DART_DEFINES], cwd=ROOT)
    adb(device, 'shell', 'am', 'force-stop', ANDROID_PACKAGE)
    adb(device, 'install', '-r', '-g', str(ANDROID_APK))
    adb(device, 'shell', 'appops', 'set', ANDROID_PACKAGE, 'MANAGE_EXTERNAL_STORAGE', 'allow')
    prepare_android_screen(device)
    push_android_music(device, work, Path(local_music_dir(work, args.music_dir)))

    local_data_dir = work / 'android' / 'files'
    if local_data_dir.exists():
        shutil.rmtree(local_data_dir)
    local_data_dir.mkdir(parents=True)
    keep_dir = work / 'windows' / 'keep'
    has_keep = keep_dir.exists()
    data_keep_paths = [name for name in KEEP_PATHS if name != KEEP_SESSION_PATH]
    seed_data(work, local_data_dir, Path(args.scenes), ANDROID_MUSIC_DIR, keep_dir=keep_dir if has_keep else None, keep_paths=data_keep_paths)
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
    parser.add_argument('--platform', default='windows', choices=['windows', 'linux', 'android'])
    parser.add_argument('--device', default='emulator-5554')
    parser.add_argument('--music-dir', help='the seeded music dir as this machine sees it')
    parser.add_argument('--scenes', default=str(DEFAULT_SCENES))
    parser.add_argument('--skip-build', action='store_true')
    parser.add_argument('--interactive', action='store_true')
    args = parser.parse_args()

    work = Path(args.work)
    shooters = {'windows': shoot_windows, 'linux': shoot_linux, 'android': shoot_android}
    done, out_dir = shooters[args.platform](args, work)

    collected_dir = work / 'out' / args.platform
    if done is None:
        manual_dir = out_dir / 'manual'
        if manual_dir.exists():
            shutil.copytree(manual_dir, collected_dir / 'manual', dirs_exist_ok=True)
        print(f"interactive session saved -> {work / args.platform / 'keep'}")
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
