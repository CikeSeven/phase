# Responses 回归样本

- `pi_responses_first_turn.json`：pi commit `6160683a4a8012f0d1cd30c145df18b4ca6f5176` 的普通 Responses 构造函数在固定测试输入下的产物，未发起网络请求。包含显式提供的模型输出上限，不表示两应用的默认参数或 Codex OAuth 行为相同。
- `astra_first_turn_reasoning.sse`：2026-09-20 真机新会话首条消息的 GPT-6 Astra Responses 响应，两个 reasoning item、四段公开摘要；用户已确认首轮可见。
- `astra_no_reasoning.sse`：同日一次短回复的响应，没有 reasoning item，usage 中 reasoning_tokens 为 0；同份响应在相月与 pi 解析器中均只有正文。

两份 SSE 已脱敏缩减：文字替换为同长度占位符，ID/加密载荷替换为稳定假值；去掉请求回显和冗长正文增量，正文完成快照统一替换为测试文案。保留思考事件、索引、段落关系和终态；没有用户对话、端点、凭据或真实加密载荷。
