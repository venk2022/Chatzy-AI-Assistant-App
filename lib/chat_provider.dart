import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';

class ChatProvider extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;

  Map<String, List<ChatMessage>> get groupedMessages {
    final Map<String, List<ChatMessage>> grouped = {};
    for (final message in _messages) {
      final dateKey = DateFormat('yyyy-MM-dd').format(message.timestamp);
      grouped.putIfAbsent(dateKey, () => []);
      grouped[dateKey]!.add(message);
    }
    return grouped;
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void sendMessage(String message) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userMessage = ChatMessage(
      id: null,
      text: message,
      isUser: true,
      timestamp: DateTime.now(),
    );

    _messages.add(userMessage);
    notifyListeners();

    final docRef = await _firestore.collection('messages').add({
      'userId': user.uid,
      'text': message,
      'isUser': true,
      'timestamp': FieldValue.serverTimestamp(),
    });

    userMessage.id = docRef.id;

    // Set loading state before getting bot response
    _setLoading(true);
    await getBotResponse(message);
    _setLoading(false);
  }

  Future<void> getBotResponse(String userMessage) async {
    final String? apiKey = dotenv.env['GEMINI_API_KEY'];
    final user = _auth.currentUser;
    if (user == null) return;

    if (apiKey == null || apiKey.isEmpty) {
      _addErrorMessage("❌ Gemini API key not found. Please check your .env file.");
      return;
    }

    const String modelName = "gemini-1.5-flash";
    final String apiUrl =
        "https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey";

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": userMessage}
              ]
            }
          ]
        }),
      );

      String reply;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        reply = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? "🤖 No response from Gemini.";
      } else if (response.statusCode == 429) {
        reply = "⚠️ Too many requests to Gemini. Please wait and try again.";
      } else {
        final errorMsg = jsonDecode(response.body)['error']?['message'] ?? 'Unknown error.';
        reply = "❌ Error ${response.statusCode}: $errorMsg";
      }

      final botMessage = ChatMessage(
        id: null,
        text: reply.trim(),
        isUser: false,
        timestamp: DateTime.now(),
      );

      _messages.add(botMessage);
      notifyListeners();

      final docRef = await _firestore.collection('messages').add({
        'userId': user.uid,
        'text': botMessage.text,
        'isUser': false,
        'timestamp': FieldValue.serverTimestamp(),
      });

      botMessage.id = docRef.id;
    } catch (e) {
      _addErrorMessage("❌ Exception: ${e.toString()}");
    }
  }

  void _addErrorMessage(String errorMessage) {
    final botMessage = ChatMessage(
      id: null,
      text: errorMessage,
      isUser: false,
      timestamp: DateTime.now(),
    );

    _messages.add(botMessage);
    notifyListeners();
  }

  void loadMessages() async {
    final user = _auth.currentUser;
    if (user == null) return;

    _setLoading(true);

    try {
      final snapshot = await _firestore
          .collection('messages')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: false)
          .get();

      final loadedMessages = snapshot.docs.map((doc) {
        final data = doc.data();
        final rawTimestamp = data['timestamp'];
        DateTime timestamp;

        // ✅ Robust timestamp conversion
        if (rawTimestamp is Timestamp) {
          timestamp = rawTimestamp.toDate();
        } else if (rawTimestamp is DateTime) {
          timestamp = rawTimestamp;
        } else if (rawTimestamp is String) {
          timestamp = DateTime.tryParse(rawTimestamp) ?? DateTime.now();
        } else {
          timestamp = DateTime.now(); // fallback
        }

        return ChatMessage(
          id: doc.id,
          text: data['text'],
          isUser: data['isUser'],
          timestamp: timestamp,
        );
      }).toList();

      _messages.clear();
      _messages.addAll(loadedMessages);
    } catch (e) {
      _addErrorMessage("❌ Error loading messages: ${e.toString()}");
    } finally {
      _setLoading(false);
    }
  }

  void updateMessageById(String id, String newText) async {
    final index = _messages.indexWhere((msg) => msg.id == id);
    if (index != -1) {
      _messages[index].text = newText;
      notifyListeners();

      try {
        await _firestore.collection('messages').doc(id).update({
          'text': newText,
        });
      } catch (e) {
        _addErrorMessage("❌ Error updating message: ${e.toString()}");
      }
    }
  }

  void deleteMessageById(String id) async {
    _messages.removeWhere((msg) => msg.id == id);
    notifyListeners();

    try {
      await _firestore.collection('messages').doc(id).delete();
    } catch (e) {
      _addErrorMessage("❌ Error deleting message: ${e.toString()}");
    }
  }

  Future<void> deleteAllMessages() async {
    final user = _auth.currentUser;
    if (user == null) return;

    _setLoading(true);

    try {
      final snapshot = await _firestore
          .collection('messages')
          .where('userId', isEqualTo: user.uid)
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      _messages.clear();
      notifyListeners();
    } catch (e) {
      _addErrorMessage("❌ Error deleting all messages: ${e.toString()}");
    } finally {
      _setLoading(false);
    }
  }

  // Additional helper methods for better UX
  int get totalMessageCount => _messages.length;

  int get conversationCount => (_messages.length / 2).floor();

  bool get hasMessages => _messages.isNotEmpty;

  ChatMessage? get lastMessage => _messages.isNotEmpty ? _messages.last : null;

  String get lastActivity {
    if (_messages.isEmpty) return "No messages yet";
    final lastMsg = _messages.last;
    final now = DateTime.now();
    final diff = now.difference(lastMsg.timestamp);

    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return DateFormat('MMM dd').format(lastMsg.timestamp);
  }
}

class ChatMessage {
  String? id;
  String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}