import 'package:CryptoChat/pages/home_page.dart';
import 'package:CryptoChat/pages/grupos_page.dart';
import 'package:CryptoChat/pages/solicitudes_page.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../helpers/style.dart';
import 'config_page.dart';

class TabBarPage extends StatefulWidget {
  final int initialIndex;

  // Constructor with an optional initialIndex, defaulting to 1
  const TabBarPage({super.key, this.initialIndex = 0});

  @override
  _TabBarPageState createState() => _TabBarPageState();
}

class _TabBarPageState extends State<TabBarPage> {
  late int _currentIndex;

  final List<Widget> _pages = [
    const HomePage(), // Chat
    const GruposPage(), // Groups
    const SolicitudesPage(), // Contact Requests
    const ConfigPage(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex =
        widget.initialIndex; // Set the initial index based on the passed value
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        // Create space around the navigation bar
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4), // Shadow color
              blurRadius: 15, // How soft the shadow is
              spreadRadius: 4, // How far the shadow spreads
              offset: const Offset(0, 5), // Shadow position
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20.0),
            topRight: Radius.circular(20.0),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            backgroundColor: Colors.white, // Background color of the bar
            selectedItemColor: header, // Active icon/text color
            unselectedItemColor:
                const Color(0xFF2C2C2C), // Default icon/text color
            type: BottomNavigationBarType.fixed, // Fixed layout
            items: [
              _buildBottomNavigationBarItem(
                icon: FontAwesomeIcons.solidCommentDots,
                label: 'Chat',
              ),
              _buildBottomNavigationBarItem(
                icon: FontAwesomeIcons.peopleGroup,
                label: 'Groups',
              ),
              _buildBottomNavigationBarItem(
                icon: FontAwesomeIcons.idCard,
                label: 'Contact\nRequests', // Example multi-line label
              ),
              _buildBottomNavigationBarItem(
                icon: FontAwesomeIcons.gear,
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildBottomNavigationBarItem({
    required IconData icon,
    required String label,
  }) {
    return BottomNavigationBarItem(
      icon: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(icon),
          const SizedBox(height: 4), // Add space between icon and label
        ],
      ),
      label: label,
    );
  }
}

// import 'package:CryptoChat/pages/home_page.dart';
// import 'package:flutter/material.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// import '../helpers/style.dart';

// class TabBarPage extends StatefulWidget {
//   @override
//   _TabBarPageState createState() => _TabBarPageState();
// }

// class _TabBarPageState extends State<TabBarPage> {
//   int _currentIndex = 0;

//   final List<Widget> _pages = [
//     HomePage(), // Chat
//     GroupsPage(),
//     ContactRequestsPage(),
//     SettingsPage(),
//   ];

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: _pages[_currentIndex],
//       bottomNavigationBar: Container(
//         // Create space around the navigation bar
//         decoration: BoxDecoration(
//           color: Colors.transparent,
//           borderRadius: BorderRadius.circular(20.0),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.9), // Shadow color
//               blurRadius: 15, // How soft the shadow is
//               spreadRadius: 4, // How far the shadow spreads
//               offset: const Offset(0, 5), // Shadow position
//             ),
//           ],
//         ),
//         child: ClipRRect(
//           borderRadius: BorderRadius.only(
//             topLeft: Radius.circular(20.0),
//             topRight: Radius.circular(20.0),
//           ),
//           child: BottomNavigationBar(
//             currentIndex: _currentIndex,
//             onTap: (index) {
//               setState(() {
//                 _currentIndex = index;
//               });
//             },
//             backgroundColor: Colors.white, // Background color of the bar
//             selectedItemColor: header, // Active icon/text color
//             unselectedItemColor:
//                 const Color(0xFF2C2C2C), // Default icon/text color
//             type: BottomNavigationBarType.fixed, // Fixed layout
//             items: const [
//               BottomNavigationBarItem(
//                 icon: FaIcon(FontAwesomeIcons.solidCommentDots),
//                 label: 'Chat',
//               ),
//               BottomNavigationBarItem(
//                 icon: FaIcon(FontAwesomeIcons.peopleGroup),
//                 label: 'Groups',
//               ),
//               BottomNavigationBarItem(
//                 icon: FaIcon(FontAwesomeIcons.idCard),
//                 label: 'Contact Requests',
//               ),
//               BottomNavigationBarItem(
//                 icon: FaIcon(FontAwesomeIcons.gear),
//                 label: 'Settings',
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// class GroupsPage extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Groups')),
//       body: const Center(child: Text('Groups Page Content')),
//     );
//   }
// }

// class ContactRequestsPage extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Contact Requests')),
//       body: const Center(child: Text('Contact Requests Content')),
//     );
//   }
// }

// class SettingsPage extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Settings')),
//       body: const Center(child: Text('Settings Page Content')),
//     );
//   }
// }
