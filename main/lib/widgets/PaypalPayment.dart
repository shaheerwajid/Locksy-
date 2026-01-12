// import 'dart:convert';
// import 'dart:core';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:CryptoChat/helpers/style.dart';
// import 'package:CryptoChat/services/PaypalServices.dart';
// import 'package:CryptoChat/services/auth_service.dart';
// import 'package:webview_flutter/webview_flutter.dart';
// import 'package:http/http.dart' as http;

// class PaypalPayment extends StatefulWidget {
//   final Function onFinish;

//   PaypalPayment({required this.onFinish});

//   @override
//   State<StatefulWidget> createState() {
//     return PaypalPaymentState();
//   }
// }

// class PaypalPaymentState extends State<PaypalPayment> {
//   GlobalKey<ScaffoldMessengerState> _scaffoldKey =
//       GlobalKey<ScaffoldMessengerState>();
//   String? checkoutUrl;
//   PaypalServices services = PaypalServices();

//   AuthService? auth;

//   @override
//   void initState() {
//     this.auth = Provider.of<AuthService>(context, listen: false);
//     if (Platform.isAndroid) WebView.platform = SurfaceAndroidWebView();
//     Future.delayed(Duration(seconds: 2), () async {
//       try {
//         final res = await services.createPayment();
//         setState(() {
//           checkoutUrl = res["urlPago"];
//         });
//       } catch (e) {
//         print('exception: ' + e.toString());
//         final snackBar = SnackBar(
//           content: Text(e.toString()),
//           duration: Duration(seconds: 10),
//           action: SnackBarAction(
//             label: 'Close',
//             onPressed: () {},
//           ),
//         );
//         _scaffoldKey.currentState!.showSnackBar(snackBar);
//       }
//     });

//     super.initState();
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (checkoutUrl != null) {
//       checkoutUrl = '?uid=' +
//           this.auth!.usuario!.uid! +
//           '&lang=' +
//           this.auth!.usuario!.idioma!;
//       return Scaffold(
//         appBar: AppBar(
//           backgroundColor: azulClaro,
//           leading: GestureDetector(
//             child: Icon(Icons.arrow_back_ios),
//             onTap: () => Navigator.pop(context),
//           ),
//         ),
//         body: Container(
//           padding: EdgeInsets.only(left: 5, right: 5),
//           child: WebView(
//             initialUrl: checkoutUrl,
//             javascriptMode: JavascriptMode.unrestricted,
//             navigationDelegate: (NavigationRequest request) async {
//               print(request.url);
//               if (request.url.contains("payPalResponse")) {
//                 await auth!.pagosUsuario(auth!.usuario!);
//                 widget.onFinish();
//               }
//               return NavigationDecision.navigate;
//             },
//             javascriptChannels: <JavascriptChannel>[
//               JavascriptChannel(
//                   name: 'Print',
//                   onMessageReceived: (JavascriptMessage msg) async {
//                     var payPalResponse = jsonDecode(msg.message);
//                     http
//                         .post(
//                       Uri.parse(
//                           'https://www.CryptoChat.ninja/pms-admin/payPalResponse'),
//                       headers: <String, String>{
//                         'Content-Type': 'application/json; charset=UTF-8',
//                       },
//                       body: jsonEncode(<String, String>{
//                         "id_pago": payPalResponse["id"],
//                         "state": payPalResponse["status"],
//                         "cart": payPalResponse["id"],
//                         "value": payPalResponse["purchase_units"][0]["amount"]
//                             ["value"],
//                         "fecha_transaccion": payPalResponse["create_time"]
//                             .toString()
//                             .substring(0, 10),
//                         "usuario": auth!.usuario!.uid!,
//                         "response": msg.message.toString(),
//                       }),
//                     )
//                         .then((res) {
//                       widget.onFinish();
//                     });
//                   }),
//             ].toSet(),
//           ),
//         ),
//       );
//     } else {
//       return Scaffold(
//         key: _scaffoldKey,
//         appBar: AppBar(
//           leading: IconButton(
//               icon: Icon(Icons.arrow_back),
//               onPressed: () {
//                 Navigator.of(context).pop();
//               }),
//           backgroundColor: Colors.black12,
//           elevation: 0.0,
//         ),
//         body: Center(child: Container(child: CircularProgressIndicator())),
//       );
//     }
//   }
// }
