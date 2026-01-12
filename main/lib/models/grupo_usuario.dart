import 'dart:convert';

GrupoUsuario grupoUsuarioFromJson(String str) =>
    GrupoUsuario.fromJson(json.decode(str));

String grupoToJson(GrupoUsuario data) => json.encode(data.toJson());

class GrupoUsuario {
  GrupoUsuario({
    this.codigoGrupo,
    this.uidUsuario,
    this.codigoUsuario,
    this.avatarUsuario,
    this.nombreUsuario,
  });

  String? codigoGrupo;
  String? uidUsuario;
  String? codigoUsuario;
  String? avatarUsuario;
  String? nombreUsuario;

  factory GrupoUsuario.fromJson(Map<String, dynamic> json) => GrupoUsuario(
        codigoGrupo: json['codigoGrupo'],
        uidUsuario: json['uidUsuario'],
        codigoUsuario: json['codigoUsuario'],
        avatarUsuario: json['avatarUsuario'],
        nombreUsuario: json['nombreUsuario'],
      );

  Map<String, dynamic> toJson() => {
        "codigoGrupo": codigoGrupo,
        "uidUsuario": uidUsuario,
        "codigoUsuario": codigoUsuario,
        "avatarUsuario": avatarUsuario,
        "nombreUsuario": nombreUsuario,
      };
}
