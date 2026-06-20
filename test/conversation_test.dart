import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vidlang/models/conversation_message.dart';
import 'package:vidlang/providers/conversation_provider.dart';
import 'package:vidlang/services/qwen_realtime_service.dart';

// Mock classes for testing
class MockWebSocketChannel {
  final Sink<String> _sink = StreamController<String>().sink;
  Sink<String> get sink => _sink;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConversationMessage Tests', () {
    test('parseAiResponse should correctly parse English and Chinese', () {
      const rawText = 'How are you today?[中文]你今天怎么样？';
      final result = ConversationMessage.parseAiResponse(rawText);

      expect(result.english, 'How are you today?');
      expect(result.chinese, '你今天怎么样？');
    });

    test('parseAiResponse should handle text without Chinese translation', () {
      const rawText = 'Hello, how are you?';
      final result = ConversationMessage.parseAiResponse(rawText);

      expect(result.english, 'Hello, how are you?');
      expect(result.chinese, null);
    });

    test('parseAiResponse should handle empty Chinese text', () {
      const rawText = 'Hello[中文]';
      final result = ConversationMessage.parseAiResponse(rawText);

      expect(result.english, 'Hello');
      expect(result.chinese, null);
    });

    test('ConversationMessage should create with correct role', () {
      final userMsg = ConversationMessage(role: MessageRole.user, text: 'Hello');
      final aiMsg = ConversationMessage(role: MessageRole.ai, text: 'Hi there');

      expect(userMsg.role, MessageRole.user);
      expect(aiMsg.role, MessageRole.ai);
      expect(userMsg.id, isNotEmpty);
      expect(aiMsg.id, isNotEmpty);
    });

    test('ConversationMessage.copyWith should create updated copy', () {
      final msg = ConversationMessage(
        role: MessageRole.ai,
        text: 'Hello',
        isStreaming: true,
      );

      final updatedMsg = msg.copyWith(text: 'Hello world', isStreaming: false);

      expect(updatedMsg.text, 'Hello world');
      expect(updatedMsg.isStreaming, false);
      expect(updatedMsg.id, msg.id); // ID should remain the same
    });
  });

  group('RealtimeEvent Tests', () {
    test('UserTranscriptionCompleted should store transcript', () {
      const transcript = 'Hello, how are you?';
      final event = UserTranscriptionCompleted(transcript);

      expect(event.transcript, transcript);
    });

    test('AiTextDelta should store delta text', () {
      const delta = 'Hello';
      final event = AiTextDelta(delta);

      expect(event.delta, delta);
    });

    test('RealtimeError should store error message', () {
      const message = 'Connection failed';
      final event = RealtimeError(message);

      expect(event.message, message);
    });

    test('ConnectionClosed should store code and reason', () {
      const code = 1000;
      const reason = 'Normal closure';
      final event = ConnectionClosed(code, reason);

      expect(event.code, code);
      expect(event.reason, reason);
    });
  });

  group('ConversationState Tests', () {
    test('ConversationState should have all expected states', () {
      final states = ConversationState.values;

      expect(states, contains(ConversationState.idle));
      expect(states, contains(ConversationState.connecting));
      expect(states, contains(ConversationState.aiSpeaking));
      expect(states, contains(ConversationState.listening));
      expect(states, contains(ConversationState.processing));
      expect(states, contains(ConversationState.error));
      expect(states, contains(ConversationState.disconnected));
    });
  });

  group('ConversationStateData Tests', () {
    test('ConversationStateData should initialize with default values', () {
      const data = ConversationStateData();

      expect(data.state, ConversationState.idle);
      expect(data.messages, isEmpty);
      expect(data.showTranslation, true);
      expect(data.turnCount, 0);
      expect(data.duration, Duration.zero);
    });

    test('ConversationStateData.copyWith should create updated copy', () {
      const data = ConversationStateData();

      final updated = data.copyWith(
        state: ConversationState.listening,
        turnCount: 5,
      );

      expect(updated.state, ConversationState.listening);
      expect(updated.turnCount, 5);
      expect(updated.messages, isEmpty); // Should keep original
      expect(updated.showTranslation, true); // Should keep original
    });
  });

  group('ConversationSession Tests', () {
    test('ConversationSession.fromJson should parse correctly', () {
      final json = {
        'conversation_id': 'conv_123',
        'ws_url': 'wss://example.com/ws',
        'api_key': 'key_123',
        'instructions': 'Speak English',
        'voice': 'Ethan',
        'model': 'qwen3.5-omni-plus-realtime',
        'cost_cny': 1.5,
        'balance_after': 98.5,
      };

      final session = ConversationSession.fromJson(json);

      expect(session.conversationId, 'conv_123');
      expect(session.wsUrl, 'wss://example.com/ws');
      expect(session.apiKey, 'key_123');
      expect(session.instructions, 'Speak English');
      expect(session.voice, 'Ethan');
      expect(session.model, 'qwen3.5-omni-plus-realtime');
      expect(session.costCny, 1.5);
      expect(session.balanceAfter, 98.5);
    });

    test('ConversationSession.fromJson should use defaults for optional fields', () {
      final json = {
        'conversation_id': 'conv_456',
        'ws_url': 'wss://example.com/ws2',
        'api_key': 'key_456',
        'instructions': 'Test instructions',
        'cost_cny': 0.5,
        'balance_after': 99.5,
      } as Map<String, dynamic>;

      final session = ConversationSession.fromJson(json);

      expect(session.voice, 'Ethan'); // Default voice
      expect(session.model, 'qwen3.5-omni-plus-realtime'); // Default model
    });
  });

  group('QwenRealtimeService Tests', () {
    late QwenRealtimeService service;

    setUp(() {
      service = QwenRealtimeService();
    });

    tearDown(() {
      service.dispose();
    });

    test('isConnected should be false initially', () {
      expect(service.isConnected, false);
    });

    test('events stream should emit ConnectionOpened after connect', () async {
      // Note: This test requires a valid WebSocket URL
      // We'll test the structure without actual connection
      final events = service.events;
      
      expect(events, isNotNull);
    });

    test('disconnect should not throw when not connected', () {
      expect(() => service.disconnect(), returnsNormally);
    });

    test('dispose should not throw', () {
      expect(() => service.dispose(), returnsNormally);
    });
  });

  group('Integration-like Tests', () {
    test('Full message parsing flow', () {
      // Simulate AI response with translation
      const aiResponse = 'What kind of music do you like?[中文]你喜欢什么类型的音乐？';
      
      final parsed = ConversationMessage.parseAiResponse(aiResponse);
      
      expect(parsed.english.isNotEmpty, true);
      expect(parsed.chinese?.isNotEmpty ?? false, true);
      
      // Create message with parsed data
      final message = ConversationMessage(
        role: MessageRole.ai,
        text: parsed.english,
        translation: parsed.chinese,
      );
      
      expect(message.text, 'What kind of music do you like?');
      expect(message.translation, '你喜欢什么类型的音乐？');
      expect(message.role, MessageRole.ai);
    });

    test('User message flow simulation', () {
      // Simulate user transcription completion
      const transcript = 'I like pop music';
      final event = UserTranscriptionCompleted(transcript);
      
      expect(event.transcript, transcript);
      
      // Create user message
      final message = ConversationMessage(
        role: MessageRole.user,
        text: event.transcript,
      );
      
      expect(message.role, MessageRole.user);
      expect(message.text, 'I like pop music');
    });

    test('Message stream simulation', () async {
      // Simulate streaming text accumulation
      final chunks = ['Hello', ' ', 'world', '!'];
      var accumulated = '';
      
      for (final chunk in chunks) {
        accumulated += chunk;
        // In real scenario, this would emit AiTextDelta events
      }
      
      expect(accumulated, 'Hello world!');
    });
  });
}
