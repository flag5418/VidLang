import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vidlang/models/shengtong_result.dart';

void main() {
  group('ShengtongSentenceResult', () {
    test('parses minimal sentence result', () {
      final json = {
        'overall': 85,
        'fluency': 82,
        'pronunciation': 84,
        'integrity': 90,
        'rhythm': 78,
      };

      final result = ShengtongSentenceResult.fromJson(json);

      expect(result.overall, equals(85.0));
      expect(result.fluency, equals(82.0));
      expect(result.pronunciation, equals(84.0));
      expect(result.integrity, equals(90.0));
      expect(result.rhythm, equals(78.0));
      expect(result.words, isEmpty);
    });

    test('parses full sentence result with all fields', () {
      final json = {
        'overall': 49,
        'speed': 104,
        'resource_version': '4.0.4',
        'scorable_word_count': 5,
        'pronunciation': 49,
        'fluency': 64,
        'rhythm': 58,
        'integrity': 100,
        'duration': '4.356',
        'numeric_duration': 4.356,
        'pause_count': 3,
        'rear_tone': 'fall',
        'emotion': 52,
        'kernel_version': '6.4.2',
        'words': [
          {
            'word': 'It',
            'charType': 0,
            'scores': {
              'overall': 99,
              'pronunciation': 99,
              'prominence': 0,
            },
            'word_parts': [
              {
                'part': 'It',
                'charType': 0,
                'beginIndex': 0,
                'endIndex': 1,
              },
            ],
          },
        ],
        'liaison': [
          {
            'first': {'word': 'It', 'index': 0},
            'second': {'word': 'is', 'index': 1},
            'linkable_type': 0,
            'first_phoneme': 't',
            'second_phoneme': 'ɪ',
          },
        ],
        'plosion': [
          {
            'first': {'word': 'old', 'index': 3},
            'second': {'word': 'book', 'index': 4},
            'linkable_type': 3,
            'first_phoneme': 'd',
            'second_phoneme': 'b',
          },
        ],
        'warning': [
          {
            'code': 1004,
            'message': 'Audio noisy!',
          },
        ],
      };

      final result = ShengtongSentenceResult.fromJson(json);

      expect(result.overall, equals(49.0));
      expect(result.speed, equals(104));
      expect(result.scorableWordCount, equals(5));
      expect(result.pronunciation, equals(49.0));
      expect(result.fluency, equals(64.0));
      expect(result.rhythm, equals(58.0));
      expect(result.integrity, equals(100.0));
      expect(result.duration, equals(4.356));
      expect(result.numericDuration, equals(4.356));
      expect(result.pauseCount, equals(3));
      expect(result.rearTone, equals('fall'));
      expect(result.emotion, equals(52));
      expect(result.kernelVersion, equals('6.4.2'));
      expect(result.resourceVersion, equals('4.0.4'));
      expect(result.words.length, equals(1));
      expect(result.words.first.word, equals('It'));
      expect(result.words.first.scores.overall, equals(99.0));
      expect(result.liaison, isNotNull);
      expect(result.liaison!.length, equals(1));
      expect(result.liaison![0].firstWord.word, equals('It'));
      expect(result.liaison![0].firstWord.index, equals(0));
      expect(result.liaison![0].linkableType, equals(0));
      expect(result.plosion, isNotNull);
      expect(result.plosion!.length, equals(1));
      expect(result.plosion![0].firstPhoneme, equals('d'));
      expect(result.warning, isNotNull);
      expect(result.warning!.length, equals(1));
      expect(result.warning!.first.code, equals(1004));
      expect(result.warning!.first.message, equals('Audio noisy!'));
    });

    test('handles float precision scores', () {
      final json = {
        'overall': 87.5,
        'fluency': 90.0,
        'pronunciation': 85.3,
        'integrity': 88.0,
        'rhythm': 76.8,
      };

      final result = ShengtongSentenceResult.fromJson(json);

      expect(result.overall, equals(87.5));
      expect(result.pronunciation, equals(85.3));
      expect(result.rhythm, equals(76.8));
    });

    test('handles empty words array', () {
      final json = {
        'overall': 50,
        'fluency': 50,
        'pronunciation': 50,
        'integrity': 50,
        'rhythm': 50,
        'words': [],
      };

      final result = ShengtongSentenceResult.fromJson(json);
      expect(result.words, isEmpty);
    });

    test('handles missing optional fields', () {
      final json = {
        'overall': 60,
        'fluency': 60,
        'pronunciation': 60,
        'integrity': 60,
        'rhythm': 60,
      };

      final result = ShengtongSentenceResult.fromJson(json);
      expect(result.speed, isNull);
      expect(result.duration, isNull);
      expect(result.numericDuration, isNull);
      expect(result.pauseCount, isNull);
      expect(result.rearTone, isNull);
      expect(result.emotion, isNull);
    });

    test('serializes to JSON correctly', () {
      final result = ShengtongSentenceResult(
        overall: 85.0,
        fluency: 82.0,
        pronunciation: 84.0,
        integrity: 90.0,
        rhythm: 78.0,
        speed: 104,
        duration: 4.356,
        pauseCount: 3,
        rearTone: 'fall',
      );

      final json = result.toJson();
      expect(json['overall'], equals(85.0));
      expect(json['fluency'], equals(82.0));
      expect(json['pronunciation'], equals(84.0));
      expect(json['integrity'], equals(90.0));
      expect(json['rhythm'], equals(78.0));
      expect(json['speed'], equals(104));
      expect(json['rear_tone'], equals('fall'));
    });
  });

  group('ShengtongWordResult', () {
    test('parses word with scores', () {
      final json = {
        'word': 'Today',
        'charType': 0,
        'scores': {
          'pronunciation': 88,
          'overall': 88,
        },
        'word_parts': [
          {
            'part': 'Today',
            'charType': 0,
            'endIndex': 4,
            'beginIndex': 0,
          },
        ],
      };

      final word = ShengtongWordResult.fromJson(json);

      expect(word.word, equals('Today'));
      expect(word.charType, equals(0));
      expect(word.scores.pronunciation, equals(88.0));
      expect(word.scores.overall, equals(88.0));
      expect(word.wordParts.length, equals(1));
      expect(word.wordParts.first.part, equals('Today'));
    });

    test('parses word with phonemes', () {
      final json = {
        'word': 'It',
        'charType': 0,
        'scores': {
          'overall': 99,
          'pronunciation': 99,
        },
        'phonemes': [
          {
            'phoneme': 'ɪ',
            'span': {'start': 122, 'end': 142},
            'pronunciation': 97,
            'stress_mark': 0,
          },
          {
            'phoneme': 't',
            'span': {'start': 142, 'end': 153},
            'pronunciation': 100,
            'stress_mark': 0,
          },
        ],
        'word_parts': [
          {
            'part': 'It',
            'charType': 0,
            'beginIndex': 0,
            'endIndex': 1,
          },
        ],
      };

      final word = ShengtongWordResult.fromJson(json);

      expect(word.phonemes, isNotNull);
      expect(word.phonemes!.length, equals(2));
      expect(word.phonemes![0].phoneme, equals('ɪ'));
      expect(word.phonemes![0].pronunciation, equals(97.0));
      expect(word.phonemes![0].span.start, equals(122));
      expect(word.phonemes![0].span.end, equals(142));
      expect(word.phonemes![1].phoneme, equals('t'));
      expect(word.phonemes![1].pronunciation, equals(100.0));
    });

    test('parses word with pause', () {
      final json = {
        'word': 'an',
        'charType': 0,
        'scores': {
          'overall': 1,
          'pronunciation': 1,
        },
        'pause': {
          'type': 1,
          'duration': 37,
        },
        'readType': 3,
        'word_parts': [
          {
            'part': 'an',
            'charType': 0,
            'beginIndex': 6,
            'endIndex': 7,
          },
        ],
      };

      final word = ShengtongWordResult.fromJson(json);

      expect(word.readType, equals(3)); // 漏读
      expect(word.pause, isNotNull);
      expect(word.pause!.type, equals(1));
      expect(word.pause!.duration, equals(37));
    });

    test('parses word with phonics', () {
      final json = {
        'word': 'It',
        'charType': 0,
        'scores': {'overall': 97, 'pronunciation': 97},
        'phonics': [
          {
            'spell': 'I',
            'phoneme': ['ɪ'],
            'overall': 97,
          },
          {
            'spell': 't',
            'phoneme': ['t'],
            'overall': 100,
          },
        ],
        'word_parts': [
          {
            'part': 'It',
            'charType': 0,
            'beginIndex': 0,
            'endIndex': 1,
          },
        ],
      };

      final word = ShengtongWordResult.fromJson(json);

      expect(word.phonics, isNotNull);
      expect(word.phonics!.length, equals(2));
      expect(word.phonics![0].spell, equals('I'));
      expect(word.phonics![0].phoneme, equals(['ɪ']));
      expect(word.phonics![0].overall, equals(97.0));
    });

    test('parses word with stress info', () {
      final json = {
        'word': 'It',
        'charType': 0,
        'scores': {
          'overall': 99,
          'pronunciation': 99,
          'stress': [
            {
              'phoneme_offset': 0,
              'phonetic': 'ɪt',
              'ref_stress': 1,
              'spell': 'It',
              'overall': 99,
              'stress': 1,
            },
          ],
          'prominence': 0,
        },
        'word_parts': [
          {
            'part': 'It',
            'charType': 0,
            'beginIndex': 0,
            'endIndex': 1,
          },
        ],
      };

      final word = ShengtongWordResult.fromJson(json);

      expect(word.scores.stress, isNotNull);
      expect(word.scores.stress!.length, equals(1));
      expect(word.scores.stress![0].phonetic, equals('ɪt'));
      expect(word.scores.stress![0].spell, equals('It'));
      expect(word.scores.stress![0].stress, equals(1)); // 重读
      expect(word.scores.stress![0].refStress, equals(1));
      expect(word.scores.prominence, equals(0));
    });

    test('parses punctuation word', () {
      final json = {
        'word': '.',
        'charType': 1,
        'scores': {'pronunciation': 7, 'overall': 7},
        'word_parts': [
          {
            'part': '.',
            'charType': 1,
            'beginIndex': 18,
            'endIndex': 19,
          },
        ],
      };

      final word = ShengtongWordResult.fromJson(json);
      expect(word.charType, equals(1));
      expect(word.word, equals('.'));
    });
  });

  group('ShengtongWordScores', () {
    test('parses with all fields', () {
      final json = {
        'overall': 99,
        'pronunciation': 99,
        'prominence': 0,
        'stress': [
          {
            'phoneme_offset': 0,
            'phonetic': 'ɪt',
            'ref_stress': 1,
            'spell': 'It',
            'overall': 99,
            'stress': 1,
          },
        ],
      };

      final scores = ShengtongWordScores.fromJson(json);
      expect(scores.overall, equals(99.0));
      expect(scores.pronunciation, equals(99.0));
      expect(scores.prominence, equals(0));
      expect(scores.stress!.length, equals(1));
    });

    test('handles null json', () {
      final scores = ShengtongWordScores.fromJson(null);
      expect(scores.overall, equals(0.0));
      expect(scores.pronunciation, equals(0.0));
      expect(scores.prominence, isNull);
      expect(scores.stress, isNull);
    });

    test('handles empty json', () {
      final scores = ShengtongWordScores.fromJson({});
      expect(scores.overall, equals(0.0));
      expect(scores.pronunciation, equals(0.0));
    });
  });

  group('ShengtongEvalMessage', () {
    test('parses complete eval message', () {
      final json = {
        'timestamp': '2020-12-14 14:26:25:377',
        'eof': 1,
        'recordId': 'xxx123',
        'result': {
          'overall': 56,
          'fluency': 56,
          'pronunciation': 56,
          'integrity': 100,
          'rhythm': 50,
          'scorable_word_count': 5,
          'words': [
            {
              'word': 'Today',
              'charType': 0,
              'scores': {'pronunciation': 88, 'overall': 88},
              'word_parts': [
                {
                  'part': 'Today',
                  'charType': 0,
                  'beginIndex': 0,
                  'endIndex': 4,
                },
              ],
            },
          ],
        },
      };

      final message = ShengtongEvalMessage.fromJson(json);

      expect(message.timestamp, equals('2020-12-14 14:26:25:377'));
      expect(message.eof, equals(1)); // 最终结果
      expect(message.recordId, equals('xxx123'));
      expect(message.result, isNotNull);
      expect(message.result!.overall, equals(56.0));
      expect(message.result!.fluency, equals(56.0));
      expect(message.result!.words.length, equals(1));
      expect(message.errId, isNull);
    });

    test('parses error message with errId', () {
      final json = {
        'applicationId': 'xxx',
        'eof': 1,
        'errId': 4001,
        'error': 'Application not found',
        'refText': 'test',
      };

      final message = ShengtongEvalMessage.fromJson(json);

      expect(message.eof, equals(1));
      expect(message.errId, equals(4001));
      expect(message.error, equals('Application not found'));
      expect(message.result, isNull);
    });

    test('identifies intermediate result by eof=0', () {
      final json = {
        'timestamp': '2020-12-14 14:26:25:377',
        'eof': 0,
        'recordId': 'xxx',
        'result': {
          'overall': 50,
          'fluency': 50,
          'pronunciation': 50,
          'integrity': 80,
          'rhythm': 60,
        },
      };

      final message = ShengtongEvalMessage.fromJson(json);
      expect(message.eof, equals(0)); // 中间结果
      expect(message.result, isNotNull);
    });

    test('parses intermediate result (eof=0)', () {
      final json = {
        'timestamp': '2020-12-14 14:26:25:377',
        'eof': 0,
        'result': {
          'overall': 45,
          'fluency': 42,
          'pronunciation': 48,
          'integrity': 70,
          'rhythm': 55,
          'words': [],
        },
      };

      final message = ShengtongEvalMessage.fromJson(json);
      expect(message.eof, equals(0));
      expect(message.result!.overall, equals(45.0));
    });

    test('parses message with liaison and plosion', () {
      final json = {
        'eof': 1,
        'recordId': 'rec_123',
        'result': {
          'overall': 75,
          'fluency': 72,
          'pronunciation': 76,
          'integrity': 85,
          'rhythm': 68,
          'liaison': [
            {
              'first': {'word': 'It', 'index': 0},
              'second': {'word': 'is', 'index': 1},
              'linkable_type': 0,
              'first_phoneme': 't',
              'second_phoneme': 'ɪ',
            },
          ],
          'plosion': [
            {
              'first': {'word': 'old', 'index': 3},
              'second': {'word': 'book', 'index': 4},
              'linkable_type': 3,
              'first_phoneme': 'd',
              'second_phoneme': 'b',
            },
          ],
          'words': [],
        },
      };

      final message = ShengtongEvalMessage.fromJson(json);
      expect(message.result!.liaison!.length, equals(1));
      expect(message.result!.liaison![0].firstWord.word, equals('It'));
      expect(message.result!.liaison![0].secondWord.word, equals('is'));
      expect(message.result!.plosion!.length, equals(1));
      expect(message.result!.plosion![0].firstWord.word, equals('old'));
      expect(message.result!.plosion![0].secondWord.word, equals('book'));
    });

    test('parses message with duration as string', () {
      final json = {
        'eof': 1,
        'result': {
          'overall': 80,
          'fluency': 78,
          'pronunciation': 82,
          'integrity': 85,
          'rhythm': 75,
          'duration': '4.356',
          'numeric_duration': 4.356,
          'pause_count': 3,
          'rear_tone': 'fall',
          'words': [],
        },
      };

      final message = ShengtongEvalMessage.fromJson(json);
      expect(message.result!.duration, equals(4.356));
      expect(message.result!.numericDuration, equals(4.356));
      expect(message.result!.pauseCount, equals(3));
      expect(message.result!.rearTone, equals('fall'));
    });

    test('parses message with emotion score', () {
      final json = {
        'eof': 1,
        'result': {
          'overall': 80,
          'fluency': 78,
          'pronunciation': 82,
          'integrity': 85,
          'rhythm': 75,
          'emotion': 65,
          'words': [],
        },
      };

      final message = ShengtongEvalMessage.fromJson(json);
      expect(message.result!.emotion, equals(65));
    });
  });

  group('Round-trip serialization', () {
    test('sentence result serializes and deserializes correctly', () {
      final original = ShengtongSentenceResult(
        overall: 87.5,
        fluency: 90.0,
        pronunciation: 85.3,
        integrity: 88.0,
        rhythm: 76.8,
        speed: 110,
        duration: 5.2,
        pauseCount: 2,
        rearTone: 'rise',
        emotion: 60,
        words: [
          ShengtongWordResult(
            word: 'hello',
            charType: 0,
            scores: ShengtongWordScores(overall: 90.0, pronunciation: 92.0),
            wordParts: [
              ShengtongWordPart(part: 'hello', charType: 0, beginIndex: 0, endIndex: 5),
            ],
          ),
        ],
      );

      final json = original.toJson();
      final restored = ShengtongSentenceResult.fromJson(json);

      expect(restored.overall, equals(original.overall));
      expect(restored.fluency, equals(original.fluency));
      expect(restored.pronunciation, equals(original.pronunciation));
      expect(restored.integrity, equals(original.integrity));
      expect(restored.rhythm, equals(original.rhythm));
      expect(restored.speed, equals(original.speed));
      expect(restored.words.first.word, equals(original.words.first.word));
    });

    test('eval message serializes and deserializes correctly', () {
      final original = ShengtongEvalMessage(
        timestamp: '2024-01-15 10:30:00:000',
        eof: 1,
        recordId: 'test_record_123',
        result: ShengtongSentenceResult(
          overall: 92.0,
          fluency: 95.0,
          pronunciation: 90.0,
          integrity: 94.0,
          rhythm: 88.0,
        ),
      );

      final json = original.toJson();
      final restored = ShengtongEvalMessage.fromJson(json);

      expect(restored.eof, equals(1));
      expect(restored.recordId, equals('test_record_123'));
      expect(restored.result!.overall, equals(92.0));
      expect(restored.result!.fluency, equals(95.0));
    });
  });

  group('Edge cases', () {
    test('handles zero scores', () {
      final json = {
        'overall': 0,
        'fluency': 0,
        'pronunciation': 0,
        'integrity': 0,
        'rhythm': 0,
        'words': [],
      };

      final result = ShengtongSentenceResult.fromJson(json);
      expect(result.overall, equals(0.0));
      expect(result.fluency, equals(0.0));
    });

    test('handles perfect scores', () {
      final json = {
        'overall': 100,
        'fluency': 100,
        'pronunciation': 100,
        'integrity': 100,
        'rhythm': 100,
        'words': [],
      };

      final result = ShengtongSentenceResult.fromJson(json);
      expect(result.overall, equals(100.0));
      expect(result.fluency, equals(100.0));
    });

    test('handles string duration values', () {
      final json = {
        'overall': 50,
        'fluency': 50,
        'pronunciation': 50,
        'integrity': 50,
        'rhythm': 50,
        'duration': '3.5',
        'words': [],
      };

      final result = ShengtongSentenceResult.fromJson(json);
      expect(result.duration, equals(3.5));
    });

    test('handles empty word array', () {
      final json = {
        'overall': 50,
        'fluency': 50,
        'pronunciation': 50,
        'integrity': 50,
        'rhythm': 50,
        'words': null,
      };

      final result = ShengtongSentenceResult.fromJson(json);
      expect(result.words, isEmpty);
    });

    test('handles null liaison and plosion', () {
      final json = {
        'overall': 50,
        'fluency': 50,
        'pronunciation': 50,
        'integrity': 50,
        'rhythm': 50,
        'words': [],
      };

      final result = ShengtongSentenceResult.fromJson(json);
      expect(result.liaison, isNull);
      expect(result.plosion, isNull);
    });

    test('handles readType values', () {
      final json = {
        'eof': 1,
        'result': {
          'overall': 50,
          'fluency': 50,
          'pronunciation': 50,
          'integrity': 50,
          'rhythm': 50,
          'words': [
            {
              'word': 'normal',
              'charType': 0,
              'scores': {'overall': 80, 'pronunciation': 80},
              'readType': 0,
              'word_parts': [
                {'part': 'normal', 'charType': 0, 'beginIndex': 0, 'endIndex': 6},
              ],
            },
            {
              'word': 'missed',
              'charType': 0,
              'scores': {'overall': 0, 'pronunciation': 0},
              'readType': 3,
              'word_parts': [
                {'part': 'missed', 'charType': 0, 'beginIndex': 7, 'endIndex': 13},
              ],
            },
          ],
        },
      };

      final message = ShengtongEvalMessage.fromJson(json);
      expect(message.result!.words[0].readType, equals(0)); // 正常
      expect(message.result!.words[1].readType, equals(3)); // 漏读
    });

    test('handles liaison linkable types', () {
      final json = {
        'eof': 1,
        'result': {
          'overall': 50,
          'fluency': 50,
          'pronunciation': 50,
          'integrity': 50,
          'rhythm': 50,
          'liaison': [
            {
              'first': {'word': 'It', 'index': 0},
              'second': {'word': 'is', 'index': 1},
              'linkable_type': 0, // 辅音 + 元音
              'first_phoneme': 't',
              'second_phoneme': 'ɪ',
            },
          ],
          'words': [],
        },
      };

      final message = ShengtongEvalMessage.fromJson(json);
      expect(message.result!.liaison!.first.linkableType, equals(0));
    });

    test('handles plosion linkable type 3 (失去爆破)', () {
      final json = {
        'eof': 1,
        'result': {
          'overall': 50,
          'fluency': 50,
          'pronunciation': 50,
          'integrity': 50,
          'rhythm': 50,
          'plosion': [
            {
              'first': {'word': 'old', 'index': 3},
              'second': {'word': 'book', 'index': 4},
              'linkable_type': 3, // 失去爆破
              'first_phoneme': 'd',
              'second_phoneme': 'b',
            },
          ],
          'words': [],
        },
      };

      final message = ShengtongEvalMessage.fromJson(json);
      expect(message.result!.plosion!.first.linkableType, equals(3));
    });
  });

  group('Convenience methods', () {
    test('can extract top scores from sentence result', () {
      final json = {
        'overall': 85,
        'fluency': 82,
        'pronunciation': 84,
        'integrity': 90,
        'rhythm': 78,
        'words': [],
      };

      final result = ShengtongSentenceResult.fromJson(json);

      // The model stores the key scores that the existing code expects
      expect(result.overall, equals(85.0));
      expect(result.fluency, equals(82.0));
    });
  });
}
