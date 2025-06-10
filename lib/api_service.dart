// api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

class ApiService {
  static const String _baseUrl = 'http://192.168.1.101:8000/api/conversations';
  final fb_auth.User? user;

  ApiService(this.user);

  Future<dynamic> _handleResponse(http.Response response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body);
    } else {
      final error = json.decode(response.body);
      throw Exception(error['error'] ?? 'Request failed with status ${response.statusCode}');
    }
  }

  Future<void> _checkConnectivity() async {
    try {
      final response = await http.get(Uri.parse(_baseUrl), headers: await _getHeaders());
      if (response.statusCode != 200) {
        throw Exception('API unavailable');
      }
    } catch (e) {
      throw Exception('Failed to connect to API: $e');
    }
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await user?.getIdToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Future> getConversations() async {  // Modifiez cette ligne
    await _checkConnectivity();
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse(_baseUrl), headers: headers);
    return _handleResponse(response);
  }

// Ajoutez cette nouvelle méthode pour récupérer une conversation spécifique
  Future<dynamic> getConversation(String id) async {
    await _checkConnectivity();
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/$id'),
      headers: headers,
    );
    return _handleResponse(response);
  }

  Future<dynamic> createConversation(String title) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: headers,
      body: json.encode({'title': title}),
    );
    return _handleResponse(response);
  }

  Future<void> updateConversation(String id, String title) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('$_baseUrl/$id'),
      headers: headers,
      body: json.encode({'title': title}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update conversation');
    }
  }

  Future<void> deleteConversation(String id) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$_baseUrl/$id'),
      headers: headers,
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete conversation');
    }
  }

  Future<dynamic> addMessage(String conversationId, String content, bool isUser) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/$conversationId/messages'),
      headers: headers,
      body: json.encode({'content': content, 'isUser': isUser}),
    );

    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to add message');
    }
  }
}