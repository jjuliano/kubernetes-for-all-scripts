#!/usr/bin/env python3
"""Minimal sample microservice for Kubernetes for All companion scripts."""
import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer

NAME = os.environ.get("SERVICE_NAME", "bridge")
PORT = int(os.environ.get("PORT", "8080"))


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, body, content_type="application/json"):
        if isinstance(body, (dict, list)):
            data = json.dumps(body).encode()
        elif isinstance(body, str):
            data = body.encode()
        else:
            data = body
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        path = self.path.split("?", 1)[0]
        if path in ("/", "/health", "/healthz", "/ready"):
            self._send(200, {"service": NAME, "status": "ok", "path": path})
        elif path == "/metrics":
            self._send(
                200,
                f"# TYPE up gauge\nup{{service=\"{NAME}\"}} 1\n",
                "text/plain; version=0.0.4",
            )
        else:
            self._send(404, {"error": "not found", "service": NAME})

    def log_message(self, fmt, *args):
        print(NAME + ": " + (fmt % args), flush=True)


if __name__ == "__main__":
    print(f"Starting {NAME} on 0.0.0.0:{PORT}", flush=True)
    HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
