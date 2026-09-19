// MCP stdio 测试固件（Node）：与 Python 固件同一套 FIXTURE_MODE 语义，
// 覆盖基础握手、目录、调用、RPC 错误与服务器 ping 请求，验证不同运行时
// 的行协议兼容性。
import { appendFileSync } from 'node:fs';
import * as readline from 'node:readline';

const mode = process.env.FIXTURE_MODE ?? 'basic';
const marker = process.env.FIXTURE_MARKER ?? '';
const logPath = process.env.FIXTURE_LOG;
let pendingPing = null;

const note = (text) => {
  if (logPath) appendFileSync(logPath, text + '\n');
};
const send = (object) => {
  process.stdout.write(JSON.stringify(object) + '\n');
};

const rl = readline.createInterface({ input: process.stdin });
rl.on('line', (line) => {
  line = line.trim();
  if (!line) return;
  const message = JSON.parse(line);
  if (message.method === undefined) {
    // 客户端对我们 ping 请求的应答：完成挂起的 tools/call。
    if (message.id === 'srv-ping' && pendingPing !== null) {
      note('ping-answered');
      send({
        jsonrpc: '2.0',
        id: pendingPing,
        result: { content: [{ type: 'text', text: '应答后完成' + marker }] },
      });
      pendingPing = null;
    }
    return;
  }
  if (message.method === 'initialize') {
    send({
      jsonrpc: '2.0',
      id: message.id,
      result: {
        protocolVersion: '2025-06-18',
        capabilities: { tools: {} },
        serverInfo: { name: 'fixture-node', version: '1.0' },
      },
    });
  } else if (message.method === 'tools/list') {
    send({
      jsonrpc: '2.0',
      id: message.id,
      result: {
        tools: [
          {
            name: 'echo',
            description: '回显文本',
            inputSchema: {
              type: 'object',
              properties: { text: { type: 'string' } },
            },
          },
        ],
      },
    });
  } else if (message.method === 'tools/call') {
    const text = message.params?.arguments?.text ?? '';
    if (mode === 'rpc_error') {
      send({
        jsonrpc: '2.0',
        id: message.id,
        error: { code: -32000, message: '业务失败' },
      });
    } else if (mode === 'ping') {
      pendingPing = message.id;
      send({ jsonrpc: '2.0', id: 'srv-ping', method: 'ping' });
    } else {
      send({
        jsonrpc: '2.0',
        id: message.id,
        result: {
          content: [{ type: 'text', text: text + marker }],
          structuredContent: { echo: text + marker },
        },
      });
    }
  }
});
