import 'package:http/http.dart' as http;
import 'dart:convert';

class MoodService {
  // This is a simplified version. In a real app, you would integrate with an ML model
  // or use sentiment analysis API

  Future<String> detectMoodFromText(String text) async {
    try {
      // Simple keyword-based mood detection
      final keywords = {
        'happy': ['good', 'great', 'excellent', 'happy', 'joy', 'love'],
        'sad': ['sad', 'bad', 'terrible', 'upset', 'cry', 'depressed'],
        'stressed': ['stress', 'anxious', 'worried', 'pressure', 'tired'],
        'neutral': ['okay', 'fine', 'normal', 'alright'],
      };

      final lowerText = text.toLowerCase();
      var moodCount = {
        'happy': 0,
        'sad': 0,
        'stressed': 0,
        'neutral': 0,
      };

      for (final entry in keywords.entries) {
        for (final keyword in entry.value) {
          if (lowerText.contains(keyword)) {
            moodCount[entry.key] = moodCount[entry.key]! + 1;
          }
        }
      }

      // Get mood with highest count
      final detectedMood =
          moodCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;

      return detectedMood;
    } catch (e) {
      return 'neutral'; // Default mood
    }
  }

  List<String> getMoodRecommendations(String mood) {
    final recommendations = {
      'happy': [
        'Great! Your positive mood is perfect for financial planning!',
        'Consider reviewing your investment portfolio',
        'Share your financial goals with loved ones',
        'Set up automatic savings while you\'re feeling motivated',
      ],
      'sad': [
        'Remember: Small steps lead to big financial changes',
        'Take a walk and listen to a financial podcast',
        'Review your progress - you\'ve come further than you think!',
        'Treat yourself within budget - self-care is important',
      ],
      'stressed': [
        'Take 5 deep breaths before making any financial decisions',
        'Break down big financial tasks into smaller steps',
        'Remember: Financial journeys have ups and downs',
        'Try meditation apps that focus on financial peace',
      ],
      'neutral': [
        'Perfect time for objective financial planning',
        'Review your monthly budget without emotional bias',
        'Set specific, measurable financial goals',
        'Consider consulting a financial advisor',
      ],
    };

    return recommendations[mood] ??
        [
          'Track your expenses daily',
          'Set financial goals for this month',
          'Review your budget weekly',
        ];
  }
}
