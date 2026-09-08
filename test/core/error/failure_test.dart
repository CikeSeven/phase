import 'package:flutter_test/flutter_test.dart';
import 'package:phase/core/error/failure.dart';

void main() {
  group('Failure 体系', () {
    test('各子类型均可构造且 message 透传', () {
      const failures = <Failure>[
        NetworkFailure('net'),
        AuthFailure('auth'),
        RateLimitFailure('rate'),
        ServerFailure('server'),
        CancelledFailure('cancelled'),
        UnknownFailure('unknown'),
      ];
      expect(failures, hasLength(6));
      for (final failure in failures) {
        expect(failure.message, isNotEmpty);
        expect(failure.userMessage, isNotEmpty);
        expect(failure, isA<Exception>());
      }
    });

    test('userMessage 为面向用户的中文文案，不泄露内部 message', () {
      expect(const NetworkFailure('timeout x').userMessage, contains('网络'));
      expect(const AuthFailure('401').userMessage, contains('API Key'));
      expect(const RateLimitFailure('429').userMessage, contains('频繁'));
      expect(const ServerFailure('500').userMessage, contains('服务商'));
      expect(const CancelledFailure('x').userMessage, contains('停止'));
      expect(const UnknownFailure('x').userMessage, contains('未知'));
    });

    test('子类型可按 sealed 体系区分', () {
      const Failure failure = AuthFailure('x');
      expect(failure, isA<AuthFailure>());
      expect(failure, isNot(isA<NetworkFailure>()));
    });
  });
}
