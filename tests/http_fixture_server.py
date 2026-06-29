#!/usr/bin/env python3

import json
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse


COUNTS: dict[str, int] = {}
COUNTS_LOCK = threading.Lock()


class FixtureHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, format: str, *args: object) -> None:
        return

    def _send(self, status: int, content_type: str, body: bytes) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("X-Fixture", "mantra")
        self.end_headers()
        if self.command != "HEAD":
            try:
                self.wfile.write(body)
            except (BrokenPipeError, ConnectionResetError):
                pass

    def _send_json(self, value: object, status: int = 200) -> None:
        body = json.dumps(value, separators=(",", ":"), sort_keys=True).encode()
        self._send(status, "application/json; charset=utf-8", body)

    def _read_body(self) -> bytes:
        length = int(self.headers.get("Content-Length", "0"))
        return self.rfile.read(length)

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        query = parse_qs(parsed.query)

        if parsed.path == "/json":
            self._send_json(
                {
                    "message": "hello",
                    "method": self.command,
                    "query": query,
                }
            )
            return

        if parsed.path == "/text":
            self._send(200, "text/plain; charset=utf-8", b"plain response")
            return

        if parsed.path == "/status/404":
            self._send_json({"error": "missing"}, status=404)
            return

        if parsed.path == "/redirect":
            self.send_response(302)
            self.send_header("Location", "/json?redirected=true")
            self.send_header("Content-Length", "0")
            self.end_headers()
            return

        if parsed.path == "/redirect-cross-origin":
            self.send_response(302)
            self.send_header(
                "Location",
                f"http://localhost:{self.server.server_port}/json",
            )
            self.send_header("Content-Length", "0")
            self.end_headers()
            return

        if parsed.path == "/large":
            self._send(200, "text/plain", b"x" * 4096)
            return

        if parsed.path == "/bad-json":
            self._send(200, "application/json", b"{not valid json")
            return

        if parsed.path == "/slow":
            time.sleep(0.25)
            self._send_json({"slow": True})
            return

        if parsed.path == "/count":
            key = query.get("id", ["default"])[0]
            with COUNTS_LOCK:
                COUNTS[key] = COUNTS.get(key, 0) + 1
                count = COUNTS[key]
            self._send_json({"count": count})
            return

        self._send_json({"error": "unknown fixture path"}, status=404)

    def do_HEAD(self) -> None:
        self.do_GET()

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        if parsed.path != "/echo":
            self._send_json({"error": "unknown fixture path"}, status=404)
            return

        raw_body = self._read_body()
        try:
            body = json.loads(raw_body.decode())
        except json.JSONDecodeError:
            body = raw_body.decode(errors="replace")
        self._send_json(
            {
                "body": body,
                "content_type": self.headers.get("Content-Type", ""),
                "method": self.command,
            }
        )


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: http_fixture_server.py <port-file>")

    server = ThreadingHTTPServer(("127.0.0.1", 0), FixtureHandler)
    with open(sys.argv[1], "w", encoding="utf-8") as port_file:
        port_file.write(str(server.server_port))
        port_file.flush()
    server.serve_forever()


if __name__ == "__main__":
    main()
