import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

void showToast(BuildContext context, String msg, Color color, IconData icon,
    {int? duration, ToastGravity? gravity}) {
  FToast fToast;
  fToast = FToast();
  fToast.init(context);

  duration ??= 5;
  gravity ??= ToastGravity.CENTER;

  Widget toast = Container(
    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(25.0),
      color: color,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon),
        const SizedBox(
          width: 12.0,
        ),
        Text(msg),
      ],
    ),
  );

  fToast.showToast(
    child: toast,
    toastDuration: Duration(seconds: duration),
    gravity: gravity,
  );

  // Toast.show(
  //   msg,
  //   context,
  //   duration: duration,
  //   gravity: gravity,
  //   backgroundColor: color,
  // );
}
