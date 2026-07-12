import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'core/firebase/firebase_emulators.dart';
import 'core/theme/admin_theme.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await connectFirebaseEmulators();

  runApp(const CrimeReportAdminApp());
}

class CrimeReportAdminApp extends StatelessWidget {
  const CrimeReportAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Crime and Emergency Report Admin',
      debugShowCheckedModeBanner: false,
      theme: AdminTheme.dark(),
      home: const AdminLocationDashboard(),
    );
  }
}

class AdminLocationDashboard extends StatelessWidget {
  const AdminLocationDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Location map',
            onPressed: () {},
            icon: const Icon(Icons.map_outlined),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('reports').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _AdminMessage(
              icon: Icons.lock_outline,
              title: 'Reports unavailable',
              message:
                  'Confirm this admin user has claim-based access and Firestore rules are deployed.',
            );
          }

          final reports = snapshot.data?.docs
                  .map(AdminReportLocation.fromDoc)
                  .where((report) => report.hasLocation)
                  .toList() ??
              <AdminReportLocation>[];

          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
            children: [
              const Text(
                'Report Locations',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'Map display for submitted reports with GPS or GhanaPostGPS data.',
                style: TextStyle(color: AdminTheme.textMuted),
              ),
              const SizedBox(height: 24),
              _AdminMapPanel(reports: reports),
              const SizedBox(height: 24),
              if (reports.isEmpty)
                const _AdminMessage(
                  icon: Icons.location_off_outlined,
                  title: 'No report locations yet',
                  message:
                      'Locations will appear here after mobile reports sync to Firestore.',
                )
              else
                ...reports.map((report) => _AdminReportLocationTile(report)),
            ],
          );
        },
      ),
    );
  }
}

class AdminReportLocation {
  const AdminReportLocation({
    required this.id,
    required this.category,
    required this.status,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.ghanaPostGps,
  });

  final String id;
  final String category;
  final String status;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final String? ghanaPostGps;

  bool get hasCoordinates => latitude != null && longitude != null;

  bool get hasLocation =>
      hasCoordinates || (ghanaPostGps != null && ghanaPostGps!.isNotEmpty);

  factory AdminReportLocation.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final location = data['location'] as Map<String, dynamic>?;

    return AdminReportLocation(
      id: doc.id,
      category: data['category'] as String? ?? 'Uncategorized',
      status: data['status'] as String? ?? 'unknown',
      latitude: (location?['latitude'] as num?)?.toDouble(),
      longitude: (location?['longitude'] as num?)?.toDouble(),
      accuracyMeters: (location?['accuracyMeters'] as num?)?.toDouble(),
      ghanaPostGps: location?['ghanaPostGps'] as String?,
    );
  }
}

class _AdminMapPanel extends StatelessWidget {
  const _AdminMapPanel({required this.reports});

  final List<AdminReportLocation> reports;

  @override
  Widget build(BuildContext context) {
    final coordinateCount = reports
        .where((report) => report.hasCoordinates)
        .length;

    return Container(
      height: 220,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AdminTheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF222D44)),
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFF0D1424),
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.map_outlined,
                  color: AdminTheme.cyan,
                  size: 42,
                ),
                const SizedBox(height: 12),
                Text(
                  '$coordinateCount GPS reports mapped',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Static preview until production map keys are configured.',
                  style: TextStyle(color: AdminTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminReportLocationTile extends StatelessWidget {
  const _AdminReportLocationTile(this.report);

  final AdminReportLocation report;

  @override
  Widget build(BuildContext context) {
    final coordinateText = report.hasCoordinates
        ? '${report.latitude!.toStringAsFixed(5)}, '
            '${report.longitude!.toStringAsFixed(5)}'
        : 'No GPS coordinates';
    final accuracyText = report.accuracyMeters == null
        ? null
        : 'Accuracy +/-${report.accuracyMeters!.round()}m';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AdminTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF222D44)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.location_on_outlined, color: AdminTheme.primaryRed),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.category,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  coordinateText,
                  style: const TextStyle(color: AdminTheme.textMuted),
                ),
                if (accuracyText != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    accuracyText,
                    style: const TextStyle(color: AdminTheme.textMuted),
                  ),
                ],
                if (report.ghanaPostGps != null &&
                    report.ghanaPostGps!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    report.ghanaPostGps!,
                    style: const TextStyle(color: AdminTheme.textMuted),
                  ),
                ],
              ],
            ),
          ),
          Chip(label: Text(report.status)),
        ],
      ),
    );
  }
}

class _AdminMessage extends StatelessWidget {
  const _AdminMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AdminTheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF222D44)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AdminTheme.textMuted, size: 44),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AdminTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
