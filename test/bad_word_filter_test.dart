import 'package:flutter_test/flutter_test.dart';
import 'package:barrim/src/utils/bad_word_filter.dart';

void main() {
  group('BadWordFilter Tests', () {
    test('should detect bad words in text', () {
      expect(BadWordFilter.containsBadWords('This is a test'), false);
      expect(BadWordFilter.containsBadWords('This is a bad word test'), false);
      expect(BadWordFilter.containsBadWords('This contains fuck'), true);
      expect(BadWordFilter.containsBadWords('This contains FUCK'), true);
      expect(BadWordFilter.containsBadWords('This contains f*ck'), true);
    });

    test('should get list of bad words found', () {
      final badWords = BadWordFilter.getBadWordsFound('This contains fuck and shit');
      expect(badWords.length, 2);
      expect(badWords.contains('fuck'), true);
      expect(badWords.contains('shit'), true);
    });

    test('should filter bad words from text', () {
      final filtered = BadWordFilter.filterBadWords('This contains fuck and shit');
      expect(filtered, 'This contains **** and ****');
    });

    test('should handle empty text', () {
      expect(BadWordFilter.containsBadWords(''), false);
      expect(BadWordFilter.getBadWordsFound(''), isEmpty);
      expect(BadWordFilter.filterBadWords(''), '');
    });

    test('should detect Arabic/Lebanese offensive terms', () {
      expect(BadWordFilter.containsBadWords('ya kalb'), true);
      expect(BadWordFilter.containsBadWords('ya ibn kalb'), true);
      expect(BadWordFilter.containsBadWords('ya sharmouta'), true);
    });

    test('should detect leetspeak variations', () {
      expect(BadWordFilter.containsBadWords('f*ck'), true);
      expect(BadWordFilter.containsBadWords('f**k'), true);
      expect(BadWordFilter.containsBadWords('sh*t'), true);
    });

    test('should detect abbreviations', () {
      expect(BadWordFilter.containsBadWords('wtf'), true);
      expect(BadWordFilter.containsBadWords('omg'), true);
      expect(BadWordFilter.containsBadWords('lol'), true);
    });
  });
}
