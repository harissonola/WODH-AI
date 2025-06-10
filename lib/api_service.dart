import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _baseUrl = 'http://192.168.1.101:8000/api/conversations';
  static const String _linuxTokenKey = 'linux_token';
  static const String _userIdKey = 'user_id';

  final String? _userId;
  final String? _linuxAuthToken;

  ApiService({User? user, String? userId, String? linuxAuthToken})
      : _userId = userId,
        _linuxAuthToken = linuxAuthToken {
    if (!Platform.isLinux && user == null) {
      throw ArgumentError("User must be provided for non-Linux platforms");
    }
  }


  Future<Map<String, String>> _getHeaders() async {
    final headers = {
      'Content-Type': 'application/json',
    };

    // Si on est sur Linux et qu'on a un token
    if (Platform.isLinux && _linuxAuthToken != null) {
      headers['Authorization'] = 'Bearer $_linuxAuthToken';
    }
    // Sinon, vérifier s'il y a un token dans les préférences partagées
    else {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_linuxTokenKey);
      final userId = prefs.getString(_userIdKey);

      if (token != null && userId != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  Future<dynamic> _handleResponse(http.Response response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return json.decode(response.body);
    } else {
      final error = json.decode(response.body);
      throw Exception(error['error'] ?? 'Request failed with status ${response.statusCode}');
    }
  }

  Future<dynamic> getConversations() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse(_baseUrl), headers: headers);
    return _handleResponse(response);
  }

  Future<dynamic> getConversation(String id) async {
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