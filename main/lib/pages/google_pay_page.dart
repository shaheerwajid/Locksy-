// import 'dart:async';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:in_app_purchase/in_app_purchase.dart';
// import 'package:in_app_purchase_android/billing_client_wrappers.dart';
// import 'package:in_app_purchase_android/in_app_purchase_android.dart';
// import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
// import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
// import 'package:provider/provider.dart';
// import 'package:CryptoChat/services/auth_service.dart';
// import 'package:CryptoChat/services/consumable_store.dart';
// import 'package:CryptoChat/services/usuarios_service.dart';

// const bool _kAutoConsume = true;

// const String _kConsumableId = 'tm_3';
// const String _kUpgradeId = 't_3m';
// const String _kSilverSubscriptionId = 't_6m';
// const String _kGoldSubscriptionId = 't_12m';
// String? valorProducto;
// const List<String> _kProductIds = <String>[
//   // _kConsumableId,
//   _kUpgradeId,
//   _kSilverSubscriptionId,
//   _kGoldSubscriptionId,
// ];

// class GooglePay extends StatefulWidget {
//   @override
//   GooglePayState createState() => GooglePayState();
// }

// class GooglePayState extends State<GooglePay> {
//   final InAppPurchase _inAppPurchase = InAppPurchase.instance;
//   StreamSubscription<List<PurchaseDetails>>? _subscription;
//   List<String> _notFoundIds = [];
//   List<ProductDetails> _products = [];
//   List<PurchaseDetails> _purchases = [];
//   List<String> _consumables = [];
//   bool _isAvailable = false;
//   bool _purchasePending = false;
//   bool _loading = true;
//   String? _queryProductError;

//   AuthService? authService;
//   final usuarioService = new UsuariosService();

//   @override
//   void initState() {
//     this.authService = Provider.of<AuthService>(context, listen: false);
//     final Stream<List<PurchaseDetails>> purchaseUpdated =
//         _inAppPurchase.purchaseStream;
//     _subscription = purchaseUpdated.listen((purchaseDetailsList) {
//       _listenToPurchaseUpdated(purchaseDetailsList);
//     }, onDone: () {
//       _subscription!.cancel();
//     }, onError: (error) {});
//     initStoreInfo();
//     super.initState();
//   }

//   Future<void> initStoreInfo() async {
//     final bool isAvailable = await _inAppPurchase.isAvailable();
//     if (!isAvailable) {
//       setState(() {
//         _isAvailable = isAvailable;
//         _products = [];
//         _purchases = [];
//         _notFoundIds = [];
//         _consumables = [];
//         _purchasePending = false;
//         _loading = false;
//       });
//       return;
//     }

//     if (Platform.isIOS) {
//       // var iosPlatformAddition = _inAppPurchase
//       //     .getPlatformAddition<InAppPurchaseIosPlatformAddition>();
//       // await iosPlatformAddition.setDelegate(ExamplePaymentQueueDelegate());
//     }

//     ProductDetailsResponse productDetailResponse =
//         await _inAppPurchase.queryProductDetails(_kProductIds.toSet());
//     if (productDetailResponse.error != null) {
//       setState(() {
//         _queryProductError = productDetailResponse.error!.message;
//         _isAvailable = isAvailable;
//         _products = productDetailResponse.productDetails;
//         _purchases = [];
//         _notFoundIds = productDetailResponse.notFoundIDs;
//         _consumables = [];
//         _purchasePending = false;
//         _loading = false;
//       });
//       return;
//     }

//     if (productDetailResponse.productDetails.isEmpty) {
//       setState(() {
//         _queryProductError = null;
//         _isAvailable = isAvailable;
//         _products = productDetailResponse.productDetails;
//         _purchases = [];
//         _notFoundIds = productDetailResponse.notFoundIDs;
//         _consumables = [];
//         _purchasePending = false;
//         _loading = false;
//       });
//       return;
//     }

//     List<String> consumables = await ConsumableStore.load();
//     setState(() {
//       _isAvailable = isAvailable;
//       _products = productDetailResponse.productDetails;
//       _notFoundIds = productDetailResponse.notFoundIDs;
//       _consumables = consumables;
//       _purchasePending = false;
//       _loading = false;
//     });
//   }

//   @override
//   void dispose() {
//     if (Platform.isIOS) {
//       // var iosPlatformAddition = _inAppPurchase
//       //     .getPlatformAddition<InAppPurchaseIosPlatformAddition>();
//       // iosPlatformAddition.setDelegate(null);
//     }
//     _subscription!.cancel();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     List<Widget> stack = [];
//     if (_queryProductError == null) {
//       stack.add(
//         ListView(
//           children: [
//             _buildProductList(),
//           ],
//         ),
//       );
//     } else {
//       stack.add(Center(
//         child: Text(_queryProductError!),
//       ));
//     }
//     if (_purchasePending) {
//       stack.add(
//         Stack(
//           children: [
//             Opacity(
//               opacity: 0.3,
//               child: const ModalBarrier(dismissible: false, color: Colors.grey),
//             ),
//             Center(
//               child: CircularProgressIndicator(),
//             ),
//           ],
//         ),
//       );
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Google Pay'),
//       ),
//       body: Stack(
//         children: stack,
//       ),
//     );
//   }

//   Card _buildProductList() {
//     if (_loading) {
//       return Card(
//           child: (ListTile(
//               leading: CircularProgressIndicator(),
//               title: Text('Fetching products...'))));
//     }
//     if (!_isAvailable) {
//       return Card();
//     }
//     final ListTile productHeader =
//         ListTile(title: Text('Seleccione un producto'));
//     List<ListTile> productList = <ListTile>[];
//     if (_notFoundIds.isNotEmpty) {
//       productList.add(ListTile(
//           title: Text('[${_notFoundIds.join(", ")}] not found',
//               style: TextStyle(color: ThemeData.light().errorColor)),
//           subtitle: Text(
//               'This app needs special configuration to run. Please see example/README.md for instructions.')));
//     }

//     Map<String, PurchaseDetails> purchases =
//         Map.fromEntries(_purchases.map((PurchaseDetails purchase) {
//       if (purchase.pendingCompletePurchase) {
//         _inAppPurchase.completePurchase(purchase);
//       }
//       return MapEntry<String, PurchaseDetails>(purchase.productID, purchase);
//     }));
//     productList.addAll(_products.map(
//       (ProductDetails productDetails) {
//         return ListTile(
//             title: Text(
//               productDetails.title,
//             ),
//             subtitle: Text(
//               productDetails.description,
//             ),
//             trailing: TextButton(
//               child: Text(productDetails.price),
//               style: TextButton.styleFrom(
//                 backgroundColor: Colors.green[800],
//                 // primary: Colors.white,
//               ),
//               onPressed: () {
//                 PurchaseParam purchaseParam;
//                 valorProducto = productDetails.price;
//                 if (Platform.isAndroid) {
//                   final oldSubscription =
//                       _getOldSubscription(productDetails, purchases);

//                   purchaseParam = GooglePlayPurchaseParam(
//                       productDetails: productDetails,
//                       applicationUserName: null,
//                       changeSubscriptionParam: (oldSubscription != null)
//                           ? ChangeSubscriptionParam(
//                               oldPurchaseDetails: oldSubscription,
//                               prorationMode:
//                                   ProrationMode.immediateWithTimeProration,
//                             )
//                           : null);
//                 } else {
//                   purchaseParam = PurchaseParam(
//                     productDetails: productDetails,
//                     applicationUserName: null,
//                   );
//                 }

//                 if (productDetails.id == _kConsumableId) {
//                   _inAppPurchase.buyConsumable(
//                       purchaseParam: purchaseParam,
//                       autoConsume: _kAutoConsume || Platform.isIOS);
//                 } else {
//                   _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
//                 }
//               },
//             ));
//       },
//     ));

//     return Card(
//         child:
//             Column(children: <Widget>[productHeader, Divider()] + productList));
//   }

//   Future<void> consume(String id) async {
//     await ConsumableStore.consume(id);
//     final List<String> consumables = await ConsumableStore.load();
//     setState(() {
//       _consumables = consumables;
//     });
//   }

//   void showPendingUI() {
//     setState(() {
//       _purchasePending = true;
//     });
//   }

//   void deliverProduct(PurchaseDetails purchaseDetails) async {
//     if (purchaseDetails.productID == _kConsumableId) {
//       await ConsumableStore.save(purchaseDetails!.purchaseID!);
//       List<String> consumables = await ConsumableStore.load();
//       setState(() {
//         _purchasePending = false;
//         _consumables = consumables;
//       });
//     } else {
//       usuarioService
//           .validaPago(
//               authService!.usuario!.uid,
//               purchaseDetails.verificationData.localVerificationData,
//               purchaseDetails.verificationData.source,
//               valorProducto)
//           .then((value) {
//         print(value);
//         Navigator.pop(context, true);
//       });
//       print(purchaseDetails.verificationData.localVerificationData);
//       setState(() {
//         _purchases.add(purchaseDetails);
//         _purchasePending = false;
//       });
//     }
//   }

//   void handleError(IAPError error) {
//     setState(() {
//       _purchasePending = false;
//     });
//   }

//   Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) {
//     return Future<bool>.value(true);
//   }

//   void _handleInvalidPurchase(PurchaseDetails purchaseDetails) {}

//   void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
//     purchaseDetailsList.forEach((PurchaseDetails purchaseDetails) async {
//       if (purchaseDetails.status == PurchaseStatus.pending) {
//         showPendingUI();
//       } else {
//         if (purchaseDetails.status == PurchaseStatus.error) {
//           handleError(purchaseDetails.error!);
//         } else if (purchaseDetails.status == PurchaseStatus.purchased) {
//           bool valid = await _verifyPurchase(purchaseDetails);
//           if (valid) {
//             deliverProduct(purchaseDetails);
//           } else {
//             _handleInvalidPurchase(purchaseDetails);
//             return;
//           }
//         }
//         if (Platform.isAndroid) {
//           if (!_kAutoConsume && purchaseDetails.productID == _kConsumableId) {
//             final InAppPurchaseAndroidPlatformAddition androidAddition =
//                 _inAppPurchase.getPlatformAddition<
//                     InAppPurchaseAndroidPlatformAddition>();
//             await androidAddition.consumePurchase(purchaseDetails);
//           }
//         }
//         if (purchaseDetails.pendingCompletePurchase) {
//           await _inAppPurchase.completePurchase(purchaseDetails);
//         }
//       }
//     });
//   }

//   Future<void> confirmPriceChange(BuildContext context) async {
//     if (Platform.isAndroid) {
//       final InAppPurchaseAndroidPlatformAddition androidAddition =
//           _inAppPurchase
//               .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
//       // var priceChangeConfirmationResult =
//       //     await androidAddition.launchPriceChangeConfirmationFlow(
//       //   sku: 'purchaseId',
//       // );
//       // if (priceChangeConfirmationResult.responseCode == BillingResponse.ok) {
//       //   ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//       //     content: Text('Price change accepted'),
//       //   ));
//       // } else {
//       //   ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//       //     content: Text(
//       //       priceChangeConfirmationResult.debugMessage ??
//       //           "Price change failed with code ${priceChangeConfirmationResult.responseCode}",
//       //     ),
//       //   ));
//       // }
//     }
//     if (Platform.isIOS) {
//       // var iapIosPlatformAddition = _inAppPurchase
//       //     .getPlatformAddition<InAppPurchaseIosPlatformAddition>();
//       // await iapIosPlatformAddition.showPriceConsentIfNeeded();
//     }
//   }

//   GooglePlayPurchaseDetails? _getOldSubscription(
//       ProductDetails productDetails, Map<String, PurchaseDetails> purchases) {
//     GooglePlayPurchaseDetails? oldSubscription;
//     if (productDetails.id == _kSilverSubscriptionId &&
//         purchases[_kGoldSubscriptionId] != null) {
//       oldSubscription =
//           purchases[_kGoldSubscriptionId] as GooglePlayPurchaseDetails;
//     } else if (productDetails.id == _kGoldSubscriptionId &&
//         purchases[_kSilverSubscriptionId] != null) {
//       oldSubscription =
//           purchases[_kSilverSubscriptionId] as GooglePlayPurchaseDetails;
//     }
//     return oldSubscription;
//   }
// }

// class ExamplePaymentQueueDelegate implements SKPaymentQueueDelegateWrapper {
//   @override
//   bool shouldContinueTransaction(
//       SKPaymentTransactionWrapper transaction, SKStorefrontWrapper storefront) {
//     return true;
//   }

//   @override
//   bool shouldShowPriceConsent() {
//     return false;
//   }
// }
