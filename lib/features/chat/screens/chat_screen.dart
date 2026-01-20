import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:finpredict/widgets/glass_card.dart';
import 'package:finpredict/widgets/custom_button.dart';
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

  final List<Map<String, dynamic>> _aiResponses = [
    {
      'keywords': ['hello', 'hi', 'hey'],
      'response':
          'Hello! I\'m your FinPredict AI assistant. How can I help with your finances today?',
    },
    {
      'keywords': ['budget', 'save', 'saving'],
      'response':
          'To save money effectively:\n1. Track all expenses\n2. Set specific savings goals\n3. Use the 50/30/20 rule\n4. Review your budget weekly',
    },
    {
      'keywords': ['expense', 'spend', 'spending'],
      'response':
          'For expense management:\n• Categorize your expenses\n• Set limits for each category\n• Use expense tracking daily\n• Review patterns monthly',
    },
    {
      'keywords': ['loan', 'debt', 'borrow'],
      'response':
          'For loan management:\n1. Prioritize high-interest debts\n2. Make consistent payments\n3. Consider debt consolidation\n4. Build an emergency fund',
    },
    {
      'keywords': ['task', 'reminder', 'todo'],
      'response':
          'For task management:\n• Use the Tasks feature to track todos\n• Set reminders for important deadlines\n• Break big tasks into smaller steps\n• Celebrate completed tasks!',
    },
    {
      'keywords': ['mood', 'feel', 'emotion'],
      'response':
          'Your mood affects financial decisions:\n• Happy: Good for long-term planning\n• Stressed: Avoid major decisions\n• Sad: Focus on small wins\n• Always track mood patterns',
    },
    {
      'keywords': ['thank', 'thanks'],
      'response':
          'You\'re welcome! Remember, financial success is a journey. Keep tracking and stay consistent! 💪',
    },
  ];

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

    // Get AI response
    final aiResponse = _getAIResponse(message);

    // Save AI response
    await _firebaseService.saveChatMessage(_currentUser!.uid, {
      'message': aiResponse,
      'sender': 'ai',
      'timestamp': DateTime.now(),
    });

    _messageController.clear();
    _scrollToBottom();
  }

  String _getAIResponse(String message) {
    final lowerMessage = message.toLowerCase();

    for (final response in _aiResponses) {
      for (final keyword in response['keywords']) {
        if (lowerMessage.contains(keyword)) {
          return response['response'];
        }
      }
    }

    // Default response
    return 'I understand you\'re asking about: "$message"\n\nAs your financial assistant, I recommend:\n1. Tracking all income and expenses\n2. Setting clear financial goals\n3. Reviewing your progress weekly\n4. Adjusting your strategy as needed\n\nFeel free to ask specific questions about budgeting, saving, or loans!';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
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
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
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
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        child: GlassCard(
                          borderRadius: 20,
                          blur: 10,
                          color: isUser
                              ? const Color(0xFF3B82F6).withOpacity(0.2)
                              : const Color(0xFFFBA002).withOpacity(0.2),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isUser)
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.auto_awesome,
                                        color: const Color(0xFFFBA002),
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
                                const SizedBox(height: 4),
                                Text(
                                  message['message'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
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
          // Input area
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF0F172A),
            child: Row(
              children: [
                Expanded(
                  child: GlassCard(
                    borderRadius: 20,
                    blur: 10,
                    child: CustomTextField(
                      controller: _messageController,
                      label: '',
                      hintText: 'Ask about finances, budget, loans...',
                      onChanged: (value) {
                        setState(() {});
                      },
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
                    onPressed: _messageController.text.trim().isEmpty
                        ? null
                        : _sendMessage,
                    icon: const Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
