#!/usr/bin/env python3
"""Lightweight repository checks for local frontend assets and JavaScript syntax."""
from html.parser import HTMLParser
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
HTML_FILES = sorted(ROOT.rglob("*.html"))
JS_FILES = sorted(p for p in ROOT.rglob("*.js") if "node_modules" not in p.parts and ".git" not in p.parts)
ERRORS = []

class AssetParser(HTMLParser):
    def __init__(self, file):
        super().__init__(convert_charrefs=True)
        self.file = file
        self.inline = []
        self.current = None

    def handle_starttag(self, tag, attrs):
        if tag.lower() != "script":
            return
        attrs = dict(attrs)
        src = attrs.get("src")
        if src and not src.startswith(("http://", "https://", "//", "data:")):
            clean_src = src.split("?", 1)[0].split("#", 1)[0]
            target = ((ROOT / clean_src.lstrip("/")) if clean_src.startswith("/") else (self.file.parent / clean_src)).resolve()
            if not target.exists():
                ERRORS.append(f"{self.file.relative_to(ROOT)}: missing script asset: {src}")
        if not src:
            kind = (attrs.get("type") or "").lower()
            if kind in ("", "text/javascript", "application/javascript", "module"):
                self.current = []

    def handle_data(self, data):
        if self.current is not None:
            self.current.append(data)

    def handle_endtag(self, tag):
        if tag.lower() == "script" and self.current is not None:
            source = "".join(self.current)
            if source.strip():
                self.inline.append(source)
            self.current = None

def check_js(source, label):
    proc = subprocess.run(
        ["node", "--check", "--input-type=module"],
        input=source, text=True, capture_output=True
    )
    if proc.returncode:
        ERRORS.append(f"{label}: JavaScript syntax error\n{proc.stderr.strip()}")

for file in HTML_FILES:
    parser = AssetParser(file)
    try:
        parser.feed(file.read_text(encoding="utf-8"))
    except Exception as exc:
        ERRORS.append(f"{file.relative_to(ROOT)}: HTML parse error: {exc}")
        continue
    for index, source in enumerate(parser.inline, 1):
        check_js(source, f"{file.relative_to(ROOT)} inline script #{index}")

for file in JS_FILES:
    check_js(file.read_text(encoding="utf-8"), str(file.relative_to(ROOT)))

if ERRORS:
    print("\n".join(f"ERROR: {item}" for item in ERRORS))
    print(f"\nFrontend validation failed: {len(ERRORS)} issue(s).")
    sys.exit(1)

print(f"Frontend validation passed: {len(HTML_FILES)} HTML files, {len(JS_FILES)} JS files.")
