#!/usr/bin/env python3
# by claude
"""lists local changes in namida's dependencies that a github ci build won't get.

ci has no pubspec_overrides.yaml and no pubspec.lock, so each git dependency resolves to the head of its ref
(declared in namida's pubspec or in a dependency's pubspec), and submodules update with `--remote`.
every path override and every submodule is compared to that exact commit.

usage: python scripts/unpushed_deps.py [--no-fetch] [-v]
exits with 1 when a difference affects the build (changes only in tests, examples or docs don't).
"""

import argparse
import os
import posixpath
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, field

import yaml

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


class _UnpushedDepsChecker:
    _HOSTED = "pub.dev"
    _SDK = "the sdk"
    _NAMIDA_PATH = "a path inside namida"
    _MAX_LISTED_FILES = 12
    _SHA_REGEX = re.compile(r"[0-9a-f]{7,40}")
    _SYMREF_REGEX = re.compile(r"^ref: refs/heads/(\S+)\s+HEAD", re.M)

    def __init__(self, should_fetch: bool):
        self._should_fetch = should_fetch
        self._remotes_by_repo: dict[str, dict[str, str]] = {}
        self._repo_by_url: dict[str, tuple[str, str]] = {}
        self._fetched: set[tuple[str, str]] = set()
        self._ci_revs: dict[tuple[str, str, str | None], _CiRev | None] = {}

    def run(self, is_verbose: bool) -> int:
        override_jobs = self._read_override_jobs()
        submodule_jobs = self._read_submodule_jobs()
        jobs = override_jobs + submodule_jobs
        repos = {job.repo for job in jobs if job.repo is not None}
        self._register_repos(repos)
        if self._should_fetch:
            self._prefetch(repos)

        sources = self._resolve_ci_sources()
        for job in override_jobs:
            job.ci_source = sources.get(job.name)

        with ThreadPoolExecutor(16) as executor:
            reports = list(executor.map(self._check, jobs))
        namida_unpushed = self._count_namida_unpushed()
        return self._print_reports(reports, namida_unpushed, is_verbose)


    def _read_override_jobs(self) -> "list[_Job]":
        overrides_path = os.path.join(ROOT, "pubspec_overrides.yaml")
        if not os.path.exists(overrides_path):
            return []
        overrides_yaml = self._load_yaml_file(overrides_path)
        overrides = overrides_yaml.get("dependency_overrides") or {}
        jobs = []
        for name, spec in overrides.items():
            path = spec.get("path") if isinstance(spec, dict) else None
            if path is None:
                override_source = self._source_of(spec, parent=None)
                jobs.append(_Job(name=name, display_path="git override", local_dir=None, repo=None, override_source=override_source))
                continue
            local_dir = os.path.normpath(os.path.join(ROOT, path))
            jobs.append(_Job(name=name, display_path=path, local_dir=local_dir, repo=None))
        path_jobs = [job for job in jobs if job.local_dir is not None]
        with ThreadPoolExecutor(16) as executor:
            repos = list(executor.map(self._toplevel_of, (job.local_dir for job in path_jobs)))
        for job, repo in zip(path_jobs, repos):
            job.repo = repo
        return jobs

    def _read_submodule_jobs(self) -> "list[_Job]":
        out, _ = self._git(ROOT, "config", "-f", ".gitmodules", "--get-regexp", r"^submodule\..*\.(path|url|branch)$")
        entries: dict[str, dict[str, str]] = {}
        for line in out.splitlines():
            key, value = line.split(" ", 1)
            submodule_key = key.removeprefix("submodule.")
            submodule_name, prop = submodule_key.rsplit(".", 1)
            entries.setdefault(submodule_name, {})[prop] = value
        jobs = []
        for entry in entries.values():
            path = entry["path"]
            local_dir = os.path.normpath(os.path.join(ROOT, path))
            repo = self._toplevel_of(local_dir)
            is_checked_out = repo is not None and os.path.normcase(repo) == os.path.normcase(local_dir)
            if not is_checked_out:
                continue
            url = self._normalize_url(entry["url"])
            ci_source = _GitSource(url=url, ref=entry.get("branch"), subdir="")
            jobs.append(_Job(name=path, display_path=path, local_dir=local_dir, repo=repo, ci_source=ci_source))
        return jobs

    def _count_namida_unpushed(self) -> int:
        out, code = self._git(ROOT, "rev-list", "--count", "@{u}..HEAD")
        return int(out) if code == 0 else 0


    def _resolve_ci_sources(self) -> "dict[str, _GitSource | str]":
        pubspec = self._load_yaml_file(os.path.join(ROOT, "pubspec.yaml"))
        sources: dict[str, _GitSource | str] = {}
        for section in ("dependency_overrides", "dependencies", "dev_dependencies"):
            deps = pubspec.get(section) or {}
            for name, spec in deps.items():
                if name in sources:
                    continue
                sources[name] = self._source_of(spec, parent=None)

        crawled: set[_GitSource] = set()
        level = [source for source in sources.values() if isinstance(source, _GitSource)]
        while level:
            unique_level = [source for source in dict.fromkeys(level) if source not in crawled]
            crawled.update(unique_level)
            self._resolve_ci_revs(unique_level)
            with ThreadPoolExecutor(16) as executor:
                pubspec_texts = list(executor.map(self._read_pubspec_at_ci, unique_level))
            level = []
            for source, pubspec_text in zip(unique_level, pubspec_texts):
                if pubspec_text is None:
                    continue
                dep_pubspec = yaml.safe_load(pubspec_text) or {}
                deps = dep_pubspec.get("dependencies") or {}
                for name, spec in deps.items():
                    if name in sources:
                        continue
                    dep_source = self._source_of(spec, parent=source)
                    sources[name] = dep_source
                    if isinstance(dep_source, _GitSource):
                        level.append(dep_source)
        return sources

    def _resolve_ci_revs(self, sources: "list[_GitSource]"):
        keys = set()
        for source in sources:
            repo_remote = self._repo_by_url.get(source.url)
            if repo_remote is None:
                continue
            repo, remote = repo_remote
            keys.add((repo, remote, source.ref))
        with ThreadPoolExecutor(16) as executor:
            list(executor.map(lambda key: self._ci_rev(*key), keys))

    def _source_of(self, spec, parent: "_GitSource | None") -> "_GitSource | str":
        if not isinstance(spec, dict):
            return self._HOSTED
        git_spec = spec.get("git")
        if isinstance(git_spec, str):
            url = self._normalize_url(git_spec)
            return _GitSource(url=url, ref=None, subdir="")
        if isinstance(git_spec, dict):
            url = self._normalize_url(git_spec["url"])
            ref = git_spec.get("ref")
            ref_text = None if ref is None else str(ref)
            subdir = self._normalize_subdir(git_spec.get("path") or "")
            return _GitSource(url=url, ref=ref_text, subdir=subdir)
        path = spec.get("path")
        if path is not None:
            if parent is None:
                return self._NAMIDA_PATH
            joined_path = posixpath.join(parent.subdir, path)
            subdir = self._normalize_subdir(joined_path)
            return _GitSource(url=parent.url, ref=parent.ref, subdir=subdir)
        if "sdk" in spec:
            return self._SDK
        return self._HOSTED

    def _read_pubspec_at_ci(self, source: "_GitSource") -> str | None:
        repo_remote = self._repo_by_url.get(source.url)
        if repo_remote is None:
            return None
        repo, remote = repo_remote
        ci_rev = self._ci_rev(repo, remote, source.ref)
        if ci_rev is None:
            return None
        file_path = posixpath.join(source.subdir, "pubspec.yaml")
        out, code = self._git(repo, "show", f"{ci_rev.sha}:{file_path}")
        return out if code == 0 else None


    def _register_repos(self, repos: set[str]):
        sorted_repos = sorted(repos)
        with ThreadPoolExecutor(16) as executor:
            remotes_per_repo = list(executor.map(self._read_remotes, sorted_repos))
        for repo, remotes in zip(sorted_repos, remotes_per_repo):
            self._remotes_by_repo[repo] = remotes
            for remote, url in remotes.items():
                self._repo_by_url.setdefault(url, (repo, remote))

    def _read_remotes(self, repo: str) -> dict[str, str]:
        out, _ = self._git(repo, "config", "--get-regexp", r"^remote\..*\.url$")
        remotes = {}
        for line in out.splitlines():
            key, url = line.split(" ", 1)
            remote = key.removeprefix("remote.").removesuffix(".url")
            remotes[remote] = self._normalize_url(url)
        return remotes

    def _remote_for(self, repo: str, url: str) -> str | None:
        remotes = self._remotes_by_repo.get(repo) or {}
        for remote, remote_url in remotes.items():
            if remote_url == url:
                return remote
        return None

    def _prefetch(self, repos: set[str]):
        origin_repos = [repo for repo in repos if "origin" in self._remotes_by_repo[repo]]
        with ThreadPoolExecutor(16) as executor:
            list(executor.map(lambda repo: self._fetch(repo, "origin"), origin_repos))

    def _fetch(self, repo: str, remote: str):
        key = (repo, remote)
        if key in self._fetched:
            return
        self._fetched.add(key)
        _, code = self._git(repo, "fetch", "--quiet", remote)
        if code != 0:
            print(f"fetching {remote} failed in {repo}, using the last fetched refs", file=sys.stderr)

    def _ci_rev(self, repo: str, remote: str, ref: str | None) -> "_CiRev | None":
        key = (repo, remote, ref)
        if key in self._ci_revs:
            return self._ci_revs[key]
        if self._should_fetch:
            self._fetch(repo, remote)
        ci_rev = self._compute_ci_rev(repo, remote, ref)
        self._ci_revs[key] = ci_rev
        return ci_rev

    def _compute_ci_rev(self, repo: str, remote: str, ref: str | None) -> "_CiRev | None":
        candidates = []
        if ref is None:
            branch = self._default_branch(repo, remote)
            if branch is None:
                return None
            candidates.append(f"{remote}/{branch}")
        else:
            candidates.append(f"{remote}/{ref}")
            candidates.append(f"refs/tags/{ref}")
            if self._SHA_REGEX.fullmatch(ref):
                candidates.append(ref)
        for candidate in candidates:
            sha, code = self._git(repo, "rev-parse", "--verify", "--quiet", f"{candidate}^{{commit}}")
            if code == 0:
                label = candidate.removeprefix("refs/tags/")
                return _CiRev(label=label, sha=sha)
        return None

    def _default_branch(self, repo: str, remote: str) -> str | None:
        out, code = self._git(repo, "symbolic-ref", "--short", f"refs/remotes/{remote}/HEAD")
        if code == 0:
            return out.removeprefix(f"{remote}/")
        out, _ = self._git(repo, "ls-remote", "--symref", remote, "HEAD")
        match = self._SYMREF_REGEX.search(out)
        return match.group(1) if match else None


    def _check(self, job: "_Job") -> "_Report":
        report = _Report(name=job.name, display_path=job.display_path)
        ci_source = job.ci_source
        if job.local_dir is None:
            if job.override_source != ci_source:
                report.problem = f"override uses {self._describe(job.override_source)}, ci uses {self._describe(ci_source)}"
            return report
        if not isinstance(ci_source, _GitSource):
            report.problem = f"ci gets it from {self._describe(ci_source)}, local changes never reach ci"
            return report
        repo = job.repo
        if repo is None:
            report.problem = "local dir isn't in a git repo"
            return report
        remote = self._remote_for(repo, ci_source.url)
        if remote is None:
            report.problem = f"local repo has no remote for {ci_source.url}"
            return report
        relative_dir = os.path.relpath(job.local_dir, repo)
        local_subdir = self._normalize_subdir(relative_dir)
        if local_subdir != ci_source.subdir:
            report.problem = f"local dir is '{local_subdir}' in its repo, ci uses '{ci_source.subdir}'"
            return report
        ci_rev = self._ci_rev(repo, remote, ci_source.ref)
        if ci_rev is None:
            report.problem = f"'{ci_source.ref or 'HEAD'}' doesn't exist on {remote}"
            return report
        report.ci_label = ci_rev.label
        if ci_source.subdir:
            _, code = self._git(repo, "cat-file", "-e", f"{ci_rev.sha}:{ci_source.subdir}")
            if code != 0:
                report.problem = f"'{ci_source.subdir}' doesn't exist on {ci_rev.label}"
                return report

        local_branch, _ = self._git(repo, "rev-parse", "--abbrev-ref", "HEAD")
        ci_branch = ci_rev.label.removeprefix(f"{remote}/")
        if local_branch != ci_branch:
            report.local_branch = local_branch

        pathspec = ci_source.subdir or "."
        status_out, _ = self._git(repo, "status", "--porcelain", "--untracked-files=all", "--", pathspec)
        for line in status_out.splitlines():
            status = line[:2]
            repo_path = line[3:].split(" -> ")[-1]
            package_path = self._package_path(repo_path, ci_source.subdir)
            report.uncommitted.append((status, package_path))

        unpushed_count, _ = self._git(repo, "rev-list", "--count", f"{ci_rev.sha}..HEAD", "--", pathspec)
        report.unpushed_commits = int(unpushed_count or 0)
        if report.unpushed_commits:
            unpushed_out, _ = self._git(repo, "diff", "--name-only", f"{ci_rev.sha}...HEAD", "--", pathspec)
            report.unpushed_files = [self._package_path(path, ci_source.subdir) for path in unpushed_out.splitlines()]
        behind_count, _ = self._git(repo, "rev-list", "--count", f"HEAD..{ci_rev.sha}", "--", pathspec)
        report.behind_commits = int(behind_count or 0)
        return report


    def _print_reports(self, reports: "list[_Report]", namida_unpushed: int, is_verbose: bool) -> int:
        sorted_reports = sorted(reports, key=lambda report: report.name)
        changed = []
        build_affecting = []
        minor = []
        clean = []
        for report in sorted_reports:
            if report.is_clean():
                clean.append(report)
                continue
            changed.append(report)
            target = build_affecting if report.affects_build() else minor
            target.append(report)
        if namida_unpushed:
            print(f"!! namida has {namida_unpushed} unpushed commit(s)\n")
        for report in build_affecting:
            self._print_report(report, marker="!!")
        for report in minor:
            self._print_report(report, marker="..")
        if is_verbose:
            for report in clean:
                print(f"ok {report.name}  ({report.ci_label or report.display_path})")
            if clean:
                print()

        if changed:
            print(f"{len(changed)} of {len(reports)} deps differ from ci, {len(build_affecting)} affect the build")
        else:
            print(f"all {len(reports)} deps match ci")
        has_build_issues = namida_unpushed > 0 or len(build_affecting) > 0
        return 1 if has_build_issues else 0

    def _print_report(self, report: "_Report", marker: str):
        header_parts = [f"{marker} {report.name}", report.display_path]
        if report.ci_label:
            header_parts.append(f"ci: {report.ci_label}")
        if report.local_branch:
            header_parts.append(f"local: {report.local_branch}")
        print("  ".join(header_parts))
        if report.problem is not None:
            print(f"     {report.problem}")
        uncommitted_lines = [f"{status} {path}" + report.non_build_suffix(path) for status, path in report.uncommitted]
        self._print_limited(uncommitted_lines)
        if report.unpushed_commits:
            print(f"     {report.unpushed_commits} unpushed commit(s):")
            unpushed_lines = [f"^  {path}" + report.non_build_suffix(path) for path in report.unpushed_files]
            self._print_limited(unpushed_lines)
        if report.behind_commits:
            print(f"     ci has {report.behind_commits} commit(s) not pulled locally")
        print()

    def _print_limited(self, lines: list[str]):
        for line in lines[: self._MAX_LISTED_FILES]:
            print(f"     {line}")
        hidden_count = len(lines) - self._MAX_LISTED_FILES
        if hidden_count > 0:
            print(f"     ... {hidden_count} more")


    def _describe(self, source: "_GitSource | str | None") -> str:
        if source is None:
            return "an unknown source (declared by a dep with no local repo)"
        if isinstance(source, _GitSource):
            ref_suffix = f"@{source.ref}" if source.ref else ""
            subdir_suffix = f" ({source.subdir})" if source.subdir else ""
            return f"{source.url}{ref_suffix}{subdir_suffix}"
        return source

    @staticmethod
    def _package_path(repo_path: str, subdir: str) -> str:
        unquoted_path = repo_path.strip('"')
        return unquoted_path.removeprefix(f"{subdir}/") if subdir else unquoted_path

    @staticmethod
    def _toplevel_of(local_dir: str) -> str | None:
        if not os.path.isdir(local_dir):
            return None
        out, code = _UnpushedDepsChecker._git(local_dir, "rev-parse", "--show-toplevel")
        if code != 0:
            return None
        toplevel = os.path.normpath(out)
        is_namida = os.path.normcase(toplevel) == os.path.normcase(ROOT)
        return None if is_namida else toplevel

    @staticmethod
    def _normalize_url(url: str) -> str:
        normalized = url.strip().lower()
        normalized = re.sub(r"^(?:[a-z+]+://)?(?:[^@/]+@)?", "", normalized)
        normalized = normalized.replace(":", "/", 1)
        normalized = normalized.rstrip("/")
        return normalized.removesuffix(".git")

    @staticmethod
    def _normalize_subdir(path: str) -> str:
        posix_path = path.replace("\\", "/")
        normalized = posixpath.normpath(posix_path) if posix_path else "."
        return "" if normalized == "." else normalized.strip("/")

    @staticmethod
    def _load_yaml_file(path: str) -> dict:
        with open(path, encoding="utf-8") as file:
            return yaml.safe_load(file) or {}

    @staticmethod
    def _git(cwd: str, *args: str) -> tuple[str, int]:
        result = subprocess.run(
            ["git", "-c", "core.quotepath=false", "-C", cwd, *args],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            stdin=subprocess.DEVNULL,
        )
        return result.stdout.rstrip("\n"), result.returncode


@dataclass(frozen=True)
class _GitSource:
    url: str
    ref: str | None
    subdir: str


@dataclass(frozen=True)
class _CiRev:
    label: str
    sha: str


@dataclass
class _Job:
    name: str
    display_path: str
    local_dir: str | None
    repo: str | None
    ci_source: _GitSource | str | None = None
    override_source: _GitSource | str | None = None


@dataclass
class _Report:
    _NON_BUILD_DIRS = ("test/", "integration_test/", "example/", "benchmark/", "doc/", "docs/", ".github/")
    _NON_BUILD_EXTENSIONS = (".md",)

    name: str
    display_path: str
    ci_label: str = ""
    local_branch: str = ""
    problem: str | None = None
    uncommitted: list[tuple[str, str]] = field(default_factory=list)
    unpushed_commits: int = 0
    unpushed_files: list[str] = field(default_factory=list)
    behind_commits: int = 0

    def is_clean(self) -> bool:
        return self.problem is None and not self.uncommitted and not self.unpushed_commits and not self.behind_commits

    def affects_build(self) -> bool:
        if self.problem is not None:
            return True
        uncommitted_paths = [path for _, path in self.uncommitted]
        changed_paths = uncommitted_paths + self.unpushed_files
        return any(self.is_build_file(path) for path in changed_paths)

    def non_build_suffix(self, path: str) -> str:
        return "" if self.is_build_file(path) else "  (non-build)"

    @classmethod
    def is_build_file(cls, package_path: str) -> bool:
        is_non_build_dir = package_path.startswith(cls._NON_BUILD_DIRS)
        is_non_build_extension = package_path.endswith(cls._NON_BUILD_EXTENSIONS)
        return not is_non_build_dir and not is_non_build_extension


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="list local changes in namida's dependencies that a github ci build won't get")
    parser.add_argument("--no-fetch", action="store_true", help="compare against the last fetched remote refs")
    parser.add_argument("-v", "--verbose", action="store_true", help="also list deps that match ci")
    args = parser.parse_args()
    checker = _UnpushedDepsChecker(should_fetch=not args.no_fetch)
    sys.exit(checker.run(is_verbose=args.verbose))
