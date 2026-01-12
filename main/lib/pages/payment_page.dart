import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:CryptoChat/global/AppLocalizations.dart';
import 'package:CryptoChat/helpers/style.dart';
import 'package:CryptoChat/models/objPago.dart';
import 'package:CryptoChat/models/usuario.dart';
import 'package:CryptoChat/providers/db_provider.dart';
import 'package:CryptoChat/services/auth_service.dart';
import 'package:CryptoChat/widgets/CheckoutPayment.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  _PaymentPageState createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  AuthService? authService;
  List<ObjPago> pagos = [];
  Usuario? usuario;
  // PayUOrder? order;
  bool mostrarBoton = true;

  final ButtonStyle botonPay = ElevatedButton.styleFrom(
    backgroundColor: gris,
    // primary: amarilloClaro,
    minimumSize: const Size(100, 40),
    padding: const EdgeInsets.symmetric(horizontal: 20),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(5)),
    ),
  );

  @override
  void initState() {
    authService = Provider.of<AuthService>(context, listen: false);
    usuario = authService!.usuario;
    _getPagos();
    super.initState();
  }

  _getPagos() async {
    pagos = await DBProvider.db.getPagos();
    for (var e in pagos) {
      print(pagoToJson(e));
    }
    if (pagos.isNotEmpty &&
        DateTime.parse(DateTime.now().toString())
            .isBefore(DateTime.parse(pagos[0].fecha!.substring(0, 10)))) {
      mostrarBoton = false;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: grisClaro,
      appBar: AppBar(
        shadowColor: transparente,
        backgroundColor: transparente,
        leading: InkWell(
          child: Icon(
            Icons.arrow_back_ios_rounded,
            color: amarillo,
          ),
          onTap: () {
            Navigator.pop(context, true);
          },
        ),
        title: Text(
          AppLocalizations.of(context)!.translate('BILLING'),
          style: TextStyle(color: gris),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            color: grisClaro,
            child: Center(
              child: Image(
                image: const AssetImage('assets/banner/icon_img.png'),
                width: 130.0,
                color: gris,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.only(left: 20),
            color: grisClaro,
            alignment: Alignment.centerLeft,
            child: Text(
              AppLocalizations.of(context)!.translate('PAY_WITH'),
              style: TextStyle(
                  fontSize: 16, color: gris, fontWeight: FontWeight.bold),
            ),
          ),
          Container(
            color: grisClaro,
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: botonPay,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CheckoutPayment(
                          onFinish: () {
                            Navigator.pushNamedAndRemoveUntil(
                                context, 'home', (route) => false);
                          },
                        ),
                      ),
                    );
                  },
                  child:
                      Text(AppLocalizations.of(context)!.translate('PAY_NOW')),
                ),
                // SizedBox(width: 20),
                // ElevatedButton(
                //     style: botonPay,
                //     onPressed: () => Navigator.push(
                //             context,
                //             MaterialPageRoute(
                //               builder: (context) => GooglePay(),
                //             )).then((value) {
                //           if (value == true) _getPagos();
                //         }),
                //     child: Text('Pay App'))
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            color: gris,
            width: MediaQuery.of(context).size.width,
            child: Text(
              AppLocalizations.of(context)!.translate('PAYMENT_HISTORY'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: blanco,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Flexible(
            child: Container(
              color: blanco,
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                separatorBuilder: (_, i) => const Divider(),
                itemCount: pagos.length,
                itemBuilder: (_, i) => _listaPagos(pagos[i], i),
              ),
            ),
          )
        ],
      ),
    );
  }

  ListTile _listaPagos(ObjPago pago, i) {
    var nombre = pago.nombre ?? '';
    var fecha = pago.fechaPago != null ? pago.fechaPago!.substring(0, 10) : '';
    var valor = pago.valor ?? '0';
    return ListTile(
      tileColor: blanco,
      title: Text(nombre!),
      subtitle: Text(fecha),
      trailing: Text('\$${valor!}'),
    );
  }
}
