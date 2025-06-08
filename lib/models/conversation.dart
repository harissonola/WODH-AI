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

  List<Conversation> get conversations => _conversations;
  Conversation? get currentConversation => _currentConversation;

  void editMessage(String conversationId, int messageIndex, String newContent) {
    final conversation = _conversations.firstWhere((conv) => conv.id == conversationId);
    if (messageIndex >= 0 && messageIndex < conversation.messages.length) {
      conversation.messages[messageIndex].content = newContent;
      notifyListeners();
    }
  }

  // Modifiez la méthode addMessageVersion pour ajouter automatiquement la réponse
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

        // Ajouter automatiquement la réponse de l'IA après la version modifiée
        final responseMessage = Message(
          content: aiResponse,
          isUser: false,
        );
        conversation.messages.insert(messageIndex + 1, responseMessage);

        notifyListeners();
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

  void createNewConversation([String title = 'Nouvelle conversation']) {
    final newConversation = Conversation(title: title);
    _conversations.insert(0, newConversation);
    _currentConversation = newConversation;
    notifyListeners();
  }

  void selectConversation(String id) {
    _currentConversation = _conversations.firstWhere((conv) => conv.id == id);
    notifyListeners();
  }

  void deleteConversation(String id) {
    _conversations.removeWhere((conv) => conv.id == id);
    if (_currentConversation?.id == id) {
      _currentConversation = null;
    }
    notifyListeners();
  }

  void addMessageToCurrent(String content, bool isUser) {
    if (_currentConversation == null) {
      createNewConversation();
    }
    _currentConversation!.addMessage(Message(content: content, isUser: isUser));
    notifyListeners();
  }

  void updateConversationTitle(String conversationId, String newTitle) {
    final conversation = _conversations.firstWhere((conv) => conv.id == conversationId);
    conversation.updateTitle(newTitle);
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