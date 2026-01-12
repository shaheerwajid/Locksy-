import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert' as convert;
import 'package:CryptoChat/models/pago.dart';

class PayuServices {
  String urlPayU = "https://www.CryptoChat.net/C_service/paymentPayU";

  Future<Map<String, String>> createPayment() async {
    return {
      "urlPago": urlPayU,
    };
  }

  Future<Pago> executePayment(url, payerId, accessToken) async {
    try {
      var response = await http.post(Uri.parse(url),
          body: convert.jsonEncode({"payer_id": payerId}),
          headers: {
            "content-type": "application/json",
            'Authorization': 'Bearer ' + accessToken
          });

      final body = convert.jsonDecode(response.body);
      Pago pago = Pago();
      if (response.statusCode == 200) {
        pago.idPago = body["id"];
        pago.cart = body["cart"];
        pago.fechaFin = body["fecha_fin"];
        pago.fechaTransaccion = body["create_time"];
        pago.state = body["state"];
        pago.value = body["transactions"][0]["amount"]["total"];
      }
      return pago;
    } catch (e) {
      rethrow;
    }
  }
}
