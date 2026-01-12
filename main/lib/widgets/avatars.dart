import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:CryptoChat/global/AppLocalizations.dart';
import 'package:CryptoChat/helpers/funciones.dart';
import 'package:CryptoChat/helpers/style.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:CryptoChat/services/auth_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

class AvatarPage extends StatefulWidget {
  final List<dynamic> lista;
  final String tipo;
  final String avatar;

  const AvatarPage({super.key, 
    required this.lista,
    required this.avatar,
    required this.tipo,
  });

  @override
  _AvatarPageState createState() => _AvatarPageState();
}

class _AvatarPageState extends State<AvatarPage> {
  List<dynamic> list = [];
  String? tipo;
  String? avatar;

  int _current = 0;
  List<String> avatarList = [];
  List<Widget> imageSliders = [];

  AuthService? authService;

  @override
  void initState() {
    authService = Provider.of<AuthService>(context, listen: false);
    avatar = widget.avatar;
    list = widget.lista;
    tipo = widget.tipo;
    _getavatars();
    super.initState();
  }

  Future<String?> saveImageToCache(XFile file) async {
    try {
      final cacheDir = await getTemporaryDirectory(); // Get the cache directory
      final fileName = file.name; // Get the file name
      final savedFile = File('${cacheDir.path}/$fileName');
      final bytes = await file.readAsBytes(); // Read the file as bytes
      if (bytes.isEmpty) {
        throw 'File is empty';
      }
      await savedFile.writeAsBytes(bytes); // Save the bytes to the file
      return savedFile.path; // Return the saved file path
    } catch (e) {
      log('Error saving image to cache: $e');
      return null;
    }
  }

  _getavatars() async {
    avatarList = list.map((e) => e.toString()).toList();
    setState(() {
      imageSliders = avatarList.map((item) {
        final isFile = File(item).existsSync();
        return Container(
          width: 190,
          decoration: BoxDecoration(
            color: blanco,
            borderRadius: BorderRadius.circular(100),
          ),
          margin: const EdgeInsets.all(5.0),
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(5.0)),
            child: Stack(
              children: <Widget>[
                isFile
                    ? Image.file(
                        File(item),
                        width: 500,
                      )
                    : Image.asset(getAvatar(item, tipo!), width: 500),
              ],
            ),
          ),
        );
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isFile = avatar != null && File(avatar!).existsSync();
    return Scaffold(
      backgroundColor: drawer_white,
      appBar: AppBar(
        leading: InkWell(
          child: Icon(
            Icons.arrow_back_ios_rounded,
            color: gris,
          ),
          onTap: () {
            Navigator.pop(context, true);
          },
        ),
        centerTitle: true,
        title: Text(
          'Avatar',
          style: TextStyle(color: gris),
        ),
        backgroundColor: drawer_light_white,
        shadowColor: drawer_light_white,
      ),
      body: SafeArea(
        child: ListView(
          children: [
            Hero(
              tag: 'avatar',
              child: GestureDetector(
                child: Container(
                  decoration:
                      BoxDecoration(color: blanco, shape: BoxShape.circle),
                  width: MediaQuery.of(context).size.width,
                  height: 200,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(90),
                    child: isFile
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width:
                                    200, // Set the width to match the container size
                                height:
                                    200, // Set the height to match the container size
                                decoration: BoxDecoration(
                                  shape: BoxShape
                                      .circle, // Make the container a circle
                                  color:
                                      blanco, // Optional: Background color for the container
                                ),
                                child: ClipOval(
                                  // Clip the image into a circular shape
                                  child: Image.file(
                                    File(avatar!),

                                    fit: BoxFit
                                        .fitWidth, // Ensure the image covers the circular area without distortion
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Image.asset(
                            getAvatar(avatar!, tipo!),
                          ),
                  ),
                ),
                onTap: () {},
              ),
            ),
            Container(
              margin: const EdgeInsets.all(20),
              child: Text(
                AppLocalizations.of(context)!.translate('CHOOSE_AVATAR'),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 20, color: gris, fontWeight: FontWeight.bold),
              ),
            ),
            CarouselSlider(
              items: imageSliders,
              options: CarouselOptions(
                enlargeCenterPage: true,
                aspectRatio: 2.0,
                onPageChanged: (index, reason) {
                  setState(() {
                    _current = index;
                    avatar = avatarList[index];
                  });
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: avatarList.map((url) {
                int index = avatarList.indexOf(url);
                return Container(
                  width: 8.0,
                  height: 8.0,
                  margin: const EdgeInsets.symmetric(
                      vertical: 20.0, horizontal: 3.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _current == index ? primary : gris,
                  ),
                );
              }).toList(),
            ),
            Container(
              margin: const EdgeInsets.only(
                  left: 100, right: 100, bottom: 30, top: 30),
              child: SizedBox.fromSize(
                size: const Size(130, 50),
                child: Material(
                  borderRadius: BorderRadius.circular(15),
                  color: primary,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(15),
                    splashColor: secondary,
                    child: Center(
                      child: Text(
                        AppLocalizations.of(context)!.translate('SAVE'),
                        style: TextStyle(color: white, fontSize: 18),
                      ),
                    ),
                    onTap: () => Navigator.pop(context, avatar),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  child: SizedBox.fromSize(
                    size: const Size(130, 50),
                    child: Material(
                      borderRadius: BorderRadius.circular(15),
                      color: primary, // Use the same color as the 'Save' button
                      child: InkWell(
                        borderRadius: BorderRadius.circular(15),
                        splashColor: secondary, // Use the same splash color
                        child: Center(
                          child: Text(
                            AppLocalizations.of(context)!
                                .translate("Take_image"),
                            // Button text
                            style: TextStyle(color: white, fontSize: 18),
                          ),
                        ),
                        onTap: () async {
                          try {
                            final ImagePicker picker = ImagePicker();
                            XFile? pickedFile = await picker.pickImage(
                              source: ImageSource.camera,
                              imageQuality: 50,
                            );
                            if (pickedFile != null) {
                              final savedPath =
                                  await saveImageToCache(pickedFile);
                              if (savedPath != null) {
                                log('Image saved to cache: $savedPath');
                                setState(() {
                                  avatar = savedPath;
                                });
                              }
                            }
                          } catch (e) {
                            log(e.toString());
                          }
                        },
                      ),
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  child: SizedBox.fromSize(
                    size: const Size(130, 50),
                    child: Material(
                      borderRadius: BorderRadius.circular(15),
                      color: primary, // Use the same color as the 'Save' button
                      child: InkWell(
                        borderRadius: BorderRadius.circular(15),
                        splashColor: secondary, // Use the same splash color
                        child: Center(
                          child: Text(
                            AppLocalizations.of(context)!
                                .translate('Select_image'), // Button text
                            style: TextStyle(color: white, fontSize: 18),
                          ),
                        ),
                        onTap: () async {
                          try {
                            final ImagePicker picker = ImagePicker();
                            XFile? pickedFile = await picker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 50,
                            );
                            if (pickedFile != null) {
                              final savedPath =
                                  await saveImageToCache(pickedFile);
                              if (savedPath != null) {
                                log('Image saved to cache: $savedPath');
                                setState(() {
                                  avatar = savedPath;
                                });
                              }
                            }
                          } catch (e) {
                            log(e.toString());
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
