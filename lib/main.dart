import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

class Conversation {
  final String id;
  final String? title;
  final DateTime createdAt;
  final DateTime updatedAt;

  Conversation({
    required this.id,
    this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Conversation(
      id: doc.id,
      title: data['title'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

class Message {
  final String id;
  final String content;
  final DateTime timestamp;
  final bool isUser;

  Message({
    required this.id,
    required this.content,
    required this.timestamp,
    required this.isUser,
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      content: data['content'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      isUser: data['isUser'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'isUser': isUser,
    };
  }
}

class ConversationProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userId;
  List<Conversation> _conversations = [];
  StreamSubscription<QuerySnapshot>? _conversationsSubscription;

  List<Conversation> get conversations => _conversations;

  void setUserId(String? userId) {
    if (_userId == userId) return;

    _userId = userId;
    _conversationsSubscription?.cancel();
    _conversations = [];

    if (userId != null) {
      _loadConversations();
    }

    notifyListeners();
  }

  void _loadConversations() {
    _conversationsSubscription = _firestore
        .collection('users')
        .doc(_userId)
        .collection('conversations')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _conversations = snapshot.docs
          .map((doc) => Conversation.fromFirestore(doc))
          .toList();
      notifyListeners();
    });
  }

  Future<Conversation> createConversation() async {
    final docRef = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('conversations')
        .add({
      'title': 'Nouvelle conversation',
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });

    return Conversation(
      id: docRef.id,
      title: 'Nouvelle conversation',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> updateConversationTitle(String conversationId, String newTitle) async {
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('conversations')
        .doc(conversationId)
        .update({
      'title': newTitle,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> deleteConversation(String conversationId) async {
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('conversations')
        .doc(conversationId)
        .delete();
  }

  Stream<List<Message>> getMessages(String conversationId) {
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => Message.fromFirestore(doc))
        .toList());
  }

  Future<void> addMessage(
      String conversationId,
      String content,
      bool isUser,
      ) async {
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .add({
      'content': content,
      'timestamp': Timestamp.now(),
      'isUser': isUser,
    });

    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('conversations')
        .doc(conversationId)
        .update({
      'updatedAt': Timestamp.now(),
    });
  }

  @override
  void dispose() {
    _conversationsSubscription?.cancel();
    super.dispose();
  }
}