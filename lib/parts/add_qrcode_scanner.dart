import 'package:flutter/material.dart';
import 'package:ai_barcode/ai_barcode.dart';

class AddQRScannerPage extends StatefulWidget {
  const AddQRScannerPage({Key? key}) : super(key: key);

  @override
  State<AddQRScannerPage> createState() => _AddQRScannerPageState();
}

class _AddQRScannerPageState extends State<AddQRScannerPage> {
  String _code = '';
  ScannerController? _scannerController;

  @override
  void initState() {
    super.initState();
    _scannerController = ScannerController(scannerResult: (result) {
      setState(() {
        _code = result;
      });
    }, scannerViewCreated: () {
      TargetPlatform platform = Theme.of(context).platform;
      if (platform == TargetPlatform.android) {
        _scannerController?.startCamera();
        _scannerController?.startCameraPreview();
      } else if (platform == TargetPlatform.iOS) {
        _scannerController?.startCamera();
      }
    });
  }

  @override
  void dispose() {
    _scannerController?.stopCamera();
    _scannerController?.stopCameraPreview();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QRコードスキャン'),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 5,
            child: PlatformAiBarcodeScannerWidget(
              platformScannerController: _scannerController!,
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: _code.isNotEmpty
                  ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'QRコード: $_code',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(_code);
                    },
                    child: const Text('このQRコードを使用'),
                  ),
                ],
              )
                  : const Text('QRコードをスキャンしてください'),
            ),
          )
        ],
      ),
    );
  }
}