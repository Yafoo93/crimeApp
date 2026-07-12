import 'package:flutter/material.dart';

import '../../../core/services/location_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/safe_alert_button.dart';
import '../data/local_report_store.dart';
import '../domain/local_report.dart';
import 'report_evidence_screen.dart';
import 'report_flow_widgets.dart';

class ReportLocationScreen extends StatefulWidget {
  const ReportLocationScreen({
    super.key,
    required this.report,
  });

  final LocalReport report;

  @override
  State<ReportLocationScreen> createState() => _ReportLocationScreenState();
}

class _ReportLocationScreenState extends State<ReportLocationScreen> {
  final _locationService = LocationService();
  final _ghanaPostController = TextEditingController();

  late LocalReportLocation _location;
  bool _isLocating = false;
  bool _isSaving = false;
  String? _statusMessage;
  LocationCaptureStatus? _lastFailure;

  @override
  void initState() {
    super.initState();
    _location = widget.report.location;
    _ghanaPostController.text = _location.ghanaPostGps ?? '';
  }

  @override
  void dispose() {
    _ghanaPostController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isLocating = true;
      _statusMessage = null;
      _lastFailure = null;
    });

    final result = await _locationService.captureCurrentLocation();

    if (!mounted) return;

    setState(() {
      _isLocating = false;
      if (result.isSuccess) {
        final position = result.position!;
        _location = _location.copyWith(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracyMeters: position.accuracy,
        );
        _statusMessage =
            'Location captured (+/-${position.accuracy.round()}m accuracy).';
      } else {
        _lastFailure = result.status;
        _statusMessage = result.message;
      }
    });
  }

  void _onGhanaPostChanged(String value) {
    _location = _location.copyWith(ghanaPostGps: _normalizeGhanaPostGps(value));
    setState(() {});
  }

  Future<void> _continue() async {
    final ghanaPostGps = _location.ghanaPostGps ?? '';
    if (ghanaPostGps.isNotEmpty && !_isValidGhanaPostGps(ghanaPostGps)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid GhanaPostGPS address, e.g. GA-183-9090.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final updated = await LocalReportStore().updateLocation(
      report: widget.report,
      location: _location,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportEvidenceScreen(report: updated),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ghanaPostGps = _location.ghanaPostGps ?? '';
    final hasManualAddress = ghanaPostGps.isNotEmpty;
    final isManualAddressValid =
        !hasManualAddress || _isValidGhanaPostGps(ghanaPostGps);
    final canContinue =
        _location.hasCoordinates || (hasManualAddress && isManualAddressValid);

    return ReportFlowScaffold(
      title: 'Location',
      subtitle:
          'Share your GPS position or enter a GhanaPostGPS address so responders can find the incident.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeAlertButton(
            label: 'USE CURRENT LOCATION',
            icon: Icons.my_location_rounded,
            isLoading: _isLocating,
            secondary: _location.hasCoordinates,
            onPressed: _useCurrentLocation,
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _statusMessage!,
              style: TextStyle(
                color: _location.hasCoordinates
                    ? AppTheme.green
                    : AppTheme.amber,
                height: 1.4,
              ),
            ),
          ],
          if (_lastFailure == LocationCaptureStatus.permissionDeniedForever ||
              _lastFailure == LocationCaptureStatus.serviceDisabled) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _lastFailure == LocationCaptureStatus.serviceDisabled
                  ? _locationService.openLocationSettings
                  : _locationService.openAppSettings,
              child: const Text('Open settings'),
            ),
          ],
          const SizedBox(height: 20),
          _MapPreview(location: _location),
          const SizedBox(height: 24),
          const Text(
            'GhanaPostGPS address',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ghanaPostController,
            textCapitalization: TextCapitalization.characters,
            onChanged: _onGhanaPostChanged,
            decoration: InputDecoration(
              hintText: 'e.g. GA-183-9090',
              errorText: hasManualAddress && !isManualAddressValid
                  ? 'Use format GA-183-9090'
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Use this as a fallback or addition if GPS is unavailable or inaccurate.',
            style: TextStyle(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 24),
          SafeAlertButton(
            label: 'PREVIEW REPORT',
            icon: Icons.article_outlined,
            isLoading: _isSaving,
            onPressed: canContinue ? _continue : null,
          ),
          if (!canContinue) ...[
            const SizedBox(height: 12),
            const Text(
              'Capture your location or enter a GhanaPostGPS address to continue.',
              style: TextStyle(color: AppTheme.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview({required this.location});

  final LocalReportLocation location;

  @override
  Widget build(BuildContext context) {
    if (!location.hasCoordinates) {
      return Container(
        height: 160,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF222D44)),
        ),
        child: const Text(
          'Map preview appears once a location is captured.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textMuted),
        ),
      );
    }

    // A live GoogleMap tile preview can replace this once a Google Maps API
    // key is configured for Android/iOS (google_maps_flutter is already a
    // dependency). Without a key the native SDK throws at runtime, so a
    // static preview is used until that setup step is done.
    return Container(
      height: 160,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF222D44)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.location_on_rounded, color: AppTheme.primaryRed, size: 36),
          const SizedBox(height: 10),
          Text(
            '${location.latitude!.toStringAsFixed(5)}, '
            '${location.longitude!.toStringAsFixed(5)}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          if (location.accuracyMeters != null) ...[
            const SizedBox(height: 4),
            Text(
              'Accuracy +/-${location.accuracyMeters!.round()}m',
              style: const TextStyle(color: AppTheme.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

String _normalizeGhanaPostGps(String value) {
  return value.trim().toUpperCase().replaceAll(' ', '');
}

bool _isValidGhanaPostGps(String value) {
  return RegExp(r'^[A-Z]{2}-\d{3,4}-\d{3,4}$').hasMatch(value);
}
