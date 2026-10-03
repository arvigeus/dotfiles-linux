#!/usr/bin/env python3
"""Script-only update inventory/evidence/cache. No model or shell evaluation."""

from __future__ import annotations

import argparse
import concurrent.futures
import contextlib
import fcntl
import hashlib
import html.parser
import ipaddress
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

STATE = Path(
    os.environ.get(
        "PI_SYSTEM_UPDATE_STATE",
        str(
            Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state")))
            / "pi-system-update"
        ),
    )
)
NEWS = "https://archlinux.org/feeds/news/"
MAX_BODY = 4 * 1024 * 1024
ENV = {**os.environ, "LC_ALL": "C", "LANG": "C"}


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True).encode()).hexdigest()


def run(args, codes=(0,), timeout=180):
    result = subprocess.run(
        args, capture_output=True, text=True, env=ENV, timeout=timeout, check=False
    )
    if result.returncode not in codes:
        raise RuntimeError(
            f"{args[0]} failed ({result.returncode}): {result.stderr.strip()}"
        )
    return result.stdout


def load(name, default=None):
    path = STATE / name
    try:
        return json.loads(path.read_text()) if path.exists() else default
    except (OSError, json.JSONDecodeError) as exc:
        raise RuntimeError(
            f"Cannot read update state {path}: {exc}; restore it rather than silently discarding decisions"
        ) from exc


def save(name, value):
    STATE.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd, temporary = tempfile.mkstemp(dir=STATE)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(value, stream, indent=2, sort_keys=True)
            stream.write("\n")
        os.replace(temporary, STATE / name)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


@contextlib.contextmanager
def locked():
    STATE.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (STATE / "lock").open("a") as stream:
        try:
            fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as exc:
            raise RuntimeError("Another update operation is running") from exc
        yield


def validate_url(url):
    if not isinstance(url, str) or len(url) > 2048:
        raise ValueError("Source URLs must be at most 2048 characters")
    parsed = urllib.parse.urlsplit(url)
    if (
        parsed.scheme != "https"
        or not parsed.hostname
        or parsed.username
        or parsed.password
    ):
        raise ValueError("Sources must be public HTTPS URLs without credentials")
    if parsed.port not in (None, 443):
        raise ValueError("Sources must use the standard HTTPS port")
    addresses = socket.getaddrinfo(parsed.hostname, 443, type=socket.SOCK_STREAM)
    if not addresses or any(
        not ipaddress.ip_address(item[4][0]).is_global for item in addresses
    ):
        raise ValueError("Local/private source URLs are not allowed")
    return url


class PublicRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        validate_url(newurl)
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def fetch(url):
    validate_url(url)
    # HTTPS and public addresses validated above and before every redirect.
    request = urllib.request.Request(  # noqa: S310 -- validated HTTPS only
        url,
        headers={
            "User-Agent": "pi-system-update/1.0",
            "Accept": "text/html,application/json,text/plain,application/xml",
        },
    )
    with urllib.request.build_opener(PublicRedirect()).open(
        request, timeout=30
    ) as response:
        validate_url(response.url)
        body = response.read(MAX_BODY + 1)
        if len(body) > MAX_BODY:
            raise RuntimeError("Source exceeds 4 MiB; choose a narrower changelog URL")
        return body.decode("utf-8", errors="replace")


class Readable(html.parser.HTMLParser):
    def __init__(self):
        super().__init__()
        self.parts = []
        self.hidden = 0

    def handle_starttag(self, tag, attrs):
        if tag in {"script", "style"}:
            self.hidden += 1
        if tag in {"p", "div", "li", "br", "h1", "h2", "h3", "pre", "tr"}:
            self.parts.append("\n")

    def handle_endtag(self, tag):
        if tag in {"script", "style"}:
            self.hidden = max(0, self.hidden - 1)

    def handle_data(self, data):
        if not self.hidden:
            self.parts.append(data)


def readable(body):
    if re.search(r"<(?:html|body|div|p)[\s>]", body, re.IGNORECASE):
        parser = Readable()
        parser.feed(body)
        body = "".join(parser.parts)
    return "\n".join(line.strip() for line in body.splitlines() if line.strip())


def distro():
    values = {}
    for line in Path("/etc/os-release").read_text().splitlines():
        key, _, value = line.partition("=")
        values[key] = value.strip('"')
    if values.get("ID") not in {"arch", "fedora"}:
        raise RuntimeError(
            "Only Arch Linux and Fedora are supported (not derivative distributions)"
        )
    return values["ID"]


def dnf5():
    version = run(["dnf", "--version"]).lower()
    return "dnf5" in version or bool(re.match(r"5\.", version.strip()))


def inventory(system):
    if system == "arch":
        return sorted(run(["pacman", "-Q"]).splitlines())
    return sorted(
        run(
            [
                "rpm",
                "-qa",
                "--qf",
                "%{NAME}.%{ARCH}\t%{EPOCHNUM}:%{VERSION}-%{RELEASE}\\n",
            ]
        ).splitlines()
    )


def candidates(system):
    if system == "arch":
        # checkupdates refreshes a separate DB; never pacman -Sy on the live DB.
        db = STATE / "checkupdates-db"
        result = subprocess.run(
            ["checkupdates"],
            env={**ENV, "CHECKUPDATES_DB": str(db)},
            capture_output=True,
            text=True,
            timeout=180,
            check=False,
        )
        if result.returncode not in (0, 2):
            raise RuntimeError(f"checkupdates failed: {result.stderr.strip()}")
        packages = []
        for line in result.stdout.splitlines():
            match = re.fullmatch(r"(\S+) (\S+) -> (\S+)", line)
            if not match:
                raise RuntimeError(f"Unexpected checkupdates line: {line}")
            name, old, new = match.groups()
            info = run(["pacman", "--dbpath", str(db), "-Si", "--", name])
            fields = dict(re.findall(r"^([^:\n]+?)\s+:\s*(.*)$", info, re.MULTILINE))
            packages.append(
                {
                    "key": name,
                    "name": name,
                    "old": old,
                    "new": new,
                    "repo": fields.get("Repository", "unknown"),
                    "homepage": fields.get("URL", ""),
                    "native_changelog": False,
                }
            )
        return sorted(packages, key=lambda item: item["key"])
    five = dnf5()
    fmt = "%{name}\t%{arch}\t%{evr}\t%{repoid}\t%{url}"
    command = [
        "dnf",
        "--refresh",
        "repoquery",
        "--upgrades",
        "--latest-limit=1",
        "--qf",
        fmt + ("\\n" if five else ""),
    ]
    installed = {}
    for line in inventory(system):
        key, version = line.split("\t", 1)
        installed.setdefault(key, []).append(version)
    packages = []
    for line in run(command).splitlines():
        # Ignore DNF's non-record status output, but never accept malformed records.
        if "\t" not in line:
            continue
        fields = line.split("\t")
        if len(fields) != 5:
            raise RuntimeError(f"Unexpected DNF query record: {line}")
        name, arch, new, repo, homepage = fields
        key = f"{name}.{arch}"
        if key not in installed:
            raise RuntimeError(f"DNF upgrade has no installed counterpart: {key}")
        packages.append(
            {
                "key": key,
                "name": name,
                "old": ", ".join(installed[key]),
                "new": new,
                "repo": repo,
                "homepage": homepage,
                "native_changelog": True,
            }
        )
    if len({item["key"] for item in packages}) != len(packages):
        raise RuntimeError(
            "Multiple upgrade candidates per package; resolve repository ambiguity first"
        )
    return sorted(packages, key=lambda item: item["key"])


def arch_news():
    body = fetch(NEWS)
    # A bounded UTF-8 feed needs neither DTDs nor custom entities. Reject these
    # before using the stdlib parser (including NUL-obfuscated UTF-16 markup).
    if "\x00" in body or re.search(r"<!\s*(?:DOCTYPE|ENTITY)\b", body, re.IGNORECASE):
        raise RuntimeError("Arch news contains prohibited XML declarations")
    root = ET.fromstring(body)  # noqa: S314 -- bounded XML, DTD/entities rejected
    entries = []
    for item in root.findall("./channel/item"):
        url = item.findtext("link", "")
        entries.append(
            {
                "key": "news:" + digest(url)[:16],
                "url": url,
                "title": item.findtext("title", ""),
                "date": item.findtext("pubDate", ""),
                "text": readable(item.findtext("description", "")),
            }
        )
    if not entries:
        raise RuntimeError("Arch news feed was empty or unrecognized")
    return entries


def plan_required():
    plan = load("plan.json")
    if not plan:
        raise RuntimeError("Run check first")
    return plan


def source_key(plan, package):
    # Keep ecosystems/repos separate; Fedora architecture variants share URLs.
    return f"{package.get('manager', plan['distro'])}:{package['repo']}:{package['name']}"


def required_kinds(package):
    return ("upstream",) if package.get("manager") else ("upstream", "distro")


def news_fingerprint(item):
    return digest(item)


def pending_news(feed):
    read = load("news-read.json", {})
    # Resolved articles stay read across routine package upgrades. Unresolved
    # articles remain visible even after aging out of the finite RSS feed.
    entries = {item["key"]: item for item in feed}
    for key, record in read.items():
        if record["review"]["decision"] != "ready":
            entries.setdefault(key, record["item"])
    return [item for key, item in entries.items()
            if key not in read or read[key]["fingerprint"] != news_fingerprint(item)
            or read[key]["review"]["decision"] != "ready"]


def extra_candidates():
    """Topgrade dry-run prints commands, so query actual managers for versions."""
    packages, warnings = [], []
    if shutil.which("npm"):
        root = Path(run(["npm", "root", "--global"]).strip())
        try:
            writable = root.is_absolute() and root.is_dir() and os.access(root, os.W_OK)
        except OSError as exc:
            raise RuntimeError(f"Cannot inspect npm global root: {exc}") from exc
        if not writable:
            warnings.append("npm global prefix is not writable; skipped (no automatic sudo npm).")
        else:
            output = run(["npm", "outdated", "--global", "--json", "--long"], codes=(0, 1))
            try:
                records = json.loads(output)
            except json.JSONDecodeError as exc:
                raise RuntimeError("npm outdated returned invalid JSON") from exc
            if not isinstance(records, dict) or "error" in records:
                raise RuntimeError("npm outdated returned an error or unrecognized JSON")
            unsupported = False
            for name, item in records.items():
                if not isinstance(item, dict):
                    raise RuntimeError("npm outdated returned a malformed package record")
                old, new = item.get("current"), item.get("wanted")
                if not re.fullmatch(r"(?:@[\w.-]+/)?[\w.-]+", name):
                    raise RuntimeError(f"Unexpected npm package identity: {name}")
                if not all(isinstance(v, str) and re.fullmatch(r"\d+\.[\w.+-]+", v) for v in (old, new)):
                    warnings.append(f"npm:{name}: linked/non-registry version; entire npm update skipped because Topgrade updates all globals.")
                    unsupported = True
                    continue
                if old != new:
                    packages.append({"key": f"npm:{name}", "manager": "npm", "name": name,
                                     "old": old, "new": new, "repo": str(root),
                                     "homepage": item.get("homepage", ""), "native_changelog": False})
            if unsupported:
                packages = [package for package in packages if package.get("manager") != "npm"]
    if shutil.which("flatpak"):
        for scope in ("user", "system"):
            columns = "--columns=ref:f,version:f,commit:f,origin:f"
            installed = {}
            for line in run(["flatpak", "list", f"--{scope}", columns]).splitlines():
                ref, version, commit, origin = flatpak_record(line)
                installed[(ref, origin)] = (version, commit)
            for line in run(["flatpak", "remote-ls", f"--{scope}", "--updates", "--all", "--arch=*", columns]).splitlines():
                ref, version, commit, origin = flatpak_record(line)
                if (ref, origin) not in installed:
                    raise RuntimeError(f"Flatpak update has no installed counterpart: {scope}:{ref}:{origin}")
                old_version, old_commit = installed[(ref, origin)]
                name = ref.split("/")[-3]
                packages.append({"key": f"flatpak:{scope}:{ref}", "manager": "flatpak", "scope": scope,
                                 "name": name, "old": old_version or old_commit, "new": version or commit,
                                 "old_commit": old_commit, "new_commit": commit, "ref": ref,
                                 "repo": origin, "homepage": "", "native_changelog": False})
        if Path("/etc/flatpak/installations.d").exists():
            warnings.append("Named Flatpak installations are outside default user/system scope.")
    if len({p["key"] for p in packages}) != len(packages):
        raise RuntimeError("Ambiguous extra-manager candidates; resolve duplicate identities first")
    return sorted(packages, key=lambda p: p["key"]), warnings


def flatpak_record(line):
    fields = line.split("\t")
    if len(fields) != 4 or len(fields[0].split("/")) < 3 or not fields[2] or not fields[3]:
        raise RuntimeError(f"Unexpected Flatpak record: {line}")
    return fields


TOPGRADE_CONFIG = """[misc]
cleanup = false
no_self_update = true
no_retry = true
pre_sudo = false
run_in_tmux = false
[npm]
use_sudo = false
[flatpak]
use_sudo = false
"""


@contextlib.contextmanager
def topgrade_command(steps, dry=False):
    # Explicit config bypasses topgrade.toml AND topgrade.d (including hooks).
    with tempfile.TemporaryDirectory(prefix="pi-topgrade-") as directory:
        config = Path(directory) / "topgrade.toml"
        config.write_text(TOPGRADE_CONFIG)
        yield ["topgrade", "--config", str(config), "--no-self-update", "--no-retry", "--no-tmux",
               *(["--dry-run"] if dry else []), "--only", *steps]


def topgrade_steps(packages):
    managers = {p.get("manager") for p in packages}
    return [step for manager, step in (("npm", "node"), ("flatpak", "flatpak")) if manager in managers]


def topgrade_preview(packages):
    steps = topgrade_steps(packages)
    available = bool(shutil.which("topgrade"))
    result = {"available": available, "steps": steps, "preview": "",
              "notice": "Only npm and default user/system Flatpak are integrated; no user hooks, firmware, self-update, autoremove or other Topgrade steps."}
    if available and steps:
        with topgrade_command(steps, dry=True) as command:
            result["preview"] = run(command)
    return result


def extra_commands(packages):
    managers = {p.get("manager") for p in packages}
    commands = []
    if "npm" in managers:
        commands.append(["npm", "update", "--global"])
    if "flatpak" in managers:
        commands.extend([["flatpak", "update", "--user"], ["flatpak", "update", "--system"]])
    return commands


def scan():
    system = distro()
    native = candidates(system)
    extra, warnings = extra_candidates()
    packages = native + extra
    snapshot = inventory(system)
    feed = arch_news() if system == "arch" else []
    news = pending_news(feed)
    identity = {"distro": system, "packages": packages, "installed": digest(snapshot),
                "news": news, "news_feed_hash": digest(feed)}
    plan = {**identity, "id": digest(identity)[:20], "created": time.time(),
            "installed_inventory": snapshot, "warnings": warnings,
            "topgrade": topgrade_preview(extra), "evidence": {}, "reads": {}}
    save("plan.json", plan)
    refresh_evidence(plan)
    return report_page(status(), 0, 20)


def refresh_evidence(plan):
    # Workers only fetch; the main thread owns state. Per-item checkpoints make
    # a cancelled/failed check resumable without rewriting the growing plan N times.
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        jobs = {pool.submit(build_evidence, plan, item["key"]): item["key"]
                for item in plan["packages"] + plan["news"]}
        for job in concurrent.futures.as_completed(jobs):
            key = jobs[job]
            evidence = job.result()
            save("evidence-" + digest(key) + ".json", {"created": plan["created"], "evidence": evidence})
            plan["evidence"][key] = evidence
    save("plan.json", plan)


def report_page(report, offset, limit):
    if offset < 0 or not 1 <= limit <= 50:
        raise ValueError("Invalid page bounds")
    report["total"] = len(report["items"])
    report["pending_total"] = len(report["pending"])
    report["needs_ai_total"] = len(report["needs_ai"])
    report["items"] = report["items"][offset : offset + limit]
    keys = {item["key"] for item in report["items"]}
    report["pending"] = [key for key in report["pending"] if key in keys]
    report["needs_ai"] = [key for key in report["needs_ai"] if key in keys]
    return report


def source_state(plan, package):
    records = load("sources.json", {}).get(source_key(plan, package), {})
    return {kind: record for kind, record in records.items()
            if record.get("scope", "rolling") == "rolling"
            or record.get("versions") == [package["old"], package["new"]]}


def document(url):
    text = readable(fetch(url))
    if not text.strip():
        raise ValueError("Empty extracted evidence; choose usable release notes")
    return {"source": url, "text": text}


def build_evidence(plan, key):
    if key.startswith("news:"):
        item = next((item for item in plan["news"] if item["key"] == key), None)
        if not item:
            raise ValueError("Unknown news key")
        read = load("news-read.json", {}).get(key)
        if read and read["fingerprint"] == news_fingerprint(item):
            return read["evidence"]
        # Feed descriptions may be excerpts; fetch the complete unread article.
        try:
            evidence = {"key": key, "documents": [document(item["url"])],
                        "errors": [], "missing": [], "absent": []}
        except (OSError, ValueError, RuntimeError) as exc:
            evidence = {
                "key": key,
                "documents": [],
                "errors": [str(exc)],
                "missing": [],
            }
    else:
        package = next((item for item in plan["packages"] if item["key"] == key), None)
        if not package:
            raise ValueError("Unknown package key")
        sources = source_state(plan, package)
        documents, errors, missing, absent = [], [], [], []
        for kind in required_kinds(package):
            if kind == "distro" and package["native_changelog"]:
                try:
                    text = run(
                        [
                            "dnf",
                            "repoquery",
                            "--upgrades",
                            "--latest-limit=1",
                            "--changelogs",
                            package["key"],
                        ]
                    )
                    if not text.strip():
                        missing.append("distro: empty RPM changelog")
                    else:
                        documents.append(
                            {
                                "source": "RPM repository changelog metadata",
                                "text": text,
                            }
                        )
                except (RuntimeError, subprocess.TimeoutExpired) as exc:
                    errors.append(str(exc))
                continue
            record = sources.get(kind)
            if record is None:
                missing.append(f"{kind}: not searched")
            elif not record.get("urls", [record.get("url")] if record.get("url") else []):
                absent.append(f"{kind}: confirmed absent ({record['reason']})")
            else:
                for url in record.get("urls", [record["url"]] if record.get("url") else []):
                    try:
                        documents.append(document(url))
                    except (OSError, ValueError, RuntimeError) as exc:
                        errors.append(f"{kind}: {exc}")
        evidence = {
            "key": key,
            "documents": documents,
            "errors": errors,
            "missing": missing,
            "absent": absent,
        }
    evidence.setdefault("absent", [])
    evidence["hash"] = digest(evidence)
    return evidence


def evidence_for(plan, key, refresh=False):
    # Explicit refresh retries unresolved articles; normal checks fetch only unread.
    if refresh and key.startswith("news:"):
        read = load("news-read.json", {})
        read.pop(key, None)
        save("news-read.json", read)
    evidence = build_evidence(plan, key)
    plan["evidence"][key] = evidence
    plan.setdefault("reads", {}).pop(key, None)
    save("evidence-" + digest(key) + ".json", {"created": plan["created"], "evidence": evidence})
    save("plan.json", plan)
    return evidence


def review_key(plan, key, evidence):
    package = next((item for item in plan["packages"] if item["key"] == key), None)
    return digest(
        {
            "distro": plan["distro"],
            "package": package,
            "key": key,
            "hash": evidence["hash"],
            "installed": plan["installed"] if key.startswith("news:") else None,
        }
    )


def cached_evidence(plan, key):
    evidence = plan["evidence"].get(key)
    if evidence is None:
        checkpoint = load("evidence-" + digest(key) + ".json", {})
        if checkpoint.get("created") == plan["created"]:
            evidence = checkpoint["evidence"]
            plan["evidence"][key] = evidence
    return evidence


def status():
    plan = plan_required()
    reviews = load("reviews.json", {})
    read_news = load("news-read.json", {})
    items = []
    for item in plan["packages"] + plan["news"]:
        key = item["key"]
        evidence = cached_evidence(plan, key)
        review = reviews.get(review_key(plan, key, evidence)) if evidence else None
        if key.startswith("news:"):
            # The read marker is authoritative: a revised RSS item or explicit
            # reset must be reconsidered even if the old article hash is identical.
            review = None
            read = read_news.get(key)
            if read and read["fingerprint"] == news_fingerprint(item) and evidence and evidence["hash"] == read["evidence"]["hash"]:
                review = read["review"]
        record = {**item, "review": review, "evidence_cached": evidence is not None}
        if not key.startswith("news:"):
            sources = source_state(plan, item)
            record["sources"] = sources
            record["search_needed"] = [kind for kind in required_kinds(item)
                                       if kind not in sources and not (kind == "distro" and item["native_changelog"])]
            if not review and evidence and not evidence["documents"] and not record["search_needed"]:
                # Absence and transport failures need visibility, not recurring AI.
                unavailable = not evidence["errors"] and not evidence["missing"] and bool(evidence.get("absent"))
                record["review"] = {"decision": "unavailable" if unavailable else "unknown",
                                    "summary": "; ".join(evidence["errors"] + evidence["missing"] + evidence.get("absent", [])),
                                    "automatic": True}
        items.append(record)
    pending = [item["key"] for item in items if not item["review"] or item["review"]["decision"] != "ready"]
    return {"id": plan["id"], "distro": plan["distro"], "created": plan["created"],
            "package_count": len(plan["packages"]), "news_count": len(plan["news"]),
            "pending": pending, "needs_ai": [item["key"] for item in items if not item["review"]],
            "items": items, "review_digest": digest([{ "key": item["key"], "review": item["review"] } for item in items]),
            "warnings": plan.get("warnings", []), "topgrade": plan.get("topgrade", {}),
            "notice": "Candidates, not a solved transaction. Inspect dependencies/replacements/removals in the manager. AUR builds, pipx, other Topgrade steps, local recipes and firmware are outside this plan."}


def set_source(request):
    plan = plan_required()
    package = next(
        (item for item in plan["packages"] if item["key"] == request["key"]), None
    )
    if not package:
        raise ValueError("Unknown package")
    kind = request["kind"]
    if kind not in required_kinds(package):
        raise ValueError("Invalid source kind for this manager")
    urls = request.get("urls", [request["url"]] if request.get("url") else [])
    if not isinstance(urls, list) or len(urls) > 20 or any(not isinstance(url, str) for url in urls):
        raise ValueError("Provide at most 20 HTTPS document URLs")
    reason = request.get("reason", "").strip()
    if not reason or len(reason) > 2000:
        raise ValueError("Record verified provenance/absence rationale (1–2000 characters)")
    for url in urls:
        document(url)
    scope = request.get("scope", "versions" if urls else "rolling")
    if scope not in {"rolling", "versions"}:
        raise ValueError("Invalid source scope")
    sources = load("sources.json", {})
    sources.setdefault(source_key(plan, package), {})[kind] = {
        "urls": list(dict.fromkeys(urls)), "reason": reason, "scope": scope,
        "versions": [package["old"], package["new"]], "checked": time.time(),
    }
    save("sources.json", sources)
    # Invalidate all arch variants of this package in this plan.
    for item in plan["packages"]:
        if source_key(plan, item) == source_key(plan, package):
            invalidate_evidence(plan, item["key"])
    save("plan.json", plan)
    return {"saved": source_key(plan, package), "kind": kind, "urls": urls, "scope": scope}


def invalidate_evidence(plan, key):
    plan["evidence"].pop(key, None)
    plan.setdefault("reads", {}).pop(key, None)
    (STATE / ("evidence-" + digest(key) + ".json")).unlink(missing_ok=True)


def set_review(request):
    plan = plan_required()
    key = request["key"]
    evidence = cached_evidence(plan, key)
    if not evidence or evidence["hash"] != request["hash"]:
        raise ValueError("Evidence missing or changed; fetch and review again")
    decision = request["decision"]
    if decision not in {"ready", "attention", "unknown"}:
        raise ValueError("Invalid review decision")
    if decision == "ready":
        documents = evidence["documents"]
        if evidence["errors"] or evidence["missing"] or not documents or any(not doc["text"].strip() for doc in documents):
            raise ValueError("Incomplete/empty evidence cannot be marked ready; record unknown")
        receipt = plan.get("reads", {}).get(key, {})
        if receipt.get("hash") != evidence["hash"] or any(
            receipt.get("documents", {}).get(str(index)) != [[0, len(doc["text"])]]
            for index, doc in enumerate(documents)
        ):
            raise ValueError("Page every evidence document before marking ready")
    summary = request.get("reason", "").strip()
    if not summary or len(summary) > 4000:
        raise ValueError(
            "A review summary with version coverage and any actions is required"
        )
    reviews = load("reviews.json", {})
    follow_up = request.get("follow_up", "").strip()
    if len(follow_up) > 2000:
        raise ValueError("Post-update instructions must be at most 2000 characters")
    review = {"decision": decision, "summary": summary, "follow_up": follow_up, "reviewed": time.time()}
    reviews[review_key(plan, key, evidence)] = review
    save("reviews.json", reviews)
    if key.startswith("news:"):
        item = next(item for item in plan["news"] if item["key"] == key)
        read = load("news-read.json", {})
        read[key] = {"fingerprint": news_fingerprint(item), "item": item,
                     "review": review, "evidence": evidence}
        save("news-read.json", read)
    return {"key": key, "decision": decision}


def record_read(plan, key, evidence, index, start, end):
    receipt = plan.setdefault("reads", {}).setdefault(key, {"hash": evidence["hash"], "documents": {}})
    if receipt["hash"] != evidence["hash"]:
        receipt.update(hash=evidence["hash"], documents={})
    ranges = sorted(receipt["documents"].get(str(index), []) + [[start, end]])
    merged = []
    for left, right in ranges:
        if merged and left <= merged[-1][1]:
            merged[-1][1] = max(merged[-1][1], right)
        else:
            merged.append([left, right])
    receipt["documents"][str(index)] = merged
    save("plan.json", plan)


def audit():
    system = distro()
    commands = {"failed_services": ["systemctl", "--failed", "--no-pager", "--plain"]}
    if system == "arch":
        commands.update(
            orphan_candidates=["pacman", "-Qdtq"], foreign_packages=["pacman", "-Qm"]
        )
    else:
        commands.update(
            unneeded_candidates=["dnf", "repoquery", "--unneeded"],
            duplicates=["dnf", "repoquery", "--duplicates"],
        )
    report = {
        "distro": system,
        "configuration_files": [],
        "dangling_links": [],
        "redundant_configs": [],
        "results": {},
        "errors": {},
        "notice": "Read-only suggestions. Never automatically remove or merge these; clean rebuild is the declarative reconciliation boundary.",
    }
    suffixes = (".pacnew", ".pacsave") if system == "arch" else (".rpmnew", ".rpmsave")
    for directory, dirs, files in os.walk("/etc"):
        for name in dirs + files:
            path = Path(directory) / name
            try:
                if path.is_symlink() and not path.exists():
                    report["dangling_links"].append(str(path))
                if name.endswith(suffixes):
                    report["configuration_files"].append(str(path))
                    if redundant_config(path):
                        report["redundant_configs"].append(str(path))
            except OSError as exc:
                report["errors"][str(path)] = str(exc)
    for key, command in commands.items():
        try:
            report["results"][key] = run(
                command, codes=(0, 1) if key == "orphan_candidates" else (0,)
            )
        except (OSError, RuntimeError, subprocess.SubprocessError) as exc:
            report["errors"][key] = str(exc)
    save("audit.json", report)
    return report


def redundant_config(path):
    # Never touch .pacsave/.rpmsave backups, changed configs, or symbolic links.
    if path.suffix not in {".pacnew", ".rpmnew"}:
        return False
    original = path.with_suffix("")
    if path.is_symlink() or original.is_symlink() or not path.is_file() or not original.is_file():
        return False
    new, old = path.stat(), original.stat()
    if new.st_size > MAX_BODY or (new.st_size, new.st_mode, new.st_uid, new.st_gid) != (old.st_size, old.st_mode, old.st_uid, old.st_gid):
        return False
    if path.read_bytes() != original.read_bytes():
        return False
    # ACLs/SELinux labels are metadata too; do not discard a changed attribute.
    def attributes(file):
        return {name: os.getxattr(file, name) for name in os.listxattr(file)}
    return attributes(path) == attributes(original)


def cleanup():
    """Conservative, unprivileged housekeeping. All ambiguous debris is reported."""
    report = audit()
    removed, errors = [], {}
    for name in report["redundant_configs"]:
        path = Path(name)
        try:
            # Root-owned configs need an explicit administrator decision, not an
            # automatic sudo escalation or an arbitrary deletion tool for the AI.
            parent = path.parent.stat()
            if path.stat().st_uid == os.getuid() and parent.st_uid == os.getuid() and not parent.st_mode & 0o022 and redundant_config(path):
                path.unlink()
                removed.append(name)
        except OSError as exc:
            errors[name] = str(exc)
    plan = load("plan.json", {})
    keep = {"evidence-" + digest(item["key"]) + ".json"
            for item in plan.get("packages", []) + plan.get("news", [])}
    for path in list(STATE.glob("evidence-*.json")) + list(STATE.glob("result-*.json")):
        try:
            if path.name not in keep and not path.is_symlink() and path.stat().st_mtime < time.time() - 30 * 86400:
                path.unlink()
                removed.append(str(path))
        except OSError as exc:
            errors[str(path)] = str(exc)
    return {"removed": removed, "errors": errors,
            "manual": [name for name in report["configuration_files"] if name not in removed],
            "dangling_links": report["dangling_links"],
            "notice": "Only old extension evidence and identical user-owned .pacnew/.rpmnew removed. Changed/root-owned configs, dangling links, backups, orphan packages and kernels require explicit review."}


def transaction(plan_id, command):
    save("transaction.json", {"plan": plan_id, "command": command,
                              "started": time.time(), "status": "in-progress"})
    result = subprocess.run(command, env=ENV, check=False)
    save("transaction.json", {"plan": plan_id, "command": command,
                              "finished": time.time(), "exit_code": result.returncode})
    if result.returncode:
        raise RuntimeError(f"Update exited {result.returncode}; inspect native logs, no automatic retry/repair")


def apply(plan_id, allow_unresolved=False, approval=None):
    if not sys.stdin.isatty() or not sys.stdout.isatty():
        raise RuntimeError("Apply requires an interactive terminal")
    plan = plan_required()
    if plan["id"] != plan_id or time.time() - plan["created"] > 3600:
        raise RuntimeError("Plan changed or is older than one hour; run check again")
    system = distro()
    if system != plan["distro"] or digest(inventory(system)) != plan["installed"]:
        raise RuntimeError("Installed package state changed; run check again")
    native = [p for p in plan["packages"] if not p.get("manager")]
    extra = [p for p in plan["packages"] if p.get("manager")]
    if candidates(system) != native:
        raise RuntimeError("Upgrade candidates changed; run check and review again")
    current_extra, _ = extra_candidates()
    if current_extra != extra:
        raise RuntimeError("Extra-manager candidates changed; run check again")
    if bool(shutil.which("topgrade")) != plan.get("topgrade", {}).get("available", False):
        raise RuntimeError("Topgrade availability changed; run check again")
    if system == "arch":
        feed = arch_news()
        if digest(feed) != plan.get("news_feed_hash", digest(plan["news"])):
            raise RuntimeError("Arch news changed; run check and review again")
    before = {item["key"]: (cached_evidence(plan, item["key"]) or {}).get("hash")
              for item in plan["packages"] + plan["news"]}
    refresh_evidence(plan)
    changed = [key for key, old_hash in before.items() if plan["evidence"][key]["hash"] != old_hash]
    if changed:
        raise RuntimeError(f"Evidence changed; review again: {', '.join(changed)}")
    report = status()
    if approval is not None and approval != report["review_digest"]:
        raise RuntimeError("Review decisions changed after confirmation; inspect the new findings first")
    if report["pending"] and not allow_unresolved:
        raise RuntimeError("Unresolved reviews; explicitly accept their listed risks in Pi")
    if not plan["packages"]:
        return {"outcome": "no-op", "updated": False, "reason": "No supported package upgrades"}
    # One Pi confirmation; each native manager still presents its own proposal.
    print(f"Reviewed plan {plan_id}: {len(plan['packages'])} package candidates.")
    print("Inspect dependencies/replacements/removals and decline unexplained changes. No automatic repair.")
    if report["pending"]:
        print("Accepted unresolved coverage:", ", ".join(report["pending"]))
    if native:
        transaction(plan_id, ["sudo", "pacman", "-Syu"] if system == "arch" else ["sudo", "dnf", "upgrade", "--refresh"])
    steps = topgrade_steps(extra)
    if steps and plan.get("topgrade", {}).get("available"):
        with topgrade_command(steps) as command:
            transaction(plan_id, command)
    else:
        for command in extra_commands(extra):
            transaction(plan_id, command)
    updated = digest(inventory(system)) != plan["installed"]
    if extra:
        remaining, _ = extra_candidates()
        updated = updated or remaining != extra
    housekeeping = cleanup()
    save("last-success.json", {"plan": plan_id, "finished": time.time(), "updated": updated})
    return {"outcome": "completed" if updated else "no-op", "updated": updated,
            "cleanup": housekeeping, "audit": load("audit.json"),
            "notice": "Inspect native output and reboot/UKI hooks. No hardware behavior was validated."}


def dispatch(request):
    action = request["action"]
    if action == "check":
        return scan()
    if action == "status":
        return report_page(status(), request.get("offset", 0), request.get("limit", 20))
    if action == "forget-news":
        read = load("news-read.json", {})
        if request.get("key"):
            read.pop(request["key"], None)
        else:
            read.clear()
        save("news-read.json", read)
        return {"reset": request.get("key", "all"), "notice": "Run check again to reread news"}
    if action == "result":
        result = load("result-" + digest(request["key"]) + ".json")
        if result is None:
            raise RuntimeError("No result for this attempt; it may have been interrupted")
        return result
    if action == "inventory":
        snapshot = plan_required().get("installed_inventory")
        if snapshot is None:
            raise RuntimeError("Old plan has no inventory; run check again")
        rows = [line for line in snapshot if request.get("key", "") in line]
        offset, limit = request.get("offset", 0), request.get("limit", 50)
        if offset < 0 or not 1 <= limit <= 50:
            raise ValueError("Invalid inventory page bounds")
        return {"total": len(rows), "items": rows[offset:offset + limit]}
    if action == "evidence":
        plan = plan_required()
        key = request["key"]
        evidence = cached_evidence(plan, key)
        if evidence is None or request.get("refresh", False):
            evidence = evidence_for(plan, key, refresh=request.get("refresh", False))
        # Paginate one document; never silently truncate evidence before reviewing.
        index, offset, limit = (
            request.get("document", 0),
            request.get("offset", 0),
            request.get("limit", 4000),
        )
        if index < 0 or offset < 0 or not 1 <= limit <= 4000:
            raise ValueError("Invalid evidence bounds")
        documents = evidence["documents"]
        document = documents[index] if index < len(documents) else None
        if document and offset > len(document["text"]):
            raise ValueError("Offset exceeds document length")
        if document:
            record_read(plan, key, evidence, index, offset, min(offset + limit, len(document["text"])))
        return {
            "key": key,
            "hash": evidence["hash"],
            "errors": evidence["errors"],
            "missing": evidence["missing"],
            "absent": evidence.get("absent", []),
            "document_count": len(documents),
            "document": index,
            "source": document["source"] if document else None,
            "total_chars": len(document["text"]) if document else 0,
            "text": document["text"][offset : offset + limit] if document else "",
        }
    if action == "source":
        return set_source(request)
    if action == "review":
        return set_review(request)
    if action == "forget-source":
        plan = plan_required()
        package = next(
            item for item in plan["packages"] if item["key"] == request["key"]
        )
        sources = load("sources.json", {})
        sources.get(source_key(plan, package), {}).pop(request["kind"], None)
        save("sources.json", sources)
        for item in plan["packages"]:
            if source_key(plan, item) == source_key(plan, package):
                invalidate_evidence(plan, item["key"])
        save("plan.json", plan)
        return {"forgotten": request["key"]}
    if action == "audit":
        return audit()
    if action == "cleanup":
        return cleanup()
    raise ValueError("Unknown action")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--request",
        help="JSON request (check/status/evidence/source/review/audit/forget-source)",
    )
    parser.add_argument("--apply", metavar="PLAN_ID")
    parser.add_argument("--allow-unresolved", action="store_true")
    parser.add_argument("--attempt", help="Unique Pi apply attempt identifier for structured results")
    parser.add_argument("--approval", help="Exact review digest displayed by Pi before confirmation")
    args = parser.parse_args()
    try:
        if os.geteuid() == 0:
            raise RuntimeError(
                "Run as your ordinary user, not root; apply invokes sudo only for the manager"
            )
        with locked():
            result = (
                apply(args.apply, args.allow_unresolved, args.approval)
                if args.apply
                else dispatch(json.loads(args.request or '{"action":"status"}'))
            )
        if args.apply and args.attempt:
            save("result-" + digest(args.attempt) + ".json", result)
        print(json.dumps({"outcome": result["outcome"], "updated": result["updated"]} if args.apply else result, indent=2))
    except Exception as exc:  # noqa: BLE001 -- CLI boundary, report and exit nonzero
        if args.apply and args.attempt:
            save("result-" + digest(args.attempt) + ".json", {"outcome": "failed", "error": str(exc)})
        print(json.dumps({"error": str(exc)}), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
