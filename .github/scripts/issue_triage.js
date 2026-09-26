// by claude

const MARKER = '<!-- namida-triage -->';
const OUTDATED_GRACE_MS = 3 * 24 * 60 * 60 * 1000;
const MIN_TITLE_LENGTH = 10;
const MIN_PASTED_LOGS_LENGTH = 300;
const NO_RESPONSE = '_No response_';
const MAX_SEARCH_WORDS = 6;
const MAX_DUPLICATES = 3;
const MIN_DUPLICATE_SCORE = 0.5;
const MAINTAINER_ASSOCIATIONS = new Set(['OWNER', 'MEMBER', 'COLLABORATOR']);
const BETA_REPO = { owner: 'namidaco', repo: 'namida-snapshots' };

const FIELD = {
  version: 'namida version',
  platforms: 'platforms',
  severity: 'how bad is it',
  area: 'where does it happen',
  featureArea: 'where in the app',
  ytProblem: "what's broken on youtube",
  logs: 'logs',
  noLogs: "can't share logs?",
};

const LABEL = {
  bug: 'bug',
  needsLogs: 'needs logs',
  outdated: 'outdated version',
};

const PLATFORM_LABELS = {
  Android: 'android',
  Windows: 'windows',
  Linux: 'linux',
};

const SEVERITY_LABELS = {
  "💥 crash / app won't open": 'crash',
  '🤏 small glitch / looks off': 'issue',
};

const AREA_LABELS = {
  'Library & indexing': 'area: library',
  'Playback & queue': 'area: playback',
  'Player & miniplayer': 'area: player',
  'Playlists & history': 'area: playlists',
  'Tags editor': 'area: tags',
  Lyrics: 'area: lyrics',
  YouTube: 'area: youtube',
  Downloads: 'area: downloads',
  Sync: 'area: sync',
  'Widgets & notification': 'area: widgets',
  'Settings & backups': 'area: settings',
};

const MANAGED_LABELS = new Set([
  ...Object.values(PLATFORM_LABELS),
  ...Object.values(SEVERITY_LABELS),
  ...Object.values(AREA_LABELS),
  LABEL.needsLogs,
  LABEL.outdated,
]);

const LABEL_COLORS = {
  android: '3ddc84',
  windows: '0078d4',
  linux: 'f9d0c4',
  crash: 'b60205',
  [LABEL.needsLogs]: 'fbca04',
  [LABEL.outdated]: 'd4c5f9',
};
const AREA_LABEL_COLOR = 'c5def5';
const DEFAULT_LABEL_COLOR = 'ededed';

const STOP_WORDS = new Set([
  'the', 'and', 'for', 'not', 'with', 'when', 'that', 'this', 'from', 'are', 'was', 'has', 'have', 'can', 'cant',
  'does', 'doesn', 'doesnt', 'don', 'dont', 'its', 'into', 'after', 'while', 'but', 'you', 'your', 'all', 'any',
  'bug', 'issue', 'feature', 'request', 'question', 'namida', 'app', 'please', 'write', 'title', 'here',
]);

const NOTE = {
  title: "✏️ **the title needs a bit more love**, a short summary of the problem helps a lot",
  logs: '📦 **logs are missing**, grab them from **Settings > About > Share Logs** and drop the zip in the logs section. app won\'t open? the "can\'t share logs?" section says where the log files live on your device',
  version: '🔢 **the version needs to be exact**, copy it from **Settings > About** (ex: `7.4.0-beta`), "latest" changes every few days',
  outdated: (reported, latest) =>
    `⏳ **you're on an older build** (\`${reported}\`), the latest beta is [\`${latest.tag}\`](${latest.url}). mind giving it a spin? might be fixed already`,
};

const COMMENT_NOTES_HEADER = 'heyy 👋 couple things before we dig in:';
const COMMENT_DUPLICATES_HEADER = '👀 **these look kinda similar**, maybe one of them is yours? if so, a 👍 there helps more than a new issue';
const COMMENT_FOOTER = "<sub>i'm a bot 🤖 edit the issue and i'll update this on my own</sub>";

module.exports = async ({ github, context, core }) => {
  const issue = context.payload.issue;
  const fields = parseForm(issue.body ?? '');
  if (fields.size === 0) {
    core.info('not created from a form, skipping');
    return;
  }

  const { owner, repo } = context.repo;
  const isMaintainer = MAINTAINER_ASSOCIATIONS.has(issue.author_association);
  const isBugLike = issue.labels.some((l) => l.name === LABEL.bug);

  const desiredLabels = collectFieldLabels(fields);
  const notes = [];

  if (!isMaintainer) {
    if (isPlaceholderTitle(issue.title)) notes.push(NOTE.title);

    if (isBugLike && fields.has(FIELD.logs) && !hasLogs(fields)) {
      desiredLabels.add(LABEL.needsLogs);
      notes.push(NOTE.logs);
    }

    const reportedVersionText = fields.get(FIELD.version);
    const reportedVersion = parseVersion(reportedVersionText);
    if (isBugLike && reportedVersionText && !reportedVersion) notes.push(NOTE.version);

    if (isBugLike && reportedVersion) {
      const latest = await findNewerBeta(github, reportedVersion);
      if (latest) {
        const safeVersion = reportedVersionText.replace(/`/g, '').slice(0, 40);
        desiredLabels.add(LABEL.outdated);
        notes.push(NOTE.outdated(safeVersion, latest));
      }
    }
  }

  const duplicates = isMaintainer ? [] : await findDuplicates(github, owner, repo, issue);
  const comment = renderComment(notes, duplicates);
  const isNewIssue = context.payload.action === 'opened';

  await syncLabels(github, owner, repo, issue, desiredLabels);
  await upsertComment(github, owner, repo, issue.number, comment, isNewIssue);
};

function parseForm(body) {
  const fields = new Map();
  const sections = body.split(/^### /m).slice(1);

  for (const section of sections) {
    const newLine = section.indexOf('\n');
    const hasValue = newLine !== -1;
    const rawHeading = hasValue ? section.slice(0, newLine) : section;
    const rawValue = hasValue ? section.slice(newLine + 1).trim() : '';
    const heading = rawHeading.trim().toLowerCase();
    const value = rawValue === NO_RESPONSE ? '' : rawValue;
    fields.set(heading, value);
  }

  return fields;
}

function collectFieldLabels(fields) {
  const labels = new Set();
  const add = (map, value) => {
    if (!value) return;
    const label = map[value.trim()];
    if (label) labels.add(label);
  };

  const platforms = fields.get(FIELD.platforms) ?? '';
  for (const platform of platforms.split(',')) {
    add(PLATFORM_LABELS, platform);
  }

  const area = fields.get(FIELD.area) || fields.get(FIELD.featureArea);
  add(AREA_LABELS, area);
  add(SEVERITY_LABELS, fields.get(FIELD.severity));
  if (fields.has(FIELD.ytProblem)) labels.add(AREA_LABELS.YouTube);

  return labels;
}

function isPlaceholderTitle(title) {
  if (/write the title here/i.test(title)) return true;

  const titleWithoutTags = title.replace(/\[[^\]]*\]/g, '').trim();
  return titleWithoutTags.length < MIN_TITLE_LENGTH;
}

function hasLogs(fields) {
  const noLogsCheckbox = fields.get(FIELD.noLogs) ?? '';
  const isNoLogsChecked = /- \[x\]/i.test(noLogsCheckbox);
  if (isNoLogsChecked) return true;

  const logs = fields.get(FIELD.logs) ?? '';
  const hasAttachment = /github\.com\/\S*?files\/\d+\//i.test(logs);
  const hasPastedLogs = logs.length > MIN_PASTED_LOGS_LENGTH;
  return hasAttachment || hasPastedLogs;
}

async function findNewerBeta(github, reported) {
  let release;
  try {
    const response = await github.rest.repos.getLatestRelease(BETA_REPO);
    release = response.data;
  } catch (_) {
    return null;
  }
  const latest = parseVersion(release.tag_name);
  if (!latest) return null;

  const canCompareBuilds = reported.buildDate != null && latest.buildDate != null;
  const isOutdated = canCompareBuilds
    ? latest.buildDate - reported.buildDate > OUTDATED_GRACE_MS
    : compareCore(reported.core, latest.core) < 0;
  if (!isOutdated) return null;

  return { tag: release.tag_name, url: release.html_url };
}

function parseVersion(text) {
  const match = /(\d+)\.(\d+)\.(\d+)(?:-beta)?(?:\+(\d{6}))?/i.exec(text ?? '');
  if (!match) return null;

  const [, major, minor, patch, build] = match;
  const core = [major, minor, patch].map(Number);
  return { core, buildDate: parseBuildDate(build) };
}

function parseBuildDate(build) {
  if (!build) return null;

  const year = 2000 + Number(build.slice(0, 2));
  const monthIndex = Number(build.slice(2, 4)) - 1;
  const day = Number(build.slice(4, 6));
  return Date.UTC(year, monthIndex, day);
}

function compareCore(a, b) {
  for (let i = 0; i < a.length; i++) {
    if (a[i] !== b[i]) return a[i] - b[i];
  }
  return 0;
}

async function findDuplicates(github, owner, repo, issue) {
  const words = titleWords(issue.title);
  if (words.length < 2) return [];

  const searchTerms = words.slice(0, MAX_SEARCH_WORDS).join(' OR ');
  const query = `repo:${owner}/${repo} is:issue in:title (${searchTerms})`;

  let items;
  try {
    const response = await github.request('GET /search/issues', {
      q: query,
      advanced_search: 'true',
      per_page: 30,
    });
    items = response.data.items;
  } catch (_) {
    return [];
  }

  const stems = new Set(words.map(stem));
  const candidates = [];
  for (const item of items) {
    if (item.number === issue.number) continue;

    const itemStems = new Set(titleWords(item.title).map(stem));
    const score = diceScore(stems, itemStems);
    if (score >= MIN_DUPLICATE_SCORE) candidates.push({ item, score });
  }

  candidates.sort((a, b) => b.score - a.score);
  const bestCandidates = candidates.slice(0, MAX_DUPLICATES);
  return bestCandidates.map((c) => c.item);
}

function titleWords(title) {
  const words = title
    .toLowerCase()
    .replace(/\[[^\]]*\]/g, ' ')
    .split(/[^a-z0-9]+/)
    .filter((w) => w.length > 2 && !STOP_WORDS.has(w));
  return [...new Set(words)];
}

function stem(word) {
  if (word.length > 5 && word.endsWith('ing')) return word.slice(0, -3);
  if (word.length > 4 && word.endsWith('ed')) return word.slice(0, -2);
  if (word.length > 3 && word.endsWith('s') && !word.endsWith('ss')) return word.slice(0, -1);
  return word;
}

function diceScore(a, b) {
  if (a.size === 0 || b.size === 0) return 0;
  let common = 0;
  for (const w of a) if (b.has(w)) common++;
  return (2 * common) / (a.size + b.size);
}

async function syncLabels(github, owner, repo, issue, desired) {
  const current = new Set(issue.labels.map((l) => l.name));
  const toAdd = [...desired].filter((l) => !current.has(l));
  const toRemove = [...current].filter((l) => MANAGED_LABELS.has(l) && !desired.has(l));

  if (toAdd.length > 0) {
    await createMissingLabels(github, owner, repo, toAdd);
    await github.rest.issues.addLabels({ owner, repo, issue_number: issue.number, labels: toAdd });
  }
  for (const name of toRemove) {
    await github.rest.issues.removeLabel({ owner, repo, issue_number: issue.number, name }).catch(() => {});
  }
}

async function createMissingLabels(github, owner, repo, names) {
  const existing = await github.paginate(github.rest.issues.listLabelsForRepo, { owner, repo, per_page: 100 });
  const existingNames = new Set(existing.map((l) => l.name.toLowerCase()));
  for (const name of names) {
    if (existingNames.has(name.toLowerCase())) continue;
    const fallbackColor = name.startsWith('area: ') ? AREA_LABEL_COLOR : DEFAULT_LABEL_COLOR;
    const color = LABEL_COLORS[name] ?? fallbackColor;
    await github.rest.issues.createLabel({ owner, repo, name, color }).catch(() => {});
  }
}

function renderComment(notes, duplicates) {
  if (notes.length === 0 && duplicates.length === 0) return null;

  const lines = [MARKER];
  if (notes.length > 0) {
    const noteLines = notes.map((n) => `- ${n}`);
    lines.push(COMMENT_NOTES_HEADER, '', ...noteLines, '');
  }
  if (duplicates.length > 0) {
    const duplicateLines = duplicates.map(renderDuplicateLine);
    lines.push(COMMENT_DUPLICATES_HEADER, '', ...duplicateLines, '');
  }
  lines.push(COMMENT_FOOTER);
  return lines.join('\n');
}

function renderDuplicateLine(duplicate) {
  const unmentionedTitle = duplicate.title.replace(/@/g, '@\u200b');
  const closedSuffix = duplicate.state === 'closed' ? ' _(closed)_' : '';
  return `- #${duplicate.number} ${unmentionedTitle}${closedSuffix}`;
}

async function upsertComment(github, owner, repo, issueNumber, body, isNewIssue) {
  let existing;
  if (!isNewIssue) {
    const comments = await github.paginate(github.rest.issues.listComments, { owner, repo, issue_number: issueNumber, per_page: 100 });
    existing = comments.find((c) => c.user?.type === 'Bot' && c.body?.startsWith(MARKER));
  }

  if (body == null) {
    if (existing) await github.rest.issues.deleteComment({ owner, repo, comment_id: existing.id });
  } else if (existing == null) {
    await github.rest.issues.createComment({ owner, repo, issue_number: issueNumber, body });
  } else if (existing.body !== body) {
    await github.rest.issues.updateComment({ owner, repo, comment_id: existing.id, body });
  }
}
