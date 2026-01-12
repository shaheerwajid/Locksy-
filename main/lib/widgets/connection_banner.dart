import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:CryptoChat/services/socket_service.dart';

class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<SocketService>(
      builder: (context, socketService, child) {
        final status = socketService.serverStatus;

        // Only show banner if not connected
        if (status == ServerStatus.Online) {
          return const SizedBox.shrink();
        }

        String message;
        Color backgroundColor;
        IconData icon;

        switch (status) {
          case ServerStatus.Connecting:
            message = 'Connecting...';
            backgroundColor = Colors.orange;
            icon = Icons.sync;
            break;
          case ServerStatus.Offline:
            message =
                'Offline - Messages will be sent when connection is restored';
            backgroundColor = Colors.red;
            icon = Icons.wifi_off;
            break;
          default:
            return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: backgroundColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (status == ServerStatus.Connecting)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else
                Icon(
                  icon,
                  color: Colors.white,
                  size: 16,
                ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
