"""MCP stdio 测试固件：按 FIXTURE_MODE 切换行为，输出严格单行 JSON-RPC。

基础模式覆盖握手、目录与调用；其余模式覆盖分块输出、RPC 错误、超时迟到
响应、停止取消通知、进程退出、stdout 污染、list_changed 通知与服务器
ping 请求。FIXTURE_LOG 把观察到的事件写到宿主文件供断言。
"""

import json
import os
import sys

mode = os.environ.get("FIXTURE_MODE", "basic")
marker = os.environ.get("FIXTURE_MARKER", "")
log_path = os.environ.get("FIXTURE_LOG")
lists = 0
pending_ping = None


def note(text):
    if log_path:
        with open(log_path, "a", encoding="utf-8") as handle:
            handle.write(text + "\n")


def send(obj):
    sys.stdout.write(json.dumps(obj, ensure_ascii=False) + "\n")
    sys.stdout.flush()


def send_chunked(obj):
    data = json.dumps(obj, ensure_ascii=False).encode("utf-8")
    for offset in range(0, len(data), 7):
        sys.stdout.buffer.write(data[offset : offset + 7])
        sys.stdout.buffer.flush()
    sys.stdout.buffer.write(b"\n")
    sys.stdout.buffer.flush()


def echo_tool():
    return {
        "name": "echo",
        "description": "回显文本",
        "inputSchema": {
            "type": "object",
            "properties": {"text": {"type": "string"}},
        },
    }


def call_result(request_id, text):
    return {
        "jsonrpc": "2.0",
        "id": request_id,
        "result": {
            "content": [{"type": "text", "text": text}],
            "structuredContent": {"echo": text},
        },
    }


for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    message = json.loads(line)
    if "method" not in message:
        # 客户端对我们 ping 请求的应答：完成挂起的 tools/call。
        if message.get("id") == "srv-ping" and pending_ping is not None:
            note("ping-answered")
            send(call_result(pending_ping, "应答后完成" + marker))
            pending_ping = None
        continue
    method = message["method"]
    request_id = message.get("id")
    if method == "initialize":
        send(
            {
                "jsonrpc": "2.0",
                "id": request_id,
                "result": {
                    "protocolVersion": os.environ.get(
                        "FIXTURE_VERSION", "2025-06-18"
                    ),
                    "capabilities": {
                        "tools": {"listChanged": mode == "list_changed"}
                    },
                    "serverInfo": {"name": "fixture-stdio", "version": "1.0"},
                },
            }
        )
    elif method == "notifications/initialized":
        if mode == "exit_after_init":
            sys.stderr.write("boom: 初始化后退出\n")
            sys.stderr.flush()
            note("exited")
            sys.exit(2)
    elif method == "notifications/cancelled":
        note("cancelled:%s" % message["params"]["requestId"])
    elif method == "tools/list":
        lists += 1
        send(
            {
                "jsonrpc": "2.0",
                "id": request_id,
                "result": {"tools": [echo_tool()]},
            }
        )
        if mode == "list_changed" and lists == 2:
            send(
                {
                    "jsonrpc": "2.0",
                    "method": "notifications/tools/list_changed",
                }
            )
    elif method == "tools/call":
        text = (message["params"].get("arguments") or {}).get("text", "")
        if mode == "rpc_error":
            send(
                {
                    "jsonrpc": "2.0",
                    "id": request_id,
                    "error": {"code": -32000, "message": "业务失败"},
                }
            )
        elif mode == "chunked":
            send_chunked(call_result(request_id, (text + marker) * 200))
        elif mode == "hang":
            note("call-arrived")
        elif mode == "late":
            import time

            time.sleep(3)
            send(call_result(request_id, text + marker))
        elif mode == "ping":
            pending_ping = request_id
            send({"jsonrpc": "2.0", "id": "srv-ping", "method": "ping"})
        elif mode == "garbage":
            sys.stdout.write("this is not json\n")
            sys.stdout.flush()
        else:
            send(call_result(request_id, text + marker))
