import 'package:flutter/material.dart';
import 'package:CryptoChat/global/AppLocalizations.dart';
import 'package:CryptoChat/global/environment.dart';
import 'package:CryptoChat/helpers/style.dart';
import 'package:CryptoChat/models/usuario.dart';
import 'package:CryptoChat/models/grupo.dart';
import 'package:CryptoChat/services/search_service.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with SingleTickerProviderStateMixin {
  final SearchService _searchService = SearchService();
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  List<Usuario> _users = [];
  List<dynamic> _messages = [];
  List<Grupo> _groups = [];
  bool _isLoading = false;
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _users = [];
        _messages = [];
        _groups = [];
        _currentQuery = '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _currentQuery = query;
    });

    try {
      final result = await _searchService.aggregateSearch(query, limit: 20);
      setState(() {
        _users = result.users ?? [];
        _messages = result.messages ?? [];
        _groups = result.groups ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Search error: $e');
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
        title: TextField(
          controller: _searchController,
          style: TextStyle(color: background),
          decoration: InputDecoration(
            hintText:
                AppLocalizations.of(context)?.translate('SEARCH') ?? 'Search',
            hintStyle: TextStyle(color: background.withOpacity(0.7)),
            border: InputBorder.none,
          ),
          onSubmitted: _performSearch,
          textInputAction: TextInputAction.search,
        ),
        backgroundColor: header,
        bottom: TabBar(
          controller: _tabController,
          labelColor: background,
          unselectedLabelColor: background.withOpacity(0.7),
          indicatorColor: background,
          tabs: [
            const Tab(text: 'All'),
            Tab(
                text: AppLocalizations.of(context)?.translate('USERS') ??
                    'Users'),
            const Tab(text: 'Messages'),
            Tab(
                text: AppLocalizations.of(context)?.translate('GROUPS') ??
                    'Groups'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAllResults(),
                _buildUsersList(),
                _buildMessagesList(),
                _buildGroupsList(),
              ],
            ),
    );
  }

  Widget _buildAllResults() {
    if (_currentQuery.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)?.translate('ENTER_SEARCH_QUERY') ??
              'Enter a search query',
          style: TextStyle(color: gris),
        ),
      );
    }

    return ListView(
      children: [
        if (_users.isNotEmpty) ...[
          _buildSectionHeader('Users (${_users.length})'),
          ..._users.map((user) => _buildUserItem(user)),
        ],
        if (_messages.isNotEmpty) ...[
          _buildSectionHeader('Messages (${_messages.length})'),
          ..._messages.map((msg) => _buildMessageItem(msg)),
        ],
        if (_groups.isNotEmpty) ...[
          _buildSectionHeader('Groups (${_groups.length})'),
          ..._groups.map((group) => _buildGroupItem(group)),
        ],
        if (_users.isEmpty && _messages.isEmpty && _groups.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'No results found',
                style: TextStyle(color: gris),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUsersList() {
    if (_currentQuery.isEmpty) {
      return Center(
        child: Text(
          'Enter a search query',
          style: TextStyle(color: gris),
        ),
      );
    }

    if (_users.isEmpty) {
      return Center(
        child: Text(
          'No users found',
          style: TextStyle(color: gris),
        ),
      );
    }

    return ListView.builder(
      itemCount: _users.length,
      itemBuilder: (context, index) => _buildUserItem(_users[index]),
    );
  }

  Widget _buildMessagesList() {
    if (_currentQuery.isEmpty) {
      return Center(
        child: Text(
          'Enter a search query',
          style: TextStyle(color: gris),
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Text(
          'No messages found',
          style: TextStyle(color: gris),
        ),
      );
    }

    return ListView.builder(
      itemCount: _messages.length,
      itemBuilder: (context, index) => _buildMessageItem(_messages[index]),
    );
  }

  Widget _buildGroupsList() {
    if (_currentQuery.isEmpty) {
      return Center(
        child: Text(
          'Enter a search query',
          style: TextStyle(color: gris),
        ),
      );
    }

    if (_groups.isEmpty) {
      return Center(
        child: Text(
          'No groups found',
          style: TextStyle(color: gris),
        ),
      );
    }

    return ListView.builder(
      itemCount: _groups.length,
      itemBuilder: (context, index) => _buildGroupItem(_groups[index]),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: header,
        ),
      ),
    );
  }

  Widget _buildUserItem(Usuario user) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: user.avatar != null
            ? NetworkImage('${Environment.urlArchivos}${user.avatar}')
            : null,
        child: user.avatar == null ? const Icon(Icons.person) : null,
      ),
      title: Text(user.nombre ?? 'Unknown'),
      subtitle: Text(user.email ?? ''),
      onTap: () {
        // Navigate to user profile or chat
        // Navigator.pushNamed(context, 'chat', arguments: user);
      },
    );
  }

  Widget _buildMessageItem(dynamic message) {
    return ListTile(
      title: const Text('Message'),
      subtitle: Text(message['content']?.toString() ?? ''),
      onTap: () {
        // Navigate to message/chat
      },
    );
  }

  Widget _buildGroupItem(Grupo group) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: group.avatar != null
            ? NetworkImage('${Environment.urlArchivos}${group.avatar}')
            : null,
        child: group.avatar == null ? const Icon(Icons.group) : null,
      ),
      title: Text(group.nombre ?? 'Unknown Group'),
      subtitle: Text(group.descripcion ?? ''),
      onTap: () {
        // Navigate to group chat
        // Navigator.pushNamed(context, 'chatGrupal', arguments: group);
      },
    );
  }
}
