import 'dart:convert';

ObjPago pagoFromJson(String str) => ObjPago.fromJson(json.decode(str));
String pagoToJson(ObjPago data) => json.encode(data.toJson());

class ObjPago {
  String? nombre;
  String? valor;
  String? fechaPago;
  String? fecha;

  ObjPago({this.nombre, this.valor, this.fecha, this.fechaPago});

  factory ObjPago.fromJson(Map<String, dynamic> json) => ObjPago(
        nombre: json["nombre"],
        valor: json["valor"],
        fechaPago: json["fechaPago"],
        fecha: json["fecha"],
      );

  Map<String, dynamic> toJson() => {
        "nombre": nombre,
        "valor": valor,
        "fecha": fecha,
        "fechaPago": fechaPago,
      };
}
