import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../global/AppLocalizations.dart';

class DissapearingMessagesPage extends StatefulWidget {
  const DissapearingMessagesPage({super.key});

  @override
  DissapearingMessagesPageState createState() =>
      DissapearingMessagesPageState();
}

class DissapearingMessagesPageState extends State<DissapearingMessagesPage> {
  final List<String> durations = [
    'Off',
    '1 min',
    '5 min',
    '15 min',
    '12 hours',
    '24 hours',
    '48 hours',
    '7 days',
    '14 days',
    '21 days'
  ];
  String? selectedDuration;

  @override
  void initState() {
    super.initState();
    _loadSavedDuration();
  }

  Future<void> _loadSavedDuration() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedDuration = prefs.getString('selectedDuration');
    });
  }

  Future<void> _saveSelectedDuration(String duration) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (duration == 'Off') {
      await prefs.remove('selectedDuration');
    } else {
      await prefs.setString('selectedDuration', duration);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.grey),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Choose Duration',
          style: TextStyle(color: Colors.grey),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Message at the top
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
                AppLocalizations.of(context)!.translate('privacy_and_storage')),
          ),
          Divider(
              color: Colors.grey[300], height: 1), // Divider after the message

          // List of durations
          Expanded(
            child: ListView.separated(
              itemCount: durations.length,
              itemBuilder: (context, index) {
                final duration = durations[index];
                return ListTile(
                  title: Text(
                    duration,
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                  trailing: (selectedDuration == duration) ||
                          (selectedDuration == null && duration == 'Off')
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () async {
                    setState(() {
                      selectedDuration = duration;
                    });
                    await _saveSelectedDuration(duration);
                    debugPrint('Saved selected duration: $duration');
                  },
                );
              },
              separatorBuilder: (context, index) => Divider(
                color: Colors.grey[300],
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
