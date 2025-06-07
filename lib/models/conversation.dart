import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

class Message {
  final String id;
  String content; // Modifiable pour permettre l'édition
  final DateTime timestamp;
  final bool isUser;

  Message({
    required this.content,
    required this.isUser,
    String? id,
    DateTime? timestamp,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  String get formattedTime => DateFormat.Hm().format(timestamp);
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

  // Méthode pour éditer un message existant
  void editMessage(String conversationId, int messageIndex, String newContent) {
    final conversation = _conversations.firstWhere((conv) => conv.id == conversationId);
    if (messageIndex >= 0 && messageIndex < conversation.messages.length) {
      conversation.messages[messageIndex].content = newContent;
      notifyListeners();
    }
  }

  // NOUVELLE MÉTHODE : Supprimer le dernier message
  void removeLastMessage() {
    if (_currentConversation != null && _currentConversation!.messages.isNotEmpty) {
      _currentConversation!.messages.removeLast();
      notifyListeners();
    }
  }

  // Méthode pour supprimer un message spécifique par index
  void removeMessageAt(int index) {
    if (_currentConversation != null &&
        index >= 0 &&
        index < _currentConversation!.messages.length) {
      _currentConversation!.messages.removeAt(index);
      notifyListeners();
    }
  }

  // Méthode pour supprimer tous les messages après un index donné
  void removeMessagesAfter(int index) {
    if (_currentConversation != null &&
        index >= 0 &&
        index < _currentConversation!.messages.length) {
      _currentConversation!.messages.removeRange(
          index + 1,
          _currentConversation!.messages.length
      );
      notifyListeners();
    }
  }

  void createNewConversation([String title = 'Nouvelle conversation']) {
    final newConversation = Conversation(
      title: title,
    );
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

  // Méthode utilitaire pour vider une conversation
  void clearCurrentConversation() {
    if (_currentConversation != null) {
      _currentConversation!.messages.clear();
      notifyListeners();
    }
  }

  // Méthode pour obtenir le dernier message utilisateur
  Message? getLastUserMessage() {
    if (_currentConversation == null) return null;

    try {
      return _currentConversation!.messages
          .lastWhere((message) => message.isUser);
    } catch (e) {
      return null; // Aucun message utilisateur trouvé
    }
  }

  // Méthode pour obtenir le dernier message assistant
  Message? getLastAssistantMessage() {
    if (_currentConversation == null) return null;

    try {
      return _currentConversation!.messages
          .lastWhere((message) => !message.isUser);
    } catch (e) {
      return null; // Aucun message assistant trouvé
    }
  }
}