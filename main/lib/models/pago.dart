import 'dart:convert';

Pago pagoFromJson(String str) => Pago.fromJson(json.decode(str));
String pagoToJson(Pago data) => json.encode(data.toJson());

class Pago {
  Pago({
    this.idPago,
    this.state,
    this.cart,
    this.value,
    this.fechaTransaccion,
    this.fechaFin,
    this.usuario,
  });

  String? idPago;
  String? state;
  String? cart;
  String? value;
  String? fechaTransaccion;
  String? fechaFin;
  String? usuario;
  // Usuario usuario;

  factory Pago.fromJson(Map<String, dynamic> json) => Pago(
        // usuario: Usuario.fromJson(json["usuario"]),
        usuario: json["usuario"],
        idPago: json["id_pago"],
        state: json["state"],
        cart: json["cart"],
        value: json["value"],
        fechaTransaccion: json["fecha_transaccion"],
        fechaFin: json["fecha_fin"],
      );

  Map<String, dynamic> toJson() => {
        "usuario": usuario,
        "id_pago": idPago,
        "state": state,
        "cart": cart,
        "value": value,
        "fecha_transaccion": fechaTransaccion,
        "fecha_fin": fechaFin,
      };
}
