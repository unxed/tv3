#!/usr/bin/env python3
"""The text policy of this repository: tools/text-policy.py (exit code 1 when it is broken).

1. Every tracked text file is UTF-8 (no code page bytes, no U+FFFD, no byte order mark).
2. Comments, documents, hard-coded strings and demo texts are English. Cyrillic is allowed only where it is data: the examples of a comment
   about a Cyrillic letter, and the tests (the text that a test feeds to the code).
3. No legacy single-byte glyph in a source: a frame, a shade or a block is a name of TvGlyphs (glLightH ...), not #196 or #$C4. The only
   places with bytes of the IBM PC set are tvglyphs.pas itself (the table), tvcp.inc (generated) and the tests of the code pages.
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CYR = re.compile("[\u0400-\u04ff]")
CYRILLIC_OK = [
    r"^tests/",            # the text of a test is data
    r"^dostests/",
    r"^src/tvutf8\.pas$",  # an example of a CP866 text that is valid UTF-8 (a comment)
    r"^src/tvtermio\.pas$",  # an example of a key of the Russian layout (a comment)
    r"^src/tvxlat\.pas$",    # the keyboard layouts are the data of the unit
    r"^src/tvapp\.pas$",     # an example of a key of the Russian layout (a comment)
]
GLYPH_BYTES_OK = [r"^src/tvglyphs\.pas$", r"^src/tvcp\.inc$", r"^src/tvwidth\.inc$", r"^tests/", r"^dostests/"]
GLYPH = re.compile(r"#(17[6-9]|18[0-9]|19[0-9]|2[01][0-9]|22[0-3]|240|249|25[0-4])\b|#\$(B[0-9A-Fa-f]|[C-D][0-9A-Fa-f]|F0|F9|FA|FB|FC|FD|FE)\b", re.I)
PAS = re.compile(r"\.(pas|inc)$")


def tracked():
    out = subprocess.check_output(["git", "-C", str(ROOT), "ls-files", "-z"]).decode("utf-8")
    for name in out.split("\0"):
        if name and (ROOT / name).is_file():
            yield name, (ROOT / name).read_bytes()


def any_match(patterns, name):
    return any(re.search(p, name) for p in patterns)


def code_only(text):
    """A Pascal text without its comments (the strings stay)."""
    out, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        if c == "'":
            j = i + 1
            while j < n and text[j] != "\n" and not (text[j] == "'" and text[j + 1:j + 2] != "'"):
                j += 2 if text[j] == "'" else 1
            out.append(text[i:j + 1])
            i = j + 1
        elif c == "{":
            j = text.find("}", i)
            i = n if j < 0 else j + 1
        elif text.startswith("(*", i):
            j = text.find("*)", i + 2)
            i = n if j < 0 else j + 2
        elif text.startswith("//", i):
            j = text.find("\n", i)
            i = n if j < 0 else j
        else:
            out.append(c)
            i += 1
    return "".join(out)


def check():
    problems = []
    for name, data in tracked():
        if b"\0" in data:
            continue
        try:
            text = data.decode("utf-8")
        except UnicodeDecodeError as error:
            problems.append("%s: not UTF-8 (byte %d)" % (name, error.start))
            continue
        if text.startswith("\ufeff") or "\ufffd" in text:
            problems.append("%s: byte order mark or U+FFFD" % name)
        if CYR.search(text) and not any_match(CYRILLIC_OK, name):
            problems.append("%s: Cyrillic outside the allowed files (translate it, or list the file in tools/text-policy.py)" % name)
        if PAS.search(name) and not any_match(GLYPH_BYTES_OK, name):
            for number, line in enumerate(code_only(text).split("\n"), 1):
                if GLYPH.search(line):
                    problems.append("%s: a single-byte glyph in the code (use a name of TvGlyphs): %s" % (name, line.strip()[:80]))
                    break
    return problems


if __name__ == "__main__":
    found = check()
    for problem in found:
        print("POLICY:", problem)
    print("text policy: %d problems" % len(found))
    sys.exit(1 if found else 0)
