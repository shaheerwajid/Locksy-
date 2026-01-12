import 'package:flutter/material.dart';
import 'package:flutter_onboarding_slider/flutter_onboarding_slider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
import 'onboarding_content.dart';
import 'package:CryptoChat/helpers/style.dart';

class OnboardingScreen extends StatelessWidget {
  final Color kDarkBlueColor = const Color(0xFF049EAC);
  final Color kDarkBlackColor = const Color(0xFF2d2d2d);

  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: OnBoardingSlider(
        finishButtonText: 'Get Started',
        onFinish: () async {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setBool('hasSeenOnboarding', true);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const LoginPage(),
            ),
          );
        },
        finishButtonStyle: FinishButtonStyle(
          backgroundColor: primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15), // Adjust the radius as needed
          ),
          // Optional: Set padding and elevation
          elevation: 5, // Adds shadow if desired


        ),
        skipTextButton: Text(
          'Skip',
          style: TextStyle(
            fontSize: 16,
            color: text_color,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Text(
          '',
          style: TextStyle(
            fontSize: 16,
            color: text_color,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailingFunction: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const LoginPage(),
            ),
          );
        },
        controllerColor: primary,
        totalPage: 3,
        headerBackgroundColor: background,
        pageBackgroundColor: background,
        background: [
          Container(color: background),
          Container(color:background),
          Container(color:background),
        ],
        speed: 1.8,
        pageBodies: [
          OnboardingContent(
            title: 'Secure Chat',
            description: 'Communicate freely with end-to-end encryption, ensuring your privacy is always protected.',
            color: text_color,
            imagePath: 'assets/banner/images_chat_1.png',
          ),
          OnboardingContent(
            title: 'Private Groups',
            description: 'Create secure group chats with friends or teams where only authorized members can join.',
            color: text_color,
            imagePath: 'assets/banner/images_chat_2.png',
          ),
          OnboardingContent(
            title: 'Data Protection',
            description: 'Your conversations are encrypted and never stored on our servers. Stay safe and in control.',
            color: text_color,
            imagePath: 'assets/banner/images_chat_3.png',
          ),
        ],
      ),
    );
  }
}
