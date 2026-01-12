import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart' as rv;
import 'package:CryptoChat/global/AppLocalizations.dart';
import 'package:CryptoChat/global/environment.dart';
import 'package:CryptoChat/helpers/style.dart';
import 'package:url_launcher/url_launcher.dart';

class InfoPage extends StatefulWidget {
  const InfoPage({super.key});

  @override
  _InfoPageState createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  rv.Artboard? _riveArtboard;
  rv.RiveAnimationController? controller;
  int? year;
  // bool get isPlaying => _controller.isActive;
  @override
  void initState() {
    DateTime date = DateTime.now();
    year = date.year;
    rootBundle.load('assets/rive/logo.riv').then(
      (data) async {
        final file = rv.RiveFile.import(data);
        final artboard = file.mainArtboard;
        artboard.addController(controller = rv.SimpleAnimation('intro'));

        setState(() => _riveArtboard = artboard);
      },
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: drawer_white,
      appBar: AppBar(
        shadowColor: drawer_light_white,
        backgroundColor: drawer_light_white,
        leading: InkWell(
          child: Icon(
            Icons.arrow_back_ios_rounded,
            color: gris,
          ),
          onTap: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context)!.translate('ABOUT'),
          style: TextStyle(color: gris),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width,
              child: Image.asset(
                'assets/background/img_chat.png',
                color: negro.withOpacity(0.03),
                fit: BoxFit.cover,
              ),
            ),
            _riveArtboard == null
                ? const SizedBox()
                : rv.Rive(
                    artboard: _riveArtboard!,
                  ),
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.all(15),
                child: Image.asset(
                  'assets/banner/text_img.png',
                  color: primary,
                  height: 40,
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.all(60),
                child: Text(
                  '${AppLocalizations.of(context)!.translate('VERSION')} 1.0.0',
                  style: const TextStyle(
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.copyright),
                        Text(
                          '$year ',
                          style: const TextStyle(
                            fontSize: 15,
                          ),
                        ),
                        const Text(
                          'Locksy.',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      margin: const EdgeInsets.all(10),
                      child: GestureDetector(
                        child: Text(
                          AppLocalizations.of(context)!.translate('TERMS'),
                          style: const TextStyle(
                            fontSize: 13,
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () => lauchURL(Environment.urlTerminos),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future lauchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(
        url,
        forceSafariVC: false,
        forceWebView: false,
        enableJavaScript: true,
      );
    } else {
      print('Could not launch $url');
    }
  }
}
