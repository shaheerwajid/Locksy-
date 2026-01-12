import 'package:flutter/material.dart';
import 'package:CryptoChat/global/AppLocalizations.dart';
import 'package:CryptoChat/helpers/style.dart';
// import 'package:CryptoChat/services/socket_service.dart'; // Reserved for future real-time notifications
// import 'package:provider/provider.dart'; // Reserved for future use
import 'package:pull_to_refresh/pull_to_refresh.dart';

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final DateTime timestamp;
  final bool read;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    this.data,
    required this.timestamp,
    this.read = false,
  });
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  _NotificationsPageState createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);
  List<NotificationItem> _notifications = [];
  // SocketService? _socketService; // Reserved for future real-time notifications

  @override
  void initState() {
    super.initState();
    // _socketService = Provider.of<SocketService>(context, listen: false); // Reserved for future use
    _loadNotifications();
    _setupSocketListeners();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  void _setupSocketListeners() {
    // Listen for real-time notifications via Socket.IO
    // This would be implemented based on your Socket.IO setup
  }

  Future<void> _loadNotifications() async {
    // Load notifications from local storage or API
    // For now, using empty list
    setState(() {
      _notifications = [];
    });
  }

  Future<void> _onRefresh() async {
    await _loadNotifications();
    _refreshController.refreshCompleted();
  }

  void _handleNotificationTap(NotificationItem notification) {
    // Handle notification tap based on type
    final type = notification.data?['type'];
    if (type == 'message') {
      // Navigate to chat
      // Navigator.pushNamed(context, 'chat', arguments: notification.data);
    } else if (type == 'contact_request') {
      // Navigate to contact requests
      // Navigator.pushNamed(context, 'contactos');
    } else if (type == 'group_added') {
      // Navigate to group
      // Navigator.pushNamed(context, 'chatGrupal', arguments: notification.data);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        leading: InkWell(
          child: Icon(Icons.arrow_back_ios_rounded, color: background),
          onTap: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context)?.translate('NOTIFICATIONS') ??
              'Notifications',
          style: TextStyle(color: background),
        ),
        centerTitle: true,
        backgroundColor: header,
      ),
      body: SmartRefresher(
        controller: _refreshController,
        onRefresh: _onRefresh,
        child: _notifications.isEmpty
            ? Center(
                child: Text(
                  'No notifications',
                  style: TextStyle(color: gris),
                ),
              )
            : ListView.builder(
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final notification = _notifications[index];
                  return _buildNotificationItem(notification);
                },
              ),
      ),
    );
  }

  Widget _buildNotificationItem(NotificationItem notification) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: notification.read ? gris : header,
          child: Icon(
            Icons.notifications,
            color: background,
          ),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.read ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Text(notification.body),
        trailing: Text(
          _formatTimestamp(notification.timestamp),
          style: TextStyle(fontSize: 12, color: gris),
        ),
        onTap: () => _handleNotificationTap(notification),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
