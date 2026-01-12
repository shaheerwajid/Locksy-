import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:CryptoChat/global/AppLocalizations.dart';
import 'package:CryptoChat/helpers/funciones.dart';
import 'package:CryptoChat/helpers/style.dart';
import 'package:CryptoChat/models/usuario.dart';
import 'package:CryptoChat/providers/db_provider.dart';
import 'package:CryptoChat/services/auth_service.dart';
import 'package:CryptoChat/widgets/mostrar_alerta.dart';

class ListaContactos extends StatefulWidget {
  final List<String>? usuarios;
  final int limite;
  const ListaContactos({super.key, this.usuarios, required this.limite});
  @override
  _ListaContactosState createState() => _ListaContactosState();
}

class _ListaContactosState extends State<ListaContactos> {
  List<Usuario> listaContactos = [];
  List<int> itemSelected = [];
  List<String> usuarioUID = [];
  int? limite;

  AuthService? authService;

  @override
  void initState() {
    authService = Provider.of<AuthService>(context, listen: false);
    limite = widget.limite;
    _getContactos();
    super.initState();
  }

  _getContactos() async {
    listaContactos.clear();
    // usuarioUID = widget.data;

    listaContactos = await DBProvider.db.getcontactos();
    if (usuarioUID.isNotEmpty) {
      // listaContactos.removeWhere((element) => false)
      // Quitar del listado que muestra los que ya están agregados
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: drawer_white,
      appBar: AppBar(
        leading: InkWell(
          child: Icon(
            Icons.arrow_back_ios_rounded,
            color: gris,
          ),
          onTap: () => Navigator.pop(context, false),
        ),
        centerTitle: true,
        title: Text(
          AppLocalizations.of(context)!.translate('CONTACTS'),
          style: TextStyle(color: gris),
        ),
        backgroundColor: drawer_light_white,
        shadowColor: drawer_light_white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Flexible(
              child: Container(
                margin: const EdgeInsets.all(30),
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: blanco,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: amarillo),
                ),
                child: ListView.separated(
                  separatorBuilder: (_, i) => Divider(
                    indent: 20,
                    endIndent: 20,
                    color: amarillo,
                  ),
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (_, i) => listContacto(listaContactos[i], i),
                  itemCount: listaContactos.length,
                ),
              ),
            ),
            SizedBox.fromSize(
              size: Size(MediaQuery.of(context).size.width * 0.5, 50),
              child: Material(
                borderRadius: BorderRadius.circular(40),
                color: primary,
                child: InkWell(
                  borderRadius: BorderRadius.circular(40),
                  splashColor: amarillo,
                  child: Center(
                    child: Text(AppLocalizations.of(context)!.translate('ADD')),
                    //ADD_CONTACTS
                  ),
                  onTap: () => Navigator.pop(context, usuarioUID),
                ),
              ),
            ),
            const SizedBox(height: 20)
          ],
        ),
      ),
    );
  }

  ListTile listContacto(Usuario contacto, index) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: blanco,
        child: Image.asset(getAvatar(contacto.avatar!, 'user_')),
      ),
      title: Text(contacto.nombre!),
      trailing: itemSelected.contains(index)
          ? Icon(
              Icons.check,
              color: verde,
            )
          : const SizedBox(),
      tileColor: itemSelected.contains(index) ? verde.withOpacity(0.3) : blanco,
      onTap: () {
        if (!itemSelected.contains(index)) {
          if (itemSelected.length >= limite!) {
            mostrarAlerta(
                context,
                AppLocalizations.of(context)!.translate('WARNING'),
                AppLocalizations.of(context)!
                    .translateReplace('MAX_LIMIT_GROUP', '{LIMIT}', '$limite'));
            // itemSelected.remove(index);
          } else {
            setState(() {
              itemSelected.add(index);
              usuarioUID.add(contacto.uid!);
            });
          }
        } else {
          setState(() {
            itemSelected.removeWhere((val) => val == index);
            usuarioUID.remove(contacto.uid);
          });
        }
      },
    );
  }
}
