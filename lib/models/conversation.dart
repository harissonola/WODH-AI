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
      id: data['id'] ?? const Uuid().v4(),
      content: data['content'],
      isUser: data['isUser'] ?? false,
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
  late final List<Message> messages;
  final DateTime createdAt;
  String? userId;

  Conversation({
    String? id,
    required this.title,
    List<Message>? messages,
    DateTime? createdAt,
    this.userId,
  })  : id = id ?? const Uuid().v4(),
        messages = messages ?? [],
        createdAt = createdAt ?? DateTime.now();

  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Conversation(
      id: doc.id,
      title: data['title'] ?? 'Nouvelle conversation',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      userId: data['userId'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'createdAt': createdAt,
      'userId': userId,
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

  void setUserId(String? userId) {
    _userId = userId;
    if (userId != null) {
      _loadConversations();
    } else {
      _conversations = [];
      _currentConversation = null;
      notifyListeners();
    }
  }

  Future<void> _loadConversations() async {
    if (_userId == null || _userId!.isEmpty) return;

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

        conv.messages = messagesSnapshot.docs
            .map((doc) => Message.fromFirestore(doc.data()))
            .toList();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading conversations: $e');
      rethrow;
    }
  }

  Future<void> _saveConversation(Conversation conversation) async {
    if (_userId == null || _userId!.isEmpty) {
      debugPrint('Cannot save conversation - no user ID');
      return;
    }

    try {
      conversation.userId = _userId;
      await _firestore
          .collection('conversations')
          .doc(conversation.id)
          .set(conversation.toFirestore());

      // Save all messages
      final batch = _firestore.batch();
      for (var message in conversation.messages) {
        final messageRef = _firestore
            .collection('conversations')
            .doc(conversation.id)
            .collection('messages')
            .doc(message.id);
        batch.set(messageRef, message.toFirestore());
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error saving conversation: $e');
      rethrow;
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

      final batch = _firestore.batch();
      for (var doc in messages.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Then delete the conversation
      await _firestore.collection('conversations').doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting conversation: $e');
      rethrow;
    }
  }

  Future<void> createNewConversation([String title = 'Nouvelle conversation']) async {
    final newConversation = Conversation(
      title: title,
      userId: _userId,
    );
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

      _currentConversation!.messages = messagesSnapshot.docs
          .map((doc) => Message.fromFirestore(doc.data()))
          .toList();
    }

    notifyListeners();
  }

  Future<void> deleteConversation(String id) async {
    await _deleteConversation(id);
    _conversations.removeWhere((conv) => conv.id == id);
    if (_currentConversation?.id == id) {
      _currentConversation = null;
    }
    notifyListeners();
  }

  Future<void> addMessageToCurrent(String content, bool isUser) async {
    if (_currentConversation == null) {
      await createNewConversation();
    }

    final message = Message(content: content, isUser: isUser);
    _currentConversation!.addMessage(message);

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

  Future<void> editMessage(
      String conversationId,
      int messageIndex,
      String newContent,
      ) async {
    final conversation = _conversations.firstWhere((conv) => conv.id == conversationId);
    if (messageIndex >= 0 && messageIndex < conversation.messages.length) {
      conversation.messages[messageIndex].content = newContent;
      await _saveConversation(conversation);
      notifyListeners();
    }
  }

  Future<void> addMessageVersion(
      String conversationId,
      int messageIndex,
      String newContent,
      String aiResponse,
      ) async {
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

        await _saveConversation(conversation);
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