import 'dart:convert';

import 'package:phase/data/models/api_protocol.dart';

String _sse(Object value) => 'data: ${jsonEncode(value)}\n\n';

String mcpCallSse(
  ApiProtocol protocol,
  String toolName, {
  Map<String, dynamic> arguments = const {},
  String callId = 'sample',
}) {
  final calls = [(id: callId, name: toolName, args: arguments)];
  return switch (protocol) {
    ApiProtocol.openaiCompletions =>
      '${_sse({
        'choices': [
          {
            'delta': {
              'tool_calls': [
                for (final (index, call) in calls.indexed) {
                    'index': index,
                    'id': call.id,
                    'type': 'function',
                    'function': {'name': call.name, 'arguments': jsonEncode(call.args)},
                  },
              ],
            },
            'finish_reason': 'tool_calls',
          },
        ],
      })}data: [DONE]\n\n',
    ApiProtocol.openaiResponses => _sse({
      'type': 'response.completed',
      'response': {
        'status': 'completed',
        'output': [
          for (final call in calls)
            {
              'type': 'function_call',
              'id': 'fc_${call.id}',
              'call_id': call.id,
              'name': call.name,
              'arguments': jsonEncode(call.args),
              'status': 'completed',
            },
        ],
      },
    }),
    ApiProtocol.anthropicMessages => [
      for (final (index, call) in calls.indexed) ...[
        _sse({
          'type': 'content_block_start',
          'index': index,
          'content_block': {
            'type': 'tool_use',
            'id': call.id,
            'name': call.name,
            'input': {},
          },
        }),
        _sse({
          'type': 'content_block_delta',
          'index': index,
          'delta': {
            'type': 'input_json_delta',
            'partial_json': jsonEncode(call.args),
          },
        }),
        _sse({'type': 'content_block_stop', 'index': index}),
      ],
      _sse({
        'type': 'message_delta',
        'delta': {'stop_reason': 'tool_use'},
      }),
      _sse({'type': 'message_stop'}),
    ].join(),
    ApiProtocol.googleGenerativeAi => _sse({
      'candidates': [
        {
          'content': {
            'role': 'model',
            'parts': [
              for (final call in calls)
                {
                  'functionCall': {'name': call.name, 'args': call.args},
                  'thoughtSignature': 'fixture-signature',
                },
            ],
          },
          'finishReason': 'STOP',
        },
      ],
    }),
  };
}

String mcpAnswerSse(ApiProtocol protocol) => switch (protocol) {
  ApiProtocol.openaiCompletions =>
    '${_sse({
      'choices': [
        {
          'delta': {'content': '已读取月相记录'},
          'finish_reason': 'stop',
        },
      ],
    })}data: [DONE]\n\n',
  ApiProtocol.openaiResponses => _sse({
    'type': 'response.completed',
    'response': {
      'status': 'completed',
      'output': [
        {
          'type': 'message',
          'id': 'answer',
          'content': [
            {'type': 'output_text', 'text': '已读取月相记录'},
          ],
        },
      ],
    },
  }),
  ApiProtocol.anthropicMessages =>
    _sse({
          'type': 'content_block_delta',
          'index': 0,
          'delta': {'type': 'text_delta', 'text': '已读取月相记录'},
        }) +
        _sse({'type': 'message_stop'}),
  ApiProtocol.googleGenerativeAi => _sse({
    'candidates': [
      {
        'content': {
          'role': 'model',
          'parts': [
            {'text': '已读取月相记录'},
          ],
        },
        'finishReason': 'STOP',
      },
    ],
  }),
};
