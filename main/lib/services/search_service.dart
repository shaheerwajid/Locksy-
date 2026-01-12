import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:CryptoChat/global/environment.dart';
import 'package:CryptoChat/services/auth_service.dart';
import 'package:CryptoChat/models/usuario.dart';
import 'package:CryptoChat/models/grupo.dart';

class SearchResult {
  final List<Usuario>? users;
  final List<dynamic>? messages;
  final List<Grupo>? groups;
  final int total;

  SearchResult({
    this.users,
    this.messages,
    this.groups,
    required this.total,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      users: json['users'] != null
          ? List<Usuario>.from(json['users'].map((x) => Usuario.fromJson(x)))
          : null,
      messages: json['messages'] != null
          ? List<dynamic>.from(json['messages'])
          : null,
      groups: json['groups'] != null
          ? List<Grupo>.from(json['groups'].map((x) => Grupo.fromJson(x)))
          : null,
      total: json['total'] ?? 0,
    );
  }
}

class SearchService {
  /// Search all (users, messages, groups)
  Future<SearchResult> aggregateSearch(String query, {int limit = 10}) async {
    try {
      final uri = Uri.parse('${Environment.apiUrl}/search/search')
          .replace(queryParameters: {
        'q': query,
        'limit': limit.toString(),
      });

      final resp = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-token': await AuthService.getToken(),
        },
      );

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        if (json['ok'] == true && json['results'] != null) {
          return SearchResult.fromJson(json['results']);
        }
      }
      return SearchResult(total: 0);
    } catch (e) {
      print('SearchService: Error in aggregateSearch: $e');
      return SearchResult(total: 0);
    }
  }

  /// Search users only
  Future<List<Usuario>> searchUsers(String query, {int limit = 10}) async {
    try {
      final uri = Uri.parse('${Environment.apiUrl}/search/search/users')
          .replace(queryParameters: {
        'q': query,
        'limit': limit.toString(),
      });

      final resp = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-token': await AuthService.getToken(),
        },
      );

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        if (json['ok'] == true && json['users'] != null) {
          return List<Usuario>.from(
              json['users'].map((x) => Usuario.fromJson(x)));
        }
      }
      return [];
    } catch (e) {
      print('SearchService: Error in searchUsers: $e');
      return [];
    }
  }

  /// Search messages only
  Future<List<dynamic>> searchMessages(String query,
      {String? userId, int limit = 20}) async {
    try {
      final params = {
        'q': query,
        'limit': limit.toString(),
      };
      if (userId != null) {
        params['userId'] = userId;
      }

      final uri = Uri.parse('${Environment.apiUrl}/search/search/messages')
          .replace(queryParameters: params);

      final resp = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-token': await AuthService.getToken(),
        },
      );

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        if (json['ok'] == true && json['messages'] != null) {
          return List<dynamic>.from(json['messages']);
        }
      }
      return [];
    } catch (e) {
      print('SearchService: Error in searchMessages: $e');
      return [];
    }
  }

  /// Search groups only
  Future<List<Grupo>> searchGroups(String query, {int limit = 10}) async {
    try {
      final uri = Uri.parse('${Environment.apiUrl}/search/search/groups')
          .replace(queryParameters: {
        'q': query,
        'limit': limit.toString(),
      });

      final resp = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-token': await AuthService.getToken(),
        },
      );

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        if (json['ok'] == true && json['groups'] != null) {
          return List<Grupo>.from(json['groups'].map((x) => Grupo.fromJson(x)));
        }
      }
      return [];
    } catch (e) {
      print('SearchService: Error in searchGroups: $e');
      return [];
    }
  }
}





