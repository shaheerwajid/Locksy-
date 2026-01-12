import 'package:flutter/material.dart';
import 'package:CryptoChat/global/AppLocalizations.dart';
import 'package:CryptoChat/helpers/style.dart';
import 'package:CryptoChat/services/feed_service.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  _FeedPageState createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final FeedService _feedService = FeedService();
  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);
  List<dynamic> _feedItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _loadFeed() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final items = await _feedService.getUserFeed();
      setState(() {
        _feedItems = items.map((item) => item.data).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Feed load error: $e');
    }
  }

  Future<void> _onRefresh() async {
    await _loadFeed();
    _refreshController.refreshCompleted();
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
          AppLocalizations.of(context)?.translate('FEED') ?? 'Feed',
          style: TextStyle(color: background),
        ),
        centerTitle: true,
        backgroundColor: header,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SmartRefresher(
              controller: _refreshController,
              onRefresh: _onRefresh,
              child: _feedItems.isEmpty
                  ? Center(
                      child: Text(
                        'No feed items available',
                        style: TextStyle(color: gris),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _feedItems.length,
                      itemBuilder: (context, index) {
                        final item = _feedItems[index];
                        return _buildFeedItem(item);
                      },
                    ),
            ),
    );
  }

  Widget _buildFeedItem(Map<String, dynamic> item) {
    final type = item['type']?.toString() ?? 'unknown';
    final data = item['data'] ?? {};

    String title = 'Feed Item';
    String subtitle = '';
    IconData icon = Icons.info;

    if (type == 'message') {
      title = 'New Message';
      final usuario = data['usuario'];
      subtitle = usuario != null && usuario['nombre'] != null
          ? 'From: ${usuario['nombre']}'
          : 'New message received';
      icon = Icons.message;
    } else if (type == 'contact') {
      title = 'New Contact';
      final usuario = data['usuario'];
      subtitle = usuario != null && usuario['nombre'] != null
          ? '${usuario['nombre']} added you'
          : 'Contact activity';
      icon = Icons.person_add;
    } else if (type == 'group') {
      title = 'Group Activity';
      subtitle = data['nombre']?.toString() ?? 'Unknown Group';
      icon = Icons.group;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Icon(icon, color: header),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          // Handle feed item tap based on type
          if (type == 'message') {
            // Navigate to chat
          } else if (type == 'contact') {
            // Navigate to contacts
          } else if (type == 'group') {
            // Navigate to group
          }
        },
      ),
    );
  }
}
