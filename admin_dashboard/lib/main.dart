import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

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

            return const AdminLocationDashboard();
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
            decoration: BoxDecoration(
              color: AdminTheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF222D44)),
            ),
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
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_useEmulators) ...[
              FilledButton(
                onPressed: () => _bootstrapEmulatorAdmin(context),
                child: const Text('Grant emulator superAdmin'),
              ),
              const SizedBox(width: 12),
            ],
            OutlinedButton(
              onPressed: _refreshClaims,
              child: const Text('Refresh claims'),
            ),
            const SizedBox(width: 12),
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

class AdminLocationDashboard extends StatelessWidget {
  const AdminLocationDashboard({super.key});

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
    final categoryLabel = data['categoryLabel'] as String?;
    final legacyCategory = data['category'] as String?;

    return AdminReportLocation(
      id: doc.id,
      category: categoryLabel ?? legacyCategory ?? 'Uncategorized',
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

class _AdminReportLocationTile extends StatefulWidget {
  const _AdminReportLocationTile(this.report);

  final AdminReportLocation report;

  @override
  State<_AdminReportLocationTile> createState() =>
      _AdminReportLocationTileState();
}

class _AdminReportLocationTileState extends State<_AdminReportLocationTile> {
  bool _isUpdating = false;

  AdminReportLocation get report => widget.report;

  Future<void> _updateStatus(String status) async {
    if (_isUpdating || report.status == status) return;

    setState(() => _isUpdating = true);
    try {
      await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('updateReportStatus')
          .call(<String, dynamic>{
        'reportId': report.id,
        'status': status,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report marked ${_statusLabel(status)}.')),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Status update failed.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status update failed.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  String _statusLabel(String status) {
    return status
        .split(RegExp(r'(?=[A-Z])|_'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Chip(label: Text(report.status)),
              const SizedBox(height: 10),
              if (_isUpdating)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                PopupMenuButton<String>(
                  tooltip: 'Update status',
                  icon: const Icon(Icons.more_vert),
                  onSelected: _updateStatus,
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'investigating',
                      child: Text('Mark investigating'),
                    ),
                    PopupMenuItem(
                      value: 'resolved',
                      child: Text('Mark resolved'),
                    ),
                    PopupMenuItem(
                      value: 'closed',
                      child: Text('Mark closed'),
                    ),
                  ],
                ),
            ],
          ),
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
