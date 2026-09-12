import '../data/models/api_protocol.dart';
import '../data/models/chat_chunk.dart';
import '../data/models/chat_request.dart';
import '../data/models/profile_model.dart';

/// AI 服务商统一抽象（design 第五部分 §4.1）。
///
/// 所有厂商差异收敛在 lib/providers/ 内：实例绑定一份服务商连接配置与
/// 运行期凭据，工厂按 [ApiProtocol] 创建对应实现。
///
/// 请求与解析失败抛 [ProviderError]；流内错误用 ResponseError 事件表达。
abstract class AiProvider {
  /// 本实现使用的协议。
  ApiProtocol get protocol;

  /// 拉取该服务商可用的模型列表；同时用于验证连接与权限。
  Future<List<ProfileModel>> listModels();

  /// 流式对话。订阅取消必须即时终止底层请求（停止生成）。
  Stream<ChatChunk> streamChat(ChatRequest request);
}
