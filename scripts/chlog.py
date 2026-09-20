#!/usr/bin/env python3
"""namida changelog tooling.

subcommands:
  beta      -> beta_changelog.md (github release body)
  stable    -> CHANGELOG.md + docs_internal/stable_commits.md + docs_internal/telegram.md
  template  -> commit message template (prepare-commit-msg hook)
  check     -> validate a commit message file (commit-msg hook)
"""

import argparse
import io
import json
import os
import re
import subprocess
import sys
import urllib.request
from dataclasses import dataclass, field
from datetime import datetime, timezone

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

CHANGELOG_PREFIXES = ("feat", "core", "perf", "chore", "fix")
OTHER_PREFIXES = ("code", "build", "github", "docs", "test")
ALL_PREFIXES = CHANGELOG_PREFIXES + OTHER_PREFIXES
PLATFORMS = ("android", "desktop", "linux", "windows", "macos", "ios")
SECTIONS = ("core", "perf", "chore", "fix")
DEFAULT_SCORES = {"feat": 3, "core": 2, "perf": 2, "chore": 2, "fix": 2}
TRAILER_KEYS = ("topic", "score", "closes", "ref", "amends", "changelog")
SUBJECT_MAX = 72
VARIOUS_TEXT = "various fixes and tweaks"

H_HIGHLIGHTS = "### ✨ Highlights:"
H_FEATURES = "### \U0001f389 New Features:"
H_FIXES = "### \U0001f6e0️ Bug fixes & Improvements:"
TITLE = "# Namida Changelog"

MAIN_REPO = "namidaco/namida"
SNAPSHOTS_REPO = "namidaco/namida-snapshots"
COMMIT_URL = "https://github.com/%s/commit/" % MAIN_REPO

REC = "\x1e"
UNIT = "\x1f"

SUBJECT_RE = re.compile(r"^(?P<prefix>[a-z]+)(?:\((?P<platform>[a-z]+)\))?:\s*(?P<text>.+)$")
TRAILER_RE = re.compile(r"^([a-z][a-z0-9-]*):[ \t]*(.*)$")
TOPIC_RE = re.compile(r"^[a-z0-9][a-z0-9-]*$")
ISSUE_RE = re.compile(r"(?:[\w.-]+/[\w.-]+)?#\d+|https?://\S+")
ISSUE_TAIL_RE = re.compile(
    r"[\s,.-]*\b(?:closes?d?|fix(?:e[sd])?|resolves?d?|refs?)\b\s*:?\s*"
    r"((?:(?:[\w.-]+/[\w.-]+)?#\d+|https?://\S+)(?:\s*,?\s*(?:(?:[\w.-]+/[\w.-]+)?#\d+|https?://\S+))*)",
    re.IGNORECASE,
)
ENTRY_RE = re.compile(r"^(?P<indent>\s*)- (?P<hashes>[0-9a-f]{7,40}(?:,\s*[0-9a-f]{7,40})*): (?P<text>.*)$")
ISSUE_URL_RE = re.compile(r"https?://github\.com/([\w.-]+/[\w.-]+)/issues/(\d+)")


def git(*args, check=True):
    p = subprocess.run(
        ["git", *args],
        capture_output=True,
        encoding="utf-8",
        errors="replace",
    )
    if check and p.returncode != 0:
        raise SystemExit("git %s failed:\n%s" % (" ".join(args), p.stderr.strip()))
    return p.stdout


def repo_root():
    return git("rev-parse", "--show-toplevel").strip()


def pubspec_version(root):
    with open(os.path.join(root, "pubspec.yaml"), encoding="utf-8") as f:
        for line in f:
            if line.startswith("version: "):
                return "v" + line.split("version: ", 1)[1].strip().split("+")[0]
    return "v0.0.0"


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def write(path, text):
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def norm_issue(raw):
    """`https://github.com/o/r/issues/5` -> `o/r#5`, bare `#5` -> `namidaco/namida#5`."""
    raw = raw.strip().rstrip(",.")
    m = ISSUE_URL_RE.match(raw)
    if m:
        return "%s#%s" % (m.group(1), m.group(2))
    if raw.startswith("#"):
        return MAIN_REPO + raw
    return raw


def short_issue(raw):
    """render `namidaco/namida#5` as `#5`, keep other repos explicit."""
    return raw[len(MAIN_REPO):] if raw.startswith(MAIN_REPO + "#") else raw


def issue_key(raw):
    repo, _, number = raw.rpartition("#")
    return (repo != MAIN_REPO, repo, int(number) if number.isdigit() else 0)


@dataclass
class Commit:
    hash: str
    short: str
    prefix: str
    platform: str = None
    text: str = ""
    bullets: list = field(default_factory=list)
    topic: str = None
    score: int = None
    closes: list = field(default_factory=list)
    refs: list = field(default_factory=list)
    amends: list = field(default_factory=list)
    override: str = None

    @property
    def effective_score(self):
        return DEFAULT_SCORES.get(self.prefix, 2) if self.score is None else self.score


def split_trailers(lines):
    """last paragraph of `key: value` lines, as long as one key is a known trailer."""
    lines = list(lines)
    while lines and not lines[-1].strip():
        lines.pop()
    i = len(lines)
    while i > 0 and TRAILER_RE.match(lines[i - 1].strip()):
        i -= 1
    if i == len(lines):
        return lines, {}
    if i > 0 and lines[i - 1].strip():
        return lines, {}
    trailers = {}
    for line in lines[i:]:
        m = TRAILER_RE.match(line.strip())
        trailers.setdefault(m.group(1), []).append(m.group(2).strip())
    if not any(key in TRAILER_KEYS for key in trailers):
        return lines, {}
    return lines[:i], trailers


def parse_bullets(lines):
    bullets = []
    for line in lines:
        s = line.strip()
        if not s:
            continue
        if s.startswith(("- ", "* ")):
            bullets.append(s[2:].strip())
        elif bullets:
            bullets[-1] += " " + s
        else:
            bullets.append(s)
    return [b for b in bullets if b]


def pull_issues(text):
    """strip trailing issue references out of a legacy subject."""
    closes, refs = [], []

    def take(m):
        kind = m.group(0).lstrip(" ,.-").split(":")[0].strip().lower()
        bucket = refs if kind.startswith("ref") else closes
        for issue in ISSUE_RE.findall(m.group(1)):
            bucket.append(norm_issue(issue))
        return " "

    cleaned = ISSUE_TAIL_RE.sub(take, text)
    cleaned = re.sub(r"\s{2,}", " ", cleaned).strip(" ,.-")
    return cleaned, closes, refs


BARE_ISSUE_TAIL_RE = re.compile(r"(?:[\s,]*(?:(?:[\w.-]+/[\w.-]+)?#\d+|https?://\S+))+$")


def pull_bare_issues(text):
    """legacy subjects ended with a bare `#146 #471` list, those are references."""
    m = BARE_ISSUE_TAIL_RE.search(text)
    if not m:
        return text, []
    return text[:m.start()].rstrip(" ,.-"), [norm_issue(i) for i in ISSUE_RE.findall(m.group(0))]


def resolve_rev(rev):
    rev = rev.strip()
    full = git("rev-parse", "--verify", "--quiet", rev + "^{commit}", check=False).strip()
    return (full or rev)[:7]


def parse_commit(full_hash, message):
    lines = message.split("\n")
    m = SUBJECT_RE.match(lines[0].strip())
    if not m:
        return Commit(hash=full_hash, short=full_hash[:7], prefix="", text=lines[0].strip())
    body_lines, trailers = split_trailers(lines[1:])
    text = m.group("text").strip()
    bullets = parse_bullets(body_lines)

    if trailers:
        text, closes, refs = pull_issues(text)
    else:
        # legacy: sub points lived in the subject behind " - ", issue refs anywhere
        if not bullets and " - " in text:
            parts = [p.strip() for p in text.split(" - ") if p.strip()]
            text, bullets = parts[0], parts[1:]
        text, closes, refs = pull_issues(text)
        text, bare = pull_bare_issues(text)
        refs.extend(bare)
        cleaned = []
        for bullet in bullets:
            bullet, more_closes, more_refs = pull_issues(bullet)
            bullet, bare = pull_bare_issues(bullet)
            closes.extend(more_closes)
            refs.extend(more_refs + bare)
            if bullet.strip():
                cleaned.append(bullet.strip())
        bullets = cleaned

    for key in ("closes", "ref"):
        for raw in trailers.get(key, []):
            target = closes if key == "closes" else refs
            target.extend(norm_issue(i) for i in ISSUE_RE.findall(raw))

    score = None
    if trailers.get("score"):
        try:
            score = max(0, min(5, int(trailers["score"][-1])))
        except ValueError:
            score = None

    platform = m.group("platform")
    return Commit(
        hash=full_hash,
        short=full_hash[:7],
        prefix=m.group("prefix"),
        platform=None if platform in (None, "android") else platform,
        text=text,
        bullets=bullets,
        topic=(trailers.get("topic") or [None])[-1],
        score=score,
        closes=list(dict.fromkeys(closes)),
        refs=list(dict.fromkeys(refs)),
        amends=[resolve_rev(h) for raw in trailers.get("amends", []) for h in raw.split(",") if h.strip()],
        override=(trailers.get("changelog") or [None])[-1],
    )


def load_commits(rev_range=None, after=None):
    args = ["log", "--no-merges", "--format=%%H%s%%B%s" % (UNIT, REC)]
    if after:
        args.append("--after=%s" % after)
    if rev_range:
        args.append(rev_range)
    out = git(*args)
    commits = []
    for record in out.split(REC):
        record = record.strip("\n")
        if not record.strip():
            continue
        full_hash, _, message = record.partition(UNIT)
        commit = parse_commit(full_hash.strip(), message)
        if commit:
            commits.append(commit)
    commits.reverse()
    return commits


def render_markdown(lines):
    """one blank line around every heading, never more than one blank in a row."""
    spaced = []
    for line in lines:
        if spaced and spaced[-1].strip() and line.startswith("#"):
            spaced.append("")
        if spaced and spaced[-1].startswith("#") and line.strip():
            spaced.append("")
        spaced.append(line)
    return re.sub(r"\n{3,}", "\n\n", "\n".join(spaced).strip("\n") + "\n")


@dataclass
class Entry:
    key: str
    section: str
    text: str
    platform: str = None
    bullets: list = field(default_factory=list)
    hashes: list = field(default_factory=list)
    score: int = 2
    closes: list = field(default_factory=list)
    refs: list = field(default_factory=list)
    topic: str = None
    commits: list = field(default_factory=list)

    def absorb(self, commit):
        if commit.short not in self.hashes:
            self.hashes.append(commit.short)
            self.commits.append(commit)
        for b in commit.bullets:
            if b not in self.bullets:
                self.bullets.append(b)
        for i in commit.closes:
            if i not in self.closes:
                self.closes.append(i)
        for i in commit.refs:
            if i not in self.refs:
                self.refs.append(i)
        self.score = max(self.score, commit.effective_score)

    def render(self):
        text = self.text
        if self.platform:
            text = "(%s) %s" % (self.platform, text)
        return "%s: %s" % (", ".join(self.hashes), " - ".join([text] + self.bullets))


def build_entries(commits):
    """topic aware grouping. commits must be oldest first."""
    entries, by_key, by_hash = [], {}, {}
    for c in commits:
        if c.prefix not in CHANGELOG_PREFIXES:
            continue
        target = None
        for ref in c.amends:
            target = by_hash.get(ref)
            if target:
                break
        if target is None:
            key = c.topic or "#" + c.short
            target = by_key.get(key)
            if target is None:
                target = Entry(
                    key=key,
                    section="feat" if c.prefix == "feat" else c.prefix,
                    text=c.override or c.text,
                    platform=c.platform,
                    score=c.effective_score,
                    topic=c.topic,
                )
                by_key[key] = target
                entries.append(target)
            else:
                if c.prefix == "feat":
                    target.section = "feat"
                if c.override:
                    target.text = c.override
                if target.platform is None:
                    target.platform = c.platform
            target.absorb(c)
        else:
            if c.short not in target.hashes:
                target.hashes.append(c.short)
            for i in c.closes:
                if i not in target.closes:
                    target.closes.append(i)
            for i in c.refs:
                if i not in target.refs:
                    target.refs.append(i)
        by_hash[c.short] = target
    return entries


class Changelog:
    """top-of-file section of CHANGELOG.md, parsed into editable lines."""

    def __init__(self, text):
        self.title = TITLE
        body = text.split("\n")
        start = next((i for i, l in enumerate(body) if l.startswith("## ")), len(body))
        end = next((i for i, l in enumerate(body[start + 1:], start + 1) if l.startswith("## ")), len(body))
        self.head = body[:start]
        self.section = body[start:end]
        self.tail = body[end:]

    @property
    def version(self):
        for line in self.section:
            if line.startswith("# v"):
                return line[2:].strip()
        return None

    def set_date(self, date_text):
        if self.section and self.section[0].startswith("## "):
            self.section[0] = "## " + date_text

    def new_section(self, version, date_text):
        self.tail = self.section + self.tail
        self.section = ["## " + date_text, "", "# " + version, ""]

    def hashes(self):
        found = {}
        for i, line in enumerate(self.section):
            m = ENTRY_RE.match(line)
            if m:
                for h in m.group("hashes").split(","):
                    found[h.strip()[:7]] = i
        return found

    def heading_index(self, heading):
        for i, line in enumerate(self.section):
            if line.strip() == heading:
                return i
        return -1

    def ensure_heading(self, heading, after=None):
        i = self.heading_index(heading)
        if i >= 0:
            return i
        at = len(self.section)
        if after is not None:
            prev = self.heading_index(after)
            if prev >= 0:
                at = self.next_heading(prev)
        while at > 0 and not self.section[at - 1].strip():
            at -= 1
        self.section[at:at] = ["", heading, ""]
        return at + 1

    def next_heading(self, index):
        for i in range(index + 1, len(self.section)):
            if self.section[i].startswith("### "):
                return i
        return len(self.section)

    def render(self):
        return render_markdown(self.head + self.section + self.tail)

    def subsection(self, name, create=True):
        start = self.ensure_heading(H_FIXES, after=H_FEATURES) if create else self.heading_index(H_FIXES)
        if start < 0:
            return None
        end = self.next_heading(start)
        found, header = None, "- %s:" % name
        for i in range(start + 1, end):
            if re.match(r"^- [a-z]+:$", self.section[i].rstrip()):
                if found is not None:
                    return (found, i)
                if self.section[i].rstrip() == header:
                    found = i
        if found is not None:
            return (found, end)
        if not create:
            return None
        at, rank = end, SECTIONS.index(name)
        for i in range(start + 1, end):
            m = re.match(r"^- ([a-z]+):$", self.section[i].rstrip())
            if m and m.group(1) in SECTIONS and SECTIONS.index(m.group(1)) > rank:
                at = i
                break
        while at > start + 1 and not self.section[at - 1].strip():
            at -= 1
        self.section[at:at] = ["", header]
        return (at + 1, at + 2)


def trim_end(lines, start, end):
    while end > start and not lines[end - 1].strip():
        end -= 1
    return end


def insert_line(cl, entry, meta_of, indent):
    if entry.section == "feat":
        heading = cl.ensure_heading(H_FEATURES, after=H_HIGHLIGHTS)
        end = cl.next_heading(heading)
        start = heading + 1
        if start >= len(cl.section) or cl.section[start].strip():
            cl.section.insert(start, "")
            end += 1
        start += 1
    else:
        start, end = cl.subsection(entry.section)
    end = trim_end(cl.section, start, end)
    family = entry.topic.split("-")[0] if entry.topic else None
    at, family_at = end, None
    for i in range(start, end):
        m = ENTRY_RE.match(cl.section[i])
        if not m:
            continue
        hashes = [h.strip()[:7] for h in m.group("hashes").split(",")]
        meta = next((meta_of[h] for h in hashes if h in meta_of), None)
        if family and meta and meta[1] and meta[1].split("-")[0] == family:
            family_at = i + 1
        if at == end and meta and meta[0] < entry.score:
            at = i
    if family_at is not None:
        at = family_at
    cl.section.insert(at, "%s- %s" % (indent, entry.render()))
    return at


def merge_entries(cl, entries, commits):
    meta_of = {c.short: (c.effective_score, c.topic) for c in commits}
    present = cl.hashes()
    by_topic = {}
    for h, i in present.items():
        topic = meta_of.get(h, (0, None))[1]
        if topic:
            by_topic.setdefault(topic, i)

    added, extended, various = [], [], []
    for entry in entries:
        if entry.score == 0:
            various.extend(h for h in entry.hashes if h not in present)
            continue
        line_index = by_topic.get(entry.topic) if entry.topic else None
        if line_index is None:
            line_index = next((present[h] for h in entry.hashes if h in present), None)
        if line_index is None:
            at = insert_line(cl, entry, meta_of, "" if entry.section == "feat" else "  ")
            added.append(entry)
            present = {h: (i + 1 if i >= at else i) for h, i in present.items()}
            by_topic = {t: (i + 1 if i >= at else i) for t, i in by_topic.items()}
            present.update((h, at) for h in entry.hashes)
            if entry.topic:
                by_topic[entry.topic] = at
            continue
        m = ENTRY_RE.match(cl.section[line_index])
        if not m:
            continue
        hashes = [h.strip() for h in m.group("hashes").split(",")]
        listed = {h[:7] for h in hashes}
        parts = [p.strip() for p in m.group("text").split(" - ")]
        changed = False
        for commit in entry.commits:
            if commit.short in listed:
                continue  # already folded in, its text may have been reworded by hand
            hashes.append(commit.short)
            changed = True
            for b in commit.bullets:
                if b not in parts:
                    parts.append(b)
        if changed:
            cl.section[line_index] = "%s- %s: %s" % (m.group("indent"), ", ".join(hashes), " - ".join(parts))
            extended.append(entry)
            present.update((h, line_index) for h in entry.hashes)
    if various:
        start, end = cl.subsection("fix")
        end = trim_end(cl.section, start, end)
        target = None
        for i in range(start, end):
            m = ENTRY_RE.match(cl.section[i])
            if m and m.group("text").strip().endswith(VARIOUS_TEXT):
                target = i
        if target is None:
            cl.section.insert(end, "  - %s: %s" % (", ".join(various), VARIOUS_TEXT))
        else:
            m = ENTRY_RE.match(cl.section[target])
            hashes = [h.strip() for h in m.group("hashes").split(",")]
            listed = {h[:7] for h in hashes}
            hashes += [h for h in various if h not in listed]
            cl.section[target] = "  - %s: %s" % (", ".join(hashes), m.group("text"))
    return added, extended, various


def highlight_lines(cl):
    i = cl.heading_index(H_HIGHLIGHTS)
    if i < 0:
        return []
    return [l for l in cl.section[i + 1:cl.next_heading(i)] if l.startswith("- ")]


def default_range(cl, version):
    hashes = list(cl.hashes())
    if not hashes or cl.version != version:
        if hashes:
            newest = git("rev-list", "--no-walk", "--date-order", "--ignore-missing", *hashes).split()
            if newest:
                return "%s..HEAD" % newest[0]
        tag = git("describe", "--tags", "--abbrev=0", check=False).strip()
        return "%s..HEAD" % tag if tag else None
    ordered = git("rev-list", "--no-walk", "--date-order", "--ignore-missing", *hashes).split()
    return "%s^..HEAD" % ordered[-1] if ordered else None


def between(text, start_marker, end_marker):
    if not text:
        return ""
    lines = text.split("\n")
    try:
        a = next(i for i, l in enumerate(lines) if l.strip().startswith(start_marker))
    except StopIteration:
        return ""
    b = next((i for i, l in enumerate(lines[a + 1:], a + 1) if l.strip().startswith(end_marker)), len(lines))
    return "\n".join(lines[a + 1:b]).strip("\n")


def render_stable_commits(cl, version, existing):
    section = [l for l in cl.section if not l.startswith("## ")]
    hi = next((i for i, l in enumerate(section) if l.strip() == H_HIGHLIGHTS), None)
    feat = next((i for i, l in enumerate(section) if l.strip() == H_FEATURES), None)
    if hi is None or feat is None:
        raise SystemExit("CHANGELOG.md top section is missing the highlights or new features heading")
    intro = between(existing, "# v", H_HIGHLIGHTS)
    out = ["# " + version, ""]
    if intro.strip():
        out += [intro.strip(), ""]
    out += [l for l in section[hi:feat] if l.strip()][:1] + section[hi + 1:feat]
    out += ["<details><summary>New Features & Bug fixes</summary>", ""]
    out += section[feat:]
    out += ["", "</details>"]
    return render_markdown(out)


def telegram_bullets(highlights):
    """draft bullets from the changelog highlights, the bold lead carries the point."""
    bullets = []
    for line in highlights:
        text = line[2:].strip()
        m = re.match(r"\*\*(.+?)\*\*(.*)", text)
        if not m:
            bullets.append(text.rstrip("."))
            continue
        lead, rest = m.group(1).strip(), m.group(2).strip()
        if rest and not rest.startswith(":"):
            lead += " " + re.split(r"[,.:–-]", rest, 1)[0]
        bullets.append(lead.strip().rstrip(","))
    return bullets


def render_telegram(cl, version, existing):
    bullets = telegram_bullets(highlight_lines(cl))
    more = "...and a lot more"
    telegram_part, _, discord_part = existing.partition("\n# Discord")
    intro = between(telegram_part, "# Telegram", "**✨").strip()
    outro = between(telegram_part, more, "============").strip()
    discord_intro = between("# Discord" + discord_part, "# Discord", "### ✨").strip() or intro
    discord_outro = between(discord_part, more, "\U0001f4dd Changelog").strip() or outro
    changelog_url = "https://github.com/%s/blob/main/CHANGELOG.md" % MAIN_REPO
    release_url = "https://github.com/%s/releases/tag/%s" % (MAIN_REPO, version)
    snapshots_url = "https://github.com/%s/releases" % SNAPSHOTS_REPO
    links = [
        ("\U0001f4dd Changelog", "Full Changelog", changelog_url),
        ("\U0001f517 Download", version, release_url),
        ("\U0001f517 Download (beta/linux)", version + "-beta", snapshots_url),
        ("\U0001f310 Website", "namida.app", "https://namida.app"),
        ("\U0001f4da Docs", "docs.namida.app", "https://docs.namida.app"),
    ]
    out = ["# Telegram", ""]
    out += [intro or "TODO intro", ""]
    out += ["**✨ Highlights:**", ""]
    out += ["• " + b for b in bullets]
    out += ["", "%s, [see all changes here](%s)" % (more, changelog_url), ""]
    out += [outro or "TODO thanks", ""]
    out += ["============"]
    out += ["%s: [%s](%s)" % (label, text, url) for label, text, url in links]
    out += ["============", "", "# Discord", ""]
    out += [discord_intro or "TODO intro", ""]
    out += ["### ✨ Highlights:", ""]
    out += ["- " + b for b in bullets]
    out += ["", "%s, [see all changes here](<%s>)" % (more, changelog_url), ""]
    out += [discord_outro or "TODO thanks", ""]
    out += ["%s: [%s](<%s>)" % (label, text, url) for label, text, url in links]
    return render_markdown(out)


def cmd_stable(args):
    root = repo_root()
    version = args.version or pubspec_version(root)
    path = os.path.join(root, "CHANGELOG.md")
    cl = Changelog(read(path))
    rev = args.since or default_range(cl, version)
    commits = load_commits(rev_range=rev)
    entries = build_entries(commits)
    date_text = args.date or datetime.now().strftime("%d/%m/%Y")

    if cl.version != version:
        cl.new_section(version, date_text)
    cl.ensure_heading(H_HIGHLIGHTS)
    cl.ensure_heading(H_FEATURES, after=H_HIGHLIGHTS)
    cl.ensure_heading(H_FIXES, after=H_FEATURES)

    added, extended, various = merge_entries(cl, entries, commits)
    if added or extended or various:
        cl.set_date(date_text)
    candidates = [e for e in entries if e.score >= 5]
    if candidates and not highlight_lines(cl):
        at = cl.heading_index(H_HIGHLIGHTS) + 1
        cl.section[at:at] = [""] + ["- **%s**: TODO" % e.text for e in candidates]

    changelog_text = cl.render()
    docs = os.path.join(root, "docs_internal")
    stable_path = os.path.join(docs, "stable_commits.md")
    telegram_path = os.path.join(docs, "telegram.md")
    stable_text = render_stable_commits(cl, version, read(stable_path) if os.path.exists(stable_path) else "")
    telegram_text = render_telegram(cl, version, read(telegram_path) if os.path.exists(telegram_path) else "")

    if args.dry_run:
        sys.stdout.write(changelog_text)
    else:
        write(path, changelog_text)
        write(stable_path, stable_text)
        write(telegram_path, telegram_text)

    def report(line=""):
        print(line, file=sys.stderr)

    report("range     %s (%d commits)" % (rev or "all", len(commits)))
    report("added     %d entries" % len(added))
    report("extended  %d entries" % len(extended))
    report("various   %d commits" % len(various))
    skipped = [c for c in commits if c.prefix not in CHANGELOG_PREFIXES]
    if skipped:
        report("skipped   %s" % ", ".join("%s (%s)" % (c.short, c.prefix or "unparsed") for c in skipped))
    missing = [c.short for c in commits if c.prefix in CHANGELOG_PREFIXES and c.score is None]
    if missing:
        shown = ", ".join(missing[:12])
        more = " and %d more" % (len(missing) - 12) if len(missing) > 12 else ""
        report("no score  %d commits: %s%s" % (len(missing), shown, more))
    if candidates:
        report("highlights (score 5), rewrite these by hand:")
        for e in candidates:
            report("  - %s" % e.text)
    report()
    report("still manual: highlights wording, telegram intro/thanks, namida_docs")


def fetch_release_date(repo):
    url = "https://api.github.com/repos/%s/releases/latest" % repo
    req = urllib.request.Request(url, headers={"Accept": "application/vnd.github.v3+json"})
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.load(resp).get("published_at")


def cmd_beta(args):
    root = repo_root()
    after, rev = None, args.since
    if args.repo:
        after = fetch_release_date(args.repo)
        if not after:
            raise SystemExit("could not read the latest release date of %s" % args.repo)
    elif not rev:
        tag = git("describe", "--tags", "--abbrev=0", check=False).strip()
        rev = "%s..HEAD" % tag if tag else None
    commits = load_commits(rev_range=rev, after=after)
    cross_repo = bool(args.repo) and args.repo != MAIN_REPO
    lines, closed, referenced = [], {}, {}
    for c in reversed(commits):
        text = "(%s) %s" % (c.platform, c.text) if c.platform else c.text
        lines.append("- %s%s %s" % (COMMIT_URL, c.hash, text))
        lines.extend("     - %s" % b for b in c.bullets)
        closed.update(dict.fromkeys(c.closes))
        referenced.update(dict.fromkeys(c.refs))
    for issue in closed:
        referenced.pop(issue, None)
    render = (lambda i: i) if cross_repo else short_issue
    footer = []
    if closed:
        footer.append("closes %s" % ", ".join(render(i) for i in sorted(closed, key=issue_key)))
    if referenced:
        footer.append("ref %s" % ", ".join(render(i) for i in sorted(referenced, key=issue_key)))
    if footer:
        lines += ["", "<details><summary>Issues</summary>", ""]
        lines += ["- %s" % line for line in footer]
        lines += ["", "</details>"]
    text = "\n".join(lines) + "\n"
    if args.dry_run:
        sys.stdout.write(text)
    else:
        write(os.path.join(root, args.out), text)
    print("%d commits since %s" % (len(commits), after or rev or "start"), file=sys.stderr)


def comment_char():
    return (git("config", "core.commentChar", check=False).strip() or "#")[:1]


SEED_TOPICS = (
    "artwork", "downloads", "equalizer", "history-import", "home", "indexing", "library",
    "lyrics", "most-played", "player", "playlists", "queue", "search", "servers", "settings",
    "shortcuts", "shuffle", "smart-playlists", "stats", "subtitles", "sync", "tagger", "theme",
    "widget", "yt-account", "yt-downloads", "yt-notifications", "yt-search",
)


def known_topics(limit=600):
    """topics already in use, padded with the app's areas so the list is never empty."""
    out = git("log", "-n", str(limit), "--format=%(trailers:key=topic,valueonly)", check=False)
    used = {t.strip() for t in out.split("\n") if t.strip()}
    return sorted(used | set(SEED_TOPICS))


TEMPLATE_HELP = """{c} known topics, reuse one so the commits merge into a single entry:
{topics}
{c}
{c} example:
{c}   chore(desktop): most played page additions
{c}
{c}   - rework header to be simpler
{c}   - button to pick a single day with days radius
{c}
{c}   topic: most-played
{c}   score: 2
{c}   closes: #1204
{c}   closes: #1082
{c}   ref: namidaco/namida-snapshots#106
{c}
{c} ---------------------------------------------------------------
{c} <prefix>(<platform>)?: <subject>      lowercase, <= {max} chars, no " - "
{c}
{c}   feat   brand new user facing feature
{c}   core   internal architecture change, still worth a changelog line
{c}   chore  small change or behaviour enhancement (default)
{c}   fix    bug fix
{c}   perf   performance
{c}
{c}   never reach the changelog:
{c}   code   internal code change, refactors, cleanups
{c}   build  packaging, dependencies, version bumps
{c}   github workflows, issue templates
{c}   docs   readme and repo docs
{c}   test   tests
{c}
{c} (platform) only when the change is platform specific:
{c}   {platforms}
{c}
{c} body: one "- " bullet per sub point, they become changelog sub points
{c}
{c} trailers, lowercase, last block, blank line before them. delete the ones you don't use:
{c}
{c}   topic: <slug>       every commit touching the same feature gets the same slug, they
{c}                       become one changelog entry with the sub points merged
{c}
{c}   score: 0-5          how big is this next to the rest of the release, sorts the section
{c}                       5 highlight, 4 major, 3 notable, 2 normal, 1 minor,
{c}                       0 hidden, folded into "various fixes and tweaks"
{c}
{c}   closes: #123        one per line, a comma list only closes the first one
{c}   ref: #123           or namidaco/namida-snapshots#12, cross repo never closes
{c}
{c}   amends: <hash>      this commit fixes or finishes <hash>, which is not released yet.
{c}                       its hash joins that entry and this text is dropped, so the release
{c}                       notes never mention the half done state. use it instead of a topic
{c}                       when there is nothing new to tell the user
{c}
{c}   changelog: <text>   what the user reads, when the subject only makes sense to us.
{c}                       ex subject "core: rewrite artwork cache keys",
{c}                          changelog: artworks no longer reload after renaming a track
{c} ---------------------------------------------------------------"""


def cmd_template(args):
    c = comment_char()
    topics = known_topics()
    listed = []
    for i in range(0, len(topics), 6):
        listed.append("%s   %s" % (c, ", ".join(topics[i:i + 6])))
    help_text = TEMPLATE_HELP.format(
        c=c,
        max=SUBJECT_MAX,
        platforms=" ".join("(%s)" % p for p in PLATFORMS if p != "android"),
        topics="\n".join(listed),
    )
    body = "chore: \n\ntopic: \nscore: 2\n\n%s\n" % help_text
    if args.file:
        existing = read(args.file) if os.path.exists(args.file) else ""
        if any(l.strip() and not l.startswith(c) for l in existing.split("\n")):
            return
        write(args.file, body + existing)
    else:
        print(body)


def cmd_check(args):
    c = comment_char()
    lines = [l for l in read(args.file).split("\n") if not l.startswith(c)]
    while lines and not lines[0].strip():
        lines.pop(0)
    if not any(l.strip() for l in lines):
        raise SystemExit("aborting commit, empty message")
    subject = lines[0].strip()
    if subject.startswith(("Merge ", "Revert ", "fixup!", "squash!", "amend!")):
        return

    errors, warnings = [], []
    m = SUBJECT_RE.match(subject)
    if not m:
        if re.match(r"^[a-z]+(\([a-z]+\))?:\s*$", subject):
            errors.append("the subject is still empty, fill in the template")
        else:
            errors.append('subject must be "<prefix>: <text>" or "<prefix>(<platform>): <text>"')
    else:
        prefix, platform, text = m.group("prefix"), m.group("platform"), m.group("text").strip()
        if prefix not in ALL_PREFIXES:
            errors.append("unknown prefix %r, use one of: %s" % (prefix, ", ".join(ALL_PREFIXES)))
        if platform and platform not in PLATFORMS:
            errors.append("unknown platform %r, use one of: %s" % (platform, ", ".join(PLATFORMS)))
        if not text:
            errors.append("subject text is empty")
        if len(subject) > SUBJECT_MAX:
            errors.append("subject is %d chars, keep it under %d and move detail to bullets" % (len(subject), SUBJECT_MAX))
        if text[:1].isupper():
            errors.append("subject must be lowercase")
        if text.endswith("."):
            errors.append("subject must not end with a period")
        if " - " in text:
            errors.append('no " - " in the subject, put sub points as "- " bullets in the body')

    body_lines, trailers = split_trailers(lines[1:])
    if lines[1:] and lines[1].strip():
        errors.append("leave a blank line between the subject and the body")
    for line in body_lines:
        if ISSUE_TAIL_RE.search(line):
            errors.append("put issue references in a closes:/ref: trailer, not in the body: %s" % line.strip())
            break
        tm = TRAILER_RE.match(line.strip())
        if tm and tm.group(1) in TRAILER_KEYS:
            errors.append("trailers must be the last block, with a blank line before them: %s" % line.strip())
            break
    if m and ISSUE_TAIL_RE.search(subject):
        errors.append("put issue references in a closes:/ref: trailer, not in the subject")

    for key, values in trailers.items():
        if key not in TRAILER_KEYS:
            errors.append("unknown trailer %r, use one of: %s" % (key, ", ".join(TRAILER_KEYS)))
        for value in values:
            if not value:
                errors.append("trailer %r has no value, fill it in or delete the line" % key)
            elif key == "score" and (not value.isdigit() or not 0 <= int(value) <= 5):
                errors.append("score must be an integer 0-5, got %r" % value)
            elif key == "topic" and not TOPIC_RE.match(value):
                errors.append("topic must be a lowercase slug like most-played, got %r" % value)
            elif key in ("closes", "ref") and not ISSUE_RE.fullmatch(value.replace(" ", "").split(",")[0]):
                errors.append("%s must be #123 or owner/repo#123, got %r" % (key, value))
            elif key == "amends" and not git("rev-parse", "--verify", "--quiet", value + "^{commit}", check=False).strip():
                errors.append("amends: %r is not a commit in this repo" % value)
    if len(trailers.get("topic", [])) > 1:
        errors.append("only one topic: trailer per commit")
    if len(trailers.get("score", [])) > 1:
        errors.append("only one score: trailer per commit")
    if m and m.group("prefix") in CHANGELOG_PREFIXES and not trailers.get("score"):
        warnings.append("no score:, defaulting to %d" % DEFAULT_SCORES.get(m.group("prefix"), 2))
    if any("," in v for v in trailers.get("closes", [])):
        warnings.append("one closes: per line, a comma list only closes the first issue")

    for w in warnings:
        print("chlog: %s" % w, file=sys.stderr)
    if errors:
        print("\ncommit message rejected:", file=sys.stderr)
        for e in errors:
            print("  - %s" % e, file=sys.stderr)
        print("\nrun `python scripts/chlog.py template` to see the format\n", file=sys.stderr)
        raise SystemExit(1)


def main():
    parser = argparse.ArgumentParser(prog="chlog", description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    subs = parser.add_subparsers(dest="cmd", required=True)

    beta = subs.add_parser("beta", help="write beta_changelog.md")
    beta.add_argument("--repo", help="range starts at this repo's latest release instead of the last local tag")
    beta.add_argument("--since", help="explicit rev range, e.g. v7.1.2..HEAD")
    beta.add_argument("--out", default="beta_changelog.md")
    beta.add_argument("--dry-run", action="store_true")
    beta.set_defaults(func=cmd_beta)

    stable = subs.add_parser("stable", help="update CHANGELOG.md, stable_commits.md and telegram.md")
    stable.add_argument("--since", help="explicit rev range, defaults to the current version's commits")
    stable.add_argument("--date", help="section date, defaults to today (dd/mm/yyyy)")
    stable.add_argument("--version", help="defaults to pubspec.yaml")
    stable.add_argument("--dry-run", action="store_true")
    stable.set_defaults(func=cmd_stable)

    template = subs.add_parser("template", help="commit message template")
    template.add_argument("file", nargs="?")
    template.set_defaults(func=cmd_template)

    check = subs.add_parser("check", help="validate a commit message file")
    check.add_argument("file")
    check.set_defaults(func=cmd_check)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
