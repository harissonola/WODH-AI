import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../api_service.dart';

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

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'].toString(),
      content: json['content'],
      isUser: json['isUser'],
      timestamp: DateTime.parse(json['timestamp']),
      versions: List<String>.from(json['versions'] ?? [json['content']]),
      aiResponses: List<String>.from(json['aiResponses'] ?? []),
      currentVersionIndex: json['currentVersionIndex'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
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
  List<Message> messages;
  final DateTime createdAt;
  String? userId;
  DateTime? updatedAt;

  Conversation({
    String? id,
    required this.title,
    List<Message>? messages,
    DateTime? createdAt,
    this.userId,
    this.updatedAt,
  })  : id = id ?? const Uuid().v4(),
        messages = messages ?? [],
        createdAt = createdAt ?? DateTime.now();

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'].toString(),
      title: json['title'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      userId: json['userId']?.toString(),
      messages: (json['messages'] as List?)?.map((m) => Message.fromJson(m)).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'userId': userId,
      'messages': messages.map((m) => m.toJson()).toList(),
    };
  }

  void addMessage(Message message) {
    messages.add(message);
    updatedAt = DateTime.now();
  }

  void updateTitle(String newTitle) {
    title = newTitle.length > 20
        ? '${newTitle.substring(0, 20)}...'
        : newTitle;
    updatedAt = DateTime.now();
  }
}

class ConversationProvider with ChangeNotifier {
  List<Conversation> _conversations = [];
  Conversation? _currentConversation;
  ApiService? _apiService;
  String? _userId;
  bool _isInitialized = false;

  List<Conversation> get conversations => _conversations;
  Conversation? get currentConversation => _currentConversation;
  bool get isInitialized => _isInitialized;

  ConversationProvider() {
    _isInitialized = true;
  }

  void setUserId(String? userId) {
    if (_userId == userId) return;

    _userId = userId;
    if (userId != null) {
      _apiService = ApiService(FirebaseAuth.instance.currentUser);
      _loadConversations();
    } else {
      _conversations = [];
      _currentConversation = null;
      notifyListeners();
    }
  }

  Future<void> _loadConversations() async {
    try {
      if (_apiService == null) return;

      final response = await _apiService!.getConversations();
      _conversations = response.map((json) => Conversation.fromJson(json)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading conversations: $e');
    }
  }

  Future<void> createNewConversation([String title = 'Nouvelle conversation']) async {
    final newConversation = Conversation(
      title: title,
      userId: _userId,
    );

    try {
      if (_apiService != null) {
        await _apiService!.createConversation(title);
      }
    } catch (e) {
      debugPrint('Error creating conversation: $e');
    }

    _conversations.insert(0, newConversation);
    _currentConversation = newConversation;
    notifyListeners();
  }

  Future<void> selectConversation(String id) async {
    try {
      if (_apiService != null) {
        final response = await _apiService!.getConversation(id);
        _currentConversation = Conversation.fromJson(response);
      } else {
        _currentConversation = _conversations.firstWhere((conv) => conv.id == id);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error selecting conversation: $e');
    }
  }

  Future<void> deleteConversation(String id) async {
    try {
      if (_apiService != null) {
        await _apiService!.deleteConversation(id);
      }

      _conversations.removeWhere((conv) => conv.id == id);
      if (_currentConversation?.id == id) {
        _currentConversation = null;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting conversation: $e');
      rethrow;
    }
  }

  Future<void> addMessageToCurrent(String content, bool isUser) async {
    if (_currentConversation == null) {
      await createNewConversation();
    }

    final message = Message(content: content, isUser: isUser);
    _currentConversation!.addMessage(message);

    try {
      if (_apiService != null) {
        await _apiService!.addMessage(_currentConversation!.id, content, isUser);
        await _apiService!.updateConversation(
          _currentConversation!.id,
          _currentConversation!.title,
        );
      }
    } catch (e) {
      debugPrint('Error saving message: $e');
    }

    notifyListeners();
  }

  Future<void> updateConversationTitle(String conversationId, String newTitle) async {
    final conversation = _conversations.firstWhere((conv) => conv.id == conversationId);
    conversation.updateTitle(newTitle);

    try {
      if (_apiService != null) {
        await _apiService!.updateConversation(conversationId, newTitle);
      }
    } catch (e) {
      debugPrint('Error updating conversation title: $e');
    }

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
      notifyListeners();

      // Note: L'API ne semble pas avoir de méthode pour éditer un message spécifique
      // Vous devrez peut-être implémenter cette fonctionnalité côté API
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
        notifyListeners();

        // Note: L'API ne semble pas avoir de méthode pour gérer les versions de messages
        // Vous devrez peut-être implémenter cette fonctionnalité côté API
      }
    }
  }

  void setMessageVersion(String messageId, int versionIndex) {
    for (final conv in _conversations) {
      for (final msg in conv.messages) {
        if (msg.id == messageId && msg.isUser) {
          msg.setVersion(versionIndex);
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