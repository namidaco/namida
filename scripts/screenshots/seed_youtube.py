"""Curates the youtube side of the screenshots: nightcore only, from the user's real caches.

usage: python scripts/screenshots/seed_youtube.py [--work build/screenshots] [--source ~/.namida]

edits the interactive session's youtube data kept in work/windows/keep (sign in with `shoot.py --interactive` first),
so every later run restores it. the account caches (feed, history, notifications, playlists, video pages) get the
real account's nightcore items, the local youtube history, likes, playlists and stats are filtered copies, and the
thumbnails of everything kept are copied along. pages read all of it from cache with the `offline` scene step.

by claude
"""

import argparse
import collections
import datetime
import json
import re
import shutil
import sqlite3
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
DEFAULT_WORK = ROOT / 'build' / 'screenshots'
DEFAULT_SOURCE = Path.home() / '.namida'

KEYWORD = 'nightcore'
FEED_SIZE = 45
FEED_MAX_PER_CHANNEL = 5
LOCAL_HISTORY_DAYS = 150
LOCAL_PLAYLISTS = ['[Nightcore]', 'Nightcore', 'Cute Songs ❤️', '🌺 Favourites 🌺']
LIKES_LIMIT = 250
ACCOUNT_PLAYLIST_TITLES = {'[Nightcore]', 'Nightcore Gaming Playlist 2026'}
KEPT_ACCOUNT_PLAYLIST_IDS = {'WL', 'LL'}
DOWNLOADS_GROUP = 'Nightcore'
DOWNLOADS_FINISHED = 12
DOWNLOADS_UNFINISHED = 3
DOWNLOAD_TEMPLATE_GROUP = 'deep'
DOWNLOAD_BYTES_PER_SECOND = 16000
CHANNELS_ALL_VIDEOS_SIZE = 60
CHANNELS_ALL_VIDEOS_MAX_PER_CHANNEL = 8
INVALID_FILENAME_REGEX = re.compile(r'[<>:"/\\|?*]')


def is_nightcore(text) -> bool:
    return isinstance(text, str) and KEYWORD in text.lower()


def checkpoint(db_path: Path):
    connection = sqlite3.connect(db_path)
    connection.execute('PRAGMA wal_checkpoint(TRUNCATE)')
    connection.close()


def read_all(db_path: Path) -> dict:
    if not db_path.exists():
        return {}
    uri = f'file:{db_path.as_posix()}?mode=ro'
    connection = sqlite3.connect(uri, uri=True)
    table = db_path.stem
    rows = connection.execute(f'SELECT key, value FROM `{table}`').fetchall()
    connection.close()
    return {key: json.loads(value) for key, value in rows if value}


def put_all(db_path: Path, values: dict):
    # -- namico_db_wrapper names the table after the db file, account suffix included
    table = db_path.stem
    connection = sqlite3.connect(db_path)
    connection.execute(f'CREATE TABLE IF NOT EXISTS `{table}` (key TEXT NOT NULL UNIQUE, value TEXT, PRIMARY KEY (key))')
    for key, value in values.items():
        text = json.dumps(value, ensure_ascii=False)
        connection.execute(f'INSERT INTO `{table}` (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value', (key, text))
    connection.commit()
    connection.close()


def account_suffixes(youtipie_dir: Path) -> list:
    return [db.stem.split('_', 1)[1] for db in youtipie_dir.glob('feed_*.db')]


def biggest_account(youtipie_dir: Path) -> str:
    feeds = sorted(youtipie_dir.glob('history_*.db'), key=lambda db: db.stat().st_size, reverse=True)
    return feeds[0].stem.split('_', 1)[1]


def read_json(path: Path):
    return json.loads(path.read_text(encoding='utf-8'))


def write_json(path: Path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False), encoding='utf-8')


class _Thumbnails:
    def __init__(self, source_youtube: Path, target_youtube: Path):
        self.source_videos = source_youtube / 'YTThumbnails'
        self.target_videos = target_youtube / 'YTThumbnails'
        self.source_channels = source_youtube / 'YTThumbnails Channels'
        self.target_channels = target_youtube / 'YTThumbnails Channels'
        self.copied = 0

    def has_video(self, video_id: str) -> bool:
        return (self.source_videos / f'{video_id}.png').exists() or (self.source_videos / 'temp' / f'{video_id}.png').exists()

    def copy_video(self, video_id: str):
        for relative in (f'{video_id}.png', f'temp/{video_id}.png', f'EXT_{video_id}.png'):
            self._copy(self.source_videos / relative, self.target_videos / relative)

    def copy_url(self, url: str):
        name = url.rstrip('/').rsplit('/', 1)[-1].split('?')[0]
        self._copy(self.source_channels / f'{name}.png', self.target_channels / f'{name}.png')

    def copy_playlist_cover(self, video_id: str):
        name = f'{video_id}_hqdefault.jpg'
        self._copy(self.source_channels / name, self.target_channels / name)

    def _copy(self, source: Path, dest: Path):
        if not source.exists() or dest.exists():
            return
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, dest)
        self.copied += 1


def collect_urls(value, urls: set):
    if isinstance(value, dict):
        for key, inner in value.items():
            if key == 'url' and isinstance(inner, str) and ('ggpht' in inner or 'googleusercontent' in inner):
                urls.add(inner)
            else:
                collect_urls(inner, urls)
    elif isinstance(value, list):
        for inner in value:
            collect_urls(inner, urls)


def pick_feed_items(existing_items: list, candidates: list) -> list:
    picked = [item for item in existing_items if is_nightcore(item.get('title')) or item.get('isMix')]
    picked_ids = {item.get('id') for item in picked}
    per_channel = collections.Counter((item.get('channel') or {}).get('id') for item in picked)
    newest_first = sorted(candidates, key=lambda item: (item.get('publishedAt') or {}).get('date') or 0, reverse=True)
    for item in newest_first:
        if len(picked) >= FEED_SIZE:
            break
        channel_id = (item.get('channel') or {}).get('id')
        if item['id'] in picked_ids or per_channel[channel_id] >= FEED_MAX_PER_CHANNEL:
            continue
        per_channel[channel_id] += 1
        picked_ids.add(item['id'])
        picked.append(item)
    return picked


def pick_channels_all_videos(candidates: list, channel_ids: set) -> list:
    newest_first = sorted(candidates, key=lambda item: (item.get('publishedAt') or {}).get('date') or 0, reverse=True)
    per_channel = collections.Counter()
    picked = []
    for item in newest_first:
        channel_id = (item.get('channel') or {}).get('id')
        if channel_id not in channel_ids or per_channel[channel_id] >= CHANNELS_ALL_VIDEOS_MAX_PER_CHANNEL:
            continue
        per_channel[channel_id] += 1
        picked.append(item)
        if len(picked) >= CHANNELS_ALL_VIDEOS_SIZE:
            break
    return picked


def write_downloads(source_youtube: Path, keep_youtube: Path, candidates: list, kept_ids: set):
    # -- a task shows as finished when its file exists, an empty one is enough
    template_db = source_youtube / 'Download Tasks' / f'{DOWNLOAD_TEMPLATE_GROUP}.db'
    template_rows = read_all(template_db)
    if not template_rows:
        return
    template = next(iter(template_rows.values()))
    tasks_db = keep_youtube / 'Download Tasks' / f'{DOWNLOADS_GROUP}.db'
    if tasks_db.exists():
        tasks_db.unlink()
    tasks_db.parent.mkdir(parents=True, exist_ok=True)
    downloads_dir = keep_youtube.parent / 'Namida' / 'Downloads' / DOWNLOADS_GROUP
    if downloads_dir.exists():
        shutil.rmtree(downloads_dir)
    downloads_dir.mkdir(parents=True)
    total = DOWNLOADS_FINISHED + DOWNLOADS_UNFINISHED
    picked = sorted(candidates, key=lambda item: (item.get('publishedAt') or {}).get('date') or 0, reverse=True)[:total]
    now_us = int(datetime.datetime.now().timestamp() * 1000000)
    rows = {}
    for index, item in enumerate(picked):
        title = item.get('title') or item['id']
        channel_title = (item.get('channel') or {}).get('title') or ''
        raw_filename = f'[{index + 1:02d}] {title} [({channel_title})].m4a'
        filename = INVALID_FILENAME_REGEX.sub('_', raw_filename)
        key = str(zlib.crc32(item['id'].encode('utf-8')))
        tags = {**(template.get('ffmpegTags') or {}), 'title': title, 'artist': channel_title, 'album': DOWNLOADS_GROUP,
                'comment': f"https://www.youtube.com/watch?v={item['id']}", 'track': f'{index + 1:02d}', 'TRACKTOTAL': str(total), 'description': ''}
        rows[key] = {
            **template, 'id': item['id'], 'groupName': DOWNLOADS_GROUP, 'filename': {'filename': filename, 'key': key},
            'ffmpegTags': tags, 'streamInfoItem': item, 'index': index, 'totalLength': total, 'playlistId': None,
            'playlistInfo': None, 'addedAt': now_us - index * 60000000, 'splitByChapters': False, 'localPlaylistName': None,
        }
        kept_ids.add(item['id'])
        if index < DOWNLOADS_FINISHED:
            # -- the card reads the size from disk
            with open(downloads_dir / filename, 'wb') as placeholder:
                placeholder.truncate((item.get('durSeconds') or 180) * DOWNLOAD_BYTES_PER_SECOND)
    connection = sqlite3.connect(tasks_db)
    connection.execute(f'CREATE TABLE `{DOWNLOADS_GROUP}` (key TEXT NOT NULL UNIQUE, value TEXT, PRIMARY KEY (key))')
    for key, value in rows.items():
        connection.execute(f'INSERT INTO `{DOWNLOADS_GROUP}` (key, value) VALUES (?, ?)', (key, json.dumps(value, ensure_ascii=False)))
    connection.commit()
    connection.close()


def main():
    parser = argparse.ArgumentParser(description='curates the youtube screenshots data')
    parser.add_argument('--work', default=str(DEFAULT_WORK))
    parser.add_argument('--source', default=str(DEFAULT_SOURCE))
    args = parser.parse_args()

    keep_youtube = Path(args.work) / 'windows' / 'keep' / 'Youtube'
    source_youtube = Path(args.source) / 'Youtube'
    keep_youtipie = keep_youtube / 'Youtipie'
    source_youtipie = source_youtube / 'Youtipie'
    if not keep_youtipie.exists():
        raise SystemExit(f'no kept youtube session in {keep_youtipie}, run shoot.py --interactive and sign in first')

    for db in keep_youtipie.glob('*.db'):
        checkpoint(db)
    accounts = account_suffixes(keep_youtipie)
    real_account = biggest_account(source_youtipie)
    thumbnails = _Thumbnails(source_youtube, keep_youtube)
    print(f'accounts {accounts}, source account {real_account}')

    real_items = read_all(source_youtipie / f'streamInfoItem_{real_account}.db')
    candidates = [item for item in real_items.values() if is_nightcore(item.get('title')) and thumbnails.has_video(item.get('id', ''))]

    real_history = read_all(source_youtipie / f'history_{real_account}.db').get('history')
    real_notifications = read_all(source_youtipie / f'notification_{real_account}.db').get('notification')
    real_user_playlists = read_all(source_youtipie / f'userPlaylists_{real_account}.db').get('userPlaylists')
    real_playlists = read_all(source_youtipie / f'playlist_{real_account}.db')
    real_video_pages = read_all(source_youtipie / f'videoPage_{real_account}.db')

    kept_ids = set()
    kept_urls = set()
    for account in accounts:
        feed_db = keep_youtipie / f'feed_{account}.db'
        feed = read_all(feed_db).get('feed') or {'cacheKey': 'feed', 'items': []}
        feed['items'] = pick_feed_items(feed.get('items') or [], candidates)
        feed['continuation'] = None
        put_all(feed_db, {'feed': feed})
        kept_ids.update(item.get('id') for item in feed['items'])
        collect_urls(feed, kept_urls)

        if real_history:
            history = dict(real_history)
            chunks = []
            for chunk in history.get('items') or []:
                chunk_items = [item for item in chunk.get('items') or [] if is_nightcore(item.get('title'))]
                if chunk_items:
                    chunks.append({**chunk, 'items': chunk_items})
                    kept_ids.update(item.get('id') for item in chunk_items)
            history['items'] = chunks
            history['continuation'] = None
            put_all(keep_youtipie / f'history_{account}.db', {'history': history})
            collect_urls(history, kept_urls)

        if real_notifications:
            notifications = dict(real_notifications)
            notifications['items'] = [item for item in notifications.get('items') or [] if is_nightcore(item.get('shortText'))]
            notifications['continuation'] = None
            put_all(keep_youtipie / f'notification_{account}.db', {'notification': notifications})
            kept_ids.update(item.get('id') for item in notifications['items'])
            collect_urls(notifications, kept_urls)

        if real_user_playlists:
            existing = read_all(keep_youtipie / f'userPlaylists_{account}.db').get('userPlaylists') or {}
            existing_items = [item for item in existing.get('items') or [] if item.get('id') in KEPT_ACCOUNT_PLAYLIST_IDS]
            nightcore_items = [item for item in real_user_playlists.get('items') or [] if item.get('title') in ACCOUNT_PLAYLIST_TITLES or is_nightcore(item.get('title'))]
            user_playlists = {**real_user_playlists, 'items': existing_items + nightcore_items, 'continuation': None}
            put_all(keep_youtipie / f'userPlaylists_{account}.db', {'userPlaylists': user_playlists})
            playlist_rows = {item['id']: real_playlists[item['id']] for item in nightcore_items if item.get('id') in real_playlists}
            put_all(keep_youtipie / f'playlist_{account}.db', playlist_rows)
            collect_urls(user_playlists, kept_urls)
            for row in playlist_rows.values():
                collect_urls(row, kept_urls)
                for video in row.get('items') or []:
                    kept_ids.add(video.get('id'))

        video_pages = {}
        for video_id, page in real_video_pages.items():
            info_title = ((page.get('videoInfo') or {}).get('title'))
            if not is_nightcore(info_title):
                continue
            related = page.get('relatedVideosResult') or {}
            related_items = [item for item in related.get('items') or [] if is_nightcore(item.get('title'))]
            video_pages[video_id] = {**page, 'relatedVideosResult': {**related, 'items': related_items, 'continuation': None}}
            kept_ids.add(video_id)
            kept_ids.update(item.get('id') for item in related_items)
            collect_urls(page, kept_urls)
        put_all(keep_youtipie / f'videoPage_{account}.db', video_pages)

    # -- subscriptions and channel pages, only channels the kept videos come from
    kept_channel_ids = {(item.get('channel') or {}).get('id') for item in real_items.values() if item.get('id') in kept_ids}
    kept_channel_ids.discard(None)
    real_user_channels = read_all(source_youtipie / f'userChannels_{real_account}.db').get('userChannels')
    real_channels = read_all(source_youtipie / f'channel_{real_account}.db')
    real_channel_tabs = read_all(source_youtipie / f'channelTab_{real_account}.db')
    channel_rows = {key: value for key, value in real_channels.items() if key in kept_channel_ids}
    # -- channel ids can hold '_', the tab name never does
    channel_tab_rows = {key: value for key, value in real_channel_tabs.items() if key.rsplit('_', 1)[0] in kept_channel_ids}
    channel_items = [item for item in (real_user_channels or {}).get('items') or [] if item.get('id') in kept_channel_ids]
    all_videos = pick_channels_all_videos(candidates, {item['id'] for item in channel_items})
    kept_ids.update(item['id'] for item in all_videos)
    for account in accounts:
        if real_user_channels:
            user_channels = {**real_user_channels, 'items': channel_items, 'continuation': None}
            put_all(keep_youtipie / f'userChannels_{account}.db', {'userChannels': user_channels})
            collect_urls(user_channels, kept_urls)
        all_videos_db = keep_youtipie / f'userChannelsAllVideos_{account}.db'
        all_videos_result = read_all(all_videos_db).get('userChannelsAllVideos') or {'cacheKey': 'userChannelsAllVideos'}
        put_all(all_videos_db, {'userChannelsAllVideos': {**all_videos_result, 'items': all_videos, 'continuation': None}})
        put_all(keep_youtipie / f'channel_{account}.db', channel_rows)
        put_all(keep_youtipie / f'channelTab_{account}.db', channel_tab_rows)
    for row in [*channel_rows.values(), *channel_tab_rows.values()]:
        collect_urls(row, kept_urls)

    write_downloads(source_youtube, keep_youtube, candidates, kept_ids)

    # -- local youtube data, shifted so the newest day is yesterday
    stats_entries = []
    for stats_file in (source_youtube / 'Youtube Stats').glob('*.json'):
        stats_entries.extend(entry for entry in read_json(stats_file) if is_nightcore(entry.get('title')))
    titles = {entry['id']: entry['title'] for entry in stats_entries}
    nightcore_ids = set(titles)

    history_dir = keep_youtube / 'Youtube History'
    if history_dir.exists():
        shutil.rmtree(history_dir)
    source_days = sorted((int(f.stem), f) for f in (source_youtube / 'Youtube History').glob('*.json') if f.stem.isdigit())
    days_with_nightcore = []
    for day, day_file in reversed(source_days):
        entries = [e for e in read_json(day_file) if e.get('id') in nightcore_ids]
        if entries:
            days_with_nightcore.append((day, entries))
        if len(days_with_nightcore) >= LOCAL_HISTORY_DAYS:
            break
    yesterday = (datetime.date.today() - datetime.date(1970, 1, 1)).days - 1
    if days_with_nightcore:
        shift_days = yesterday - days_with_nightcore[0][0]
        shift_ms = shift_days * 86400000
        for day, entries in days_with_nightcore:
            shifted = [{**e, 'watch': {**e['watch'], 'date': e['watch']['date'] + shift_ms}} for e in entries]
            write_json(history_dir / f'{day + shift_days}.json', shifted)
            kept_ids.update(e['id'] for e in entries)

    write_json(keep_youtube / 'Youtube Stats' / 'nightcore.json', stats_entries)

    playlists_dir = keep_youtube / 'Youtube Playlists'
    for name in LOCAL_PLAYLISTS:
        source_playlist = source_youtube / 'Youtube Playlists' / f'{name}.json'
        if not source_playlist.exists():
            continue
        playlist = read_json(source_playlist)
        playlist['tracks'] = [t for t in playlist['tracks'] if t.get('id') in nightcore_ids]
        write_json(playlists_dir / f'{name}.json', playlist)
        kept_ids.update(t['id'] for t in playlist['tracks'])
    likes_path = source_youtube / 'yt_likes.json'
    if likes_path.exists():
        likes = read_json(likes_path)
        likes['tracks'] = [t for t in likes['tracks'] if t.get('id') in nightcore_ids][:LIKES_LIMIT]
        write_json(keep_youtube / 'yt_likes.json', likes)
        kept_ids.update(t['id'] for t in likes['tracks'])

    kept_ids.discard(None)
    item_rows = {video_id: real_items[video_id] for video_id in kept_ids if video_id in real_items}
    for account in accounts:
        put_all(keep_youtipie / f'streamInfoItem_{account}.db', item_rows)
    for item in item_rows.values():
        collect_urls(item, kept_urls)
    for video_id in kept_ids:
        thumbnails.copy_video(video_id)
        thumbnails.copy_playlist_cover(video_id)
    for url in kept_urls:
        thumbnails.copy_url(url)
    print(f'{len(kept_ids)} videos kept, {len(item_rows)} item rows, {len(days_with_nightcore)} history days, {thumbnails.copied} thumbnails copied')


if __name__ == '__main__':
    main()
