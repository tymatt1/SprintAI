#!/usr/bin/env python3
"""Check staged files and the publication branch history without printing credential contents."""
import argparse
from pathlib import Path
import re
import subprocess
import sys

PATTERNS = [
    re.compile(rb"sk-(?:proj-|svcacct-)?[A-Za-z0-9_-]{20,}"),
    re.compile(rb"(?:AKIA|ASIA)[A-Z0-9]{16}"),
    re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    re.compile(rb"gh[pousr]_[A-Za-z0-9]{30,}"),
]


def git(*args):
    return subprocess.check_output(["git", *args])


def scan(data, label):
    if any(pattern.search(data) for pattern in PATTERNS):
        print(f"Possible credential detected in {label}; value withheld.")
        return False
    return True


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--history", action="store_true")
    args = parser.parse_args()
    ok = True
    paths = git("ls-files", "-z").decode().split("\0")
    for name in filter(None, paths):
        path = Path(name)
        if not path.is_file():
            continue
        if name.startswith(("Pods/", ".local/")) or "xcuserdata/" in name or path.suffix == ".csv":
            print(f"Private/generated file must not be tracked: {name}")
            ok = False
        if path.stat().st_size > 20 * 1024 * 1024:
            print(f"Unexpected large tracked file: {name}")
            ok = False
        if path.suffix not in (".png", ".mp3", ".task", ".mlmodel", ".bin"):
            ok = scan(git("show", ":" + name), name) and ok
    if args.history:
        objects = git("rev-list", "--objects", "HEAD").decode().splitlines()
        for entry in objects:
            fields = entry.split(" ", 1)
            if len(fields) != 2:
                continue
            oid, name = fields
            if git("cat-file", "-t", oid).strip() == b"blob":
                ok = scan(git("cat-file", "blob", oid), f"history:{name}") and ok
    print("Repository checks passed." if ok else "Repository checks failed.")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
