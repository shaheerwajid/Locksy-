import 'package:flutter/material.dart';

class OnboardingContent extends StatelessWidget {
  final String title;
  final String description;
  final Color color;
  final String imagePath; // Add imagePath parameter

  const OnboardingContent({
    required this.title,
    required this.description,
    required this.color,
    required this.imagePath, // Require imagePath
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      width: MediaQuery.of(context).size.width,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, // Center the content vertically
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          // Use the passed image path
          Image.asset(
            imagePath, // Use the imagePath parameter
            height: 300, // Adjust height as needed
            fit: BoxFit.contain, // Make sure it fits well
          ),
          const SizedBox(height: 20), // Spacing between image and text
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xff2d2d2d),
              fontFamily: 'roboto-black',
              letterSpacing: 1.0,
              fontSize: 24.0,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black26,
              fontFamily: 'roboto-regular',
              letterSpacing: 1.0,
              fontSize: 18.0,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
