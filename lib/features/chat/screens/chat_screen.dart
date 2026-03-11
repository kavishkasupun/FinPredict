import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:finpredict/widgets/glass_card.dart';
import 'package:finpredict/widgets/custom_text_field.dart';
import 'package:finpredict/services/firebase_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;

  // ============================================
  // APP CONTEXT - FinPredict App Details
  // ============================================
  final String _appContext = '''
You are the AI assistant for FinPredict, a personal finance management mobile app.
App Features:
1. EXPENSE TRACKING: Users can add, view, and categorize daily expenses
2. INCOME MANAGEMENT: Track multiple income sources
3. AI EXPENSE ALERTS: ML model predicts when expenses are too high and sends notifications
4. NEXT MONTH SPENDING FORECAST: ML predicts future spending based on patterns
5. USER CATEGORIES: Supports Employees, Students, Non-employees, Self-employed
6. TASK MANAGEMENT: Daily task tracking with reminders
7. LOAN MANAGEMENT: Track personal loans given to others (borrowers, amounts, remaining)
8. MOOD TRACKING: Track emotional state related to financial decisions
9. CHATBOT: You are this financial assistant

Rules:
- ONLY answer questions about FinPredict app features, finance, budgeting, saving, expenses, loans, or using the app
- If asked about anything else (weather, sports, general knowledge, coding, etc.), politely decline: "I'm FinPredict's financial assistant. I can only help with finance-related questions and using the FinPredict app. Please ask about budgeting, expenses, or app features!"
- Be friendly, professional, and helpful for finance topics
- Use simple language suitable for Sri Lankan users
- Give practical financial advice based on user type (student/employee/self-employed)
''';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final message = _messageController.text.trim();
    final timestamp = DateTime.now();

    // Save user message
    await _firebaseService.saveChatMessage(_currentUser!.uid, {
      'message': message,
      'sender': 'user',
      'timestamp': timestamp,
    });

    setState(() {
      _isLoading = true;
    });

    // Get AI response from API
    final aiResponse = await _getAIResponse(message);

    // Save AI response
    await _firebaseService.saveChatMessage(_currentUser!.uid, {
      'message': aiResponse,
      'sender': 'ai',
      'timestamp': DateTime.now(),
    });

    setState(() {
      _isLoading = false;
    });

    _messageController.clear();
    _scrollToBottom();
  }

  // ============================================
  // AI API CALL - Gemini Integration
  // ============================================
  Future<String> _getAIResponse(String userMessage) async {
    try {
      // Check for local patterns first (fallback)
      final localResponse = _checkLocalPatterns(userMessage);
      if (localResponse != null) {
        return localResponse;
      }

      // Call Gemini API
      const apiKey =
          'AIzaSyAIHWutDAF4uSJNn01-3vDFfGn-Roh9MIk'; // Replace with your key
      const apiUrl =
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$apiKey';

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': '$_appContext\n\nUser question: $userMessage'}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 500,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiText = data['candidates'][0]['content']['parts'][0]['text'];
        return aiText.trim();
      } else {
        print('API Error: ${response.statusCode} - ${response.body}');
        return _getFallbackResponse(userMessage);
      }
    } catch (e) {
      print('Error calling AI API: $e');
      return _getFallbackResponse(userMessage);
    }
  }

  // ============================================
  // LOCAL PATTERNS - Quick responses without API
  // ============================================
  String? _checkLocalPatterns(String message) {
    final lowerMessage = message.toLowerCase();

    // Greetings
    if (lowerMessage.contains('hello') ||
        lowerMessage.contains('hi') ||
        lowerMessage.contains('hey')) {
      return 'Hello! 👋 I\'m your FinPredict AI assistant. How can I help you with your finances today? You can ask about budgeting, expenses, loans, or how to use the app!';
    }

    // Thanks
    if (lowerMessage.contains('thank') || lowerMessage.contains('thanks')) {
      return 'You\'re welcome! 💪 Remember, financial success is a journey. Keep tracking your expenses and stay consistent with your goals!';
    }

    // App features overview
    if (lowerMessage.contains('what can you do') ||
        lowerMessage.contains('features') ||
        lowerMessage.contains('help')) {
      return '''I can help you with FinPredict app features:

💰 **Expense Tracking** - Add and categorize your daily expenses
📊 **AI Analysis** - Get alerts when spending is too high
🔮 **Spending Forecast** - See next month's predicted expenses  
👤 **User Types** - Special tips for Students/Employees/Self-employed
✅ **Task Manager** - Track your daily financial tasks
💸 **Loan Tracker** - Manage money lent to others
😊 **Mood Tracking** - Understand how emotions affect spending

What would you like to know about?''';
    }

    return null; // No local match, use API
  }

  // ============================================
  // FALLBACK RESPONSES - When API fails
  // ============================================
  String _getFallbackResponse(String message) {
    final lowerMessage = message.toLowerCase();

    // Budget related
    if (lowerMessage.contains('budget') || lowerMessage.contains('save')) {
      return '''💡 **Budgeting Tips for FinPredict:**

1. **Track Everything** - Use the app to log every expense, no matter how small
2. **50/30/20 Rule** - 50% needs, 30% wants, 20% savings
3. **Set Goals** - Use our AI to set realistic monthly budgets
4. **Review Weekly** - Check your spending patterns in the app

For your user type, I can give specific advice! Are you a Student, Employee, or Self-employed?''';
    }

    // Expense related
    if (lowerMessage.contains('expense') || lowerMessage.contains('spend')) {
      return '''📊 **Expense Management in FinPredict:**

• Tap the "+" button to add new expenses
• Categorize as Food, Transport, Bills, etc.
• The AI will alert you if spending is too high
• View monthly reports to see patterns

**Tip:** Add expenses immediately after spending to build good habits!''';
    }

    // Loan related
    if (lowerMessage.contains('loan') ||
        lowerMessage.contains('borrow') ||
        lowerMessage.contains('lend')) {
      return '''💸 **Loan Management in FinPredict:**

• Go to Loans section to track money given to others
• Add borrower name, amount, and due date
• Track remaining balance automatically
• Get reminders for pending repayments

Never forget who owes you money again! 📱''';
    }

    // Notification related
    if (lowerMessage.contains('notification') ||
        lowerMessage.contains('alert')) {
      return '''🔔 **FinPredict Notifications:**

• **Expense Alerts** - When you spend >80% of income
• **Task Reminders** - Daily financial tasks
• **Loan Due Dates** - When borrowers should repay
• **AI Forecasts** - Weekly spending predictions

Enable notifications in Settings to stay on track!''';
    }

    // Default fallback
    return '''I'm FinPredict's financial assistant! 🤖

I can help you with:
• Using the FinPredict app features
• Budgeting and saving strategies
• Managing expenses and loans
• Understanding your spending patterns

What specific finance topic would you like help with? Or ask me how to use any app feature!''';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'AI Financial Assistant',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Clear chat button
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white70),
            onPressed: () => _showClearChatDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firebaseService.firestore
                  .collection('users')
                  .doc(_currentUser!.uid)
                  .collection('chat_history')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFBA002)),
                  );
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message =
                        messages[index].data() as Map<String, dynamic>;
                    final isUser = message['sender'] == 'user';

                    return Align(
                      alignment:
                          isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.8,
                        ),
                        child: GlassCard(
                          borderRadius: 20,
                          blur: 10,
                          color: isUser
                              ? const Color(0xFF3B82F6).withOpacity(0.3)
                              : const Color(0xFFFBA002).withOpacity(0.2),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isUser)
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.auto_awesome,
                                        color: Color(0xFFFBA002),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'FinPredict AI',
                                        style: TextStyle(
                                          color: Color(0xFFFBA002),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                if (!isUser) const SizedBox(height: 8),
                                Text(
                                  message['message'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Loading indicator
          if (_isLoading)
            Container(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFFBA002),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AI is thinking...',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

          // Input area
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF0F172A),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: GlassCard(
                      borderRadius: 25,
                      blur: 10,
                      child: CustomTextField(
                        controller: _messageController,
                        label: '',
                        hintText: 'Ask about finances, budget, app features...',
                        maxLines: 1,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFBA002), Color(0xFFFFD166)],
                      ),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: IconButton(
                      onPressed: _isLoading ? null : _sendMessage,
                      icon: const Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearChatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Clear Chat?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will delete all chat history. This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              // Delete chat history from Firestore
              final batch = _firebaseService.firestore.batch();
              final chatRef = _firebaseService.firestore
                  .collection('users')
                  .doc(_currentUser!.uid)
                  .collection('chat_history');

              final snapshots = await chatRef.get();
              for (var doc in snapshots.docs) {
                batch.delete(doc.reference);
              }
              await batch.commit();

              Navigator.pop(context);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
