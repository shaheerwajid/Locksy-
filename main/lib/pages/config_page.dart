import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:CryptoChat/global/AppLocalizations.dart';
import 'package:CryptoChat/helpers/style.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:CryptoChat/pages/info_page.dart';
import 'package:CryptoChat/widgets/mostrar_alerta.dart';
import 'package:CryptoChat/services/socket_service.dart';

import '../services/auth_service.dart';

class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key});

  @override
  ConfigPageState createState() => ConfigPageState();
}

class ConfigPageState extends State<ConfigPage> {
  bool isShowOnline = false; // Track the switch state
  @override
  void initState() {
    WidgetsFlutterBinding.ensureInitialized();
    super.initState();
    _loadSwitchState();
  }

  // Load the switch state from SharedPreferences
  void _loadSwitchState() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      isShowOnline = prefs.getBool('showOnline') ?? false;
    });
  }

  // Save the switch state to SharedPreferences
  void _saveSwitchState(bool value, String? id) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    log('saved in $id showOnline');
    prefs.setBool('$id showOnline', value);
  }

  Future<bool> _loadSwitchStateFuture(String? id) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$id showOnline') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    var authService = Provider.of<AuthService>(context, listen: false);
    String? id = authService.usuario?.uid;
    return Scaffold(
      backgroundColor: drawer_white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        shadowColor: drawer_light_white,
        backgroundColor: drawer_light_white,
        title: Text(
          AppLocalizations.of(context)!.translate('SETTINGS'),
          style: TextStyle(color: gris),
        ),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          Card(
            child: FutureBuilder<bool>(
              future:
                  _loadSwitchStateFuture(id), // Load the state asynchronously
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  // Show a loading indicator while waiting
                  return ListTile(
                    tileColor: chat_color,
                    leading: const Icon(Icons.visibility_rounded),
                    title: Text(
                        AppLocalizations.of(context)!.translate('SHOW_ONLINE')),
                    trailing: const CircularProgressIndicator(),
                  );
                } else if (snapshot.hasError) {
                  // Handle errors gracefully
                  return ListTile(
                    tileColor: chat_color,
                    leading: const Icon(Icons.error),
                    title:
                        Text(AppLocalizations.of(context)!.translate('ERROR')),
                  );
                } else {
                  bool isSwitchOn =
                      snapshot.data ?? false; // Default to false if null
                  return ListTile(
                    tileColor: chat_color,
                    leading: const Icon(Icons.visibility_rounded),
                    title: Text(
                        AppLocalizations.of(context)!.translate('SHOW_ONLINE')),
                    trailing: Switch(
                      activeColor: verde,
                      value: isSwitchOn,
                      onChanged: (bool value) {
                        setState(() {
                          isShowOnline = value; // Update local state
                        });
                        _saveSwitchState(value, id); // Save the new state
                      },
                    ),
                  );
                }
              },
            ),
          ),
          Card(
            child: ListTile(
              tileColor: chat_color,
              leading: const Icon(Icons.lock_outline_rounded),
              title: Text(AppLocalizations.of(context)!.translate('SECURITY')),
              subtitle: Text(
                  AppLocalizations.of(context)!.translate('SECURITY_SETTINGS')),
              onTap: () => Navigator.pushNamed(context, 'opciones'),
            ),
          ),
          Card(
            child: ListTile(
              tileColor: chat_color,
              leading: const Icon(Icons.lock_reset_rounded),
              title: const Text('Change Password'),
              subtitle: const Text('Update your account password'),
              onTap: () => Navigator.pushNamed(context, 'change_password'),
            ),
          ),
          Card(
            child: ListTile(
              tileColor: chat_color,
              leading: const Icon(Icons.language_rounded),
              title: Text(
                  AppLocalizations.of(context)!.translate('CHANGE_LANGUAGE')),
              subtitle: Text(AppLocalizations.of(context)!
                  .translate('CHANGE_LANGUAGE_CONFIG')),
              onTap: () => Navigator.pushNamed(context, 'idiomas'),
            ),
          ),
          Card(
            child: ListTile(
              tileColor: chat_color,
              leading: const Icon(Icons.help_outline_rounded),
              title: Text(AppLocalizations.of(context)!.translate('HELP')),
              subtitle:
                  Text(AppLocalizations.of(context)!.translate('REPORT_A_BUG')),
              onTap: () {
                Navigator.pushNamed(context, 'ayuda');
              },
            ),
          ),
          Card(
            child: ListTile(
              tileColor: chat_color,
              leading: const Icon(Icons.info_outline_rounded),
              title: Text(AppLocalizations.of(context)!.translate('ABOUT')),
              subtitle: Text('Locksy ${AppLocalizations.of(context)!.translate('INFORMATION')}'),
              onTap: () {
                Navigator.of(context)
                    .push(MaterialPageRoute(builder: (context) => const InfoPage()));
              },
            ),
          ),
          Card(
            child: ListTile(
              tileColor: chat_color,
              leading: const Icon(Icons.timelapse),
              title: Text(AppLocalizations.of(context)!
                  .translate('Disapperaing_messages')),
              onTap: () => Navigator.pushNamed(context, 'disapearing_messages'),
            ),
          ),
          const Divider(),
          Card(
            child: ListTile(
              tileColor: chat_color,
              leading: Icon(
                Icons.logout,
                color: rojo,
              ),
              title: Text(
                AppLocalizations.of(context)!.translate('CLOSE_SESSION'),
                style: TextStyle(color: rojo),
              ),
              onTap: () async {
                final confirmed = await alertaConfirmar(
                  context,
                  AppLocalizations.of(context)!.translate('WARNING'),
                  '${AppLocalizations.of(context)!.translate('CLOSE_SESSION')}?',
                );
                if (confirmed == true) {
                  // Disconnect from socket
                  final socketService =
                      Provider.of<SocketService>(context, listen: false);
                  socketService.disconnect();
                  
                  // Logout from auth service
                  final authService =
                      Provider.of<AuthService>(context, listen: false);
                  await authService.logout();
                  
                  // Navigate to login page
                  if (mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      'login',
                      (route) => false,
                    );
                  }
                }
              },
            ),
          ),
          Card(
            child: ListTile(
              tileColor: chat_color,
              leading: Icon(
                Icons.delete_forever_outlined,
                color: rojo,
              ),
              title: Text(
                AppLocalizations.of(context)!.translate('CLEAR_DATABASE'),
                style: TextStyle(color: rojo),
              ),
              onTap: () => Navigator.pushNamed(context, 'database'),
            ),
          ),
        ],
      ),
    );
  }

  void changeInitialRoute(String ruta) async {
    var prefs = await SharedPreferences.getInstance();
    prefs.setString('PMSInitialRoute', ruta);
  }
}
