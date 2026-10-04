# 网页搜索与读取

设置入口为「设置 → 网页搜索」。搜索和读取分别启用，搜索服务可新增、编辑、停用、选择和删除。表单暂存修改，仅保存时提交；「检查连接」使用当前草稿发起一个小查询，可停止，不保存草稿或密钥。

## 服务与接口

| 提供方 | 默认接口基址 | 查询方式 |
| --- | --- | --- |
| DuckDuckGo | `https://html.duckduckgo.com` | HTML 搜索，无密钥；验证码或未知页面明确失败 |
| DeepSeek | `https://api.deepseek.com/anthropic/v1` | 辅助 Messages 请求和 `web_search_20250305` 原生搜索工具 |
| Exa | `https://api.exa.ai` | `/search`，支持自动、关键词和语义模式 |
| Brave Search | `https://api.search.brave.com/res/v1` | `/web/search`，支持国家、语言设置 |
| Tavily | `https://api.tavily.com` | `/search`，支持标准和深入搜索 |
| Perplexity | `https://api.perplexity.ai` | `/chat/completions`，返回答案与结构化来源或 URL 引用 |
| SearXNG | 用户配置 | 实例 `/search?format=json`，可设置引擎、语言与可选 Bearer 令牌 |

搜索服务由用户明确选择，不按失败自动切换后端。DeepSeek、Perplexity 搜索产生独立模型请求；聊天本身使用何种协议或模型不影响搜索服务选择。默认提供无密钥 DuckDuckGo 配置，但不保证网络可达或免验证码。缺少 API key、服务停用、格式异常、额度不足和网络失败均返回失败，不伪装为空搜索结果。

## 模型工具

- `web_search({"queries":["关键词"]})`：接收 1 至配置上限个查询，在网络派发前完整校验。完全相同的查询只执行一次。不同查询并发，按排名轮询合并、按 URL 去重，再应用总来源上限。任意查询失败会停止其他查询，等待结算并返回首次失败，不混入残缺的成功批次。
- `web_fetch({"url":"https://…"})`：匿名读取 HTML、文本、JSON、XML 和可提取文本的 PDF。HTML 清理脚本、隐藏内容、表单等后转为可读 Markdown，不执行 JS。PDF 使用已有提取依赖，最多 100 页。非 2xx 状态保留状态和正文，但工具状态为失败。

网页读取是静态提取，不执行登录、客户端 JS 或 OCR；纯客户端渲染页面和扫描 PDF 可能没有可读正文。隐藏内容清理针对隐藏属性和内联隐藏样式，不计算外链 CSS。文本采用 SDK 的 UTF-8、Latin-1、ASCII 解码，未知字符编码明确失败，不把乱码当成功结果。

结果以有效的结构化 JSON 写入现有工具记录，包含来源 URL、可选标题、摘录与提供方日期、答案和截断状态。`retrievedAt` 始终表示本机检索时间，不代表发布日期。工具指导要求把外部内容当数据而非指令，答案按标准 Markdown 链接引用来源。工具卡片直接读取已保存的结构化来源，历史展示不重跑搜索；正文引用和来源链接通过外部浏览器打开，只接受不含内嵌凭据的 HTTP(S) URI。

## 上限、取消与权限

默认每次工具调用最多 4 个查询、8 个来源；搜索总期限 60 秒、读取总期限 30 秒、网页正文最多 40000 字符，均可在设置页调整。每个网络响应最多 2 MiB；完整工具 JSON 最多 48 KiB（包含封装），Unicode 截断不切开代理对，超限时保留有效 JSON 并标注截断。DeepSeek 原生搜索另设每个查询的模型 token 预算与最多服务端搜索次数。

期限包含凭据读取、DNS、请求与响应正文，不仅是连接超时。用户停止会沿工具、仓储、请求作用域和实际网络连接传递；作用域结束释放定时器、取消 token 和响应连接。搜索与读取属于宿主只读工具，计划模式也可使用；仍受实际开放范围及最新服务撤权检查约束。

## 凭据与运行快照

搜索 API key 仅经 `SecureKeyStorage` 的 `web_search_secret_` 命名空间存取；普通配置和运行快照只保存版本引用。修改密钥创建新引用，旧运行继续使用原连接与原引用，不把新密钥发送到旧 endpoint。旧引用保留到服务删除；清除当前密钥、停用或删除服务阻止后续调用。删除先标记撤权，再清理所有密钥引用，失败可重试。配置保存失败回滚新凭据，不宣布保存成功。

provider 请求禁止自动重定向，不安装包含 URL、请求头或正文的日志拦截器。错误仅包含固定文案和状态分类。`web_fetch` 每跳检查 DNS 的全部地址，拒绝本机、私网、保留地址和内嵌凭据，并固定实际连接 IP；TLS 仍校验原始 hostname。重定向重新检查，最多 5 次，不转发 Cookie 或鉴权信息。

## 代码位置

- `lib/data/models/web_search_settings.dart`、`web_search_result.dart`：非敏感配置、请求结果数据。
- `lib/data/repositories/web_search_repository.dart`：配置提交、凭据引用、提供方选择、多查询执行与撤权。
- `lib/data/datasources/remote/web_search/`、`web_fetch_client.dart`、`web_page_text.dart`：协议传输、提供方映射、安全读取与正文提取。
- `lib/features/web_search/`：Riverpod 状态、设置表单、模型工具和结果展示。
- `RunConfiguration.webSearch`：运行创建时固定搜索配置；旧运行没有此字段时不自动增加 web 工具。
