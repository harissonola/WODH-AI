import 'dart:async';

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

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
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

  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Conversation(
      id: doc.id,
      title: data['title'] ?? 'Nouvelle conversation',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
      userId: data['userId'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'createdAt': createdAt,
      'updatedAt': updatedAt ?? FieldValue.serverTimestamp(),
      'userId': userId,
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
  FirebaseFirestore? _firestore;
  String? _userId;
  StreamSubscription? _conversationsSubscription;
  bool _useFirestore;

  List<Conversation> get conversations => _conversations;
  Conversation? get currentConversation => _currentConversation;



  // Constructeur principal
  ConversationProvider({bool useFirestore = true}) : _useFirestore = useFirestore {
    if (useFirestore) {
      _firestore = FirebaseFirestore.instance;
    } else {
      _firestore = null;
    }
    _conversations = [];
    _currentConversation = null;
  }

  Future<void> syncLocalConversations() async {
    if (_userId == null || _firestore == null) return;

    try {
      // Récupérer toutes les conversations du serveur
      final serverSnapshot = await _firestore!
          .collection('conversations')
          .where('userId', isEqualTo: _userId)
          .get();

      // Fusionner avec les conversations locales
      for (final serverDoc in serverSnapshot.docs) {
        final serverConv = Conversation.fromFirestore(serverDoc);
        final localIndex = _conversations.indexWhere((c) => c.id == serverConv.id);

        if (localIndex >= 0) {
          // Mettre à jour la conversation locale avec les données du serveur
          _conversations[localIndex] = serverConv;
        } else {
          // Ajouter la conversation du serveur
          _conversations.add(serverConv);
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Erreur synchronisation: $e');
    }
  }

  // Méthode factory pour créer une instance sans Firestore
  factory ConversationProvider.withoutFirestore() {
    return ConversationProvider(useFirestore: false);
  }

  void setUserId(String? userId) {
    if (_userId == userId) return;

    _userId = userId;
    _conversationsSubscription?.cancel();

    if (userId != null && _useFirestore) {
      _subscribeToConversations();
    } else {
      _conversations = [];
      _currentConversation = null;
      notifyListeners();
    }
  }

  void _subscribeToConversations() {
    if (_userId == null || _userId!.isEmpty || _firestore == null) return;

    _conversationsSubscription = _firestore!
        .collection('conversations')
        .where('userId', isEqualTo: _userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .listen((snapshot) async {
      _conversations = snapshot.docs
          .map((doc) => Conversation.fromFirestore(doc))
          .toList();

      if (_currentConversation != null) {
        final currentId = _currentConversation!.id;
        _currentConversation = _conversations.firstWhere(
              (conv) => conv.id == currentId,
          orElse: () => _currentConversation!,
        );
        await _loadMessages(_currentConversation!);
      }

      notifyListeners();
    });
  }

  Future<void> _loadMessages(Conversation conversation) async {
    if (_firestore == null) return;

    try {
      final messagesSnapshot = await _firestore!
          .collection('conversations')
          .doc(conversation.id)
          .collection('messages')
          .orderBy('timestamp')
          .get();

      conversation.messages = messagesSnapshot.docs
          .map((doc) => Message.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error loading messages: $e');
    }
  }

  Future<void> createNewConversation([String title = 'Nouvelle conversation']) async {
    final newConversation = Conversation(
      title: title,
      userId: _userId,
    );

    // Toujours sauvegarder sur Firestore si possible
    try {
      if (_firestore != null) {
        await _firestore!
            .collection('conversations')
            .doc(newConversation.id)
            .set(newConversation.toFirestore());
      }
    } catch (e) {
      debugPrint('Erreur sauvegarde Firestore: $e');
      // Continuer même en cas d'erreur pour le fonctionnement offline
    }

    _conversations.insert(0, newConversation);
    _currentConversation = newConversation;
    notifyListeners();
  }


  Future<void> selectConversation(String id) async {
    _currentConversation = _conversations.firstWhere((conv) => conv.id == id);
    if (_useFirestore) {
      await _loadMessages(_currentConversation!);
    }
    notifyListeners();
  }

  Future<void> deleteConversation(String id) async {
    if (!_useFirestore || _firestore == null) {
      _conversations.removeWhere((conv) => conv.id == id);
      if (_currentConversation?.id == id) {
        _currentConversation = null;
      }
      notifyListeners();
      return;
    }

    try {
      final messages = await _firestore!
          .collection('conversations')
          .doc(id)
          .collection('messages')
          .get();

      final batch = _firestore!.batch();
      for (var doc in messages.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      await _firestore!.collection('conversations').doc(id).delete();

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

    // Toujours essayer de sauvegarder sur Firestore
    try {
      if (_firestore != null) {
        await _firestore!
            .collection('conversations')
            .doc(_currentConversation!.id)
            .collection('messages')
            .doc(message.id)
            .set(message.toFirestore());

        await _firestore!
            .collection('conversations')
            .doc(_currentConversation!.id)
            .update({
          'updatedAt': FieldValue.serverTimestamp(),
          'title': _currentConversation!.title, // Mettre à jour aussi le titre
        });
      }
    } catch (e) {
      debugPrint('Erreur sauvegarde message: $e');
    }

    notifyListeners();
  }

  Future<void> updateConversationTitle(String conversationId, String newTitle) async {
    final conversation = _conversations.firstWhere((conv) => conv.id == conversationId);
    conversation.updateTitle(newTitle);

    if (_useFirestore && _firestore != null) {
      await _firestore!
          .collection('conversations')
          .doc(conversationId)
          .update({
        'title': newTitle,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    notifyListeners();
  }

  Future<void> _saveConversation(Conversation conversation) async {
    if (!_useFirestore || _firestore == null) return;

    try {
      await _firestore!
          .collection('conversations')
          .doc(conversation.id)
          .set(conversation.toFirestore());
    } catch (e) {
      debugPrint('Error saving conversation: $e');
      rethrow;
    }
  }

  Future<void> editMessage(
      String conversationId,
      int messageIndex,
      String newContent,
      ) async {
    final conversation = _conversations.firstWhere((conv) => conv.id == conversationId);
    if (messageIndex >= 0 && messageIndex < conversation.messages.length) {
      conversation.messages[messageIndex].content = newContent;

      if (_useFirestore && _firestore != null) {
        await _firestore!
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .doc(conversation.messages[messageIndex].id)
            .update({'content': newContent});

        await _firestore!
            .collection('conversations')
            .doc(conversationId)
            .update({'updatedAt': FieldValue.serverTimestamp()});
      }

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

        if (_useFirestore && _firestore != null) {
          await _firestore!
              .collection('conversations')
              .doc(conversationId)
              .collection('messages')
              .doc(message.id)
              .update({
            'versions': message.versions,
            'aiResponses': message.aiResponses,
            'currentVersionIndex': message.currentVersionIndex,
          });

          final responseMessage = Message(
            content: aiResponse,
            isUser: false,
          );
          conversation.messages.insert(messageIndex + 1, responseMessage);

          await _firestore!
              .collection('conversations')
              .doc(conversationId)
              .collection('messages')
              .doc(responseMessage.id)
              .set(responseMessage.toFirestore());

          await _firestore!
              .collection('conversations')
              .doc(conversationId)
              .update({'updatedAt': FieldValue.serverTimestamp()});
        }

        notifyListeners();
      }
    }
  }

  void setMessageVersion(String messageId, int versionIndex) {
    for (final conv in _conversations) {
      for (final msg in conv.messages) {
        if (msg.id == messageId && msg.isUser) {
          msg.setVersion(versionIndex);

          if (_useFirestore && _firestore != null) {
            _firestore!
                .collection('conversations')
                .doc(conv.id)
                .collection('messages')
                .doc(msg.id)
                .update({
              'currentVersionIndex': versionIndex,
              'content': msg.versions[versionIndex],
            });
          }

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

  @override
  void dispose() {
    _conversationsSubscription?.cancel();
    super.dispose();
  }
}