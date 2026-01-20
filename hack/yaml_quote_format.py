#!/usr/bin/env python3
"""
yaml_quote_format.py

Rewrite YAML by ONLY adjusting quotes around simple scalar values.

Capabilities:
- Process a single file, or recursively traverse a directory to process all *.yml/*.yaml files.
- Optional in-place edits.
- Conservative behavior: only edits simple single-line scalar values of the form:
    key: "value"
    key: 'value'
    - key: "value"

Safety goals:
- Never change the effective YAML type:
  - Keep quotes for values that look like numbers/bools/null/yes-no/on-off/inf/nan/date/time.
- Only remove quotes when the result is clearly safe as a plain YAML scalar.
- Skip complex YAML constructs (block scalars, flow collections, etc.).
"""

from __future__ import annotations

import argparse
import fnmatch
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Iterator, List, Optional, Sequence, Tuple

# ─────────────────────────────────────────────────────────────────────────────
# YAML scalar keywords that change meaning when unquoted (YAML 1.1 + common)
# ─────────────────────────────────────────────────────────────────────────────
KEYWORDS = {
    "true", "false", "True", "False", "TRUE", "FALSE",
    "null", "Null", "NULL", "~",
    "yes", "no", "on", "off", "Yes", "No", "On", "Off", "YES", "NO", "ON", "OFF",
    ".nan", ".NaN", ".NAN",
    ".inf", ".Inf", ".INF",
    "-.inf", "-.Inf", "-.INF",
    "+.inf", "+.Inf", "+.INF",
}

# ─────────────────────────────────────────────────────────────────────────────
# Regexes for values that YAML auto-types when unquoted
# ─────────────────────────────────────────────────────────────────────────────

# Integer:
#   0, 10, -42, 1_000
RE_INT = re.compile(r"^[+-]?(0|[1-9][0-9_]*)$")

# Float / scientific notation:
#   1.23, .5, 10., 1e5, -2.3E-4
RE_FLOAT = re.compile(
    r"^[+-]?("
    r"([0-9][0-9_]*\.[0-9_]*([eE][+-]?[0-9_]+)?)|"
    r"(\.[0-9_]+([eE][+-]?[0-9_]+)?)|"
    r"([0-9][0-9_]*([eE][+-]?[0-9_]+))"
    r")$"
)

# ISO-like date:
#   2026-01-20
RE_DATE = re.compile(r"^[0-9]{4}-[0-9]{2}-[0-9]{2}$")

# Time-like values:
#   12:30, 12:30:45
RE_TIME = re.compile(r"^[0-9]{2}:[0-9]{2}(:[0-9]{2})?$")

# ─────────────────────────────────────────────────────────────────────────────
# Characters that make a YAML plain scalar unsafe
# (spaces, comments, flow indicators, special prefixes, etc.)
# ─────────────────────────────────────────────────────────────────────────────
RISKY_CHARS = set(" \t:#{}[],&*?!|>'\"%@`")

# ─────────────────────────────────────────────────────────────────────────────
# Regex to match *simple* quoted key/value pairs
#
# Matches:
#   key: "value"
#   key: 'value'
#   - key: "value"
#
# Does NOT match:
#   complex keys
#   flow collections
#   multiline values
# ─────────────────────────────────────────────────────────────────────────────
KV_RE = re.compile(
    r"""^(
        [\t ]*                 # indentation
        (?:-[\t ]+)?           # optional list dash
        (?:[^:#\n]+?)          # key (conservative)
        [\t ]*:\s*             # colon separator
    )(
        (["'])                 # opening quote
        (.*)                   # inner value
        \3                     # matching closing quote
    )$""",
    re.VERBOSE,
)


@dataclass(frozen=True)
class Change:
    """Represents a single file rewrite result."""
    path: Path
    changed: bool
    lines_changed: int


def split_inline_comment(line: str) -> Tuple[str, str]:
    """
    Split a line into (content, comment).

    Conservative behavior:
    - Only splits on '#' that is not inside single or double quotes.
    - Requires whitespace before '#' to reduce false positives.

    Returns:
        (left_side, comment) where comment includes the leading '#',
        or ("line", "") if no comment is found.
    """
    in_single = False
    in_double = False
    escaped = False

    for i, ch in enumerate(line):
        if escaped:
            escaped = False
            continue

        # Only backslash-escapes inside double quotes matter here.
        if ch == "\\" and in_double:
            escaped = True
            continue

        if ch == "'" and not in_double:
            in_single = not in_single
        elif ch == '"' and not in_single:
            in_double = not in_double

        # Comment start: whitespace + '#' outside quotes.
        if ch == "#" and not in_single and not in_double and i > 0 and line[i - 1].isspace():
            return line[:i].rstrip(), line[i:]

    return line.rstrip(), ""


def is_typey_or_keyword(value: str) -> bool:
    """
    Return True if the string would change meaning/type when unquoted in YAML.

    Includes:
    - booleans / null keywords
    - integers and floats
    - dates and times (commonly auto-typed by YAML parsers/tooling)
    """
    if value in KEYWORDS:
        return True
    if RE_INT.match(value) or RE_FLOAT.match(value):
        return True
    if RE_DATE.match(value) or RE_TIME.match(value):
        return True
    return False


def is_safe_unquoted_text(value: str) -> bool:
    """
    Return True if the value is safe to emit as a plain YAML scalar.

    Safety requirements:
    - Not empty
    - No leading/trailing whitespace
    - Not numeric / keyword / date / time
    - Does not start with YAML-special punctuation
    - Contains no characters that would alter YAML parsing
    """
    if value == "":
        return False
    if value != value.strip():
        return False
    if is_typey_or_keyword(value):
        return False
    if value[0] in "-?:,[]{}#&*!|>'\"%@`":
        return False
    if any(c in RISKY_CHARS for c in value):
        return False
    return True


def should_skip_line(left_side: str) -> bool:
    """
    Return True if this line should be ignored for quote-editing.

    Skipped cases:
    - Block scalars: key: |  or key: >
    - Flow collections: key: { ... } or key: [ ... ]
    """
    if re.search(r":\s*[>|]\s*$", left_side):
        return True
    if re.search(r":\s*[\[{]\s*", left_side):
        return True
    return False


def process_line(line: str) -> Tuple[str, bool]:
    """
    Process a single YAML line.

    If the line contains a simple quoted scalar value, decide whether to:
    - remove quotes
    - keep quotes
    - or leave the line untouched

    Args:
        line: The input line (including or excluding trailing newline).

    Returns:
        (output_line, changed)
    """
    had_nl = line.endswith("\n")
    raw = line.rstrip("\n")

    left, comment = split_inline_comment(raw)

    # Fast skips for non key-value lines.
    if ":" not in left:
        return (line if had_nl else raw), False
    if should_skip_line(left):
        return (line if had_nl else raw), False

    match = KV_RE.match(left)
    if not match:
        return (line if had_nl else raw), False

    prefix = match.group(1)
    quote = match.group(3)
    inner = match.group(4)

    # Conservative: avoid touching double-quoted values containing escapes.
    if quote == '"' and "\\" in inner:
        return (line if had_nl else raw), False

    # Decide whether to remove quotes.
    if is_typey_or_keyword(inner):
        new_left = f"{prefix}{quote}{inner}{quote}"
    elif is_safe_unquoted_text(inner):
        new_left = f"{prefix}{inner}"
    else:
        new_left = f"{prefix}{quote}{inner}{quote}"

    if comment:
        out = f"{new_left} {comment}".rstrip()
    else:
        out = new_left

    out_line = out + ("\n" if had_nl else "")
    return out_line, (out_line != line)


def format_text(text: str) -> Tuple[str, int]:
    """
    Apply quote formatting to an entire YAML text.

    Args:
        text: Full YAML text.

    Returns:
        (new_text, lines_changed)
    """
    lines = text.splitlines(True)
    out_lines: List[str] = []
    changed_count = 0

    for ln in lines:
        new_ln, changed = process_line(ln)
        out_lines.append(new_ln)
        if changed:
            changed_count += 1

    return "".join(out_lines), changed_count


def is_yaml_file(path: Path, include_globs: Sequence[str]) -> bool:
    """
    Return True if a file path matches any of the include globs.

    Args:
        path: Candidate file path.
        include_globs: Patterns like ["*.yml", "*.yaml"].

    Returns:
        True if filename matches at least one glob.
    """
    name = path.name
    return any(fnmatch.fnmatch(name, pat) for pat in include_globs)


def iter_yaml_files(
    root: Path,
    include_globs: Sequence[str],
    exclude_dirs: Sequence[str],
) -> Iterator[Path]:
    """
    Recursively yield YAML files under a directory.

    Args:
        root: Directory to traverse.
        include_globs: File patterns to include (e.g. ["*.yml", "*.yaml"]).
        exclude_dirs: Directory names to skip (e.g. [".git", "node_modules"]).

    Yields:
        Paths to YAML files.
    """
    for dirpath, dirnames, filenames in os.walk(root):
        # Mutate dirnames in-place to prevent descending into excluded dirs.
        dirnames[:] = [d for d in dirnames if d not in set(exclude_dirs)]

        base = Path(dirpath)
        for fn in filenames:
            p = base / fn
            if is_yaml_file(p, include_globs):
                yield p


def rewrite_file(path: Path, in_place: bool) -> Change:
    """
    Rewrite a YAML file (or preview the rewrite if not in-place).

    Args:
        path: File to process.
        in_place: If True, write changes back to the file.

    Returns:
        A Change object describing whether the file changed and how many lines.
    """
    original = path.read_text(encoding="utf-8")
    formatted, lines_changed = format_text(original)
    changed = (formatted != original)

    if in_place and changed:
        path.write_text(formatted, encoding="utf-8")

    return Change(path=path, changed=changed, lines_changed=lines_changed)


def parse_args(argv: Optional[Sequence[str]] = None) -> argparse.Namespace:
    """
    Parse CLI arguments.

    Args:
        argv: Optional argv override (useful for testing).

    Returns:
        argparse.Namespace of parsed arguments.
    """
    parser = argparse.ArgumentParser(
        description="Format YAML by adjusting quotes on simple scalar values only."
    )
    parser.add_argument(
        "input",
        help="Input path: a YAML file, a directory to traverse, or '-' for stdin",
    )
    parser.add_argument(
        "-i", "--in-place",
        action="store_true",
        help="Rewrite files in place (directory mode rewrites each matching file).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Do not write files; just print which files would change.",
    )
    parser.add_argument(
        "--include",
        action="append",
        default=["*.yml", "*.yaml"],
        help="Glob(s) of files to include (default: *.yml, *.yaml). Can be repeated.",
    )
    parser.add_argument(
        "--exclude-dir",
        action="append",
        default=[
            ".git", ".hg", ".svn",
            "node_modules",
            ".venv", "venv",
            "__pycache__",
            "dist", "build", "target",
        ],
        help="Directory name(s) to skip when traversing. Can be repeated.",
    )
    return parser.parse_args(argv)


def run() -> int:
    """
    Main program runner.

    Handles:
    - stdin mode ('-')
    - file mode
    - directory traversal mode
    - dry-run and in-place behavior

    Returns:
        Process exit code.
    """
    args = parse_args()

    # stdin mode: read -> format -> write
    if args.input == "-":
        data = sys.stdin.read()
        out, _ = format_text(data)
        sys.stdout.write(out)
        return 0

    input_path = Path(args.input)

    if not input_path.exists():
        print(f"Error: path not found: {input_path}", file=sys.stderr)
        return 2

    # Directory mode: recurse and process matching files.
    if input_path.is_dir():
        any_changed = False
        total_changed_files = 0
        total_changed_lines = 0

        for fp in iter_yaml_files(input_path, args.include, args.exclude_dir):
            ch = rewrite_file(fp, in_place=(
                args.in_place and not args.dry_run))
            if ch.changed:
                any_changed = True
                total_changed_files += 1
                total_changed_lines += ch.lines_changed
                print(f"CHANGE {ch.path} ({ch.lines_changed} line(s))")
            else:
                print(f"OK     {ch.path}")

        if args.dry_run:
            # Dry-run implies "would change" reporting, not writing.
            if total_changed_files:
                print(
                    f"\nDry-run: {total_changed_files} file(s) would change "
                    f"({total_changed_lines} line(s))."
                )
            else:
                print("\nDry-run: no changes.")
        else:
            if total_changed_files:
                print(
                    f"\nDone: changed {total_changed_files} file(s) "
                    f"({total_changed_lines} line(s))."
                )
            else:
                print("\nDone: no changes.")

        return 1 if (args.dry_run and any_changed) else 0

    # File mode: process just one file.
    if input_path.is_file():
        ch = rewrite_file(input_path, in_place=(
            args.in_place and not args.dry_run))

        if args.dry_run:
            if ch.changed:
                print(
                    f"Dry-run: would change {ch.path} ({ch.lines_changed} line(s)).")
                return 1
            print("Dry-run: no changes.")
            return 0

        if args.in_place:
            if ch.changed:
                print(f"Changed {ch.path} ({ch.lines_changed} line(s)).")
            else:
                print("No changes.")
            return 0

        # Not in-place: print formatted content to stdout.
        original = input_path.read_text(encoding="utf-8")
        formatted, _ = format_text(original)
        sys.stdout.write(formatted)
        return 0

    print(f"Error: unsupported path type: {input_path}", file=sys.stderr)
    return 2


def main() -> int:
    """
    Script entry point.

    Returns:
        Exit code from run().
    """
    return run()


if __name__ == "__main__":
    raise SystemExit(main())
