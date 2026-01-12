import 'package:flutter/foundation.dart';
import '../providers/db_provider.dart';

/// Service for cleaning up invalid chat data (self-chats, duplicates, etc.)
class ChatCleanupService {
  /// Clean up all invalid chat data
  /// Returns a map with cleanup statistics
  static Future<Map<String, int>> cleanupAll(String currentUserId) async {
    debugPrint('[ChatCleanupService] Starting cleanup for user: $currentUserId');
    
    final results = await DBProvider.db.cleanupInvalidChatData(currentUserId);
    
    debugPrint('[ChatCleanupService] Cleanup completed:');
    debugPrint('[ChatCleanupService] - Self-chat messages deleted: ${results['selfChatMessages'] ?? 0}');
    debugPrint('[ChatCleanupService] - Self-contacts deleted: ${results['selfContacts'] ?? 0}');
    debugPrint('[ChatCleanupService] - Duplicate message groups found: ${results['duplicateMessageGroups'] ?? 0}');
    
    return results;
  }

  /// Clean up self-chat messages only
  static Future<int> cleanupSelfChats(String currentUserId) async {
    debugPrint('[ChatCleanupService] Cleaning up self-chat messages...');
    return await DBProvider.db.deleteSelfChatMessages(currentUserId);
  }

  /// Get statistics about invalid chat data
  static Future<Map<String, dynamic>> getCleanupStats(String currentUserId) async {
    final db = await DBProvider.db.database;
    
    // Count self-chat messages
    final selfChatCount = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM mensajes
      WHERE de = ? AND para = ?
    ''', [currentUserId, currentUserId]);
    
    // Count self-contacts
    final selfContactCount = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM contactos
      WHERE uid = ?
    ''', [currentUserId]);
    
    // Count duplicate messages
    final duplicateCount = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM (
        SELECT de, para, CAST(SUBSTR(mensaje, INSTR(mensaje, '"fecha":"') + 9, 17) AS INTEGER) as fecha, COUNT(*) as msg_count
        FROM mensajes
        WHERE de != para
        GROUP BY de, para, fecha
        HAVING msg_count > 1
      )
    ''');
    
    return {
      'selfChatMessages': selfChatCount.first['count'] as int? ?? 0,
      'selfContacts': selfContactCount.first['count'] as int? ?? 0,
      'duplicateMessageGroups': duplicateCount.first['count'] as int? ?? 0,
    };
  }
}

