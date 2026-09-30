#!/usr/bin/env python3
"""Validates the course files in course/ and writes the app's deck.json.

Usage:
    python3 tools/build_deck.py                 # validate and write the deck
    python3 tools/build_deck.py --check-links   # also request every reading link
"""
import argparse
import concurrent.futures
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
COURSE = ROOT / "course"
CARD_FILES = ["bricks.json", "rules.json", "assemblies.json", "path.json", "platform.json", "data.json", "ml.json", "inference.json"]
DECK = ROOT / "app" / "Sources" / "SystemLegos" / "Resources" / "deck.json"

REQUIRED = {"id", "kind", "module", "group", "title", "summary", "sections", "links"}
OPTIONAL = {"subtitle", "lego", "steps", "uses"}
LINK_KINDS = {"paper", "blog", "docs", "book", "talk", "tool", "course"}
USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Safari/605.1.15"


def load(name):
    with open(COURSE / name, encoding="utf-8") as f:
        return json.load(f)


def validate(modules, cards):
    errors = []
    groups = {(m["id"], g["id"]) for m in modules for g in m["groups"]}
    ids = [c.get("id") for c in cards]
    known = set(ids)
    for dup in sorted({i for i in ids if ids.count(i) > 1}):
        errors.append(f"duplicate card id: {dup}")
    for c in cards:
        cid = c.get("id", "?")
        missing = REQUIRED - c.keys()
        extra = c.keys() - REQUIRED - OPTIONAL
        if missing:
            errors.append(f"{cid}: missing {sorted(missing)}")
        if extra:
            errors.append(f"{cid}: unknown fields {sorted(extra)}")
        if c.get("kind") not in ("brick", "build"):
            errors.append(f"{cid}: kind must be brick or build")
        if (c.get("module"), c.get("group")) not in groups:
            errors.append(f"{cid}: unknown module/group {c.get('module')}/{c.get('group')}")
        if c.get("kind") == "build" and not c.get("steps"):
            errors.append(f"{cid}: builds need steps")
        for ref in c.get("uses") or []:
            if ref not in known:
                errors.append(f"{cid}: uses unknown card {ref}")
        for s in c.get("sections", []):
            if not s.get("title") or not s.get("items"):
                errors.append(f"{cid}: empty section {s.get('title')!r}")
        for link in c.get("links", []):
            if not str(link.get("url", "")).startswith("https://"):
                errors.append(f"{cid}: link must be https: {link.get('url')}")
            if link.get("kind") not in LINK_KINDS:
                errors.append(f"{cid}: link kind {link.get('kind')!r} not in {sorted(LINK_KINDS)}")
            if "note" not in link:
                errors.append(f"{cid}: link {link.get('url')} needs a note (null is fine)")
    return errors


def check(url):
    for method in ("HEAD", "GET"):
        req = urllib.request.Request(url, method=method, headers={"User-Agent": USER_AGENT})
        try:
            with urllib.request.urlopen(req, timeout=20) as resp:
                return url, resp.status, None
        except urllib.error.HTTPError as e:
            if method == "GET" or e.code not in (403, 405, 400, 404, 429, 501):
                return url, e.code, None
        except Exception as e:  # noqa: BLE001 - report any network failure
            if method == "GET":
                return url, None, str(e)
    return url, None, "unreachable"


def check_links(cards):
    urls = sorted({link["url"] for c in cards for link in c["links"]})
    print(f"Checking {len(urls)} links…")
    bad = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:
        for url, status, err in pool.map(check, urls):
            if status is None or status >= 400:
                bad.append((url, status, err))
    for url, status, err in bad:
        print(f"  {status or 'ERR'}  {url}  {err or ''}")
    print(f"{len(urls) - len(bad)} ok, {len(bad)} failed")
    return not bad


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check-links", action="store_true", help="request every reading link")
    args = parser.parse_args()

    modules = load("modules.json")
    cards = [c for name in CARD_FILES for c in load(name)]
    errors = validate(modules, cards)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        sys.exit(1)

    order = {(m["id"], g["id"]): i for i, (m, g) in enumerate((m, g) for m in modules for g in m["groups"])}
    cards.sort(key=lambda c: order[(c["module"], c["group"])])
    for c in cards:
        for key in OPTIONAL:
            c.setdefault(key, None)

    DECK.parent.mkdir(parents=True, exist_ok=True)
    with open(DECK, "w", encoding="utf-8") as f:
        json.dump({"modules": modules, "cards": cards}, f, ensure_ascii=False, indent=1)
        f.write("\n")

    bricks = sum(c["kind"] == "brick" for c in cards)
    links = sum(len(c["links"]) for c in cards)
    print(f"Wrote {DECK.relative_to(ROOT)}: {bricks} bricks, {len(cards) - bricks} builds, {links} reading links")
    for m in modules:
        n = sum(c["module"] == m["id"] for c in cards)
        print(f"  {m['title']}: {n} cards")

    if args.check_links and not check_links(cards):
        sys.exit(2)


if __name__ == "__main__":
    main()
