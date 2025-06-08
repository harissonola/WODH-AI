import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

class Message {
  final String id;
  String content;
  final DateTime timestamp;
  final bool isUser;
  List<String> versions;
  List<String> aiResponses;
  int currentVersionIndex;

  Message({
    required this.content,
    required this.isUser,
    String? id,
    DateTime? timestamp,
    List<String>? versions,
    List<String>? aiResponses,
    this.currentVersionIndex = 0,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now(),
        versions = versions ?? [content],
        aiResponses = aiResponses ?? [];

  factory Message.fromFirestore(Map<String, dynamic> data) {
    return Message(
      id: data['id'],
      content: data['content'],
      isUser: data['isUser'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      versions: List<String>.from(data['versions'] ?? []),
      aiResponses: List<String>.from(data['aiResponses'] ?? []),
      currentVersionIndex: data['currentVersionIndex'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'content': content,
      'isUser': isUser,
      'timestamp': timestamp,
      'versions': versions,
      'aiResponses': aiResponses,
      'currentVersionIndex': currentVersionIndex,
    };
  }

  String get formattedTime => DateFormat.Hm().format(timestamp);

  void addVersion(String newContent, String aiResponse) {
    versions.add(newContent);
    aiResponses.add(aiResponse);
    currentVersionIndex = versions.length - 1;
  }

  void setVersion(int index) {
    if (index >= 0 && index < versions.length) {
      currentVersionIndex = index;
      content = versions[index];
    }
  }
}

class Conversation {
  final String id;
  String title;
  final List<Message> messages;
  final DateTime createdAt;

  Conversation({
    String? id,
    required this.title,
    List<Message>? messages,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        messages = messages ?? [],
        createdAt = createdAt ?? DateTime.now();

  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Conversation(
      id: doc.id,
      title: data['title'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'createdAt': createdAt,
    };
  }

  void addMessage(Message message) {
    messages.add(message);
  }

  void updateTitle(String newTitle) {
    title = newTitle.length > 20
        ? '${newTitle.substring(0, 20)}...'
        : newTitle;
  }
}

class ConversationProvider with ChangeNotifier {
  List<Conversation> _conversations = [];
  Conversation? _currentConversation;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userId;

  List<Conversation> get conversations => _conversations;
  Conversation? get currentConversation => _currentConversation;

  void setUserId(String userId) {
    _userId = userId;
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    if (_userId == null) return;

    try {
      final querySnapshot = await _firestore
          .collection('conversations')
          .where('userId', isEqualTo: _userId)
          .orderBy('createdAt', descending: true)
          .get();

      _conversations = querySnapshot.docs
          .map((doc) => Conversation.fromFirestore(doc))
          .toList();

      // Load messages for each conversation
      for (var conv in _conversations) {
        final messagesSnapshot = await _firestore
            .collection('conversations')
            .doc(conv.id)
            .collection('messages')
            .orderBy('timestamp')
            .get();

        conv.messages.addAll(messagesSnapshot.docs
            .map((doc) => Message.fromFirestore(doc.data())));
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading conversations: $e');
    }
  }

  Future<void> _saveConversation(Conversation conversation) async {
    if (_userId == null) return;

    try {
      await _firestore
          .collection('conversations')
          .doc(conversation.id)
          .set({
        ...conversation.toFirestore(),
        'userId': _userId,
      });

      // Save all messages
      for (var message in conversation.messages) {
        await _firestore
            .collection('conversations')
            .doc(conversation.id)
            .collection('messages')
            .doc(message.id)
            .set(message.toFirestore());
      }
    } catch (e) {
      debugPrint('Error saving conversation: $e');
    }
  }

  Future<void> _deleteConversation(String id) async {
    try {
      // First delete all messages
      final messages = await _firestore
          .collection('conversations')
          .doc(id)
          .collection('messages')
          .get();

      for (var doc in messages.docs) {
        await doc.reference.delete();
      }

      // Then delete the conversation
      await _firestore.collection('conversations').doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting conversation: $e');
    }
  }

  void editMessage(String conversationId, int messageIndex, String newContent) {
    final conversation = _conversations.firstWhere((conv) => conv.id == conversationId);
    if (messageIndex >= 0 && messageIndex < conversation.messages.length) {
      conversation.messages[messageIndex].content = newContent;
      _saveConversation(conversation);
      notifyListeners();
    }
  }

  void addMessageVersion(
      String conversationId,
      int messageIndex,
      String newContent,
      String aiResponse,
      ) {
    final conversation = _conversations.firstWhere((conv) => conv.id == conversationId);
    if (messageIndex >= 0 && messageIndex < conversation.messages.length) {
      final message = conversation.messages[messageIndex];
      if (message.isUser) {
        message.addVersion(newContent, aiResponse);

        // Add AI response
        final responseMessage = Message(
          content: aiResponse,
          isUser: false,
        );
        conversation.messages.insert(messageIndex + 1, responseMessage);

        _saveConversation(conversation);
        notifyListeners();
      }
    }
  }

  void setMessageVersion(String messageId, int versionIndex) {
    for (final conv in _conversations) {
      for (final msg in conv.messages) {
        if (msg.id == messageId && msg.isUser) {
          msg.setVersion(versionIndex);
          _saveConversation(conv);
          notifyListeners();
          return;
        }
      }
    }
  }

  Future<void> createNewConversation([String title = 'Nouvelle conversation']) async {
    final newConversation = Conversation(title: title);
    _conversations.insert(0, newConversation);
    _currentConversation = newConversation;
    await _saveConversation(newConversation);
    notifyListeners();
  }

  Future<void> selectConversation(String id) async {
    _currentConversation = _conversations.firstWhere((conv) => conv.id == id);

    // Load messages if not already loaded
    if (_currentConversation!.messages.isEmpty) {
      final messagesSnapshot = await _firestore
          .collection('conversations')
          .doc(id)
          .collection('messages')
          .orderBy('timestamp')
          .get();

      _currentConversation!.messages.addAll(messagesSnapshot.docs
          .map((doc) => Message.fromFirestore(doc.data())));
    }

    notifyListeners();
  }

  Future<void> deleteConversation(String id) async {
    _conversations.removeWhere((conv) => conv.id == id);
    if (_currentConversation?.id == id) {
      _currentConversation = null;
    }
    await _deleteConversation(id);
    notifyListeners();
  }

  Future<void> addMessageToCurrent(String content, bool isUser) async {
    if (_currentConversation == null) {
      await createNewConversation();
    }

    final message = Message(content: content, isUser: isUser);
    _currentConversation!.addMessage(message);

    // Save message to Firestore
    await _firestore
        .collection('conversations')
        .doc(_currentConversation!.id)
        .collection('messages')
        .doc(message.id)
        .set(message.toFirestore());

    notifyListeners();
  }

  Future<void> updateConversationTitle(String conversationId, String newTitle) async {
    final conversation = _conversations.firstWhere((conv) => conv.id == conversationId);
    conversation.updateTitle(newTitle);
    await _saveConversation(conversation);
    notifyListeners();
  }

  List<Map<String, String>> getConversationHistoryUpTo(int messageIndex) {
    final messages = currentConversation?.messages ?? [];
    return messages
        .sublist(0, messageIndex)
        .where((msg) => msg.content.isNotEmpty)
        .map((msg) => {
      "role": msg.isUser ? "user" : "assistant",
      "content": msg.versions[msg.currentVersionIndex],
    })
        .toList();
  }
}