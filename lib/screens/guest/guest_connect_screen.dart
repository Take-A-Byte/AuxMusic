import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme/app_theme.dart';
import '../../models/session.dart';
import '../../providers/session_provider.dart';
import 'guest_controller_screen.dart';

class GuestConnectScreen extends ConsumerStatefulWidget {
  const GuestConnectScreen({super.key});

  @override
  ConsumerState<GuestConnectScreen> createState() => _GuestConnectScreenState();
}

class _GuestConnectScreenState extends ConsumerState<GuestConnectScreen> {
  final _nameController = TextEditingController(text: 'Guest');
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '3000');
  final _scannerController = MobileScannerController();

  bool _showScanner = true;
  bool _isConnecting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _ipController.dispose();
    _portController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join a Party'),
        actions: [
          TextButton(
            onPressed: () => setState(() => _showScanner = !_showScanner),
            child: Text(_showScanner ? 'Manual' : 'Scan QR'),
          ),
        ],
      ),
      body: SafeArea(
        child: _showScanner ? _buildScannerView() : _buildManualView(),
      ),
    );
  }

  Widget _buildScannerView() {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Stack(
            children: [
              MobileScanner(
                controller: _scannerController,
                onDetect: _onQRDetected,
              ),
              // Overlay with cutout
              CustomPaint(
                size: Size.infinite,
                painter: _ScannerOverlayPainter(),
              ),
              // Instructions
              const Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Text(
                  'Scan QR code from host device',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Name input
        Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Your name',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'Enter your name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ],
              if (_isConnecting) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(color: AppColors.primary),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManualView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Icon
          Container(
            width: 80,
            height: 80,
            margin: const EdgeInsets.only(bottom: 32),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.wifi,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          // Name Input
          const Text(
            'Your name',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: 'Enter your name',
              prefixIcon: Icon(Icons.person_outline),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 24),
          // IP Input
          const Text(
            'Host IP address',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ipController,
            decoration: const InputDecoration(
              hintText: '192.168.1.100',
              prefixIcon: Icon(Icons.dns_outlined),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          // Port Input
          const Text(
            'Port',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _portController,
            decoration: const InputDecoration(
              hintText: '3000',
              prefixIcon: Icon(Icons.numbers),
            ),
            keyboardType: TextInputType.number,
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ),
          ],
          const SizedBox(height: 32),
          // Connect Button
          ElevatedButton(
            onPressed: _isConnecting ? null : _connectManually,
            child: _isConnecting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Connect'),
          ),
        ],
      ),
    );
  }

  void _onQRDetected(BarcodeCapture capture) {
    if (_isConnecting) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    final session = Session.fromQrData(barcode!.rawValue!);
    if (session != null) {
      _connectToSession(session);
    } else {
      setState(() => _error = 'Invalid QR code');
    }
  }

  Future<void> _connectManually() async {
    final name = _nameController.text.trim();
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 3000;

    if (name.isEmpty) {
      setState(() => _error = 'Please enter your name');
      return;
    }
    if (ip.isEmpty) {
      setState(() => _error = 'Please enter host IP address');
      return;
    }

    final session = Session(
      id: '',
      hostId: '',
      hostName: 'Host',
      serverIp: ip,
      serverPort: port,
      createdAt: DateTime.now(),
    );

    await _connectToSession(session);
  }

  Future<void> _connectToSession(Session session) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your name');
      return;
    }

    setState(() {
      _isConnecting = true;
      _error = null;
    });

    try {
      await ref.read(sessionProvider.notifier).joinSession(session, name);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const GuestControllerScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _error = 'Failed to connect: ${e.toString()}';
        });
      }
    }
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black54;
    final cutoutSize = size.width * 0.7;
    final left = (size.width - cutoutSize) / 2;
    final top = (size.height - cutoutSize) / 2;
    final cutout = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, cutoutSize, cutoutSize),
      const Radius.circular(16),
    );

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(cutout),
      ),
      paint,
    );

    // Draw corner brackets
    final bracketPaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    const bracketLength = 30.0;
    final corners = [
      Offset(left, top),
      Offset(left + cutoutSize, top),
      Offset(left, top + cutoutSize),
      Offset(left + cutoutSize, top + cutoutSize),
    ];

    for (var i = 0; i < corners.length; i++) {
      final corner = corners[i];
      final path = Path();

      if (i == 0) {
        path.moveTo(corner.dx, corner.dy + bracketLength);
        path.lineTo(corner.dx, corner.dy);
        path.lineTo(corner.dx + bracketLength, corner.dy);
      } else if (i == 1) {
        path.moveTo(corner.dx - bracketLength, corner.dy);
        path.lineTo(corner.dx, corner.dy);
        path.lineTo(corner.dx, corner.dy + bracketLength);
      } else if (i == 2) {
        path.moveTo(corner.dx, corner.dy - bracketLength);
        path.lineTo(corner.dx, corner.dy);
        path.lineTo(corner.dx + bracketLength, corner.dy);
      } else {
        path.moveTo(corner.dx - bracketLength, corner.dy);
        path.lineTo(corner.dx, corner.dy);
        path.lineTo(corner.dx, corner.dy - bracketLength);
      }

      canvas.drawPath(path, bracketPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
