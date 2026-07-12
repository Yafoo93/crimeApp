import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';

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
      home: const AdminAuthGate(),
    );
  }
}

class AdminAuthGate extends StatefulWidget {
  const AdminAuthGate({super.key});

  @override
  State<AdminAuthGate> createState() => _AdminAuthGateState();
}

class _AdminAuthGateState extends State<AdminAuthGate> {
  int _claimRefreshVersion = 0;

  void _refreshClaimCheck() {
    setState(() => _claimRefreshVersion++);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const AdminLoginScreen();
        }

        return FutureBuilder<IdTokenResult>(
          key: ValueKey(_claimRefreshVersion),
          future: user.getIdTokenResult(true),
          builder: (context, tokenSnapshot) {
            if (tokenSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final claims = tokenSnapshot.data?.claims ?? <String, dynamic>{};
            final role = claims['role'];
            final isAdmin = role == 'admin' || role == 'superAdmin';
            if (!isAdmin) {
              return _MissingAdminClaimScreen(
                user: user,
                onRefresh: _refreshClaimCheck,
              );
            }

            return const AdminDashboardScreen();
          },
        );
      },
    );
  }
}

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;
  static const _useEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on FirebaseAuthException catch (error) {
      setState(() => _error = error.message ?? 'Sign in failed.');
    } catch (_) {
      setState(() => _error = 'Sign in failed.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _createEmulatorAccount() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } on FirebaseAuthException catch (error) {
      setState(() => _error = error.message ?? 'Account creation failed.');
    } catch (_) {
      setState(() => _error = 'Account creation failed.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(28),
            decoration: _panelDecoration(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.admin_panel_settings_outlined,
                  color: AdminTheme.primaryRed,
                  size: 48,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Admin Sign In',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use an account with admin or superAdmin claims.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AdminTheme.textMuted),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  onSubmitted: (_) => _signIn(),
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    style: const TextStyle(color: AdminTheme.primaryRed),
                  ),
                ],
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: _isSubmitting ? null : _signIn,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Sign In'),
                ),
                if (_useEmulators) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : _createEmulatorAccount,
                    child: const Text('Create emulator test account'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MissingAdminClaimScreen extends StatelessWidget {
  const _MissingAdminClaimScreen({
    required this.user,
    required this.onRefresh,
  });

  final User user;
  final VoidCallback onRefresh;
  static const _useEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');

  Future<void> _refreshClaims() async {
    await user.getIdToken(true);
    onRefresh();
  }

  Future<void> _bootstrapEmulatorAdmin(BuildContext context) async {
    try {
      await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('bootstrapEmulatorSuperAdmin')
          .call();
      await _refreshClaims();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Emulator superAdmin claim granted.')),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Bootstrap failed.')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bootstrap failed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: _AdminMessage(
            icon: Icons.lock_outline,
            title: 'Admin access required',
            message:
                '${user.email ?? user.uid} is signed in, but this account does not have an admin claim yet.',
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(24),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            if (_useEmulators)
              FilledButton(
                onPressed: () => _bootstrapEmulatorAdmin(context),
                child: const Text('Grant emulator superAdmin'),
              ),
            OutlinedButton(
              onPressed: _refreshClaims,
              child: const Text('Refresh claims'),
            ),
            FilledButton(
              onPressed: () => FirebaseAuth.instance.signOut(),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}

enum AdminDateFilter {
  all('All dates'),
  today('Today'),
  sevenDays('Last 7 days');

  const AdminDateFilter(this.label);
  final String label;
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _statusFilter = 'all';
  String _urgencyFilter = 'all';
  String _categoryFilter = 'all';
  AdminDateFilter _dateFilter = AdminDateFilter.all;
  String? _selectedReportId;
  final Set<String> _alertedUrgentReports = <String>{};

  Stream<QuerySnapshot<Map<String, dynamic>>> get _reportsStream {
    return FirebaseFirestore.instance
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  List<AdminReport> _applyFilters(List<AdminReport> reports) {
    final now = DateTime.now();
    return reports.where((report) {
      if (_statusFilter != 'all' && report.status != _statusFilter) {
        return false;
      }
      if (_urgencyFilter != 'all' && report.urgency != _urgencyFilter) {
        return false;
      }
      if (_categoryFilter != 'all' && report.categoryLabel != _categoryFilter) {
        return false;
      }
      if (_dateFilter == AdminDateFilter.today) {
        if (report.createdAt == null) return false;
        return _sameDay(report.createdAt!, now);
      }
      if (_dateFilter == AdminDateFilter.sevenDays) {
        if (report.createdAt == null) return false;
        return report.createdAt!.isAfter(now.subtract(const Duration(days: 7)));
      }
      return true;
    }).toList();
  }

  void _alertForUrgentReports(List<AdminReport> reports) {
    final urgentReports = reports.where(
      (report) => report.isUrgent && !report.isClosed,
    );
    final newUrgentReports = urgentReports
        .where((report) => !_alertedUrgentReports.contains(report.id))
        .toList();

    if (newUrgentReports.isEmpty) return;

    _alertedUrgentReports.addAll(newUrgentReports.map((report) => report.id));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SystemSound.play(SystemSoundType.alert);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AdminTheme.primaryRed,
          content: Text(
            '${newUrgentReports.length} urgent report${newUrgentReports.length == 1 ? '' : 's'} need review.',
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _reportsStream,
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

          final reports = snapshot.data?.docs.map(AdminReport.fromDoc).toList() ??
              <AdminReport>[];
          _alertForUrgentReports(reports);

          final filteredReports = _applyFilters(reports);
          final categories = reports
              .map((report) => report.categoryLabel)
              .where((category) => category.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
          final selectedReport = _selectedReportId == null
              ? (filteredReports.isEmpty ? null : filteredReports.first)
              : reports
                  .where((report) => report.id == _selectedReportId)
                  .cast<AdminReport?>()
                  .firstOrNull;

          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1100;
              return ListView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
                children: [
                  _DashboardHeader(totalReports: reports.length),
                  const SizedBox(height: 18),
                  _UrgentAlertBanner(reports: reports),
                  const SizedBox(height: 18),
                  _SummaryGrid(reports: reports),
                  const SizedBox(height: 18),
                  _FilterBar(
                    status: _statusFilter,
                    urgency: _urgencyFilter,
                    category: _categoryFilter,
                    dateFilter: _dateFilter,
                    categories: categories,
                    onStatusChanged: (value) {
                      setState(() => _statusFilter = value);
                    },
                    onUrgencyChanged: (value) {
                      setState(() => _urgencyFilter = value);
                    },
                    onCategoryChanged: (value) {
                      setState(() => _categoryFilter = value);
                    },
                    onDateChanged: (value) {
                      setState(() => _dateFilter = value);
                    },
                  ),
                  const SizedBox(height: 18),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: _ReportListPanel(
                            reports: filteredReports,
                            selectedReportId: selectedReport?.id,
                            onSelect: (report) {
                              setState(() => _selectedReportId = report.id);
                            },
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          flex: 7,
                          child: _ReportDetailPanel(report: selectedReport),
                        ),
                      ],
                    )
                  else ...[
                    _ReportListPanel(
                      reports: filteredReports,
                      selectedReportId: selectedReport?.id,
                      onSelect: (report) {
                        setState(() => _selectedReportId = report.id);
                      },
                    ),
                    const SizedBox(height: 18),
                    _ReportDetailPanel(report: selectedReport),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class AdminReport {
  const AdminReport({
    required this.id,
    required this.reporterId,
    required this.reporterDisplayName,
    required this.anonymous,
    required this.categoryLabel,
    required this.urgency,
    required this.description,
    required this.status,
    required this.spamFlagged,
    required this.location,
    required this.media,
    required this.adminNotesCount,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String reporterId;
  final String reporterDisplayName;
  final bool anonymous;
  final String categoryLabel;
  final String urgency;
  final String description;
  final String status;
  final bool spamFlagged;
  final AdminReportLocation location;
  final List<AdminEvidence> media;
  final int adminNotesCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isUrgent => urgency == 'urgent' || urgency == 'critical';

  bool get isClosed => status == 'resolved' || status == 'closed';

  bool get hasLocation => location.hasLocation;

  factory AdminReport.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final media = data['media'] as List<dynamic>? ?? <dynamic>[];
    final categoryLabel =
        data['categoryLabel'] as String? ?? data['category'] as String?;

    return AdminReport(
      id: doc.id,
      reporterId: data['reporterId'] as String? ?? '',
      reporterDisplayName:
          data['reporterDisplayName'] as String? ?? 'Unknown reporter',
      anonymous: data['anonymous'] as bool? ?? false,
      categoryLabel: categoryLabel ?? 'Uncategorized',
      urgency: data['urgency'] as String? ?? 'normal',
      description: data['description'] as String? ?? '',
      status: data['status'] as String? ?? 'unknown',
      spamFlagged: data['spamFlagged'] as bool? ?? false,
      location: AdminReportLocation.fromMap(
        data['location'] as Map<String, dynamic>?,
      ),
      media: media
          .whereType<Map<dynamic, dynamic>>()
          .map(AdminEvidence.fromMap)
          .toList(),
      adminNotesCount: (data['adminNotesCount'] as num?)?.toInt() ?? 0,
      createdAt: _dateFromFirestore(data['createdAt']),
      updatedAt: _dateFromFirestore(data['updatedAt']),
    );
  }
}

class AdminReportLocation {
  const AdminReportLocation({
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.ghanaPostGps,
  });

  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final String? ghanaPostGps;

  bool get hasCoordinates => latitude != null && longitude != null;

  bool get hasLocation =>
      hasCoordinates || (ghanaPostGps != null && ghanaPostGps!.isNotEmpty);

  factory AdminReportLocation.fromMap(Map<String, dynamic>? data) {
    return AdminReportLocation(
      latitude: (data?['latitude'] as num?)?.toDouble(),
      longitude: (data?['longitude'] as num?)?.toDouble(),
      accuracyMeters: (data?['accuracyMeters'] as num?)?.toDouble(),
      ghanaPostGps: data?['ghanaPostGps'] as String?,
    );
  }
}

class AdminEvidence {
  const AdminEvidence({
    required this.id,
    required this.type,
    required this.storagePath,
    required this.contentType,
    required this.sizeBytes,
    this.durationSeconds,
  });

  final String id;
  final String type;
  final String storagePath;
  final String contentType;
  final int sizeBytes;
  final int? durationSeconds;

  bool get isImage => type == 'image' || contentType.startsWith('image/');

  bool get isVoice =>
      type == 'voice' ||
      contentType.startsWith('audio/') ||
      storagePath.toLowerCase().endsWith('.m4a');

  factory AdminEvidence.fromMap(Map<dynamic, dynamic> map) {
    return AdminEvidence(
      id: map['id'] as String? ?? map['storagePath'] as String? ?? '',
      type: map['type'] as String? ?? 'file',
      storagePath: map['storagePath'] as String? ?? '',
      contentType: map['contentType'] as String? ?? 'application/octet-stream',
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
      durationSeconds: (map['durationSeconds'] as num?)?.toInt(),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.totalReports});

  final int totalReports;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Operations Dashboard',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              '$totalReports reports synced from Firestore',
              style: const TextStyle(color: AdminTheme.textMuted),
            ),
          ],
        ),
        FilledButton.icon(
          onPressed: () => FirebaseAuth.instance.signOut(),
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
        ),
      ],
    );
  }
}

class _UrgentAlertBanner extends StatelessWidget {
  const _UrgentAlertBanner({required this.reports});

  final List<AdminReport> reports;

  @override
  Widget build(BuildContext context) {
    final urgentCount = reports
        .where((report) => report.isUrgent && !report.isClosed)
        .length;
    if (urgentCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF321018),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminTheme.primaryRed),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active, color: AdminTheme.primaryRed),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$urgentCount urgent report${urgentCount == 1 ? '' : 's'} require immediate admin review.',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.reports});

  final List<AdminReport> reports;

  @override
  Widget build(BuildContext context) {
    final pending = reports
        .where((report) =>
            report.status == 'submitted' ||
            report.status == 'pendingUpload' ||
            report.status == 'uploading')
        .length;
    final urgent = reports.where((report) => report.isUrgent).length;
    final resolved = reports
        .where((report) => report.status == 'resolved' || report.status == 'closed')
        .length;

    return GridView.count(
      crossAxisCount: MediaQuery.sizeOf(context).width >= 900 ? 4 : 2,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      shrinkWrap: true,
      childAspectRatio: 2.7,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _SummaryCard(
          icon: Icons.description_outlined,
          label: 'Total',
          value: reports.length.toString(),
          color: AdminTheme.cyan,
        ),
        _SummaryCard(
          icon: Icons.pending_actions,
          label: 'Pending',
          value: pending.toString(),
          color: const Color(0xFFFFB020),
        ),
        _SummaryCard(
          icon: Icons.priority_high,
          label: 'Urgent',
          value: urgent.toString(),
          color: AdminTheme.primaryRed,
        ),
        _SummaryCard(
          icon: Icons.verified_outlined,
          label: 'Resolved',
          value: resolved.toString(),
          color: const Color(0xFF34E27A),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: AdminTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.status,
    required this.urgency,
    required this.category,
    required this.dateFilter,
    required this.categories,
    required this.onStatusChanged,
    required this.onUrgencyChanged,
    required this.onCategoryChanged,
    required this.onDateChanged,
  });

  final String status;
  final String urgency;
  final String category;
  final AdminDateFilter dateFilter;
  final List<String> categories;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onUrgencyChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<AdminDateFilter> onDateChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _DropdownFilter<String>(
            label: 'Status',
            value: status,
            values: const {
              'all': 'All statuses',
              'submitted': 'Submitted',
              'investigating': 'Investigating',
              'resolved': 'Resolved',
              'closed': 'Closed',
              'failed': 'Failed',
            },
            onChanged: onStatusChanged,
          ),
          _DropdownFilter<String>(
            label: 'Urgency',
            value: urgency,
            values: const {
              'all': 'All urgency',
              'normal': 'Normal',
              'urgent': 'Urgent',
              'critical': 'Critical',
            },
            onChanged: onUrgencyChanged,
          ),
          _DropdownFilter<String>(
            label: 'Category',
            value: category,
            values: {
              'all': 'All categories',
              for (final category in categories) category: category,
            },
            onChanged: onCategoryChanged,
          ),
          _DropdownFilter<AdminDateFilter>(
            label: 'Date',
            value: dateFilter,
            values: {
              for (final filter in AdminDateFilter.values) filter: filter.label,
            },
            onChanged: onDateChanged,
          ),
        ],
      ),
    );
  }
}

class _DropdownFilter<T> extends StatelessWidget {
  const _DropdownFilter({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final T value;
  final Map<T, String> values;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: values.entries
            .map(
              (entry) => DropdownMenuItem<T>(
                value: entry.key,
                child: Text(entry.value, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}

class _ReportListPanel extends StatelessWidget {
  const _ReportListPanel({
    required this.reports,
    required this.selectedReportId,
    required this.onSelect,
  });

  final List<AdminReport> reports;
  final String? selectedReportId;
  final ValueChanged<AdminReport> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Reports (${reports.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
          if (reports.isEmpty)
            const Padding(
              padding: EdgeInsets.all(18),
              child: _AdminMessage(
                icon: Icons.inbox_outlined,
                title: 'No reports match filters',
                message: 'Adjust filters or submit a mobile report.',
              ),
            )
          else
            ...reports.map(
              (report) => _ReportListTile(
                report: report,
                selected: report.id == selectedReportId,
                onTap: () => onSelect(report),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReportListTile extends StatelessWidget {
  const _ReportListTile({
    required this.report,
    required this.selected,
    required this.onTap,
  });

  final AdminReport report;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF19243A) : Colors.transparent,
          border: const Border(top: BorderSide(color: Color(0xFF222D44))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              report.isUrgent ? Icons.warning_amber_rounded : Icons.circle,
              color: _urgencyColor(report.urgency),
              size: report.isUrgent ? 24 : 12,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.categoryLabel,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    report.locationSummary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AdminTheme.textMuted),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _StatusPill(label: report.status),
                      _StatusPill(
                        label: report.urgency,
                        color: _urgencyColor(report.urgency),
                      ),
                      if (report.spamFlagged)
                        const _StatusPill(
                          label: 'Flagged',
                          color: AdminTheme.primaryRed,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _shortDate(report.createdAt),
              style: const TextStyle(color: AdminTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportDetailPanel extends StatelessWidget {
  const _ReportDetailPanel({required this.report});

  final AdminReport? report;

  @override
  Widget build(BuildContext context) {
    final report = this.report;
    if (report == null) {
      return const _AdminMessage(
        icon: Icons.description_outlined,
        title: 'Select a report',
        message: 'Choose a report to review details, evidence, notes, and status.',
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.categoryLabel,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    report.id,
                    style: const TextStyle(color: AdminTheme.textMuted),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  _StatusPill(label: report.status),
                  _StatusPill(
                    label: report.urgency,
                    color: _urgencyColor(report.urgency),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          _DetailSection(
            title: 'Incident',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow('Reporter', report.reporterLabel),
                _DetailRow('Created', _fullDate(report.createdAt)),
                _DetailRow('Updated', _fullDate(report.updatedAt)),
                _DetailRow('Notes', '${report.adminNotesCount} admin notes'),
                const SizedBox(height: 12),
                Text(report.description),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _DetailSection(
            title: 'Location',
            child: _LocationPanel(location: report.location),
          ),
          const SizedBox(height: 16),
          _DetailSection(
            title: 'Evidence',
            child: _EvidencePanel(media: report.media),
          ),
          const SizedBox(height: 16),
          _DetailSection(
            title: 'Admin action',
            child: _AdminActionPanel(report: report),
          ),
          const SizedBox(height: 16),
          _DetailSection(
            title: 'Admin notes',
            child: _AdminNotesList(reportId: report.id),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1424),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF222D44)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AdminTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(color: AdminTheme.textMuted),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _LocationPanel extends StatelessWidget {
  const _LocationPanel({required this.location});

  final AdminReportLocation location;

  @override
  Widget build(BuildContext context) {
    if (!location.hasLocation) {
      return const Text(
        'No location was submitted.',
        style: TextStyle(color: AdminTheme.textMuted),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 190,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF263551)),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.map_outlined, color: AdminTheme.cyan, size: 42),
                const SizedBox(height: 10),
                Text(
                  location.hasCoordinates
                      ? '${location.latitude!.toStringAsFixed(5)}, ${location.longitude!.toStringAsFixed(5)}'
                      : location.ghanaPostGps!,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (location.accuracyMeters != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Accuracy +/-${location.accuracyMeters!.round()}m',
                    style: const TextStyle(color: AdminTheme.textMuted),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          location.locationSummary,
          style: const TextStyle(color: AdminTheme.textMuted),
        ),
      ],
    );
  }
}

class _EvidencePanel extends StatelessWidget {
  const _EvidencePanel({required this.media});

  final List<AdminEvidence> media;

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) {
      return const Text(
        'No evidence files were attached.',
        style: TextStyle(color: AdminTheme.textMuted),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: media.map((item) => _EvidenceTile(item: item)).toList(),
    );
  }
}

class _EvidenceTile extends StatelessWidget {
  const _EvidenceTile({required this.item});

  final AdminEvidence item;

  Future<String> _downloadUrl() {
    return FirebaseStorage.instance.ref(item.storagePath).getDownloadURL();
  }

  Future<void> _openUrl(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _downloadUrl(),
      builder: (context, snapshot) {
        final url = snapshot.data;
        return Container(
          width: item.isImage ? 220 : 300,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AdminTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF263551)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.isImage && url != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    url,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                )
              else if (item.isVoice && url != null)
                _VoiceEvidencePlayer(url: url)
              else
                Container(
                  height: 92,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1424),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? const CircularProgressIndicator()
                      : Icon(
                          item.isVoice
                              ? Icons.keyboard_voice_outlined
                              : Icons.insert_drive_file_outlined,
                          color: AdminTheme.textMuted,
                        ),
                ),
              const SizedBox(height: 10),
              Text(
                item.type.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                _fileSize(item.sizeBytes),
                style: const TextStyle(color: AdminTheme.textMuted),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: url == null ? null : () => _openUrl(url),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VoiceEvidencePlayer extends StatefulWidget {
  const _VoiceEvidencePlayer({required this.url});

  final String url;

  @override
  State<_VoiceEvidencePlayer> createState() => _VoiceEvidencePlayerState();
}

class _VoiceEvidencePlayerState extends State<_VoiceEvidencePlayer> {
  late final AudioPlayer _player;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _load();
  }

  Future<void> _load() async {
    await _player.setUrl(widget.url);
    if (mounted) {
      setState(() => _ready = true);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1424),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          StreamBuilder<PlayerState>(
            stream: _player.playerStateStream,
            builder: (context, snapshot) {
              final playing = snapshot.data?.playing ?? false;
              return IconButton(
                tooltip: playing ? 'Pause' : 'Play',
                onPressed: !_ready
                    ? null
                    : () async {
                        if (playing) {
                          await _player.pause();
                        } else {
                          await _player.play();
                        }
                      },
                icon: Icon(playing ? Icons.pause : Icons.play_arrow),
              );
            },
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Voice note',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminActionPanel extends StatefulWidget {
  const _AdminActionPanel({required this.report});

  final AdminReport report;

  @override
  State<_AdminActionPanel> createState() => _AdminActionPanelState();
}

class _AdminActionPanelState extends State<_AdminActionPanel> {
  late String _status;
  late bool _spamFlagged;
  final _noteController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _status = widget.report.status;
    _spamFlagged = widget.report.spamFlagged;
  }

  @override
  void didUpdateWidget(covariant _AdminActionPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.report.id != widget.report.id) {
      _status = widget.report.status;
      _spamFlagged = widget.report.spamFlagged;
      _noteController.clear();
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;

    setState(() => _saving = true);
    try {
      await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('updateReportStatus')
          .call(<String, dynamic>{
        'reportId': widget.report.id,
        'status': _status,
        'spamFlagged': _spamFlagged,
        'adminNote': _noteController.text.trim(),
      });
      _noteController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report updated.')),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Update failed.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Update failed.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(
                    value: 'submitted',
                    child: Text('Submitted'),
                  ),
                  DropdownMenuItem(
                    value: 'investigating',
                    child: Text('Investigating'),
                  ),
                  DropdownMenuItem(
                    value: 'resolved',
                    child: Text('Resolved'),
                  ),
                  DropdownMenuItem(value: 'closed', child: Text('Closed')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _status = value);
                },
              ),
            ),
            FilterChip(
              selected: _spamFlagged,
              label: const Text('Spam / false report'),
              avatar: const Icon(Icons.flag_outlined),
              onSelected: (value) => setState(() => _spamFlagged = value),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _noteController,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Admin note'),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('Save admin update'),
        ),
      ],
    );
  }
}

class _AdminNotesList extends StatelessWidget {
  const _AdminNotesList({required this.reportId});

  final String reportId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('admin_notes')
          .where('reportId', isEqualTo: reportId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        final notes = snapshot.data?.docs.toList() ?? [];
        notes.sort((a, b) {
          final aDate = _dateFromFirestore(a.data()['createdAt']);
          final bDate = _dateFromFirestore(b.data()['createdAt']);
          return (bDate ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(aDate ?? DateTime.fromMillisecondsSinceEpoch(0));
        });

        if (notes.isEmpty) {
          return const Text(
            'No admin notes yet.',
            style: TextStyle(color: AdminTheme.textMuted),
          );
        }

        return Column(
          children: notes.map((note) {
            final data = note.data();
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AdminTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['note'] as String? ?? ''),
                  const SizedBox(height: 6),
                  Text(
                    '${data['adminId'] as String? ?? 'admin'} - ${_fullDate(_dateFromFirestore(data['createdAt']))}',
                    style: const TextStyle(
                      color: AdminTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    this.color = AdminTheme.cyan,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _label(label),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
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
        decoration: _panelDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AdminTheme.textMuted, size: 44),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
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

extension on AdminReport {
  String get reporterLabel {
    if (anonymous) return 'Protected reporter';
    return reporterDisplayName.isEmpty ? reporterId : reporterDisplayName;
  }

  String get locationSummary => location.locationSummary;
}

extension on AdminReportLocation {
  String get locationSummary {
    final parts = <String>[];
    if (hasCoordinates) {
      parts.add(
        '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}',
      );
    }
    if (ghanaPostGps != null && ghanaPostGps!.isNotEmpty) {
      parts.add(ghanaPostGps!);
    }
    if (parts.isEmpty) return 'No location submitted';
    return parts.join(' - ');
  }
}

extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) return iterator.current;
    return null;
  }
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    color: AdminTheme.surface,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: const Color(0xFF222D44)),
  );
}

DateTime? _dateFromFirestore(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

Color _urgencyColor(String urgency) {
  switch (urgency) {
    case 'critical':
      return AdminTheme.primaryRed;
    case 'urgent':
      return const Color(0xFFFF8A1F);
    default:
      return AdminTheme.cyan;
  }
}

String _shortDate(DateTime? date) {
  if (date == null) return '-';
  return DateFormat('MMM d').format(date);
}

String _fullDate(DateTime? date) {
  if (date == null) return '-';
  return DateFormat('MMM d, y - HH:mm').format(date);
}

String _fileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _label(String value) {
  if (value.isEmpty) return value;
  return value
      .split(RegExp(r'[_\s-]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}
