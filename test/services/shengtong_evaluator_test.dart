import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vidlang/services/shengtong_evaluator.dart';

void main() {
  group('ShengtongEvaluator', () {
    const testAppKey = 'test_app_key_123';
    const testSecretKey = 'test_secret_key_456';

    test('constructor throws ArgumentError when appKey is empty', () {
      expect(
        () => ShengtongEvaluator(appKey: '', secretKey: testSecretKey),
        throwsArgumentError,
      );
    });

    test('constructor throws ArgumentError when secretKey is empty', () {
      expect(
        () => ShengtongEvaluator(appKey: testAppKey, secretKey: ''),
        throwsArgumentError,
      );
    });

    test('constructor accepts valid keys', () {
      expect(
        () => ShengtongEvaluator(appKey: testAppKey, secretKey: testSecretKey),
        returnsNormally,
      );
    });

    test('constructor uses default WebSocket URL when useSSL is false', () {
      final evaluator = ShengtongEvaluator(
        appKey: testAppKey,
        secretKey: testSecretKey,
        useSSL: false,
      );
      expect(evaluator.baseUrl, 'ws://api.stkouyu.com:8080');
    });

    test('constructor uses default WebSocket URL when useSSL is true', () {
      final evaluator = ShengtongEvaluator(
        appKey: testAppKey,
        secretKey: testSecretKey,
        useSSL: true,
      );
      expect(evaluator.baseUrl, 'wss://api.stkouyu.com:8443');
    });

    group('callbacks', () {
      test('onResult receives evaluation results', () {
        final evaluator = ShengtongEvaluator(
          appKey: testAppKey,
          secretKey: testSecretKey,
        );

        Map<String, dynamic>? capturedResult;
        evaluator.onResult = (result) {
          capturedResult = result;
        };

        evaluator.handleMessage(
          jsonEncode({
            'cmd': 'eval',
            'code': 0,
            'result': {
              'overall': 78.5,
              'fluency': 82.0,
              'accuracy': 75.3,
              'completeness': 80.1,
              'wordScores': [
                {'word': 'hello', 'score': 80},
                {'word': 'world', 'score': 77},
              ],
            },
          }),
        );

        expect(capturedResult, isNotNull);
        expect(capturedResult!['overall'], equals(78.5));
        expect(capturedResult!['fluency'], equals(82.0));
        expect(capturedResult!['accuracy'], equals(75.3));
        expect(capturedResult!['completeness'], equals(80.1));
        expect(capturedResult!['wordScores'], isNotNull);
      });

      test('onError receives connection errors', () {
        final evaluator = ShengtongEvaluator(
          appKey: testAppKey,
          secretKey: testSecretKey,
        );

        String? capturedError;
        evaluator.onError = (error) {
          capturedError = error;
        };

        evaluator.handleMessage(
          jsonEncode({
            'cmd': 'connect',
            'code': 4001,
            'error': 'Application not found',
          }),
        );

        expect(capturedError, contains('Application not found'));
      });

      test('onConnectionStateChanged receives true on successful connect', () {
        final evaluator = ShengtongEvaluator(
          appKey: testAppKey,
          secretKey: testSecretKey,
        );

        bool? capturedState;
        evaluator.onConnectionStateChanged = (state) {
          capturedState = state;
        };

        evaluator.handleMessage(jsonEncode({'cmd': 'connect', 'code': 0}));

        expect(capturedState, equals(true));
      });

      test('onError receives failed connect message', () {
        final evaluator = ShengtongEvaluator(
          appKey: testAppKey,
          secretKey: testSecretKey,
        );

        String? capturedError;
        evaluator.onError = (error) {
          capturedError = error;
        };

        evaluator.handleMessage(
          jsonEncode({
            'cmd': 'connect',
            'code': 1001,
            'error': 'Invalid app key',
          }),
        );

        expect(capturedError, contains('Invalid app key'));
      });

      test('handles eval message with null result', () {
        final evaluator = ShengtongEvaluator(
          appKey: testAppKey,
          secretKey: testSecretKey,
        );

        Map<String, dynamic>? capturedResult;
        evaluator.onResult = (result) {
          capturedResult = result;
        };

        evaluator.handleMessage(
          jsonEncode({'cmd': 'eval', 'code': 0, 'result': null}),
        );

        expect(capturedResult, isNull);
      });

      test('handles failed eval message', () {
        final evaluator = ShengtongEvaluator(
          appKey: testAppKey,
          secretKey: testSecretKey,
        );

        Map<String, dynamic>? capturedResult;
        evaluator.onResult = (result) {
          capturedResult = result;
        };

        evaluator.handleMessage(
          jsonEncode({'cmd': 'eval', 'code': 1, 'error': 'Evaluation failed'}),
        );

        expect(capturedResult, isNull);
      });

      test('handles invalid JSON gracefully', () {
        final evaluator = ShengtongEvaluator(
          appKey: testAppKey,
          secretKey: testSecretKey,
        );

        expect(
          () => evaluator.handleMessage('not valid json'),
          returnsNormally,
        );
      });
    });

    group('full evaluation flow simulation', () {
      test('result callback receives proper score data structure', () {
        final evaluator = ShengtongEvaluator(
          appKey: testAppKey,
          secretKey: testSecretKey,
        );

        Map<String, dynamic>? capturedResult;
        evaluator.onResult = (result) {
          capturedResult = result;
        };

        evaluator.handleMessage(
          jsonEncode({
            'cmd': 'eval',
            'code': 0,
            'result': {
              'overall': 85.5,
              'fluency': 90.0,
              'accuracy': 82.0,
              'completeness': 88.0,
            },
          }),
        );

        expect(capturedResult, isNotNull);
        expect(capturedResult!['overall'], equals(85.5));
        expect(capturedResult!['fluency'], equals(90.0));
        expect(capturedResult!['accuracy'], equals(82.0));
        expect(capturedResult!['completeness'], equals(88.0));
      });

      test('handles evaluation with only overall score', () {
        final evaluator = ShengtongEvaluator(
          appKey: testAppKey,
          secretKey: testSecretKey,
        );

        Map<String, dynamic>? capturedResult;
        evaluator.onResult = (result) {
          capturedResult = result;
        };

        evaluator.handleMessage(
          jsonEncode({
            'cmd': 'eval',
            'code': 0,
            'result': {'overall': 95},
          }),
        );

        expect(capturedResult, isNotNull);
        expect(capturedResult!['overall'], equals(95));
      });

      test('handles Chinese evaluation result', () {
        final evaluator = ShengtongEvaluator(
          appKey: testAppKey,
          secretKey: testSecretKey,
        );

        Map<String, dynamic>? capturedResult;
        evaluator.onResult = (result) {
          capturedResult = result;
        };

        evaluator.handleMessage(
          jsonEncode({
            'cmd': 'eval',
            'code': 0,
            'result': {
              'overall': 92.0,
              'fluency': 90.5,
              'accuracy': 93.5,
              'completeness': 94.0,
            },
          }),
        );

        expect(capturedResult, isNotNull);
        expect(capturedResult!['overall'], equals(92.0));
      });
    });

    group('feed method', () {
      test('feed does not crash when not connected', () {
        final evaluator = ShengtongEvaluator(
          appKey: testAppKey,
          secretKey: testSecretKey,
        );

        final testData = Uint8List.fromList([1, 2, 3, 4]);
        expect(() => evaluator.feed(testData), returnsNormally);
      });

      test('feed accepts List<int>', () {
        final evaluator = ShengtongEvaluator(
          appKey: testAppKey,
          secretKey: testSecretKey,
        );

        final testData = List<int>.generate(100, (i) => i % 256);
        expect(() => evaluator.feed(testData), returnsNormally);
      });
    });

    group('stop method', () {
      test('stop does not crash when not evaluating', () {
        final evaluator = ShengtongEvaluator(
          appKey: testAppKey,
          secretKey: testSecretKey,
        );

        expect(() => evaluator.stop(), returnsNormally);
      });
    });

    group('dispose method', () {
      test('dispose does not crash', () {
        final evaluator = ShengtongEvaluator(
          appKey: testAppKey,
          secretKey: testSecretKey,
        );

        expect(() => evaluator.dispose(), returnsNormally);
      });

      test('dispose can be called multiple times', () {
        final evaluator = ShengtongEvaluator(
          appKey: testAppKey,
          secretKey: testSecretKey,
        );

        evaluator.dispose();
        expect(() => evaluator.dispose(), returnsNormally);
      });
    });

    group('start message handling', () {
      test('handles successful start message', () {
        final evaluator = ShengtongEvaluator(
          appKey: testAppKey,
          secretKey: testSecretKey,
        );

        String? capturedError;
        evaluator.onError = (error) {
          capturedError = error;
        };

        evaluator.handleMessage(jsonEncode({'cmd': 'start', 'code': 0}));

        expect(capturedError, isNull);
      });

      test('handles failed start message', () {
        final evaluator = ShengtongEvaluator(
          appKey: testAppKey,
          secretKey: testSecretKey,
        );

        String? capturedError;
        evaluator.onError = (error) {
          capturedError = error;
        };

        evaluator.handleMessage(
          jsonEncode({
            'cmd': 'start',
            'code': 1002,
            'error': 'Invalid ref text',
          }),
        );

        expect(capturedError, contains('Invalid ref text'));
      });
    });

    group('stop message handling', () {
      test('handles stop message', () {
        final evaluator = ShengtongEvaluator(
          appKey: testAppKey,
          secretKey: testSecretKey,
        );

        evaluator.handleMessage(jsonEncode({'cmd': 'stop'}));
      });
    });

    group('Edge cases', () {
      test('handles empty message', () {
        final evaluator = ShengtongEvaluator(
          appKey: testAppKey,
          secretKey: testSecretKey,
        );

        expect(() => evaluator.handleMessage('{}'), returnsNormally);
      });

      test('handles message with unknown cmd', () {
        final evaluator = ShengtongEvaluator(
          appKey: testAppKey,
          secretKey: testSecretKey,
        );

        expect(
          () => evaluator.handleMessage(jsonEncode({'cmd': 'unknown'})),
          returnsNormally,
        );
      });

      test('handles binary message', () {
        final evaluator = ShengtongEvaluator(
          appKey: testAppKey,
          secretKey: testSecretKey,
        );

        expect(
          () => evaluator.handleMessage(Uint8List.fromList([0xFF, 0xFE, 0xFD])),
          returnsNormally,
        );
      });

      test('handles byte array message', () {
        final evaluator = ShengtongEvaluator(
          appKey: testAppKey,
          secretKey: testSecretKey,
        );

        final bytes = utf8.encode(jsonEncode({'cmd': 'connect', 'code': 0}));
        evaluator.handleMessage(bytes);
      });
    });

    group('Multiple results', () {
      test('receives multiple evaluation results sequentially', () {
        final evaluator = ShengtongEvaluator(
          appKey: testAppKey,
          secretKey: testSecretKey,
        );

        final results = <Map<String, dynamic>>[];
        evaluator.onResult = (result) {
          results.add(result);
        };

        evaluator.handleMessage(
          jsonEncode({
            'cmd': 'eval',
            'code': 0,
            'result': {'overall': 80.0, 'fluency': 85.0},
          }),
        );

        evaluator.handleMessage(
          jsonEncode({
            'cmd': 'eval',
            'code': 0,
            'result': {'overall': 90.0, 'fluency': 92.0},
          }),
        );

        expect(results.length, equals(2));
        expect(results[0]['overall'], equals(80.0));
        expect(results[1]['overall'], equals(90.0));
      });

      test('clears result callback after dispose', () {
        final evaluator = ShengtongEvaluator(
          appKey: testAppKey,
          secretKey: testSecretKey,
        );

        bool? capturedState;
        evaluator.onConnectionStateChanged = (state) {
          capturedState = state;
        };

        evaluator.dispose();

        expect(capturedState, equals(false));
      });
    });

    group('Real-world scenarios', () {
      test('simulates complete follow-reading evaluation flow', () {
        final evaluator = ShengtongEvaluator(
          appKey: testAppKey,
          secretKey: testSecretKey,
        );

        Map<String, dynamic>? finalResult;
        String? finalError;
        bool? connected;

        evaluator.onResult = (result) {
          finalResult = result;
        };
        evaluator.onError = (error) {
          finalError = error;
        };
        evaluator.onConnectionStateChanged = (state) {
          connected = state;
        };

        // Step 1: Connect
        evaluator.handleMessage(jsonEncode({'cmd': 'connect', 'code': 0}));
        expect(connected, equals(true));

        // Step 2: Start evaluation
        evaluator.handleMessage(jsonEncode({'cmd': 'start', 'code': 0}));

        // Step 3: Stop evaluation
        evaluator.handleMessage(jsonEncode({'cmd': 'stop'}));

        // Step 4: Receive result
        evaluator.handleMessage(
          jsonEncode({
            'cmd': 'eval',
            'code': 0,
            'result': {
              'overall': 87.5,
              'fluency': 90.0,
              'accuracy': 85.0,
              'completeness': 88.5,
            },
          }),
        );

        expect(finalResult, isNotNull);
        expect(finalResult!['overall'], equals(87.5));
        expect(finalResult!['fluency'], equals(90.0));
        expect(finalResult!['accuracy'], equals(85.0));
        expect(finalResult!['completeness'], equals(88.5));
        expect(finalError, isNull);
      });

      test('handles evaluation failure gracefully', () {
        final evaluator = ShengtongEvaluator(
          appKey: testAppKey,
          secretKey: testSecretKey,
        );

        Map<String, dynamic>? finalResult;
        String? finalError;

        evaluator.onResult = (result) {
          finalResult = result;
        };
        evaluator.onError = (error) {
          finalError = error;
        };

        // Connection fails
        evaluator.handleMessage(
          jsonEncode({
            'cmd': 'connect',
            'code': 4001,
            'error': 'Service unavailable',
          }),
        );

        expect(finalError, contains('Service unavailable'));
        expect(finalResult, isNull);
      });

      test('handles timeout scenario (no result)', () {
        final evaluator = ShengtongEvaluator(
          appKey: testAppKey,
          secretKey: testSecretKey,
        );

        Map<String, dynamic>? finalResult;
        evaluator.onResult = (result) {
          finalResult = result;
        };

        // Connect and start, but no eval result comes
        evaluator.handleMessage(jsonEncode({'cmd': 'connect', 'code': 0}));
        evaluator.handleMessage(jsonEncode({'cmd': 'start', 'code': 0}));

        // No result should have been captured
        expect(finalResult, isNull);
      });
    });
  });
}
