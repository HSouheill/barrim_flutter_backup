# Bad Word Filter Implementation

This document describes the bad word filter system implemented in the Barrim Flutter app to prevent users from posting reviews with inappropriate content.

## Overview

The bad word filter is a comprehensive system that:
- Detects inappropriate language in real-time as users type
- Prevents submission of reviews containing bad words
- Shows visual warnings when inappropriate content is detected
- Displays a detailed warning dialog explaining the issue
- Supports multiple languages including Arabic/Lebanese offensive terms

## Features

### 1. Real-time Detection
- Monitors text input as users type
- Shows immediate visual feedback
- Prevents form submission with inappropriate content

### 2. Comprehensive Word List
- **Profanity**: Common English profanity
- **Hate Speech**: Offensive terms and slurs
- **Leetspeak**: Variations like `f*ck`, `sh*t`, `b*tch`
- **Abbreviations**: Common offensive abbreviations like `wtf`, `omg`, `lol`
- **Arabic/Lebanese**: Offensive terms in Arabic context
- **Multi-word phrases**: Phrases like `ya kalb`, `ya sharmouta`

### 3. Visual Indicators
- Red warning banner below text input
- Warning icon with descriptive text
- Color-coded UI elements (red for warnings)

### 4. User Experience
- Clear explanation of what content is inappropriate
- List of detected problematic words
- Guidance on how to fix the issue
- Option to acknowledge and revise

## Implementation

### Core Files

1. **`lib/src/utils/bad_word_filter.dart`** - Main filter logic
2. **`lib/src/features/authentication/screens/workers/sections/reviews_section.dart`** - Worker reviews integration
3. **`lib/src/features/authentication/screens/category/reviews_section.dart`** - Category reviews integration

### Key Methods

#### `BadWordFilter.containsBadWords(String text)`
Returns `true` if the text contains any inappropriate words.

#### `BadWordFilter.getBadWordsFound(String text)`
Returns a list of all inappropriate words found in the text.

#### `BadWordFilter.showBadWordWarningDialog(BuildContext context, List<String> badWords)`
Shows a warning dialog with the detected inappropriate words.

#### `BadWordFilter.filterBadWords(String text)`
Replaces inappropriate words with asterisks (for display purposes).

## Usage

### Basic Integration

```dart
import '../../../../utils/bad_word_filter.dart';

// Check for bad words before submission
if (BadWordFilter.containsBadWords(commentText)) {
  final badWords = BadWordFilter.getBadWordsFound(commentText);
  final shouldContinue = await BadWordFilter.showBadWordWarningDialog(context, badWords);
  
  if (!shouldContinue) {
    return; // User chose to cancel
  }
  
  // Prevent submission even if user acknowledges
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Please remove inappropriate language before submitting.')),
  );
  return;
}
```

### Real-time Detection

```dart
// Add listener to text controller
_commentController.addListener(_checkForBadWords);

void _checkForBadWords() {
  final text = _commentController.text;
  if (text.isEmpty) {
    setState(() {
      _hasInappropriateContent = false;
      _detectedBadWords = [];
    });
    return;
  }

  final hasBadWords = BadWordFilter.containsBadWords(text);
  final badWords = hasBadWords ? BadWordFilter.getBadWordsFound(text) : [];

  setState(() {
    _hasInappropriateContent = hasBadWords;
    _detectedBadWords = badWords;
  });
}
```

### Visual Warning Indicator

```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    TextField(
      controller: _commentController,
      // ... other properties
    ),
    // Bad word warning indicator
    if (_hasInappropriateContent)
      Container(
        margin: EdgeInsets.only(top: 8),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.red.shade700),
            SizedBox(width: 8),
            Text('Inappropriate content detected'),
          ],
        ),
      ),
  ],
)
```

## Customization

### Adding New Bad Words

To add new inappropriate words, modify the `_badWords` set in `BadWordFilter`:

```dart
static const Set<String> _badWords = {
  // Existing words...
  'newbadword',
  'anotherbadword',
};
```

### Modifying Warning Messages

Customize the warning dialog by modifying the `showBadWordWarningDialog` method:

```dart
static Future<bool> showBadWordWarningDialog(BuildContext context, List<String> badWords) {
  // Customize title, content, and styling
}
```

## Testing

Run the test suite to verify the filter works correctly:

```bash
flutter test test/bad_word_filter_test.dart
```

## Best Practices

1. **Always check before submission**: Don't rely only on real-time detection
2. **Clear user feedback**: Explain what content is inappropriate
3. **Consistent UI**: Use the same warning style across the app
4. **Regular updates**: Keep the bad words list current
5. **Privacy**: Don't log or store the actual inappropriate content

## Future Enhancements

- Machine learning-based detection
- Context-aware filtering
- User reporting system
- Customizable filter levels
- Multi-language support expansion
- Regular expression pattern matching

## Support

For questions or issues with the bad word filter implementation, refer to the code comments or create an issue in the project repository.
