#!/usr/bin/env python3
"""Ask a language server for a file's diagnostics, like an editor would.

Usage:
    scripts/lsp-probe.py FILE [--server CMD ...] [--timeout SECONDS]

Examples:
    scripts/lsp-probe.py src/game.c
    scripts/lsp-probe.py main.cpp --server clangd --clang-tidy

It prints one line per diagnostic, in compiler style:
    src/game.c:12:5: error: use of undeclared identifier 'scren_w' [undeclared_var_use]
Exit status: 0 = no errors, 1 = at least one error, 2 = usage or protocol failure.

Why this exists: an LSP server is just a program that reads and writes JSON on
stdin/stdout. Every message is framed by a "Content-Length: N" header, then a
blank line, then N bytes of JSON. Seeing the four messages below by hand is the
fastest way to understand what Vim's LSP plugin does behind the scenes:
    initialize -> initialized -> textDocument/didOpen -> (wait) publishDiagnostics
"""
import argparse
import json
import os
import pathlib
import queue
import subprocess
import sys
import threading
import time

SEVERITY = {1: "error", 2: "warning", 3: "info", 4: "hint"}
LANGUAGE = {".c": "c", ".h": "c", ".cc": "cpp", ".cpp": "cpp", ".cxx": "cpp",
            ".hpp": "cpp", ".hh": "cpp", ".py": "python", ".sh": "sh"}


def send(proc, payload: dict) -> None:
    """Frame one JSON-RPC message with its Content-Length header and send it."""
    body = json.dumps(payload).encode("utf-8")
    proc.stdin.write(b"Content-Length: %d\r\n\r\n" % len(body) + body)
    proc.stdin.flush()


def reader(stream, out: queue.Queue) -> None:
    """Background thread: split the server's stdout back into JSON messages."""
    try:
        while True:
            length = None
            while True:                          # header lines end with a blank line
                line = stream.readline()
                if not line:
                    return                       # server closed stdout
                line = line.strip()
                if not line:
                    break
                name, _, value = line.decode("ascii", "replace").partition(":")
                if name.lower() == "content-length":
                    length = int(value.strip())
            if length is None:
                continue
            out.put(json.loads(stream.read(length)))
    finally:
        out.put(None)                            # tell the main thread we are done


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("file")
    ap.add_argument("--timeout", type=float, default=30.0,
                    help="seconds to wait for diagnostics (default: 30)")
    ap.add_argument("--server", nargs=argparse.REMAINDER, default=["clangd"],
                    help="server command line (must be last); default: clangd")
    args = ap.parse_args()

    path = pathlib.Path(args.file).resolve()
    if not path.is_file():
        print(f"lsp-probe: no such file: {args.file}", file=sys.stderr)
        return 2
    try:
        proc = subprocess.Popen(args.server + (["--log=error"] if args.server[0].endswith("clangd") else []),
                                stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                stderr=subprocess.DEVNULL, cwd=path.parent)
    except OSError as e:
        print(f"lsp-probe: cannot start {args.server[0]}: {e}", file=sys.stderr)
        return 2

    inbox: queue.Queue = queue.Queue()
    threading.Thread(target=reader, args=(proc.stdout, inbox), daemon=True).start()
    uri = path.as_uri()
    diags = None
    try:
        send(proc, {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {
            "processId": os.getpid(), "rootUri": None,
            "capabilities": {"textDocument": {"publishDiagnostics": {}}}}})
        send(proc, {"jsonrpc": "2.0", "method": "initialized", "params": {}})
        send(proc, {"jsonrpc": "2.0", "method": "textDocument/didOpen", "params": {
            "textDocument": {"uri": uri, "languageId": LANGUAGE.get(path.suffix, "c"),
                             "version": 1, "text": path.read_text(encoding="utf-8")}}})
        deadline = time.monotonic() + args.timeout
        while time.monotonic() < deadline:
            try:
                msg = inbox.get(timeout=max(0.1, deadline - time.monotonic()))
            except queue.Empty:
                break
            if msg is None:
                break
            if msg.get("method") == "textDocument/publishDiagnostics" \
                    and msg["params"]["uri"] == uri:
                diags = msg["params"]["diagnostics"]
                break                            # clangd sends the full list in one go
    finally:
        try:                                     # polite shutdown, then make sure it is gone
            send(proc, {"jsonrpc": "2.0", "id": 2, "method": "shutdown"})
            send(proc, {"jsonrpc": "2.0", "method": "exit"})
            proc.wait(timeout=5)
        except Exception:
            proc.kill()
            proc.wait()

    if diags is None:
        print(f"lsp-probe: no diagnostics received within {args.timeout:.0f}s", file=sys.stderr)
        return 2
    errors = 0
    for d in sorted(diags, key=lambda d: (d["range"]["start"]["line"], d["range"]["start"]["character"])):
        sev = SEVERITY.get(d.get("severity", 1), "error")
        errors += sev == "error"
        start = d["range"]["start"]
        code = f" [{d['code']}]" if d.get("code") else ""
        message = d["message"].splitlines()[0]
        print(f"{args.file}:{start['line'] + 1}:{start['character'] + 1}: {sev}: {message}{code}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
