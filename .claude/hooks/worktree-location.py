#!/usr/bin/env python3
"""PreToolUse hook: `git worktree add` may only create worktrees in <repo>/.claude/worktrees/.

A worktree next to its repo (repositories/meteor-fix) looks like one more repo
in repositories/, and the Shopware container cannot see it. Allowed worktrees
get `.claude/worktrees/` into the repo's .git/info/exclude, so the main
checkout does not list them as untracked.
"""
import json
import os
import shlex
import subprocess
import sys

ALLOWED = "/.claude/worktrees/"
VALUE_OPTIONS = {"-b", "-B", "--reason"}


def commands(line):
    """Yields the argv of each simple command in a shell line (split on && ; | etc.)."""
    lexer = shlex.shlex(line, posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    argv = []
    try:
        for token in lexer:
            if token and set(token) <= set("&|;()"):
                yield argv
                argv = []
            else:
                argv.append(token)
    except ValueError:
        pass
    yield argv


def worktree_add(argv):
    """Returns (git -C dir or None, path) for `git [-C dir] worktree add [opts] <path>`, else None."""
    if not argv or os.path.basename(argv[0]) != "git":
        return None
    args, repo_dir = argv[1:], None
    while args and args[0].startswith("-"):
        if args[0] == "-C" and len(args) > 1:
            repo_dir = args[1]
            args = args[2:]
        elif args[0] in ("-c", "--git-dir", "--work-tree") and len(args) > 1:
            args = args[2:]
        else:
            args = args[1:]
    if args[:2] != ["worktree", "add"]:
        return None
    rest = args[2:]
    while rest:
        arg = rest.pop(0)
        if arg in VALUE_OPTIONS:
            rest = rest[1:]
        elif not arg.startswith("-"):
            return repo_dir, arg
    return None


def exclude_worktrees(repo_dir):
    try:
        common = subprocess.run(
            ["git", "-C", repo_dir, "rev-parse", "--path-format=absolute", "--git-common-dir"],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
        exclude = os.path.join(common, "info", "exclude")
        existing = open(exclude).read() if os.path.exists(exclude) else ""
        if "/.claude/worktrees/" not in existing.split("\n"):
            os.makedirs(os.path.dirname(exclude), exist_ok=True)
            with open(exclude, "a") as f:
                f.write(("" if existing.endswith("\n") or not existing else "\n") + "/.claude/worktrees/\n")
    except (OSError, subprocess.CalledProcessError):
        pass


def main():
    event = json.load(sys.stdin)
    cwd = event.get("cwd") or os.getcwd()
    for argv in commands(event.get("tool_input", {}).get("command", "")):
        hit = worktree_add(argv)
        if not hit:
            continue
        repo_dir = os.path.join(cwd, os.path.expanduser(hit[0] or "."))
        path = os.path.normpath(os.path.join(repo_dir, os.path.expanduser(hit[1])))
        if ALLOWED not in path + "/":
            print(
                f"Worktrees go in <repo>/.claude/worktrees/<name>, not {path}. "
                f"Example: git -C <repo> worktree add .claude/worktrees/<name> <ref>",
                file=sys.stderr,
            )
            sys.exit(2)
        exclude_worktrees(repo_dir)


if __name__ == "__main__":
    main()
