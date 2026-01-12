import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:CryptoChat/global/environment.dart';
import 'package:CryptoChat/services/auth_service.dart';

class FeedItem {
  final String type; // 'message', 'contact', 'group'
  final Map<String, dynamic> data;
  final DateTime? timestamp;

  FeedItem({
    required this.type,
    required this.data,
    this.timestamp,
  });

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    return FeedItem(
      type: json['type'] ?? 'unknown',
      data: json['data'] ?? {},
      timestamp:
          json['timestamp'] != null ? DateTime.parse(json['timestamp']) : null,
    );
  }
}

class FeedService {
  /// Get user feed
  Future<List<FeedItem>> getUserFeed() async {
    try {
      final uri = Uri.parse('${Environment.apiUrl}/feed/user');

      final resp = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-token': await AuthService.getToken(),
        },
      );

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        if (json['ok'] == true) {
          // Handle items array format
          if (json['items'] != null) {
            return List<FeedItem>.from(
                json['items'].map((x) => FeedItem.fromJson(x)));
          }
          // Handle feed object format (legacy)
          if (json['feed'] != null) {
            final feed = json['feed'];
            final items = <FeedItem>[];

            // Transform messages
            if (feed['messages'] != null) {
              for (var msg in feed['messages']) {
                items.add(FeedItem(
                  type: 'message',
                  data: msg,
                  timestamp: msg['createdAt'] != null
                      ? DateTime.parse(msg['createdAt'])
                      : null,
                ));
              }
            }

            // Transform contacts
            if (feed['contacts'] != null) {
              for (var contact in feed['contacts']) {
                items.add(FeedItem(
                  type: 'contact',
                  data: contact,
                  timestamp: contact['fecha'] != null
                      ? DateTime.parse(contact['fecha'])
                      : null,
                ));
              }
            }

            // Transform groups
            if (feed['groups'] != null) {
              for (var group in feed['groups']) {
                items.add(FeedItem(
                  type: 'group',
                  data: group,
                  timestamp: group['fecha'] != null
                      ? DateTime.parse(group['fecha'])
                      : null,
                ));
              }
            }

            // Sort by timestamp (newest first)
            items.sort((a, b) {
              final timeA = a.timestamp?.millisecondsSinceEpoch ?? 0;
              final timeB = b.timestamp?.millisecondsSinceEpoch ?? 0;
              return timeB.compareTo(timeA);
            });

            return items;
          }
        }
      }
      return [];
    } catch (e) {
      print('FeedService: Error in getUserFeed: $e');
      return [];
    }
  }

  /// Get group feed
  Future<List<FeedItem>> getGroupFeed(String groupId) async {
    try {
      final uri = Uri.parse('${Environment.apiUrl}/feed/group/$groupId');

      final resp = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-token': await AuthService.getToken(),
        },
      );

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        if (json['ok'] == true) {
          // Handle items array format
          if (json['items'] != null) {
            return List<FeedItem>.from(
                json['items'].map((x) => FeedItem.fromJson(x)));
          }
          // Handle feed object format (legacy)
          if (json['feed'] != null) {
            final feed = json['feed'];
            final items = <FeedItem>[];

            // Transform messages
            if (feed['messages'] != null) {
              for (var msg in feed['messages']) {
                items.add(FeedItem(
                  type: 'message',
                  data: msg,
                  timestamp: msg['createdAt'] != null
                      ? DateTime.parse(msg['createdAt'])
                      : null,
                ));
              }
            }

            // Sort by timestamp (newest first)
            items.sort((a, b) {
              final timeA = a.timestamp?.millisecondsSinceEpoch ?? 0;
              final timeB = b.timestamp?.millisecondsSinceEpoch ?? 0;
              return timeB.compareTo(timeA);
            });

            return items;
          }
        }
      }
      return [];
    } catch (e) {
      print('FeedService: Error in getGroupFeed: $e');
      return [];
    }
  }

  /// Generate/refresh user feed
  Future<bool> generateUserFeed({Map<String, dynamic>? options}) async {
    try {
      final uri = Uri.parse('${Environment.apiUrl}/feed/user/generate');

      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-token': await AuthService.getToken(),
        },
        body: jsonEncode({'options': options ?? {}}),
      );

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        return json['ok'] == true;
      }
      return false;
    } catch (e) {
      print('FeedService: Error in generateUserFeed: $e');
      return false;
    }
  }

  /// Generate/refresh group feed
  Future<bool> generateGroupFeed(String groupId,
      {Map<String, dynamic>? options}) async {
    try {
      final uri =
          Uri.parse('${Environment.apiUrl}/feed/group/$groupId/generate');

      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'x-token': await AuthService.getToken(),
        },
        body: jsonEncode({'options': options ?? {}}),
      );

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        return json['ok'] == true;
      }
      return false;
    } catch (e) {
      print('FeedService: Error in generateGroupFeed: $e');
      return false;
    }
  }
}
