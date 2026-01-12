import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert' as convert;

//import 'package:http_auth/http_auth.dart';

import 'package:CryptoChat/models/pago.dart';

class PaypalServices {
  // FOR SANDBOX MODE
  // String domain = "https://api.sandbox.paypal.com"; // for sandbox mode
  // String clientId =
  //     'AZNMEXQR4FD5IsgryqVv4EhN3xij5-t1AvueTg4lCtzTFD28oR9G2gu2zu13EHdlKEUE5S5jbsDxtRgx';
  // String secret =
  //     'EDHKPuHqztkO6M6fejSdVwx5Sh2_GX0d8cLBfvByughkHRlN9Jm8Cwk73_fh54-aAZBBAXFClYU6Lnk_';
  // FOR SANDBOX MODE

  // FOR PRODUCTION MODE => Global Especialistas S.A.S NIT 900798465-0
  String domain = "https://api.paypal.com"; // for production mode
  String clientId =
      // 'AXfC8LoalTcPWFVtHPekYSNK-XDVITqNQCNGiIb1zkloGbOK0zGUbTW4fttJFrAan2B-C-C2hgJOAWZI';
      'AZ7ynOvSyxr7D4OfgUvPpMoIevHcaMfmTMWQCVJWLi1-og3n9nQ0IJ_9WVg0qLyE21F0RF_4SKiFdaOW';
  String secret =
      // 'ENdH0GjWDGi1bIVeMuEgP36pZDF55J-n6x2cgVzTeNHgygPn2O_aMrP43e8_tUJGvUaNojbt4Efk2e1a';
      'EMhVoiTurb7LLOjXTicKmClXjg7YxX2mRadG_H6KyOdmFBeEn2HLDa_6ZoiiDQ5pgE8xy57NsXk0Tzjs';
  // FOR PRODUCTION MODE
  String urlPayPal = "https://www.CryptoChat.net/C_service/paymentPayPal";
  // for getting the access token from Paypal
  // Future<String?> getAccessToken() async {
  //   try {
  //     var client = BasicAuthClient(clientId, secret);
  //     var html = '$domain/v1/oauth2/token?grant_type=client_credentials';
  //     var response = await client.post(Uri.parse(html));
  //     if (response.statusCode == 200) {
  //       final body = convert.jsonDecode(response.body);
  //       return body["access_token"];
  //     }
  //     return null;
  //   } catch (e) {
  //     rethrow;
  //   }
  // }

  Future<Map<String, String>> createPayment() async {
    return {
      "urlPago": urlPayPal,
    };
  }

  // for creating the payment request with Paypal
  Future<Map<String, String>> createPaypalPayment(
      transactions, accessToken) async {
    try {
      var response = await http.post(Uri.parse("$domain/v1/payments/payment"),
          body: convert.jsonEncode(transactions),
          headers: {
            "content-type": "application/json",
            'Authorization': 'Bearer ' + accessToken
          });

      final body = convert.jsonDecode(response.body);
      if (response.statusCode == 201) {
        if (body["links"] != null && body["links"].length > 0) {
          List links = body["links"];

          String executeUrl = "";
          String approvalUrl = "";
          final item = links.firstWhere((o) => o["rel"] == "approval_url",
              orElse: () => null);
          if (item != null) {
            approvalUrl = item["href"];
          }
          final item1 = links.firstWhere((o) => o["rel"] == "execute",
              orElse: () => null);
          if (item1 != null) {
            executeUrl = item1["href"];
          }
          return {"executeUrl": executeUrl, "approvalUrl": approvalUrl};
        }
        return {};
      } else {
        throw Exception(body["message"]);
      }
    } catch (e) {
      rethrow;
    }
  }

  // for executing the payment transaction
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
        // return response.body;
        // return body["id"];
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
