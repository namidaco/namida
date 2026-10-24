// by claude

const MARKER = '<!-- namida-triage -->';
const DAY_MS = 24 * 60 * 60 * 1000;
const OUTDATED_GRACE_MS = 3 * DAY_MS;
const AUTHOR_DUPLICATE_WINDOW_MS = 14 * DAY_MS;
const MIN_TITLE_LENGTH = 2;
const MIN_PASTED_LOGS_LENGTH = 300;
const APP_LOGS_ZIP_PREFILL = '📦 attach ';
const NO_RESPONSE = '_No response_';
const SECTION_HEADING_PREFIX = '### ';
const CODE_FENCE_REGEX = /^ {0,3}(`{3,}|~{3,})(.*)$/;
const FOLD_OPEN = '<details><!-- namida-meta -->';
const FOLD_CLOSE = '</details><!-- /namida-meta -->';
const FOLD_SUMMARY_REGEX = /^<summary>.*<\/summary>$/;
const FOLD_SUMMARY_SEPARATOR = ' · ';
const FOLD_FALLBACK_SUMMARY = 'details';
const MAX_SEARCH_WORDS = 6;
const MAX_DUPLICATES = 3;
const MIN_DUPLICATE_SCORE = 0.5;
const MAINTAINER_ASSOCIATIONS = new Set(['OWNER', 'MEMBER', 'COLLABORATOR']);
const BETA_REPO = { owner: 'namidaco', repo: 'namida-snapshots' };

const FIELD = {
  checks: 'before we start',
  version: 'namida version',
  platforms: 'platforms',
  os: 'os version',
  device: 'device',
  source: 'installed from',
  severity: 'how bad is it',
  area: 'where does it happen',
  featureArea: 'where in the app',
  ytProblem: "what's broken on youtube",
  ytScope: 'which videos',
  ytSignedIn: 'signed in?',
  ytRegion: 'country',
  idea: 'your idea',
  question: 'what is it cutie',
  logs: 'logs',
  noLogs: "can't share logs?",
};

// -- the forms' other labels, only used to end a code fence the user left open
const OTHER_FORM_HEADINGS = [
  'any idea how to fix it?', 'anything else', 'apps that do this well', 'error message', 'how to make it happen', //
  'other ways you thought of', 'screenshots / video', 'video links', 'what did you expect instead', 'what happened', //
  "what's bugging you", //
];
const FIELD_HEADINGS = new Set([...Object.values(FIELD), ...OTHER_FORM_HEADINGS]);

const FOLDED_FIELDS = new Set([
  FIELD.checks,
  FIELD.version,
  FIELD.platforms,
  FIELD.os,
  FIELD.device,
  FIELD.source,
  FIELD.severity,
  FIELD.area,
  FIELD.featureArea,
  FIELD.ytProblem,
  FIELD.ytScope,
  FIELD.ytSignedIn,
  FIELD.ytRegion,
  FIELD.noLogs,
]);

const LABEL = {
  bug: 'bug',
  featureRequest: 'feature request',
  needsLogs: 'needs logs',
  outdated: 'outdated version',
  incomplete: 'incomplete',
};

const TITLE_PREFIXES = [
  { field: FIELD.ytProblem, prefix: '[BUG][YOUTUBE]' },
  { field: FIELD.severity, prefix: '[BUG]' },
  { field: FIELD.idea, prefix: '[FEATURE REQUEST]' },
  { field: FIELD.question, prefix: '[QUESTION]' },
];
const TITLE_TAGS_REGEX = /^\s*(?:\[\s*(?:bug|youtube|feature request|feature|question)\s*\]\s*)+/i;

const AREA_LABEL_PREFIX = 'area: ';
const DUPLICATE_KIND_LABELS = [LABEL.bug, LABEL.featureRequest];

const PLATFORM_LABELS = {
  Android: 'android',
  Windows: 'windows',
  Linux: 'linux',
  iOS: 'ios',
  macOS: 'macos',
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
  LABEL.incomplete,
]);

const LABEL_COLORS = {
  android: '3ddc84',
  windows: '0078d4',
  linux: 'f9d0c4',
  ios: 'a2aaad',
  macos: '5e5e5e',
  crash: 'b60205',
  [LABEL.needsLogs]: 'fbca04',
  [LABEL.outdated]: 'd4c5f9',
  [LABEL.incomplete]: 'cfd3d7',
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
  logsZipNotAttached: "📦 **the logs zip isn't attached yet**, namida already saved it at the path in the logs section, just drag that zip in there",
  version: '🔢 **the version needs to be exact**, copy it from **Settings > About** (ex: `7.4.0-beta`), "latest" changes every few days',
  outdated: (reported, latest) =>
    `⏳ **you're on an older build** (\`${reported}\`), the latest beta is [\`${latest.tag}\`](${latest.url}). mind giving it a spin? might be fixed already`,
};

const COMMENT_NOTES_HEADER = 'heyy 👋 couple things before we dig in:';
const COMMENT_CLOSED_INCOMPLETE = "🔒 **closed for now**, fix the points above by editing the issue and i'll reopen it on my own";
const COMMENT_AUTHOR_DUPLICATE = (number) =>
  `🔁 **you already opened #${number} about this**, let's keep it all there. edit that one or drop a comment over there instead of opening a new one`;
const COMMENT_DUPLICATES_HEADER = '👀 **these look kinda similar**, maybe one of them is yours? if so, a 👍 there helps more than a new issue';
const COMMENT_FOOTER = "<sub>i'm a bot 🤖 edit the issue and i'll update this on my own</sub>";
const COMMENT_FOOTER_FINAL = "<sub>i'm a bot 🤖</sub>";

module.exports = async ({ github, context, core }) => {
  const issue = context.payload.issue;
  const rawBody = issue.body ?? '';
  const body = toLf(rawBody);
  const parsedBody = parseBody(body);
  const fields = parseForm(parsedBody.sections);
  if (fields.size === 0) {
    core.info('not created from a form, skipping');
    return;
  }

  const { owner, repo } = context.repo;
  const isMaintainer = MAINTAINER_ASSOCIATIONS.has(issue.author_association);
  const isBugLike = issue.labels.some((l) => l.name === LABEL.bug);
  const isNewIssue = context.payload.action === 'opened';
  const isOpen = issue.state === 'open';
  const wasIncomplete = issue.labels.some((l) => l.name === LABEL.incomplete);

  const shouldEnforcePrefix = isNewIssue || !isMaintainer;
  const titlePrefix = shouldEnforcePrefix ? findTitlePrefix(fields) : null;
  const title = titlePrefix ? prefixTitle(issue.title, titlePrefix) : issue.title;

  const desiredLabels = collectFieldLabels(fields);
  const notes = [];
  let isIncomplete = false;

  if (!isMaintainer) {
    if (isPlaceholderTitle(title)) {
      notes.push(NOTE.title);
      isIncomplete = true;
    }

    const shouldHaveLogs = isBugLike && fields.has(FIELD.logs);
    const missingLogsNote = shouldHaveLogs ? findMissingLogsNote(fields) : null;
    if (missingLogsNote) {
      desiredLabels.add(LABEL.needsLogs);
      notes.push(missingLogsNote);
      isIncomplete = true;
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

  const shouldCheckAuthorDuplicates = isNewIssue && !isMaintainer;
  const authorDuplicate = shouldCheckAuthorDuplicates ? await findAuthorDuplicate(github, owner, repo, issue, title, desiredLabels, isIncomplete) : null;
  const isIncompleteReport = isIncomplete && authorDuplicate == null;
  const shouldCloseAsIncomplete = isIncompleteReport && isNewIssue;
  const shouldKeepIncompleteLabel = isIncompleteReport && wasIncomplete;
  if (shouldCloseAsIncomplete || shouldKeepIncompleteLabel) desiredLabels.add(LABEL.incomplete);

  const canReopen = !isIncomplete && !isOpen && wasIncomplete;
  const payloadFoldedBody = foldBody(body, parsedBody);
  const needsLatestIssue = canReopen || payloadFoldedBody != null;
  const latestIssue = needsLatestIssue ? await fetchIssue(github, owner, repo, issue.number, core) : null;
  const shouldReopen = canReopen && latestIssue?.closed_by?.type === 'Bot';
  const isClosedIncomplete = shouldCloseAsIncomplete || (shouldKeepIncompleteLabel && !isOpen);

  const shouldFindDuplicates = !isMaintainer && authorDuplicate == null;
  const duplicates = shouldFindDuplicates ? await findDuplicates(github, owner, repo, issue.number, title) : [];
  const comment = renderComment({ notes, duplicates, authorDuplicate, isClosedIncomplete });

  const titleUpdate = title === issue.title ? null : { title };
  const bodyUpdate = payloadFoldedBody == null ? null : buildBodyUpdate(latestIssue);
  const stateUpdate = buildStateUpdate({ authorDuplicate, shouldCloseAsIncomplete, shouldReopen });
  const issueUpdate = { ...titleUpdate, ...bodyUpdate, ...stateUpdate };

  await syncLabels(github, owner, repo, issue, desiredLabels);
  await upsertComment(github, owner, repo, issue.number, comment, isNewIssue);
  await updateIssue(github, owner, repo, issue.number, issueUpdate);
};

function parseForm(sections) {
  const fields = new Map();
  for (const section of sections) {
    const value = section.isNoResponse ? '' : section.value.trim();
    fields.set(section.key, value);
  }
  return fields;
}

function parseBody(body) {
  const lines = body.split('\n');
  const preambleLines = [];
  const sectionsLines = [];
  let targetLines = preambleLines;
  let fence = null;
  let postambleStart = lines.length;

  // -- the fold markers and the form's own headings end a fence the user left open, so it can't swallow the fields after it
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (line === FOLD_CLOSE) {
      postambleStart = i + 1;
      break;
    }
    const nextLine = lines[i + 1] ?? '';
    const isFoldOpen = line === FOLD_OPEN && FOLD_SUMMARY_REGEX.test(nextLine);
    if (isFoldOpen) {
      fence = null;
      i++;
      continue;
    }
    const isHeading = line.startsWith(SECTION_HEADING_PREFIX);
    const isSectionHeading = isHeading && (fence == null || isFormFieldHeading(line));
    if (isSectionHeading) {
      fence = null;
      targetLines = [line.slice(SECTION_HEADING_PREFIX.length)];
      sectionsLines.push(targetLines);
      continue;
    }
    fence = nextCodeFence(line, fence);
    targetLines.push(line);
  }

  const postambleLines = lines.slice(postambleStart);
  const sections = sectionsLines.map(parseSection);
  const preamble = trimBlankLines(preambleLines.join('\n'));
  const postamble = trimBlankLines(postambleLines.join('\n'));
  return { preamble, sections, postamble };
}

function isFormFieldHeading(line) {
  const heading = line.slice(SECTION_HEADING_PREFIX.length).trim().toLowerCase();
  return FIELD_HEADINGS.has(heading);
}

function nextCodeFence(line, fence) {
  const match = CODE_FENCE_REGEX.exec(line);
  if (match == null) return fence;

  const [, marker, rest] = match;
  if (fence == null) {
    const hasBacktickInInfo = marker[0] === '`' && rest.includes('`');
    return hasBacktickInInfo ? null : marker;
  }
  const isClosing = marker[0] === fence[0] && marker.length >= fence.length && rest.trim() === '';
  return isClosing ? null : fence;
}

function parseSection(sectionLines) {
  const [rawHeading, ...valueLines] = sectionLines;
  const rawValue = valueLines.join('\n');

  const heading = rawHeading.trim();
  const key = heading.toLowerCase();
  const value = trimBlankLines(rawValue);
  const isNoResponse = value.trim() === NO_RESPONSE;
  return { heading, key, value, isNoResponse };
}

function buildBodyUpdate(latestIssue) {
  if (latestIssue == null) return null;

  const rawLatestBody = latestIssue.body ?? '';
  const latestBody = toLf(rawLatestBody);
  const latestParsedBody = parseBody(latestBody);
  const foldedBody = foldBody(latestBody, latestParsedBody);
  return foldedBody == null ? null : { body: foldedBody };
}

function foldBody(body, parsedBody) {
  const { preamble, sections, postamble } = parsedBody;
  const visibleSections = [];
  const foldedSections = [];
  for (const section of sections) {
    const isFolded = section.isNoResponse || FOLDED_FIELDS.has(section.key);
    const targetSections = isFolded ? foldedSections : visibleSections;
    targetSections.push(section);
  }
  if (foldedSections.length === 0) return null;

  const blocks = [];
  if (preamble) blocks.push(preamble);
  for (const section of visibleSections) blocks.push(renderSection(section));
  blocks.push(renderFold(foldedSections));
  if (postamble) blocks.push(postamble);

  const foldedBody = blocks.join('\n\n');
  return foldedBody === body ? null : foldedBody;
}

function renderFold(sections) {
  const summaryValues = sections.filter(isSummarySection).map((s) => s.value.trim());
  const summary = summaryValues.join(FOLD_SUMMARY_SEPARATOR) || FOLD_FALLBACK_SUMMARY;
  const escapedSummary = escapeHtml(summary);
  const foldHead = `${FOLD_OPEN}\n<summary>${escapedSummary}</summary>`;
  const renderedSections = sections.map(renderSection);
  return [foldHead, ...renderedSections, FOLD_CLOSE].join('\n\n');
}

function renderSection(section) {
  return section.value ? `### ${section.heading}\n\n${section.value}` : `### ${section.heading}`;
}

function isSummarySection(section) {
  const value = section.value;
  const isCheckboxList = value.startsWith('- [');
  return value !== '' && !section.isNoResponse && !isCheckboxList && !value.includes('\n');
}

function escapeHtml(text) {
  return text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function trimBlankLines(text) {
  return text.replace(/^(?:[ \t]*\n)+/, '').trimEnd();
}

function toLf(text) {
  return text.replace(/\r\n/g, '\n');
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

function findTitlePrefix(fields) {
  const match = TITLE_PREFIXES.find((p) => fields.has(p.field));
  return match?.prefix;
}

function prefixTitle(title, prefix) {
  const bareTitle = title.replace(TITLE_TAGS_REGEX, '').trim();
  return bareTitle ? `${prefix} ${bareTitle}` : prefix;
}

function isPlaceholderTitle(title) {
  if (/write the title here/i.test(title)) return true;

  const titleWithoutTags = title.replace(/\[[^\]]*\]/g, '').trim();
  return titleWithoutTags.length < MIN_TITLE_LENGTH;
}

function findMissingLogsNote(fields) {
  const logs = fields.get(FIELD.logs) ?? '';
  const hasAttachment = /github\.com\/\S*?files\/\d+\//i.test(logs);
  const hasPastedLogs = logs.length > MIN_PASTED_LOGS_LENGTH;
  if (hasAttachment || hasPastedLogs) return null;

  const isAppZipPending = logs.includes(APP_LOGS_ZIP_PREFILL);
  if (isAppZipPending) return NOTE.logsZipNotAttached;

  const noLogsCheckbox = fields.get(FIELD.noLogs) ?? '';
  const isNoLogsChecked = /- \[x\]/i.test(noLogsCheckbox);
  return isNoLogsChecked ? null : NOTE.logs;
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

async function findDuplicates(github, owner, repo, issueNumber, title) {
  const words = titleWords(title);
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
    if (item.number === issueNumber) continue;

    const itemStems = new Set(titleWords(item.title).map(stem));
    const score = diceScore(stems, itemStems);
    if (score >= MIN_DUPLICATE_SCORE) candidates.push({ item, score });
  }

  candidates.sort((a, b) => b.score - a.score);
  const bestCandidates = candidates.slice(0, MAX_DUPLICATES);
  return bestCandidates.map((c) => c.item);
}

async function findAuthorDuplicate(github, owner, repo, issue, title, desiredLabels, isIncomplete) {
  const labelNames = new Set(issue.labels.map((l) => l.name));
  const kindLabel = DUPLICATE_KIND_LABELS.find((l) => labelNames.has(l));
  const areaLabel = [...desiredLabels].find((l) => l.startsWith(AREA_LABEL_PREFIX));
  if (!kindLabel || !areaLabel) return null;

  const windowStart = Date.parse(issue.created_at) - AUTHOR_DUPLICATE_WINDOW_MS;
  const since = new Date(windowStart).toISOString();
  let items;
  try {
    items = await github.paginate(github.rest.issues.listForRepo, {
      owner,
      repo,
      creator: issue.user.login,
      state: 'all',
      since,
      per_page: 100,
    });
  } catch (_) {
    return null;
  }

  const titleStems = new Set(titleWords(title).map(stem));
  const criteria = { issueNumber: issue.number, windowStart, kindLabel, areaLabel, titleStems, isIncomplete };
  const candidates = items.filter((item) => isAuthorDuplicateCandidate(item, criteria));
  candidates.sort((a, b) => a.number - b.number);

  const openCandidate = candidates.find((c) => c.state === 'open');
  if (openCandidate) return openCandidate;
  return candidates.at(-1) ?? null;
}

function isAuthorDuplicateCandidate(item, criteria) {
  if (item.pull_request || item.number >= criteria.issueNumber) return false;
  if (Date.parse(item.created_at) < criteria.windowStart) return false;
  if (item.state_reason === 'duplicate' || item.state_reason === 'completed') return false;

  const itemLabels = new Set(item.labels.map((l) => l.name));
  if (!itemLabels.has(criteria.kindLabel) || !itemLabels.has(criteria.areaLabel)) return false;

  const itemStems = new Set(titleWords(item.title).map(stem));
  const isSimilarTitle = diceScore(criteria.titleStems, itemStems) >= MIN_DUPLICATE_SCORE;
  if (!criteria.isIncomplete) return isSimilarTitle && item.state === 'open';

  const itemLacksDetails = itemLabels.has(LABEL.needsLogs) || itemLabels.has(LABEL.incomplete) || isPlaceholderTitle(item.title);
  return isSimilarTitle || itemLacksDetails;
}

async function fetchIssue(github, owner, repo, issueNumber, core) {
  try {
    const response = await github.rest.issues.get({ owner, repo, issue_number: issueNumber });
    return response.data;
  } catch (error) {
    core.warning(`couldn't fetch the issue, it isn't reopened or folded this run: ${error.message}`);
    return null;
  }
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
    const fallbackColor = name.startsWith(AREA_LABEL_PREFIX) ? AREA_LABEL_COLOR : DEFAULT_LABEL_COLOR;
    const color = LABEL_COLORS[name] ?? fallbackColor;
    await github.rest.issues.createLabel({ owner, repo, name, color }).catch(() => {});
  }
}

function renderComment({ notes, duplicates, authorDuplicate, isClosedIncomplete }) {
  if (authorDuplicate) {
    const duplicateLine = COMMENT_AUTHOR_DUPLICATE(authorDuplicate.number);
    return [MARKER, duplicateLine, '', COMMENT_FOOTER_FINAL].join('\n');
  }
  if (notes.length === 0 && duplicates.length === 0) return null;

  const lines = [MARKER];
  if (notes.length > 0) {
    const noteLines = notes.map((n) => `- ${n}`);
    lines.push(COMMENT_NOTES_HEADER, '', ...noteLines, '');
  }
  if (isClosedIncomplete) lines.push(COMMENT_CLOSED_INCOMPLETE, '');
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

function buildStateUpdate({ authorDuplicate, shouldCloseAsIncomplete, shouldReopen }) {
  if (authorDuplicate) return { state: 'closed', state_reason: 'duplicate', duplicate_issue_id: authorDuplicate.id };
  if (shouldCloseAsIncomplete) return { state: 'closed', state_reason: 'not_planned' };
  if (shouldReopen) return { state: 'open', state_reason: 'reopened' };
  return null;
}

async function updateIssue(github, owner, repo, issueNumber, update) {
  if (Object.keys(update).length === 0) return;
  await github.rest.issues.update({ owner, repo, issue_number: issueNumber, ...update });
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
