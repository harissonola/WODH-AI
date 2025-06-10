import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SymfonyApiService {
  static const String _baseUrl = 'http://votre-domaine-symfony.com/api'; // Remplacez par votre URL

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<Map<String, String>> _getHeaders() async {
    final token = await _auth.currentUser?.getIdToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> getConversations() async {
    try {
      final headers = await _getHeaders();
      return await http.get(
        Uri.parse('$_baseUrl/conversations'),
        headers: headers,
      );
    } catch (e) {
      debugPrint('Error getting conversations: $e');
      rethrow;
    }
  }

  Future<http.Response> createConversation(String title) async {
    try {
      final headers = await _getHeaders();
      return await http.post(
        Uri.parse('$_baseUrl/conversations'),
        headers: headers,
        body: jsonEncode({'title': title}),
      );
    } catch (e) {
      debugPrint('Error creating conversation: $e');
      rethrow;
    }
  }

  Future<http.Response> getConversation(String id) async {
    try {
      final headers = await _getHeaders();
      return await http.get(
        Uri.parse('$_baseUrl/conversations/$id'),
        headers: headers,
      );
    } catch (e) {
      debugPrint('Error getting conversation: $e');
      rethrow;
    }
  }

  Future<http.Response> updateConversation(String id, String title) async {
    try {
      final headers = await _getHeaders();
      return await http.put(
        Uri.parse('$_baseUrl/conversations/$id'),
        headers: headers,
        body: jsonEncode({'title': title}),
      );
    } catch (e) {
      debugPrint('Error updating conversation: $e');
      rethrow;
    }
  }

  Future<http.Response> deleteConversation(String id) async {
    try {
      final headers = await _getHeaders();
      return await http.delete(
        Uri.parse('$_baseUrl/conversations/$id'),
        headers: headers,
      );
    } catch (e) {
      debugPrint('Error deleting conversation: $e');
      rethrow;
    }
  }

  Future<http.Response> addMessage(String conversationId, String content, bool isUser) async {
    try {
      final headers = await _getHeaders();
      return await http.post(
        Uri.parse('$_baseUrl/conversations/$conversationId/messages'),
        headers: headers,
        body: jsonEncode({
          'content': content,
          'isUser': isUser,
        }),
      );
    } catch (e) {
      debugPrint('Error adding message: $e');
      rethrow;
    }
  }
}