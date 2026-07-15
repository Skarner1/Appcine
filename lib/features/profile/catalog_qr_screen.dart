import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/content_item.dart';
import '../../providers/providers.dart';
import '../../shared/widgets/app_buttons.dart';
import '../../shared/widgets/app_dialog.dart';
import 'catalog_qr.dart';

/// Muestra el catálogo como QR para que otro móvil lo lea. Sin red, sin cables
/// y sin cuentas: dos pantallas mirándose.
class CatalogQrScreen extends ConsumerWidget {
  const CatalogQrScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(contentListProvider).value ?? const <ContentItem>[];
    final payload = buildCatalogQrPayload(items);

    return Scaffold(
      appBar: AppBar(title: const Text('Compartir por QR')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: payload.fits
              ? _QrView(data: payload.data!, count: items.length)
              : _TooBig(payload: payload, count: items.length),
        ),
      ),
    );
  }
}

class _QrView extends StatelessWidget {
  final String data;
  final int count;

  const _QrView({required this.data, required this.count});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                // El QR necesita fondo blanco para que cualquier cámara lo lea,
                // también en tema oscuro.
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: data,
                version: QrVersions.auto,
                size: 280,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.L,
              ),
            ),
          ),
        ),
        Text(
          '$count ${count == 1 ? 'título' : 'títulos'}',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Que lo escaneen desde Perfil → Escanear QR. No hace falta internet.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

/// El QR tiene un techo duro de 2953 bytes. Cuando no cabe hay que decirlo
/// claro y ofrecer una salida, no dar un código roto.
class _TooBig extends StatelessWidget {
  final QrPayload payload;
  final int count;

  const _TooBig({required this.payload, required this.count});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_2_outlined, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text(
            'Tu catálogo no cabe en un QR',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Son $count títulos y se pasa un ${payload.overflowPercent}% del máximo '
            'que admite el formato. Un QR aguanta unos 3 KB y no hay forma de '
            'estirarlo.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          SecondaryButton(
            label: 'Volver y compartir como texto',
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// Lee el QR de otro móvil con la cámara. Todo el reconocimiento ocurre en el
/// aparato: la imagen no sale de aquí.
class ScanCatalogQrScreen extends ConsumerStatefulWidget {
  const ScanCatalogQrScreen({super.key});

  @override
  ConsumerState<ScanCatalogQrScreen> createState() =>
      _ScanCatalogQrScreenState();
}

class _ScanCatalogQrScreenState extends ConsumerState<ScanCatalogQrScreen> {
  final _controller = MobileScannerController(
    formats: [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  /// La cámara dispara varias lecturas por segundo: sin esto se abrirían varios
  /// diálogos de confirmación encima del otro.
  bool _handling = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || !isCatalogQr(raw)) return;

    _handling = true;
    await _controller.stop();

    try {
      final items = parseCatalogQr(raw);
      if (!mounted) return;

      if (items.isEmpty) {
        await _fail('El QR no traía ningún título.');
        return;
      }

      final confirmed = await showAppConfirmDialog(
        context: context,
        title: 'Importar ${items.length} títulos',
        message:
            'Se agregarán a tu catálogo actual (los que tengan el mismo id se sobrescriben). ¿Continuar?',
        confirmLabel: 'Importar',
        icon: Icons.qr_code_scanner,
        accent: AppColors.secondary,
      );

      if (!confirmed) {
        _handling = false;
        await _controller.start();
        return;
      }

      await ref.read(contentRepositoryProvider).saveAll(items);
      if (!mounted) return;
      Navigator.of(context).pop(items.length);
    } on FormatException catch (e) {
      await _fail(e.message);
    } catch (_) {
      await _fail('No se pudo leer el catálogo.');
    }
  }

  /// Avisa del fallo y vuelve a escanear: el usuario sigue con el móvil en alto.
  Future<void> _fail(String message) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    _handling = false;
    await _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear QR')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _CameraError(error: error),
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary, width: 3),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Apunta al QR que muestra el otro móvil',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  final MobileScannerException error;

  const _CameraError({required this.error});

  @override
  Widget build(BuildContext context) {
    final denied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;

    return ColoredBox(
      color: AppColors.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                denied ? Icons.no_photography_outlined : Icons.error_outline,
                size: 56,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 16),
              Text(
                denied
                    ? 'CineLog necesita la cámara para leer el QR. Actívala en los ajustes del sistema.'
                    : 'No se pudo abrir la cámara.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
