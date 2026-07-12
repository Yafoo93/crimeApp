import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/safe_alert_button.dart';
import '../data/local_report_store.dart';
import '../domain/local_report.dart';
import 'report_flow_widgets.dart';
import 'report_preview_screen.dart';

class ReportEvidenceScreen extends StatefulWidget {
  const ReportEvidenceScreen({
    super.key,
    required this.report,
  });

  final LocalReport report;

  @override
  State<ReportEvidenceScreen> createState() => _ReportEvidenceScreenState();
}

class _ReportEvidenceScreenState extends State<ReportEvidenceScreen> {
  static const _maxImageBytes = 10 * 1024 * 1024;
  static const _maxImageCount = 5;
  static const _maxVoiceSeconds = 60;

  final _picker = ImagePicker();
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();

  late LocalReport _report;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  bool _isRecording = false;
  bool _isPlaying = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;

  @override
  void initState() {
    super.initState();
    _report = widget.report;
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state.playing);
    });
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    unawaited(_playerStateSubscription?.cancel());
    unawaited(_recorder.dispose());
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_report.images.length >= _maxImageCount) {
      _showMessage('You can attach up to $_maxImageCount images.');
      return;
    }

    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked == null) return;

    final file = File(picked.path);
    final sizeBytes = await file.length();
    final mimeType = picked.mimeType ?? _mimeTypeFromPath(picked.path);

    if (!_isAllowedImageType(mimeType)) {
      _showMessage('Use JPG, PNG, HEIC, or WebP images only.');
      return;
    }

    if (sizeBytes > _maxImageBytes) {
      _showMessage('Image must be 10 MB or smaller.');
      return;
    }

    final evidenceDir = await _ensureEvidenceDir('images');
    final extension = _extensionForMimeType(mimeType);
    final copiedPath =
        '${evidenceDir.path}/${DateTime.now().microsecondsSinceEpoch}.$extension';
    await file.copy(copiedPath);

    final image = LocalImageEvidence(
      path: copiedPath,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      createdAt: DateTime.now().toUtc(),
    );
    final updated = await LocalReportStore().addImageEvidence(
      report: _report,
      image: image,
    );

    if (!mounted) return;
    setState(() => _report = updated);
  }

  Future<void> _removeImage(LocalImageEvidence image) async {
    final updated = await LocalReportStore().removeImageEvidence(
      report: _report,
      image: image,
    );
    await _deleteFileIfExists(image.path);

    if (!mounted) return;
    setState(() => _report = updated);
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
      return;
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _showMessage('Microphone permission is required to record a voice note.');
      return;
    }

    await _deleteVoiceFile();
    final evidenceDir = await _ensureEvidenceDir('voice');
    final voicePath =
        '${evidenceDir.path}/${DateTime.now().microsecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: voicePath,
    );

    setState(() {
      _isRecording = true;
      _recordingSeconds = 0;
    });

    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      final next = _recordingSeconds + 1;
      setState(() => _recordingSeconds = next);
      if (next >= _maxVoiceSeconds) {
        await _stopRecording();
      }
    });
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    final path = await _recorder.stop();
    if (path == null) {
      if (mounted) setState(() => _isRecording = false);
      return;
    }

    final durationSeconds =
        _recordingSeconds.clamp(1, _maxVoiceSeconds).toInt();
    final voice = LocalVoiceEvidence(
      path: path,
      durationSeconds: durationSeconds,
      createdAt: DateTime.now().toUtc(),
    );
    final updated = await LocalReportStore().saveVoiceEvidence(
      report: _report,
      voiceNote: voice,
    );

    if (!mounted) return;
    setState(() {
      _report = updated;
      _isRecording = false;
      _recordingSeconds = durationSeconds;
    });
  }

  Future<void> _togglePlayback() async {
    final voice = _report.voiceNote;
    if (voice == null) return;

    if (_player.playing) {
      await _player.stop();
      return;
    }

    await _player.setFilePath(voice.path);
    await _player.play();
  }

  Future<void> _deleteVoiceNote() async {
    await _player.stop();
    await _deleteVoiceFile();
    final updated = await LocalReportStore().clearVoiceEvidence(_report);

    if (!mounted) return;
    setState(() {
      _report = updated;
      _recordingSeconds = 0;
      _isPlaying = false;
    });
  }

  Future<void> _deleteVoiceFile() async {
    final voice = _report.voiceNote;
    if (voice == null) return;
    await _deleteFileIfExists(voice.path);
  }

  Future<void> _deleteFileIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<Directory> _ensureEvidenceDir(String child) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/reports/${_report.id}/$child');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  void _continue() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportPreviewScreen(report: _report),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ReportFlowScaffold(
      title: 'Evidence',
      subtitle:
          'Attach photos and an optional voice note. Files are saved locally first and uploads happen later.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SafeAlertButton(
                  label: 'CAMERA',
                  icon: Icons.camera_alt_outlined,
                  secondary: true,
                  onPressed: () => _pickImage(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SafeAlertButton(
                  label: 'GALLERY',
                  icon: Icons.photo_library_outlined,
                  secondary: true,
                  onPressed: () => _pickImage(ImageSource.gallery),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Images only for MVP. Video capture/upload is deferred.',
            style: TextStyle(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 18),
          _ImageEvidenceList(
            images: _report.images,
            onDelete: _removeImage,
          ),
          const SizedBox(height: 24),
          _VoiceEvidenceCard(
            isRecording: _isRecording,
            isPlaying: _isPlaying,
            recordingSeconds: _recordingSeconds,
            maxVoiceSeconds: _maxVoiceSeconds,
            voiceNote: _report.voiceNote,
            onRecord: _toggleRecording,
            onPlay: _togglePlayback,
            onDelete: _deleteVoiceNote,
          ),
          const SizedBox(height: 24),
          SafeAlertButton(
            label: 'PREVIEW REPORT',
            icon: Icons.article_outlined,
            onPressed: _continue,
          ),
        ],
      ),
    );
  }
}

class _ImageEvidenceList extends StatelessWidget {
  const _ImageEvidenceList({
    required this.images,
    required this.onDelete,
  });

  final List<LocalImageEvidence> images;
  final ValueChanged<LocalImageEvidence> onDelete;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return const _EvidenceEmptyCard(
        icon: Icons.image_outlined,
        text: 'No images attached yet.',
      );
    }

    return Column(
      children: images
          .map(
            (image) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF222D44)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(
                      File(image.path),
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Image evidence',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${image.mimeType} - ${_formatBytes(image.sizeBytes)}',
                          style: const TextStyle(color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete image',
                    onPressed: () => onDelete(image),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _VoiceEvidenceCard extends StatelessWidget {
  const _VoiceEvidenceCard({
    required this.isRecording,
    required this.isPlaying,
    required this.recordingSeconds,
    required this.maxVoiceSeconds,
    required this.voiceNote,
    required this.onRecord,
    required this.onPlay,
    required this.onDelete,
  });

  final bool isRecording;
  final bool isPlaying;
  final int recordingSeconds;
  final int maxVoiceSeconds;
  final LocalVoiceEvidence? voiceNote;
  final VoidCallback onRecord;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final hasVoice = voiceNote != null;
    final seconds = isRecording
        ? recordingSeconds
        : hasVoice
            ? voiceNote!.durationSeconds
            : 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF222D44)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isRecording ? Icons.mic : Icons.mic_none_rounded,
                color: isRecording ? AppTheme.primaryRed : AppTheme.cyan,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasVoice || isRecording ? 'Voice note' : 'Optional voice note',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${seconds}s / ${maxVoiceSeconds}s',
                style: const TextStyle(color: AppTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SafeAlertButton(
            label: isRecording
                ? 'STOP RECORDING'
                : hasVoice
                    ? 'RE-RECORD'
                    : 'RECORD VOICE',
            icon: isRecording ? Icons.stop_circle_outlined : Icons.mic,
            secondary: !isRecording,
            onPressed: onRecord,
          ),
          if (hasVoice && !isRecording) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPlay,
                    icon: Icon(
                      isPlaying
                          ? Icons.stop_circle_outlined
                          : Icons.play_arrow_rounded,
                    ),
                    label: Text(isPlaying ? 'Stop' : 'Play'),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  tooltip: 'Delete voice note',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EvidenceEmptyCard extends StatelessWidget {
  const _EvidenceEmptyCard({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF222D44)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textMuted),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}

String _mimeTypeFromPath(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'application/octet-stream';
}

bool _isAllowedImageType(String mimeType) {
  return const {
    'image/jpeg',
    'image/png',
    'image/heic',
    'image/heif',
    'image/webp',
  }.contains(mimeType);
}

String _extensionForMimeType(String mimeType) {
  switch (mimeType) {
    case 'image/png':
      return 'png';
    case 'image/heic':
    case 'image/heif':
      return 'heic';
    case 'image/webp':
      return 'webp';
    case 'image/jpeg':
    default:
      return 'jpg';
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  return '${(kb / 1024).toStringAsFixed(1)} MB';
}
