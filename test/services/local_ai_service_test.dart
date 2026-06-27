import 'package:flutter_test/flutter_test.dart';
import 'package:vidlang/services/local_ai_service.dart';
import 'package:vidlang/services/local_tts_service.dart';
import 'package:vidlang/services/local_stt_service.dart';

void main() {
  group('LocalAiService', () {
    late LocalAiService aiService;

    setUp(() {
      aiService = LocalAiService.instance;
    });

    test('should be singleton', () {
      final instance1 = LocalAiService.instance;
      final instance2 = LocalAiService.instance;
      expect(instance1, same(instance2));
    });

    test('should have initial state as not initialized', () {
      expect(aiService.isInitialized, false);
      expect(aiService.isInitializing, false);
    });

    test('should return feature status', () {
      final status = aiService.getFeatureStatus(LocalAiFeature.tts);
      expect(status, isA<LocalAiFeatureStatus>());
    });

    test('translate should return fallback message', () async {
      final result = await aiService.translate(text: 'Hello');
      expect(result, contains('云端翻译'));
    });
  });

  group('LocalTtsService', () {
    test('should be singleton', () {
      final instance1 = LocalTtsService.instance;
      final instance2 = LocalTtsService.instance;
      expect(instance1, same(instance2));
    });
  });

  group('LocalSttService', () {
    test('should be singleton', () {
      final instance1 = LocalSttService.instance;
      final instance2 = LocalSttService.instance;
      expect(instance1, same(instance2));
    });
  });
}
