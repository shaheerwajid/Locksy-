import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

enum MessageQueueStatus {
  pending,
  sending,
  sent,
  failed,
}

class QueuedMessage {
  final int? id;
  final String messageId;
  final String event; // 'mensaje-personal' or 'mensaje-grupal'
  final Map<String, dynamic> payload;
  final DateTime timestamp;
  final int retryCount;
  final MessageQueueStatus status;
  final String? error;

  QueuedMessage({
    this.id,
    required this.messageId,
    required this.event,
    required this.payload,
    required this.timestamp,
    this.retryCount = 0,
    this.status = MessageQueueStatus.pending,
    this.error,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'messageId': messageId,
      'event': event,
      'payload': jsonEncode(payload),
      'timestamp': timestamp.toIso8601String(),
      'retryCount': retryCount,
      'status': status.index,
      'error': error,
    };
  }

  factory QueuedMessage.fromMap(Map<String, dynamic> map) {
    return QueuedMessage(
      id: map['id'] as int?,
      messageId: map['messageId'] as String,
      event: map['event'] as String,
      payload: jsonDecode(map['payload'] as String),
      timestamp: DateTime.parse(map['timestamp'] as String),
      retryCount: map['retryCount'] as int,
      status: MessageQueueStatus.values[map['status'] as int],
      error: map['error'] as String?,
    );
  }
}

class MessageQueueService {
  static final MessageQueueService _instance = MessageQueueService._internal();
  factory MessageQueueService() => _instance;
  MessageQueueService._internal();

  Database? _database;
  static const int _maxRetries = 3;
  static const List<Duration> _retryDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final dbFile = path.join(dbPath, 'message_queue.db');

    return await openDatabase(
      dbFile,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE message_queue(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            messageId TEXT UNIQUE NOT NULL,
            event TEXT NOT NULL,
            payload TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            retryCount INTEGER DEFAULT 0,
            status INTEGER DEFAULT 0,
            error TEXT
          )
        ''');
        await db.execute('CREATE INDEX idx_status ON message_queue(status)');
        await db
            .execute('CREATE INDEX idx_timestamp ON message_queue(timestamp)');
      },
    );
  }

  /// Add a message to the queue
  Future<void> enqueue({
    required String messageId,
    required String event,
    required Map<String, dynamic> payload,
  }) async {
    final db = await database;
    try {
      await db.insert(
        'message_queue',
        QueuedMessage(
          messageId: messageId,
          event: event,
          payload: payload,
          timestamp: DateTime.now(),
        ).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('[MessageQueue] Enqueued message: $messageId');
    } catch (e) {
      print('[MessageQueue] Error enqueueing message: $e');
      rethrow;
    }
  }

  /// Get all pending messages
  Future<List<QueuedMessage>> getPendingMessages() async {
    final db = await database;
    final maps = await db.query(
      'message_queue',
      where: 'status = ?',
      whereArgs: [MessageQueueStatus.pending.index],
      orderBy: 'timestamp ASC',
    );
    return maps.map((map) => QueuedMessage.fromMap(map)).toList();
  }

  /// Get all failed messages (for manual retry)
  Future<List<QueuedMessage>> getFailedMessages() async {
    final db = await database;
    final maps = await db.query(
      'message_queue',
      where: 'status = ?',
      whereArgs: [MessageQueueStatus.failed.index],
      orderBy: 'timestamp DESC',
      limit: 50, // Limit to last 50 failed messages
    );
    return maps.map((map) => QueuedMessage.fromMap(map)).toList();
  }

  /// Mark message as sending
  Future<void> markSending(int id) async {
    final db = await database;
    await db.update(
      'message_queue',
      {'status': MessageQueueStatus.sending.index},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Mark message as sent (remove from queue)
  Future<void> markSent(String messageId) async {
    final db = await database;
    await db.delete(
      'message_queue',
      where: 'messageId = ?',
      whereArgs: [messageId],
    );
    print('[MessageQueue] Marked message as sent: $messageId');
  }

  /// Mark message as failed
  Future<void> markFailed(int id, String error) async {
    final db = await database;
    await db.update(
      'message_queue',
      {
        'status': MessageQueueStatus.failed.index,
        'error': error,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    print('[MessageQueue] Marked message as failed: $id - $error');
  }

  /// Increment retry count
  Future<void> incrementRetry(int id) async {
    final db = await database;
    final maps = await db.query(
      'message_queue',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      final currentRetry = maps.first['retryCount'] as int;
      await db.update(
        'message_queue',
        {'retryCount': currentRetry + 1},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  /// Reset message to pending (for manual retry)
  Future<void> resetToPending(int id) async {
    final db = await database;
    await db.update(
      'message_queue',
      {
        'status': MessageQueueStatus.pending.index,
        'retryCount': 0,
        'error': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Process queue - attempts to send all pending messages
  /// Returns number of successfully sent messages
  Future<int> processQueue(
    Future<String?> Function(String event, Map<String, dynamic> payload)
        sendFunction,
  ) async {
    final pending = await getPendingMessages();
    if (pending.isEmpty) return 0;

    print('[MessageQueue] Processing ${pending.length} pending messages');

    int sentCount = 0;
    for (final message in pending) {
      // Check if message has exceeded max retries
      if (message.retryCount >= _maxRetries) {
        await markFailed(
          message.id!,
          'Max retries exceeded (${message.retryCount})',
        );
        continue;
      }

      try {
        await markSending(message.id!);

        // Wait for retry delay if this is a retry
        if (message.retryCount > 0) {
          final delay = _retryDelays[
              (message.retryCount - 1).clamp(0, _retryDelays.length - 1)];
          await Future.delayed(delay);
        }

        final ack = await sendFunction(message.event, message.payload);

        if (ack != null && ack == "RECIBIDO_SERVIDOR") {
          await markSent(message.messageId);
          sentCount++;
          print(
              '[MessageQueue] ✅ Successfully sent queued message: ${message.messageId}');
        } else {
          // Increment retry count and reset to pending if under max retries
          await incrementRetry(message.id!);
          final db = await database;
          if (message.retryCount + 1 < _maxRetries) {
            await db.update(
              'message_queue',
              {'status': MessageQueueStatus.pending.index},
              where: 'id = ?',
              whereArgs: [message.id],
            );
          } else {
            await markFailed(message.id!, 'ACK was null or invalid: $ack');
          }
        }
      } catch (e) {
        print(
            '[MessageQueue] Error processing message ${message.messageId}: $e');
        await incrementRetry(message.id!);
        final db = await database;
        if (message.retryCount + 1 < _maxRetries) {
          await db.update(
            'message_queue',
            {'status': MessageQueueStatus.pending.index},
            where: 'id = ?',
            whereArgs: [message.id],
          );
        } else {
          await markFailed(message.id!, e.toString());
        }
      }
    }

    print(
        '[MessageQueue] Processed queue: $sentCount sent, ${pending.length - sentCount} remaining');
    return sentCount;
  }

  /// Clear old sent messages (cleanup)
  Future<void> clearOldMessages({int daysOld = 7}) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(Duration(days: daysOld));
    await db.delete(
      'message_queue',
      where: 'status = ? AND timestamp < ?',
      whereArgs: [MessageQueueStatus.sent.index, cutoff.toIso8601String()],
    );
  }

  /// Get queue statistics
  Future<Map<String, int>> getStats() async {
    final db = await database;
    final pending = await db.rawQuery(
      'SELECT COUNT(*) as count FROM message_queue WHERE status = ?',
      [MessageQueueStatus.pending.index],
    );
    final failed = await db.rawQuery(
      'SELECT COUNT(*) as count FROM message_queue WHERE status = ?',
      [MessageQueueStatus.failed.index],
    );
    final sending = await db.rawQuery(
      'SELECT COUNT(*) as count FROM message_queue WHERE status = ?',
      [MessageQueueStatus.sending.index],
    );

    return {
      'pending': pending.first['count'] as int,
      'failed': failed.first['count'] as int,
      'sending': sending.first['count'] as int,
    };
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
