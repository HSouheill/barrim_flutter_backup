import 'package:flutter/material.dart';

class BadWordFilter {
  // List of common inappropriate words and phrases
  static const Set<String> _badWords = {
    // Profanity
    'fuck', 'shit', 'bitch', 'ass', 'damn', 'hell',
    'piss', 'cock', 'dick', 'pussy', 'cunt', 'whore',
    'slut', 'bastard', 'motherfucker', 'fucker', 'fucking',
    'shitty', 'asshole', 'dumbass', 'jackass', 'dickhead',
    
    // Hate speech and offensive terms
    'nigger', 'nigga', 'faggot', 'fag', 'dyke', 'retard',
    'spic', 'chink', 'kike', 'wop', 'gook', 'towelhead',
    'sandnigger', 'raghead', 'cameljockey', 'terrorist',
    
    // Common variations and leetspeak
    'f*ck', 'f**k', 'f***', 'sh*t', 'b*tch', 'a**',
    'd*mn', 'h*ll', 'p*ss', 'c*ck', 'd*ck', 'p*ssy',
    'c*nt', 'wh*re', 'sl*t', 'b*stard', 'm*therf*cker',
    
    // Abbreviations
    'wtf', 'omg', 'lol', 'rofl', 'lmfao', 'stfu',
    'gtfo', 'fml', 'smh', 'tbh', 'imo', 'afaik',
    
    // Arabic/Lebanese context - common offensive terms
    'ya kalb', 'ya ibn kalb', 'ya sharmouta', 'ya zbele',
    'ya haram', 'ya kafir', 'ya munafiq', 'ya fasiq',
    
    // Additional offensive terms
    'idiot', 'moron', 'stupid', 'dumb', 'retarded',
  };

  // Check if text contains bad words
  static bool containsBadWords(String text) {
    if (text.isEmpty) return false;
    
    final lowerText = text.toLowerCase();
    
    // Check for multi-word phrases first
    for (String badPhrase in _badWords) {
      if (badPhrase.contains(' ') && lowerText.contains(badPhrase)) {
        return true;
      }
    }
    
    final words = lowerText.split(RegExp(r'\s+'));
    
    for (String word in words) {
      // Check the original word first (for leetspeak variations)
      if (_badWords.contains(word)) {
        return true;
      }
      
      // Remove punctuation for better matching (for regular words)
      final cleanWord = word.replaceAll(RegExp(r'[^\w]'), '');
      
      if (_badWords.contains(cleanWord)) {
        return true;
      }
      
      // Check for exact matches only, not partial matches
      // This prevents false positives like "bad" matching "badass"
    }
    
    return false;
  }

  // Get a list of bad words found in the text
  static List<String> getBadWordsFound(String text) {
    if (text.isEmpty) return [];
    
    final lowerText = text.toLowerCase();
    final foundBadWords = <String>{};
    
    // Check for multi-word phrases first
    for (String badPhrase in _badWords) {
      if (badPhrase.contains(' ') && lowerText.contains(badPhrase)) {
        foundBadWords.add(badPhrase);
      }
    }
    
    final words = lowerText.split(RegExp(r'\s+'));
    
    for (String word in words) {
      // Check the original word first (for leetspeak variations)
      if (_badWords.contains(word)) {
        foundBadWords.add(word);
      }
      
      // Remove punctuation for better matching (for regular words)
      final cleanWord = word.replaceAll(RegExp(r'[^\w]'), '');
      
      if (_badWords.contains(cleanWord)) {
        foundBadWords.add(cleanWord);
      }
      
      // Only exact matches, no partial matches
    }
    
    return foundBadWords.toList();
  }

  // Filter bad words from text (replace with asterisks)
  static String filterBadWords(String text) {
    if (text.isEmpty) return text;
    
    String filteredText = text;
    final lowerText = text.toLowerCase();
    final words = lowerText.split(RegExp(r'\s+'));
    
    for (String word in words) {
      final cleanWord = word.replaceAll(RegExp(r'[^\w]'), '');
      
      if (_badWords.contains(cleanWord)) {
        final replacement = '*' * cleanWord.length;
        filteredText = filteredText.replaceAll(cleanWord, replacement);
      }
    }
    
    return filteredText;
  }

  // Show warning dialog for bad words
  static Future<bool> showBadWordWarningDialog(BuildContext context, List<String> badWords) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange),
              SizedBox(width: 8),
              Text('Inappropriate Content Detected'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your review contains inappropriate language that violates our community guidelines:',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detected words:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: badWords.map((word) => 
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            word,
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ).toList(),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Please revise your review to remove inappropriate language before submitting.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text('I Understand'),
            ),
          ],
        );
      },
    ).then((value) => value ?? false);
  }
}
