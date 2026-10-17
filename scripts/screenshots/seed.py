"""Seeds the screenshots library: picks tracks, copies them with fake tags, writes namida data around them.

usage:
  python scripts/screenshots/seed.py pick [--source ~/.namida] [--count 150]
  python scripts/screenshots/seed.py music [--playlist <namida playlist json>] [--source ~/.namida] [--music-dir <dir>] [--drive E:=/mnt/Media]
  python scripts/screenshots/seed.py data --data-dir <app user data dir> --music-dir <music dir as the app sees it>

every command takes --work (default build/screenshots). `pick` writes work/playlist.json, `music` copies into
--music-dir (default work/music) and writes work/library.json, `data` turns library.json into settings, history,
favourites and playlists. the playlist order is the priority: earlier tracks get more listens and become favourites.
the user's namida playlists in PLACEMENT_PLAYLISTS pin what shows first on a page, their tracks join the library too.
pages without one are filled from `screenshots better visuals` (ordered) and the user's preferences, a folder at a time.
needs mutagen, see requirements.txt.

by claude
"""

import argparse
import collections
import datetime
import json
import os
import random
import re
import shutil
import sqlite3
import sys
import time
from pathlib import Path

from mutagen import File as MutagenFile
from mutagen.id3 import COMM, ID3, TALB, TCOM, TCON, TDRC, TIT2, TLAN, TMOO, TPE1, TPE2, TPOS, TPUB, TRCK, TXXX, ID3NoHeaderError
from mutagen.mp4 import MP4, MP4FreeForm

ROOT = Path(__file__).resolve().parent.parent.parent
DEFAULT_WORK = ROOT / 'build' / 'screenshots'
DEFAULT_SOURCE = Path.home() / '.namida'

AUDIO_EXTENSIONS = {'.m4a', '.mp3', '.ogg', '.opus', '.flac'}
MIN_DURATION_MS = 90 * 1000
MAX_DURATION_MS = 8 * 60 * 1000
MAX_TRACKS_PER_ARTIST = 6
SINGLES_RATIO = 0.3
MAX_ALBUM_TRACKS = 16
COMPILATION_SIZE = 13
# -- an artist this big gets two albums, so artist pages have more than one
MIN_TRACKS_FOR_TWO_ALBUMS = 8
# -- artists the playlist has at least this many of get more of their tracks from the source library.
# -- 0 keeps the library to the user's own picks
MIN_TRACKS_FOR_ARTIST_FILL = 2
ARTIST_FILL_COUNT = 0
FAV_SCORE_BONUS = 20
RNG_SEED = 7

# -- over a year, home's lost memories looks a year back
HISTORY_DAYS = 420
FAVOURITES_COUNT = 35
# -- pinned most played stay on top in the readme's 6 months range and in all time
MOST_PLAYED_RECENT_DAYS = 180
MOST_PLAYED_STEP = 4
TRACK_MODIFIED_GAP_SECONDS = 60
LISTENED_RATIO = 0.85
YOUTUBE_LISTEN_SECONDS = 150

TITLE_NOISE_REGEX = re.compile(r'\s*[\[(][^\])]*(release|official|lyric|video|audio|monstercat|ncs|copyright|free download|visuali[sz]er|hd|4k)[^\])]*[\])]', re.IGNORECASE)
INVALID_FILENAME_REGEX = re.compile(r'[<>:"/\\|?*]')
NON_ALNUM_REGEX = re.compile(r'\W+')
YOUTUBE_ID_REGEX = re.compile(r'(?:youtube\.com/watch\?v=|youtu\.be/)([\w-]{11})')
UNKNOWN_VALUES = {'', 'unknown artist', 'unknown album', 'unknown genre', 'unknown composer'}

ALBUM_NAMES = [
    'Neon Horizons', 'Paper Satellites', 'Afterglow Avenue', 'Midnight Bloom', 'Glass Garden', 'Echoes of Tomorrow',
    'Static Dreams', 'Lunar Drift', 'Velvet Skies', 'Cloudline', 'Starlit Roads', 'Ember & Ash',
    'Low Tide Radio', 'Silver Lining', 'Wildflower Season', 'Northern Lights', 'Faded Polaroids', 'City of Lanterns',
    'Ocean Hymns', 'Sakura Signal', 'Prism Hearts', 'Distant Shores', 'Golden Hour Tapes', 'Snowfall Letters',
    'Electric Daydream', 'Hollow Moon', 'Coastline Memories', 'Parallel Lines', 'Firefly Nights', 'Blue Hour',
    'Crimson Tide', 'Moonlit Avenue', 'Paper Hearts', 'Midnight Signals', 'Afterimage', 'Cold Summer',
    'Silent Frequencies', 'Glow', 'Orbit', 'Shattered Skies', 'Daybreak', 'Kaleidoscope',
    'Weightless', 'Echo Chamber', 'Neon Rain', 'Polaroid Summer', 'Lost in Tokyo', 'Starfall',
    'Gravity', 'Overdrive', 'Aurora', 'Wanderlust', 'Lighthouse', 'Fragments',
    'Second Sun', 'Chasing Light', 'Ivory Tower', 'Night Bloom', 'Horizon Line', 'Kingdom of Glass',
]
COMPILATION_NAMES = [
    'Night Drive Vol. 1', 'Night Drive Vol. 2', 'Late Night Sessions', 'Weekend Mixtape', 'Rooftop Stories',
    'Lights Out', 'Summer Static', 'Midnight Archives', 'Dreamwave Collection', 'Skyline Sounds',
]
GENRES = ['Electronic', 'Nightcore', 'Synthwave', 'Future Bass', 'Lo-fi', 'Indie Pop', 'Alt Rock', 'Dubstep', 'House', 'Ambient', 'J-Pop', 'Chillstep']
STYLES = ['Melodic', 'Vocal', 'Atmospheric', 'Upbeat', 'Cinematic', 'Instrumental']
MOODS = ['Energetic', 'Chill', 'Melancholic', 'Uplifting', 'Dreamy', 'Dark', 'Happy']
LABELS = ['Moonrise Records', 'Blue Hour Music', 'Paperplane Audio', 'Static Bloom', 'Lantern Sound']
# -- the user's own playlists, PLAYLISTS_WITH_TRACKS bring all their tracks into the library, PLAYLISTS_MAPPED only
# -- keep tracks the library already has. listed from the most recently modified, the first four are the 2023 readme's
PLAYLISTS_WITH_TRACKS = []
PLAYLISTS_MAPPED = ['💜🌸', 'Jul 2021', 'wyee', '2020 vibes', '❤️', '6 oct lost memories 2021', 'Music 01']
# -- the user orders these in namida, each pins what a page shows first
PLACEMENT_PLAYLISTS = {
    'tracks': 'screenshots tracks',
    'mostPlayed': 'screenshots most played',
    'recentListens': 'screenshots recent',
    'favourites': 'screenshots favourites',
    # -- in the order of the scenes' `players` roles, main first
    'player': 'screenshots player',
}
# -- tracks with the best looking artworks/videos, in the user's order. they lead the priority and fill unpinned pages
VISUALS_PLAYLIST = 'screenshots better visuals'
AUTO_PLACEMENT_SIZES = {'tracks': 10, 'mostPlayed': 10, 'recentListens': 6, 'favourites': 10}
PREFERRED_FOLDERS = {'[YT] Music', '[YT] Nightcore'}
NIGHTCORE_SCORE = 3
SYREX_SCORE = 2
PREFERRED_FOLDER_SCORE = 2
PLAYLIST_AGES_DAYS = [1, 6, 18, 33, 52, 80, 130, 210]
PLAYLIST_TAGS = {
    '💜🌸': ['mood/calm'], 'Jul 2021': ['seasons/summer'], 'wyee': ['party'], '2020 vibes': ['gym', 'night'],
    '❤️': ['mood/calm'], 'deep': ['night', 'study'], '6 oct lost memories 2021': ['mood/sad'], 'Music 01': ['mood/hype'],
}
# -- the lyrics of these never show up
LYRICS_EXCLUDED_TITLES = {'Paranoid (feat. Izzy Bizu)'}
LIBRARY_TABS = ['home', 'tracks', 'history', 'genres', 'playlists', 'folders', 'youtube']
# -- the 2023 readme's recent listens, newest first, when there is no `screenshots recent` playlist
RECENT_LISTENS_TITLES = ['Nightfall', "Everybody's Scared", 'One & Only', 'Zombie Step']
RECENT_LISTENS_GAP_MINUTES = 4
ANDROID_STORAGE_REGEX = re.compile(r'^/storage/[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}/')
WINDOWS_DRIVE_REGEX = re.compile(r'^([A-Za-z]:)[\\/]')
PLAYLIST_TAG_COLORS = {'gym': 0xFFE57373, 'night': 0xFF7986CB, 'study': 0xFF4DB6AC}
TRACK_TAGS = ['night drive', 'gym', 'study', 'road trip', 'rainy', 'party']
LANGUAGES = ['eng', 'eng', 'eng', 'eng', 'eng', 'jpn', 'kor', 'spa']
RATINGS = [0, 0, 60, 80, 80, 100]
MISSING_TRACKS = ['Old Phone/Unknown Artist - Lost Demo.mp3', 'Old Phone/Voice Memo 12.m4a', 'Downloads/untitled (1).mp3']
SMART_PLAYLISTS = [
    ('Top Played', [{'type': 'number', 'filter': 'isGreaterThan', 'source': 'totalListensInRange', 'data': 25}]),
    ('Alan Walker', [{'type': 'text', 'filter': 'contains', 'source': 'artist', 'data': [{'type': 'literal', 'text': 'alan walker'}], 'enableCleanup': True}]),
    ('Night Vibes', [{'type': 'text', 'filter': 'contains', 'source': 'album', 'data': [{'type': 'literal', 'text': 'night'}], 'enableCleanup': True}]),
]


def read_json(path: Path):
    text = path.read_text(encoding='utf-8')
    return json.loads(text)


def write_json(path: Path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    text = json.dumps(data, ensure_ascii=False, indent=2)
    path.write_text(text, encoding='utf-8')


def is_known(value) -> bool:
    if not isinstance(value, str):
        return False
    return value.strip().lower() not in UNKNOWN_VALUES


def read_tracks_db(source: Path) -> dict:
    db_path = source / 'tracks.db'
    if not db_path.exists():
        return {}
    uri = f'file:{db_path.as_posix()}?mode=ro'
    connection = sqlite3.connect(uri, uri=True)
    rows = connection.execute('select key, value from tracks').fetchall()
    connection.close()
    return {key: json.loads(value) for key, value in rows if value}


def count_plays(source: Path) -> collections.Counter:
    plays = collections.Counter()
    history_dir = source / 'History'
    for day_file in history_dir.glob('*.json'):
        try:
            entries = read_json(day_file)
        except (OSError, ValueError):
            continue
        for entry in entries:
            if entry.get('v'):
                continue
            plays[entry.get('track')] += 1
    return plays


def read_favourites(source: Path) -> set:
    favs_path = source / 'favs.json'
    if not favs_path.exists():
        return set()
    favs = read_json(favs_path)
    return {e['track'] for e in favs.get('tracks', [])}


def cmd_pick(args):
    source = Path(args.source)
    tracks = read_tracks_db(source)
    plays = count_plays(source)
    favourites = read_favourites(source)
    artworks_dir = source / 'Artworks'

    candidates = []
    for path, info in tracks.items():
        file = Path(path)
        if file.suffix.lower() not in AUDIO_EXTENSIONS:
            continue
        duration_ms = info.get('durationMS') or 0
        if not MIN_DURATION_MS <= duration_ms <= MAX_DURATION_MS:
            continue
        has_title = is_known(info.get('title'))
        has_artist = is_known(info.get('originalArtist'))
        if not has_title or not has_artist:
            continue
        artwork = artworks_dir / f'{file.name}.png'
        has_artwork = artwork.exists()
        if not has_artwork or not file.exists():
            continue
        fav_bonus = FAV_SCORE_BONUS if path in favourites else 0
        score = plays[path] + fav_bonus
        artist_key = info['originalArtist'].lower()
        song_key = song_key_of(info['originalArtist'], info['title'])
        candidates.append((score, path, artist_key, song_key))

    candidates.sort(key=lambda c: c[0], reverse=True)
    per_artist = collections.Counter()
    picked_songs = set()
    picked = []
    for score, path, artist_key, song_key in candidates:
        if per_artist[artist_key] >= MAX_TRACKS_PER_ARTIST or song_key in picked_songs:
            continue
        per_artist[artist_key] += 1
        picked_songs.add(song_key)
        picked.append(path)
        if len(picked) >= args.count:
            break

    now_ms = int(time.time() * 1000)
    playlist = {
        'name': 'Screenshots',
        'tracks': [{'dateAdded': now_ms + i, 'track': p} for i, p in enumerate(picked)],
        'creationDate': now_ms,
        'modifiedDate': now_ms,
        'sortsType': [],
        'sortReverse': False,
    }
    out = Path(args.work) / 'playlist.json'
    write_json(out, playlist)
    print(f'picked {len(picked)} tracks ({len(per_artist)} artists) -> {out}')


def clean_title(title: str) -> str:
    cleaned = TITLE_NOISE_REGEX.sub('', title)
    return cleaned.strip() or title


def safe_filename(name: str) -> str:
    cleaned = INVALID_FILENAME_REGEX.sub('', name)
    return cleaned.strip().rstrip('.')


def find_youtube_id(text: str) -> str:
    match = YOUTUBE_ID_REGEX.search(text)
    return match.group(1) if match else ''


def read_source_info(path: Path, tracks_db: dict) -> dict:
    info = tracks_db.get(str(path))
    if info is not None:
        comment = info.get('comment') or ''
        return {
            'title': info.get('title') or path.stem,
            'artist': info.get('originalArtist') or '',
            'youtubeId': find_youtube_id(comment),
        }
    easy = MutagenFile(path, easy=True)
    tags = easy.tags if easy is not None and easy.tags is not None else {}
    title = (tags.get('title') or [path.stem])[0]
    artist = (tags.get('artist') or [''])[0]
    comment = (tags.get('comment') or [''])[0]
    return {'title': title, 'artist': artist, 'youtubeId': find_youtube_id(comment)}


def song_key_of(artist: str, title: str) -> str:
    cleaned_title = clean_title(title)
    return NON_ALNUM_REGEX.sub('', f'{artist.lower()}{cleaned_title.lower()}')


def plan_albums(items: list, rng: random.Random) -> list:
    by_artist = collections.defaultdict(list)
    for item in items:
        by_artist[item['artist'].lower()].append(item)

    album_names = ALBUM_NAMES.copy()
    compilation_names = COMPILATION_NAMES.copy()
    rng.shuffle(album_names)
    rng.shuffle(compilation_names)
    used_names = collections.Counter()

    def take_name(names: list) -> str:
        # -- a big library runs out of names, later ones get a volume number
        base = names.pop() if names else rng.choice(ALBUM_NAMES)
        used_names[base] += 1
        count = used_names[base]
        return base if count == 1 else f'{base} Vol. {count}'

    albums = []
    leftovers = []
    for artist_items in by_artist.values():
        if len(artist_items) == 1:
            single = artist_items[0]
            # -- real libraries are full of singles, named after their only track
            if rng.random() < SINGLES_RATIO:
                albums.append({'name': clean_title(single['title']), 'albumArtist': single['artist'], 'items': artist_items})
            else:
                leftovers.append(single)
            continue
        if len(artist_items) >= MIN_TRACKS_FOR_TWO_ALBUMS:
            first_size = (len(artist_items) * 3 + 4) // 5
            chunks = [artist_items[:first_size], artist_items[first_size:]]
        else:
            chunks = [artist_items[start:start + MAX_ALBUM_TRACKS] for start in range(0, len(artist_items), MAX_ALBUM_TRACKS)]
        for chunk in chunks:
            albums.append({'name': take_name(album_names), 'albumArtist': chunk[0]['artist'], 'items': chunk})

    rng.shuffle(leftovers)
    for start in range(0, len(leftovers), COMPILATION_SIZE):
        chunk = leftovers[start:start + COMPILATION_SIZE]
        names = compilation_names if compilation_names else album_names
        albums.append({'name': take_name(names), 'albumArtist': 'Various Artists', 'items': chunk})

    for album in albums:
        album['genre'] = rng.choice(GENRES)
        album['year'] = rng.randint(2012, 2025)
        album['style'] = rng.choice(STYLES)
        album['label'] = rng.choice(LABELS)
        album['language'] = rng.choice(LANGUAGES)
    return albums


def write_mp4_tags(path: Path, tags: dict):
    audio = MP4(path)
    if audio.tags is None:
        audio.add_tags()
    kept = {k: audio.tags[k] for k in ('covr', '\xa9lyr') if k in audio.tags}
    audio.tags.clear()
    audio.tags.update(kept)
    audio.tags['\xa9nam'] = [tags['title']]
    audio.tags['\xa9ART'] = [tags['artist']]
    audio.tags['aART'] = [tags['albumArtist']]
    audio.tags['\xa9alb'] = [tags['album']]
    audio.tags['\xa9gen'] = [tags['genre']]
    audio.tags['\xa9day'] = [str(tags['year'])]
    audio.tags['\xa9wrt'] = [tags['composer']]
    audio.tags['trkn'] = [(tags['trackNo'], tags['trackTotal'])]
    audio.tags['disk'] = [(1, 1)]
    if tags['comment']:
        audio.tags['\xa9cmt'] = [tags['comment']]
    for key in ('MOOD', 'STYLE', 'LABEL', 'LANGUAGE', 'TAGS', 'RATING'):
        value = tags[key.lower()]
        if not value:
            continue
        audio.tags[f'----:com.apple.iTunes:{key}'] = [MP4FreeForm(value.encode('utf-8'))]
    audio.save()


def write_id3_tags(path: Path, tags: dict):
    try:
        id3 = ID3(path)
    except ID3NoHeaderError:
        id3 = ID3()
    kept = id3.getall('APIC') + id3.getall('USLT')
    id3.clear()
    for frame in kept:
        id3.add(frame)
    track_text = f"{tags['trackNo']}/{tags['trackTotal']}"
    id3.add(TIT2(encoding=3, text=tags['title']))
    id3.add(TPE1(encoding=3, text=tags['artist']))
    id3.add(TPE2(encoding=3, text=tags['albumArtist']))
    id3.add(TALB(encoding=3, text=tags['album']))
    id3.add(TCON(encoding=3, text=tags['genre']))
    id3.add(TDRC(encoding=3, text=str(tags['year'])))
    id3.add(TCOM(encoding=3, text=tags['composer']))
    id3.add(TRCK(encoding=3, text=track_text))
    id3.add(TPOS(encoding=3, text='1/1'))
    id3.add(TMOO(encoding=3, text=tags['mood']))
    id3.add(TPUB(encoding=3, text=tags['label']))
    id3.add(TLAN(encoding=3, text=tags['language']))
    id3.add(TXXX(encoding=3, desc='STYLE', text=tags['style']))
    for key in ('TAGS', 'RATING'):
        value = tags[key.lower()]
        if value:
            id3.add(TXXX(encoding=3, desc=key, text=value))
    if tags['comment']:
        id3.add(COMM(encoding=3, lang='eng', desc='', text=tags['comment']))
    id3.save(path, v2_version=4)


def write_vorbis_tags(path: Path, tags: dict):
    audio = MutagenFile(path)
    kept = {k: audio.tags[k] for k in ('metadata_block_picture', 'lyrics', 'unsyncedlyrics') if k in audio.tags}
    audio.tags.clear()
    audio.tags.update(kept)
    for key in ('title', 'artist', 'album', 'genre', 'composer', 'mood', 'style', 'label', 'language', 'tags', 'rating'):
        if tags[key]:
            audio.tags[key] = [tags[key]]
    audio.tags['albumartist'] = [tags['albumArtist']]
    audio.tags['date'] = [str(tags['year'])]
    audio.tags['tracknumber'] = [str(tags['trackNo'])]
    audio.tags['tracktotal'] = [str(tags['trackTotal'])]
    audio.tags['discnumber'] = ['1']
    if tags['comment']:
        audio.tags['comment'] = [tags['comment']]
    audio.save()


def write_tags(path: Path, tags: dict):
    extension = path.suffix.lower()
    if extension == '.m4a':
        write_mp4_tags(path, tags)
    elif extension == '.mp3':
        write_id3_tags(path, tags)
    else:
        write_vorbis_tags(path, tags)


def copy_whole(source: Path, dest: Path):
    if dest.exists():
        return
    partial = dest.with_name(f'{dest.name}.partial')
    shutil.copy2(source, partial)
    partial.replace(dest)


def collect_video(youtube_id: str, source_videos_dir: Path, videos_dir: Path) -> Path | None:
    # -- a video with a .metadata companion is still downloading
    candidates = source_videos_dir.glob(f'{youtube_id}_*.mp4')
    complete = [v for v in candidates if not v.with_name(f'{v.name}.metadata').exists()]
    if not complete:
        return None
    best = max(complete, key=lambda v: v.stat().st_size)
    dest = videos_dir / best.name
    copy_whole(best, dest)
    return dest


# -- the artists tab shows last.fm photos, runs are offline so only the user's cached ones can show
ARTIST_NAME_SPLIT = re.compile(r'\s*(?:,|&|;|/|\bx\b|\bft\.?|\bfeat\.?|\bvs\.?)\s*', re.IGNORECASE)


def collect_artist_artworks(artists: set, source_dir: Path, dest_dir: Path) -> int:
    if dest_dir.exists():
        shutil.rmtree(dest_dir)
    dest_dir.mkdir(parents=True)
    if not source_dir.exists():
        return 0
    names = {name.lower() for artist in artists for name in [artist, *ARTIST_NAME_SPLIT.split(artist)] if name}
    count = 0
    for artwork in source_dir.glob('*.png'):
        if artwork.stem.lower() in names:
            shutil.copy2(artwork, dest_dir / artwork.name)
            count += 1
    return count


def prune_dir(directory: Path, kept: set):
    for file in directory.rglob('*'):
        if file.is_file() and file not in kept:
            file.unlink()
    for folder in sorted(directory.rglob('*'), reverse=True):
        if folder.is_dir() and not any(folder.iterdir()):
            folder.rmdir()


def parse_drives(values: list | None) -> dict:
    # -- `E:=/mnt/Media`, where a windows drive of the source's paths is mounted on this machine
    drives = {}
    for value in values or []:
        drive, _, root = value.partition('=')
        drives[drive.upper()] = root
    return drives


def to_local_path(track_path: str, drives: dict) -> str:
    match = WINDOWS_DRIVE_REGEX.match(track_path)
    root = drives.get(match.group(1).upper()) if match else None
    if root is None:
        return track_path
    relative = track_path[match.end():].replace('\\', '/')
    return f"{root.rstrip('/')}/{relative}"


def resolve_source_path(track_path: str, android_root: str | None, drives: dict) -> Path | None:
    path = Path(to_local_path(track_path, drives))
    if path.exists():
        return path
    if android_root is None or not ANDROID_STORAGE_REGEX.match(track_path):
        return None
    relative = ANDROID_STORAGE_REGEX.sub('', track_path)
    mapped = Path(android_root) / relative
    return mapped if mapped.exists() else None


def read_playlist_entries(source: Path, name: str) -> dict:
    playlist_path = source / 'Playlists' / f'{name}.json'
    if not playlist_path.exists():
        print(f'playlist not found, skipped: {name}', file=sys.stderr)
        return {'name': name, 'tracks': [], 'creationDate': 0}
    return read_json(playlist_path)


def find_artist_fill(items: list, tracks_db: dict, plays: collections.Counter) -> list:
    artist_counts = collections.Counter(item['artist'].lower() for item in items)
    wanted_artists = {artist for artist, count in artist_counts.items() if count >= MIN_TRACKS_FOR_ARTIST_FILL}
    candidates = collections.defaultdict(list)
    for path, info in tracks_db.items():
        artist_key = (info.get('originalArtist') or '').lower()
        if artist_key not in wanted_artists:
            continue
        file = Path(path)
        duration_ms = info.get('durationMS') or 0
        is_audio = file.suffix.lower() in AUDIO_EXTENSIONS
        is_duration_valid = MIN_DURATION_MS <= duration_ms <= MAX_DURATION_MS
        if not is_audio or not is_duration_valid or not file.exists():
            continue
        candidates[artist_key].append((plays[path], file))
    fill = []
    for artist_key in sorted(candidates):
        most_played_first = sorted(candidates[artist_key], key=lambda c: c[0], reverse=True)
        fill.extend(file for _, file in most_played_first[:ARTIST_FILL_COUNT * 2])
    return fill


def preference_score(item: dict) -> int:
    source_text = str(item['source']).lower()
    score = 0
    if 'nightcore' in source_text:
        score += NIGHTCORE_SCORE
    if 'syrex' in source_text:
        score += SYREX_SCORE
    if item['source'].parent.name in PREFERRED_FOLDERS:
        score += PREFERRED_FOLDER_SCORE
    return score


def take_folder_groups(ranked_items: list, visual_ranks: dict, taken_ids: set, size: int) -> list:
    # -- whole folders in the order their best track ranks, so a page shows a folder's tracks together.
    # -- great visuals are grouped apart, a folder's other tracks only come after every visual one
    groups = {}
    for item in ranked_items:
        if id(item) in taken_ids:
            continue
        is_visual = id(item) in visual_ranks
        groups.setdefault((is_visual, item['source'].parent), []).append(item)
    taken = []
    for group in groups.values():
        taken.extend(group[:size - len(taken)])
        if len(taken) >= size:
            break
    taken_ids.update(id(item) for item in taken)
    return taken


def cmd_music(args):
    work = Path(args.work)
    playlist_path = Path(args.playlist) if args.playlist else work / 'playlist.json'
    playlist = read_json(playlist_path)
    source = Path(args.source)
    drives = parse_drives(args.drive)
    # -- keyed by the source's own paths, a windows source read elsewhere needs them mapped like the playlists
    tracks_db = {to_local_path(key, drives): info for key, info in read_tracks_db(source).items()}
    plays = collections.Counter({to_local_path(key, drives): count for key, count in count_plays(source).items()})
    rng = random.Random(RNG_SEED)

    items = []
    items_by_song_key = {}
    added_per_artist = collections.Counter()

    def add_item(path: Path, fill_artist_limit: int | None = None) -> dict | None:
        info = read_source_info(path, tracks_db)
        song_key = song_key_of(info['artist'], info['title'])
        existing = items_by_song_key.get(song_key)
        if existing is not None:
            return existing
        artist_key = info['artist'].lower()
        if fill_artist_limit is not None and added_per_artist[artist_key] >= fill_artist_limit:
            return None
        added_per_artist[artist_key] += 1
        info['source'] = path
        info['rank'] = len(items)
        items.append(info)
        items_by_song_key[song_key] = info
        return info

    for entry in playlist['tracks']:
        path = resolve_source_path(entry['track'], args.android_root, drives)
        if path is None:
            print(f"missing, skipped: {entry['track']}", file=sys.stderr)
            continue
        add_item(path)

    placement_items = {}
    for key, name in PLACEMENT_PLAYLISTS.items():
        entries = read_playlist_entries(source, name)['tracks']
        paths = (resolve_source_path(entry['track'], args.android_root, drives) for entry in entries)
        placement_items[key] = [add_item(path) for path in paths if path is not None]

    visual_entries = read_playlist_entries(source, VISUALS_PLAYLIST)['tracks']
    visual_paths = (resolve_source_path(entry['track'], args.android_root, drives) for entry in visual_entries)
    visual_ranks = {}
    for path in visual_paths:
        if path is not None:
            visual_ranks.setdefault(id(add_item(path)), len(visual_ranks))
    # -- great visuals first in their own order, then the preferred ones, then the picks' order
    items.sort(key=lambda item: (visual_ranks.get(id(item), len(visual_ranks)), -preference_score(item), item['rank']))
    for rank, item in enumerate(items):
        item['rank'] = rank
    auto_placed_ids = set()
    for key, size in AUTO_PLACEMENT_SIZES.items():
        if not placement_items[key]:
            placement_items[key] = take_folder_groups(items, visual_ranks, auto_placed_ids, size)

    user_playlists = []
    for name in PLAYLISTS_WITH_TRACKS + PLAYLISTS_MAPPED:
        user_playlist = read_playlist_entries(source, name)
        is_bringing_tracks = name in PLAYLISTS_WITH_TRACKS
        playlist_items = []
        for entry in user_playlist['tracks']:
            path = resolve_source_path(entry['track'], args.android_root, drives)
            if path is None:
                continue
            info = read_source_info(path, tracks_db)
            song_key = song_key_of(info['artist'], info['title'])
            item = add_item(path) if is_bringing_tracks else items_by_song_key.get(song_key)
            if item is not None and item not in playlist_items:
                playlist_items.append(item)
        user_playlists.append({'name': name, 'creationDate': user_playlist.get('creationDate', 0), 'items': playlist_items})

    if ARTIST_FILL_COUNT > 0:
        added_per_artist.clear()
        for path in find_artist_fill(items, tracks_db, plays):
            add_item(path, fill_artist_limit=ARTIST_FILL_COUNT)

    albums = plan_albums(items, rng)
    music_dir = Path(args.music_dir).resolve() if args.music_dir else work / 'music'
    videos_dir = work / 'videos'
    videos_dir.mkdir(parents=True, exist_ok=True)
    lyrics_dir = work / 'lyrics'
    lyrics_dir.mkdir(parents=True, exist_ok=True)
    source_videos_dir = source / 'Videos'
    source_lyrics_dir = source / 'Lyrics'
    kept_files = set()
    library = []
    for album in albums:
        album_items = album['items']
        album_dir = music_dir / safe_filename(album['albumArtist']) / safe_filename(album['name'])
        album_dir.mkdir(parents=True, exist_ok=True)
        for index, item in enumerate(album_items):
            track_no = index + 1
            title = clean_title(item['title'])
            source_file = item['source']
            filename = safe_filename(f'{track_no:02d} - {title}')
            dest = album_dir / f'{filename}{source_file.suffix.lower()}'
            # -- copies are retagged below on every run, so an existing one is reused as is
            copy_whole(source_file, dest)
            kept_files.add(dest)
            youtube_id = item['youtubeId']
            video = collect_video(youtube_id, source_videos_dir, videos_dir) if youtube_id else None
            if video is not None:
                kept_files.add(video)
            has_lyrics = title not in LYRICS_EXCLUDED_TITLES
            for lyrics_extension in ('.lrc', '.txt'):
                source_lyrics = source_lyrics_dir / f'{source_file.name}{lyrics_extension}'
                if not has_lyrics or not source_lyrics.exists():
                    continue
                dest_lyrics = lyrics_dir / f'{dest.name}{lyrics_extension}'
                shutil.copy2(source_lyrics, dest_lyrics)
                kept_files.add(dest_lyrics)
            track_tags_count = rng.choice([0, 0, 1, 2])
            track_tags = rng.sample(TRACK_TAGS, track_tags_count)
            rating = rng.choice(RATINGS)
            tags = {
                'title': title,
                'artist': item['artist'],
                'albumArtist': album['albumArtist'],
                'album': album['name'],
                'genre': album['genre'],
                'year': album['year'],
                'composer': item['artist'],
                'trackNo': track_no,
                'trackTotal': len(album_items),
                'mood': rng.choice(MOODS),
                'style': album['style'],
                'label': album['label'],
                'language': album['language'],
                'tags': ';'.join(track_tags),
                'rating': str(rating) if rating else '',
                'comment': f'https://www.youtube.com/watch?v={youtube_id}' if youtube_id else '',
            }
            write_tags(dest, tags)
            audio = MutagenFile(dest)
            duration_ms = int(audio.info.length * 1000)
            relative_path = dest.relative_to(music_dir).as_posix()
            item['relativePath'] = relative_path
            library.append({
                'path': relative_path, 'title': title, 'artist': item['artist'], 'album': album['name'],
                'durationMS': duration_ms, 'rank': item['rank'], 'youtubeId': youtube_id,
            })

    # -- the tracks tab sorts by date modified, newest first
    pinned_paths = [item['relativePath'] for item in placement_items['tracks']]
    ranked_paths = [item['relativePath'] for item in sorted(items, key=lambda item: item['rank'])]
    newest_modified = time.time()
    for index, relative_path in enumerate(dict.fromkeys([*pinned_paths, *ranked_paths])):
        modified = newest_modified - index * TRACK_MODIFIED_GAP_SECONDS
        os.utime(music_dir / relative_path, (modified, modified))

    prune_dir(music_dir, kept_files)
    prune_dir(lyrics_dir, kept_files)
    # -- videos fetched online during runs stay as long as their track does
    youtube_ids = {item['youtubeId'] for item in library if item['youtubeId']}
    for video in videos_dir.glob('*.mp4'):
        video_id = video.name.rsplit('_', 1)[0]
        if video_id not in youtube_ids:
            video.unlink()
    library.sort(key=lambda item: item['rank'])
    artists = {item['artist'] for item in library} | {album['albumArtist'] for album in albums}
    artist_artworks_count = collect_artist_artworks(artists, source / 'Artworks Artists', work / 'artist_artworks')
    playlists = [
        {'name': pl['name'], 'creationDate': pl['creationDate'], 'tracks': [item['relativePath'] for item in pl['items']]}
        for pl in user_playlists
    ]
    placement = {key: list(dict.fromkeys(item['relativePath'] for item in pinned)) for key, pinned in placement_items.items()}
    write_json(work / 'library.json', {'musicDir': str(music_dir), 'tracks': library, 'playlists': playlists, 'placement': placement})
    videos_count = sum(1 for _ in videos_dir.iterdir())
    lyrics_count = sum(1 for _ in lyrics_dir.iterdir())
    print(f'{len(library)} tracks in {len(albums)} albums, {videos_count} cached videos, {lyrics_count} lyrics, {artist_artworks_count} artist photos -> {music_dir}')


def days_since_1970(date: datetime.date) -> int:
    epoch = datetime.date(1970, 1, 1)
    return (date - epoch).days


def to_ms(dt: datetime.datetime) -> int:
    return int(dt.timestamp() * 1000)


def build_weights(count: int, rng: random.Random) -> list:
    # -- zipf-ish over the playlist order, the priority. jitter keeps it from being a straight line
    return [1.0 / (rank + 3) ** 0.9 * rng.uniform(0.6, 1.4) for rank in range(count)]


def generate_history(library: list, paths: list, rng: random.Random) -> dict:
    weights = build_weights(len(library), rng)
    track_indices = range(len(library))
    today = datetime.date.today()
    days = {}
    for day_offset in range(HISTORY_DAYS):
        date = today - datetime.timedelta(days=day_offset)
        is_weekend = date.weekday() >= 5
        if day_offset > 0 and rng.random() < 0.08:
            continue
        sessions_count = rng.randint(1, 3) + (1 if is_weekend else 0)
        entries = []
        for _ in range(sessions_count):
            hour = rng.choice([8, 13, 17, 19, 21, 22, 23])
            session_start = datetime.time(hour, rng.randint(0, 59))
            cursor = datetime.datetime.combine(date, session_start)
            for _ in range(rng.randint(3, 12)):
                index = rng.choices(track_indices, weights=weights)[0]
                entries.append({'dateAdded': to_ms(cursor), 'track': paths[index]})
                duration_ms = library[index]['durationMS']
                cursor += datetime.timedelta(milliseconds=duration_ms + rng.randint(0, 20000))
        # -- today stays in the past, the app would otherwise show listens from the future
        now_ms = int(time.time() * 1000)
        entries = [e for e in entries if e['dateAdded'] < now_ms]
        if not entries:
            continue
        entries.sort(key=lambda e: e['dateAdded'], reverse=True)
        days[days_since_1970(date)] = entries
    return days


def build_playlist(name: str, paths: list, created: datetime.datetime, extra: dict = None, modified: datetime.datetime = None) -> dict:
    created_ms = to_ms(created)
    modified_ms = to_ms(modified) if modified else created_ms + len(paths) * 60000
    playlist = {
        'name': name,
        'tracks': [{'dateAdded': created_ms + i * 60000, 'track': p} for i, p in enumerate(paths)],
        'creationDate': created_ms,
        'modifiedDate': modified_ms,
        'sortsType': [],
        'sortReverse': False,
    }
    if extra:
        playlist.update(extra)
    return playlist


def add_recent_listens(history: dict, recent_paths: list):
    now = datetime.datetime.now()
    today = days_since_1970(now.date())
    entries = history.setdefault(today, [])
    for index, path in enumerate(recent_paths):
        listened_at = now - datetime.timedelta(minutes=(index + 1) * RECENT_LISTENS_GAP_MINUTES)
        entries.append({'dateAdded': to_ms(listened_at), 'track': path})
    entries.sort(key=lambda e: e['dateAdded'], reverse=True)


def lift_most_played(history: dict, pinned_paths: list, rng: random.Random):
    # -- the recent range first, its extra listens count for all time too. all time ones go before that range
    today = days_since_1970(datetime.date.today())
    recent_first_day = today - MOST_PLAYED_RECENT_DAYS
    pinned = set(pinned_paths)
    past_days = [day for day in history if day < today]
    for is_recent in (True, False):
        window_days = [day for day in history if day >= recent_first_day] if is_recent else list(history)
        extra_days = [day for day in past_days if (day >= recent_first_day) == is_recent]
        if not extra_days:
            continue
        counts = collections.Counter(e['track'] for day in window_days for e in history[day])
        target = max((count for path, count in counts.items() if path not in pinned), default=0)
        for path in reversed(pinned_paths):
            target = max(counts[path], target + MOST_PLAYED_STEP)
            for day in rng.choices(extra_days, k=target - counts[path]):
                day_start = datetime.datetime.combine(datetime.date(1970, 1, 1) + datetime.timedelta(days=day), datetime.time(8))
                listened_at = day_start + datetime.timedelta(seconds=rng.randint(0, 15 * 3600))
                history[day].append({'dateAdded': to_ms(listened_at), 'track': path})
    for entries in history.values():
        entries.sort(key=lambda e: e['dateAdded'], reverse=True)


def add_missing_listens(history: dict, music_dir: str, separator: str, rng: random.Random):
    days = sorted(history.keys())
    for relative_path in MISSING_TRACKS:
        missing_path = music_dir + separator + relative_path.replace('/', separator)
        for day in rng.sample(days, 3):
            entries = history[day]
            listen_ms = entries[-1]['dateAdded'] - rng.randint(60000, 600000)
            entries.append({'dateAdded': listen_ms, 'track': missing_path})


def read_youtube_listens_per_day(data_dir: Path) -> dict:
    # -- the kept youtube session is copied in before this runs
    history_dir = data_dir / 'Youtube' / 'Youtube History'
    if not history_dir.exists():
        return {}
    return {int(f.stem): len(read_json(f)) for f in history_dir.glob('*.json') if f.stem.isdigit()}


def write_listen_time(data_dir: Path, history: dict, durations_by_path: dict):
    db_path = data_dir / 'listen_time_daily.db'
    if db_path.exists():
        db_path.unlink()
    connection = sqlite3.connect(db_path)
    connection.execute('CREATE TABLE `listen_time_daily` (key TEXT NOT NULL UNIQUE, value TEXT, PRIMARY KEY (key))')
    youtube_listens = read_youtube_listens_per_day(data_dir)
    totals = {'tr': 0, 'yt': 0}
    for day in sorted(history.keys() | youtube_listens.keys()):
        day_ms = sum(durations_by_path.get(e['track'], 0) for e in history.get(day, []))
        # -- listens are rarely played to the very end
        day_totals = {'tr': int(day_ms * LISTENED_RATIO / 1000), 'yt': youtube_listens.get(day, 0) * YOUTUBE_LISTEN_SECONDS}
        value = {key: seconds for key, seconds in day_totals.items() if seconds > 0}
        for key, seconds in value.items():
            totals[key] += seconds
        connection.execute('INSERT INTO listen_time_daily (key, value) VALUES (?, ?)', (str(day), json.dumps(value)))
    connection.commit()
    connection.close()
    write_json(data_dir / 'total_listen.txt', {key: seconds for key, seconds in totals.items() if seconds > 0})


def write_smart_playlists(db_path: Path, now: datetime.datetime):
    if db_path.exists():
        db_path.unlink()
    connection = sqlite3.connect(db_path)
    connection.execute('CREATE TABLE `smart_playlists` (key TEXT NOT NULL UNIQUE, value TEXT, PRIMARY KEY (key))')
    for index, (name, rules) in enumerate(SMART_PLAYLISTS):
        created = now - datetime.timedelta(days=30 + index * 7)
        smart_playlist = {
            'name': name,
            'creationDate': to_ms(created),
            'joiner': 'and',
            'sorts': [],
            'sortReverse': False,
            'moods': [],
            'ruleGroups': [{'joiner': 'and', 'rules': rules}],
        }
        value = json.dumps(smart_playlist, ensure_ascii=False)
        connection.execute('INSERT INTO smart_playlists (key, value) VALUES (?, ?)', (name, value))
    connection.commit()
    connection.close()


def link_or_copy(source: Path, dest: Path):
    try:
        os.link(source, dest)
    except OSError:
        shutil.copy2(source, dest)


def cmd_data(args):
    work = Path(args.work)
    data_dir = Path(args.data_dir)
    music_dir = args.music_dir.rstrip('/\\')
    separator = '\\' if '\\' in music_dir or re.match(r'^[A-Za-z]:', music_dir) else '/'
    library_json = read_json(work / 'library.json')
    library = library_json['tracks']

    def to_app_path(relative_path: str) -> str:
        return music_dir + separator + relative_path.replace('/', separator)

    paths = [to_app_path(item['path']) for item in library]
    placement = {key: [to_app_path(relative_path) for relative_path in pinned] for key, pinned in library_json.get('placement', {}).items()}
    rng = random.Random(RNG_SEED)
    now = datetime.datetime.now()

    write_json(data_dir / 'namida_settings.json', {
        '_v': 2,
        'language': {'code': 'en', 'name': 'English', 'country': 'United States'},
        'themeMode': 'light',
        'directoriesToScan': [{'source': music_dir}],
        'libraryTabs': LIBRARY_TABS,
        'forceSquaredTrackThumbnail': True,
        'forceSquaredAlbumThumbnail': True,
        'trackThumbnailSizeinList': 65.0,
        'trackListTileHeight': 65.0,
        'borderRadiusMultiplier': 0.9,
        'fontScaleFactor': 0.85,
        'mostPlayedTimeRange': 'allTime',
        'youtubeVideoQualities': ['4k', '2k', '1080p', '720p', '480p', '360p'],
        'effectsBackground': 'none',
        # -- the 2023 readme's sorting, newest first
        'mediaItemsTrackSorting_v2': {'track': {'sorts': ['dateModified'], 'reverse': True}},
        'mediaGroupSorting': {'playlist': {'sorts': ['modifiedDate'], 'reverse': True}},
    })
    write_json(data_dir / 'namida_settings_player.json', {'_v': 2, 'volume': 0.0, 'pauseOnVolume0': False, 'killAfterDismissingApp': 'always'})
    # -- flat bands, enabled only so the sound control shots aren't dimmed
    write_json(data_dir / 'namida_settings_eq.json', {'_v': 2, 'equalizerEnabled': True})
    write_json(data_dir / 'namida_settings_tutorial.json', {'_v': 2, 'llpfsSeen': True, 'snackDismissHints': 3})
    # -- a decided invasion never prompts
    write_json(data_dir / 'namida_settings_extra.json', {'_v': 2, 'jellysInvasion': False})

    for work_subdir, data_subdir in (('videos', 'Videos'), ('lyrics', 'Lyrics'), ('artist_artworks', 'Artworks Artists')):
        target_dir = data_dir / data_subdir
        target_dir.mkdir(parents=True, exist_ok=True)
        source_dir = work / work_subdir
        if not source_dir.exists():
            continue
        for file in source_dir.iterdir():
            dest = target_dir / file.name
            if not dest.exists():
                link_or_copy(file, dest)

    history_dir = data_dir / 'History'
    if history_dir.exists():
        shutil.rmtree(history_dir)
    history = generate_history(library, paths, rng)
    add_missing_listens(history, music_dir, separator, rng)
    lift_most_played(history, placement.get('mostPlayed', []), rng)
    path_by_title = {item['title']: path for item, path in zip(library, paths)}
    default_recent_paths = [path_by_title[title] for title in RECENT_LISTENS_TITLES if title in path_by_title]
    recent_paths = placement.get('recentListens') or default_recent_paths
    # -- collection_1 taps the main player track in home's recent listens
    main_player_path = next(iter(placement.get('player', [])), None)
    if main_player_path is not None and main_player_path not in recent_paths:
        recent_paths = [main_player_path, *recent_paths]
    add_recent_listens(history, recent_paths)
    for day, entries in history.items():
        write_json(history_dir / f'{day}.json', entries)
    durations_by_path = {path: item['durationMS'] for path, item in zip(paths, library)}
    write_listen_time(data_dir, history, durations_by_path)

    play_counts = collections.Counter(e['track'] for entries in history.values() for e in entries)
    pinned_favourites = placement.get('favourites', [])
    top_paths = [p for p, _ in play_counts.most_common()]
    favourite_paths = list(dict.fromkeys([*pinned_favourites, *top_paths]))[:max(FAVOURITES_COUNT, len(pinned_favourites))]
    favourites_created = now - datetime.timedelta(days=300)
    write_json(data_dir / 'favs.json', build_playlist('_FAVOURITES_', favourite_paths, favourites_created, {'isFav': True}))

    playlists_dir = data_dir / 'Playlists'
    if playlists_dir.exists():
        shutil.rmtree(playlists_dir)
    playlists = library_json['playlists']
    for index, pl in enumerate(playlists):
        name = pl['name']
        playlist_paths = [to_app_path(relative_path) for relative_path in pl['tracks']]
        modified = now - datetime.timedelta(days=PLAYLIST_AGES_DAYS[index % len(PLAYLIST_AGES_DAYS)], hours=index)
        created_fallback = modified - datetime.timedelta(days=30)
        created = datetime.datetime.fromtimestamp(pl['creationDate'] / 1000) if pl['creationDate'] else created_fallback
        playlist_extra = {'tags': PLAYLIST_TAGS.get(name, [])}
        playlist = build_playlist(name, playlist_paths, min(created, modified), playlist_extra, modified)
        safe_name = safe_filename(name) or f'playlist {index + 1}'
        write_json(playlists_dir / f'{safe_name}.json', playlist)
    write_json(data_dir / 'Playlists Metadata' / 'tags.json', {'colors': PLAYLIST_TAG_COLORS})
    write_smart_playlists(data_dir / 'smart_playlists.db', now)

    listens_count = sum(len(entries) for entries in history.values())
    print(f'{listens_count} listens over {len(history)} days, {len(playlists)} playlists -> {data_dir}')


def main():
    parser = argparse.ArgumentParser(description='seeds the screenshots library')
    parser.add_argument('--work', default=str(DEFAULT_WORK))
    commands = parser.add_subparsers(dest='command', required=True)

    pick = commands.add_parser('pick')
    pick.add_argument('--source', default=str(DEFAULT_SOURCE))
    pick.add_argument('--count', type=int, default=150)

    music = commands.add_parser('music')
    music.add_argument('--playlist')
    music.add_argument('--source', default=str(DEFAULT_SOURCE))
    music.add_argument('--music-dir')
    music.add_argument('--android-root', help='where an android sd card path (/storage/XXXX-XXXX/...) lives on this machine')
    music.add_argument('--drive', action='append', help='X:=<dir>, where a windows drive of the source lives on this machine (repeatable)')

    data = commands.add_parser('data')
    data.add_argument('--data-dir', required=True)
    data.add_argument('--music-dir', required=True)

    args = parser.parse_args()
    handlers = {'pick': cmd_pick, 'music': cmd_music, 'data': cmd_data}
    handlers[args.command](args)


if __name__ == '__main__':
    main()
