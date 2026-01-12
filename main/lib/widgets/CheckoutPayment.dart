import 'dart:core';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:CryptoChat/global/environment.dart';
import 'package:CryptoChat/helpers/style.dart';
import 'package:CryptoChat/services/auth_service.dart';
import 'package:webview_flutter/webview_flutter.dart';
// import 'package:CryptoChat/services/PayuService.dart';

class CheckoutPayment extends StatefulWidget {
  final Function onFinish;

  const CheckoutPayment({super.key, required this.onFinish});

  @override
  State<StatefulWidget> createState() {
    return CheckoutPaymentState();
  }
}

class CheckoutPaymentState extends State<CheckoutPayment> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldKey =
      GlobalKey<ScaffoldMessengerState>();
  String? checkoutUrl;
  late final WebViewController _controller;

  AuthService? auth;

  @override
  void initState() {
    super.initState();
    auth = Provider.of<AuthService>(context, listen: false);

    // Initialize WebViewController
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.contains('paymentSuccess')) {
              widget.onFinish();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    Future.delayed(const Duration(seconds: 2), () async {
      try {
        final url = '${Environment.urlService}paymentCheckout';
        setState(() {
          checkoutUrl = url;
        });
        await _controller.loadRequest(Uri.parse(url));
      } catch (e) {
        print('exception: $e');
        final snackBar = SnackBar(
          content: Text(e.toString()),
          duration: const Duration(seconds: 10),
          action: SnackBarAction(
            label: 'Close',
            onPressed: () {},
          ),
        );
        _scaffoldKey.currentState!.showSnackBar(snackBar);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldKey,
      child: Scaffold(
        appBar: AppBar(
          shadowColor: transparente,
          backgroundColor: transparente,
          leading: InkWell(
            child: Icon(
              Icons.arrow_back_ios_rounded,
              color: amarillo,
            ),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          title: Text(
            'Payment',
            style: TextStyle(color: gris),
          ),
          centerTitle: true,
        ),
        body: checkoutUrl == null
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : WebViewWidget(controller: _controller),
      ),
    );
  }
}
