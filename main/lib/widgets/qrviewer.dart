import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:CryptoChat/global/AppLocalizations.dart';
import 'package:CryptoChat/helpers/style.dart';
import 'package:CryptoChat/widgets/toast_message.dart';

class QRViewer extends StatefulWidget {
  const QRViewer({super.key});

  @override
  State<StatefulWidget> createState() => _QRViewerState();
}

class _QRViewerState extends State<QRViewer> {
  MobileScannerController? controller;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  bool _flash = false;
  bool _isScanning = true;

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  // In order to get hot reload to work we need to pause the camera if the platform
  // is android, or resume the camera if the platform is iOS.
  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller?.stop();
    }
    controller?.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          Expanded(
              flex: 4,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _buildQrView(context),
                  Positioned(
                    top: 250,
                    child: Text(
                      AppLocalizations.of(context)!.translate('CODE_SCAN'),
                      style: TextStyle(color: amarillo),
                    ),
                  ),
                  Positioned(
                    bottom: 200,
                    child: FloatingActionButton(
                      backgroundColor: amarillo,
                      child: Icon(
                        _flash ? Icons.flash_on : Icons.flash_off,
                        color: blanco,
                      ),
                      onPressed: () async {
                        await controller?.toggleTorch();
                        setState(() {
                          _flash = !_flash;
                        });
                      },
                    ),
                  ),
                  Positioned(
                    top: 50,
                    right: 20,
                    child: FloatingActionButton(
                      backgroundColor: transparente,
                      child: Icon(
                        Icons.cancel,
                        color: amarillo,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              )),
        ],
      ),
    );
  }

  Widget _buildQrView(BuildContext context) {
    // For this example we check how width or tall the device is and change the scanArea and overlay accordingly.
    var scanArea = (MediaQuery.of(context).size.width < 400 ||
            MediaQuery.of(context).size.height < 400)
        ? 150.0
        : 300.0;

    return Stack(
      children: [
        MobileScanner(
          key: qrKey,
          controller: controller,
          onDetect: _onDetect,
        ),
        // Custom overlay to match the original QrScannerOverlayShape design
        CustomPaint(
          painter: QrScannerOverlayPainter(
            borderColor: amarillo,
            borderRadius: 5,
            borderLength: 30,
            borderWidth: 5,
            cutOutSize: scanArea,
          ),
          child: Container(),
        ),
      ],
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_isScanning) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      _isScanning = false;
      final String? code = barcodes.first.rawValue;

      if (code != null) {
        controller!.stop();
        Navigator.pop(context, code);
        showToast(context, AppLocalizations.of(context)!.translate('WAIT'),
            verde.withOpacity(0.9), Icons.check);
      }
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}

// Custom painter to recreate the QrScannerOverlayShape appearance
class QrScannerOverlayPainter extends CustomPainter {
  final Color borderColor;
  final double borderRadius;
  final double borderLength;
  final double borderWidth;
  final double cutOutSize;

  QrScannerOverlayPainter({
    required this.borderColor,
    required this.borderRadius,
    required this.borderLength,
    required this.borderWidth,
    required this.cutOutSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    // Draw overlay background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Calculate cutout position (center)
    final cutOutLeft = (size.width - cutOutSize) / 2;
    final cutOutTop = (size.height - cutOutSize) / 2;
    final cutOutRect = Rect.fromLTWH(
      cutOutLeft,
      cutOutTop,
      cutOutSize,
      cutOutSize,
    );

    // Clear the cutout area
    final cutOutPaint = Paint()..blendMode = BlendMode.clear;
    canvas.drawRRect(
      RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)),
      cutOutPaint,
    );

    // Draw border corners
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    // Top-left corner
    canvas.drawLine(
      Offset(cutOutLeft, cutOutTop + borderLength),
      Offset(cutOutLeft, cutOutTop),
      borderPaint,
    );
    canvas.drawLine(
      Offset(cutOutLeft, cutOutTop),
      Offset(cutOutLeft + borderLength, cutOutTop),
      borderPaint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(cutOutLeft + cutOutSize - borderLength, cutOutTop),
      Offset(cutOutLeft + cutOutSize, cutOutTop),
      borderPaint,
    );
    canvas.drawLine(
      Offset(cutOutLeft + cutOutSize, cutOutTop),
      Offset(cutOutLeft + cutOutSize, cutOutTop + borderLength),
      borderPaint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(cutOutLeft, cutOutTop + cutOutSize - borderLength),
      Offset(cutOutLeft, cutOutTop + cutOutSize),
      borderPaint,
    );
    canvas.drawLine(
      Offset(cutOutLeft, cutOutTop + cutOutSize),
      Offset(cutOutLeft + borderLength, cutOutTop + cutOutSize),
      borderPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(cutOutLeft + cutOutSize - borderLength, cutOutTop + cutOutSize),
      Offset(cutOutLeft + cutOutSize, cutOutTop + cutOutSize),
      borderPaint,
    );
    canvas.drawLine(
      Offset(cutOutLeft + cutOutSize, cutOutTop + cutOutSize - borderLength),
      Offset(cutOutLeft + cutOutSize, cutOutTop + cutOutSize),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
