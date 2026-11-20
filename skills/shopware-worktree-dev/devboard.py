#!/usr/bin/env python3
"""devboard: every running Shopware instance and the dev servers attached to it.

  devboard.py serve [--port N] [--open]   live dashboard at http://localhost:N/
  devboard.py list                        the same data as plain text
  devboard.py subject [TEXT | --clear]    show or set what the current checkout is about

An instance is a running compose project with a `web` service. A dev server is
any node process listening on a public port inside that container (vite for the
admin, webpack for the storefront); its working directory names the checkout.

The subject lives in the checkout's own git dir (`.git/devboard-subject`, or
`.git/worktrees/<name>/devboard-subject`), so it is never committed and
disappears together with the worktree.
"""
from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

CONTAINER_ROOT = "/var/www/html"
SUBJECT_FILE = "devboard-subject"
DEFAULT_PORT = 5299


def run(*cmd: str) -> str:
    """Stdout of a command, or "" when it fails; the board shows what it can."""
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=10).stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        return ""


def git(path: str, *args: str) -> str:
    return run("git", "-C", path, *args)


# --- subject


def subject_path(checkout: str) -> str | None:
    git_dir = git(checkout, "rev-parse", "--absolute-git-dir")
    return os.path.join(git_dir, SUBJECT_FILE) if git_dir else None


def read_subject(checkout: str) -> str:
    path = subject_path(checkout)
    try:
        with open(path) as f:
            return f.read().strip()
    except (OSError, TypeError):
        return ""


def write_subject(checkout: str, text: str) -> None:
    path = subject_path(checkout)
    if not path:
        raise ValueError(f"{checkout} is not a git checkout")
    text = " ".join(text.split())
    if text:
        with open(path, "w") as f:
            f.write(text + "\n")
    elif os.path.exists(path):
        os.remove(path)


# --- discovery

# Prints "port<TAB>pid<TAB>cwd<TAB>cmdline" for every node process listening on
# a public address. Loopback listeners are vite's internal plugin servers.
LISTENER_SCRIPT = r"""
netstat -ltnp 2>/dev/null | awk '$6 == "LISTEN" && $7 ~ /\/node$/ && ($4 ~ /^0\.0\.0\.0:/ || $4 ~ /^:::/) { print $4, $7 }' |
while read addr prog; do
    pid=${prog%%/*}
    printf '%s\t%s\t%s\t%s\n' "${addr##*:}" "$pid" "$(readlink /proc/$pid/cwd)" "$(tr '\0' ' ' < /proc/$pid/cmdline)"
done
"""


def running_instances() -> list[dict]:
    fmt = "\t".join([
        "{{.Names}}",
        '{{.Label "com.docker.compose.project"}}',
        '{{.Label "com.docker.compose.project.working_dir"}}',
        '{{.Label "dev.orbstack.domains"}}',
        "{{.Status}}",
    ])
    out = run("docker", "ps", "--filter", "label=com.docker.compose.service=web", "--format", fmt)
    instances = []
    for line in out.splitlines():
        container, project, root, domains, status = (line.split("\t") + [""] * 5)[:5]
        host = domains.split(",")[0] or "localhost"
        instances.append({
            "container": container,
            "project": project,
            "root": root,
            "host": host,
            "url": f"http://{host}/admin",
            "status": status,
        })
    return sorted(instances, key=lambda i: i["project"])


def checkout_root(path: str) -> str:
    """Walks up from a directory to the checkout that contains it."""
    while path != "/" and not os.path.exists(os.path.join(path, ".git")):
        path = os.path.dirname(path)
    return path


def server_kind(cmdline: str) -> str:
    if "vite" in cmdline:
        return "admin"
    if "webpack" in cmdline or "storefront" in cmdline:
        return "storefront"
    return "node"


def dev_servers(instance: dict) -> list[dict]:
    out = run("docker", "exec", instance["container"], "sh", "-c", LISTENER_SCRIPT)
    servers = []
    for line in out.splitlines():
        port, _pid, cwd, cmdline = (line.split("\t") + [""] * 4)[:4]
        if cwd.startswith(CONTAINER_ROOT):
            host_cwd = instance["root"] + cwd[len(CONTAINER_ROOT):]
        elif os.path.isdir(cwd):
            host_cwd = cwd  # a worktree outside the instance, mirror-mounted at its host path
        else:
            continue
        servers.append({
            "port": int(port),
            "kind": server_kind(cmdline),
            "url": f"http://{instance['host']}:{port}/",
            "checkout": checkout_root(host_cwd),
        })
    return sorted(servers, key=lambda s: s["port"])


def github_repo(root: str) -> str:
    match = re.search(r"github\.com[:/]([^/]+/[^/.]+)", git(root, "remote", "get-url", "origin"))
    return match.group(1) if match else ""


def pr_link(repo: str, *names: str) -> str:
    for name in names:
        match = re.search(r"(?:^|[/_-])pr-?(\d{3,})", name)
        if match and repo:
            return f"https://github.com/{repo}/pull/{match.group(1)}"
    return ""


def checkout_info(path: str, repo: str) -> dict:
    branch = git(path, "branch", "--show-current") or f"detached @ {git(path, 'rev-parse', '--short', 'HEAD')}"
    name = os.path.basename(path)
    return {
        "path": path,
        "name": name,
        "branch": branch,
        "subject": read_subject(path),
        "vscode": "vscode://file" + path,
        "pr": pr_link(repo, branch, name),
    }


def worktree_paths(root: str) -> list[str]:
    out = git(root, "worktree", "list", "--porcelain")
    return [line[len("worktree "):] for line in out.splitlines() if line.startswith("worktree ")]


def is_up(url: str) -> bool:
    """Any HTTP answer counts; only a refused or timed-out connection is down."""
    try:
        urllib.request.urlopen(urllib.request.Request(url, method="HEAD"), timeout=4)
        return True
    except urllib.error.HTTPError:
        return True
    except (urllib.error.URLError, OSError):
        return False


def collect() -> list[dict]:
    """Instances, each with its dev servers grouped by checkout and its idle worktrees."""
    instances = running_instances()
    with concurrent.futures.ThreadPoolExecutor(max_workers=16) as pool:
        all_servers = list(pool.map(dev_servers, instances))
        probes = instances + [server for servers in all_servers for server in servers]
        reachability = pool.map(lambda target: is_up(target["url"]), probes)

        for instance, servers in zip(instances, all_servers):
            repo = github_repo(instance["root"])
            paths = worktree_paths(instance["root"]) or [instance["root"]]
            info = dict(zip(paths, pool.map(lambda path: checkout_info(path, repo), paths)))
            instance.update(info.pop(instance["root"], None) or checkout_info(instance["root"], repo))

            by_checkout: dict[str, dict] = {}
            for server in servers:
                entry = by_checkout.setdefault(
                    server["checkout"], info.pop(server["checkout"], None) or checkout_info(server["checkout"], repo)
                )
                entry.setdefault("servers", []).append(server)
            instance["devServers"] = list(by_checkout.values())
            instance["idle"] = list(info.values())

        for target, up in zip(probes, reachability):
            target["up"] = up
    return instances


def known_checkouts(instances: list[dict]) -> set[str]:
    paths = set()
    for instance in instances:
        paths.add(instance["root"])
        paths.update(entry["path"] for entry in instance["devServers"] + instance["idle"])
    return paths


# --- text output


def print_list(instances: list[dict]) -> None:
    if not instances:
        print("no running instances")
    for instance in instances:
        state = "up" if instance["up"] else "DOWN"
        print(f"{instance['url']}  [{state}]  {instance['root']}  ({instance['branch']})")
        print(f"    {instance['subject'] or '(no subject)'}")
        for entry in instance["devServers"]:
            for server in entry["servers"]:
                state = "up" if server["up"] else "DOWN"
                print(f"  {server['url']}  {server['kind']}  [{state}]")
            print(f"    {entry['path']}  ({entry['branch']})")
            print(f"    {entry['subject'] or '(no subject)'}")
        if not instance["devServers"]:
            print("  no dev servers")
        print()


# --- web dashboard

PAGE = os.path.join(os.path.dirname(os.path.realpath(__file__)), "devboard.html")


class Handler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        if self.path == "/":
            with open(PAGE) as f:
                self.reply(200, f.read(), "text/html")
        elif self.path == "/api/instances":
            self.reply(200, json.dumps(collect()), "application/json")
        else:
            self.reply(404, "not found", "text/plain")

    def do_POST(self) -> None:
        if self.path != "/api/subject":
            return self.reply(404, "not found", "text/plain")
        body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))) or "{}")
        path = body.get("path", "")
        # Only checkouts the board itself discovered, so a request cannot pick an arbitrary git dir.
        if path not in known_checkouts(collect()):
            return self.reply(400, "unknown checkout", "text/plain")
        write_subject(path, str(body.get("subject", "")))
        self.reply(204, "", "text/plain")

    def reply(self, status: int, body: str, content_type: str) -> None:
        data = body.encode()
        self.send_response(status)
        self.send_header("Content-Type", f"{content_type}; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *_args) -> None:
        pass


def serve(port: int, open_browser: bool) -> None:
    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    url = f"http://localhost:{port}/"
    print(f"devboard on {url}", flush=True)
    if open_browser:
        webbrowser.open(url)
    server.serve_forever()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)
    serve_cmd = commands.add_parser("serve", help="run the live dashboard")
    serve_cmd.add_argument("--port", type=int, default=DEFAULT_PORT)
    serve_cmd.add_argument("--open", action="store_true", help="open it in the default browser")
    commands.add_parser("list", help="print instances and dev servers")
    subject_cmd = commands.add_parser("subject", help="show or set the subject of the current checkout")
    subject_cmd.add_argument("text", nargs="*")
    subject_cmd.add_argument("--clear", action="store_true")
    args = parser.parse_args()

    if args.command == "serve":
        serve(args.port, args.open)
    elif args.command == "list":
        print_list(collect())
    else:
        checkout = git(os.getcwd(), "rev-parse", "--show-toplevel") or sys.exit("not inside a git checkout")
        if args.clear or args.text:
            write_subject(checkout, " ".join(args.text))
        print(read_subject(checkout) or "(no subject)")


if __name__ == "__main__":
    main()
