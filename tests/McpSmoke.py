"""Check stdio MCP handshakes without requiring a running analysis GUI."""

import json
import os
import selectors
import subprocess
import sys
import tempfile
import time


def check(command, require_tools):
    with tempfile.TemporaryFile() as errors:
        process = subprocess.Popen(
            [command], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=errors
        )
        selector = selectors.DefaultSelector()
        selector.register(process.stdout, selectors.EVENT_READ)
        pending = bytearray()

        def send(message):
            process.stdin.write((json.dumps(message) + "\n").encode())
            process.stdin.flush()

        def receive(request_id):
            deadline = time.monotonic() + 45
            while time.monotonic() < deadline:
                while b"\n" in pending:
                    line, _, remainder = pending.partition(b"\n")
                    pending[:] = remainder
                    if not line.strip():
                        continue
                    response = json.loads(line)
                    if response.get("id") == request_id:
                        return response
                if selector.select(timeout=1):
                    chunk = os.read(process.stdout.fileno(), 65536)
                    if not chunk:
                        raise RuntimeError("MCP server exited before responding")
                    pending.extend(chunk)
            raise TimeoutError("MCP response exceeded 45 seconds")

        try:
            send({
                "jsonrpc": "2.0", "id": 1, "method": "initialize",
                "params": {
                    "protocolVersion": "2024-11-05", "capabilities": {},
                    "clientInfo": {"name": "reverse-tools-smoke", "version": "1"},
                },
            })
            initialized = receive(1)
            assert "result" in initialized, initialized
            assert "tools" in initialized["result"]["capabilities"], initialized
            send({"jsonrpc": "2.0", "method": "notifications/initialized"})
            if require_tools:
                send({"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}})
                listed = receive(2)
                names = {tool["name"] for tool in listed["result"]["tools"]}
                assert {"get_class_source", "get_android_manifest"} <= names, names
                print(f"{command}: initialize and tools/list OK ({len(names)} tools)")
            else:
                print(f"{command}: initialize OK; IDA-backed tools require a running IDA")
        except Exception:
            errors.seek(0)
            sys.stderr.write(errors.read().decode(errors="replace"))
            raise
        finally:
            selector.close()
            process.stdin.close()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()


if __name__ == "__main__":
    check(sys.argv[1], require_tools=False)
    check(sys.argv[2], require_tools=True)
