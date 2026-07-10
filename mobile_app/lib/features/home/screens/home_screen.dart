import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/services/emergency_call_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_service.dart';
import '../../reports/data/local_report_store.dart';
import '../../reports/domain/local_report.dart';
import '../../reports/screens/report_category_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.authService,
    required this.user,
  });

  final AuthService authService;
  final User user;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  Future<void> _dial112(BuildContext context) async {
    try {
      final opened = await EmergencyCallService().dial112();
      if (!opened && context.mounted) {
        _showMessage(context, 'Could not open the phone dialer.');
      }
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, 'Could not open the phone dialer.');
      }
    }
  }

  Future<void> _startReport(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportCategoryScreen(ownerId: widget.user.uid),
      ),
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.user.isAnonymous
        ? 'Protected Reporter'
        : (widget.user.displayName?.trim().isNotEmpty ?? false)
            ? widget.user.displayName!.trim()
            : 'Reporter';

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _HomeTab(
              displayName: displayName,
              onReportIncident: () => _startReport(context),
              onCall112: () => _dial112(context),
              onOpenReports: () => setState(() => _selectedIndex = 1),
              onSignOut: widget.authService.signOut,
            ),
            _ReportsTab(
              ownerId: widget.user.uid,
              onReportIncident: () => _startReport(context),
            ),
            _ProfileTab(
              displayName: displayName,
              isProtected: widget.user.isAnonymous,
              onSignOut: widget.authService.signOut,
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() {
          _selectedIndex = index;
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.displayName,
    required this.onReportIncident,
    required this.onCall112,
    required this.onOpenReports,
    required this.onSignOut,
  });

  final String displayName;
  final VoidCallback onReportIncident;
  final VoidCallback onCall112;
  final VoidCallback onOpenReports;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
      children: [
        _HomeHeader(displayName: displayName, onSignOut: onSignOut),
        const SizedBox(height: 28),
        _ReportIncidentCard(onTap: onReportIncident),
        const SizedBox(height: 16),
        _Call112Card(onTap: onCall112),
        const SizedBox(height: 14),
        const _EmergencyGuidanceCard(),
        const SizedBox(height: 28),
        _MyReportsCard(onTap: onOpenReports),
        const SizedBox(height: 28),
        const Text(
          'QUICK ACTIONS',
          style: TextStyle(
            color: AppTheme.textMuted,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _QuickAction(
              icon: Icons.mic_none_rounded,
              label: 'Voice Note',
              onTap: onReportIncident,
            ),
            _QuickAction(
              icon: Icons.camera_alt_outlined,
              label: 'Evidence',
              onTap: onReportIncident,
            ),
            _QuickAction(
              icon: Icons.location_on_outlined,
              label: 'Location',
              onTap: onReportIncident,
            ),
            _QuickAction(
              icon: Icons.assignment_outlined,
              label: 'My Reports',
              onTap: onOpenReports,
            ),
          ],
        ),
        const SizedBox(height: 28),
        const _AreaAlertCard(),
        const SizedBox(height: 28),
        Row(
          children: [
            const Expanded(
              child: Text(
                'RECENT REPORTS',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            TextButton(onPressed: onOpenReports, child: const Text('View all')),
          ],
        ),
        const _ReportTile(
          title: 'Robbery',
          location: '14th Ave & Main St',
          status: 'Investigating',
          time: '2h ago',
        ),
        const _ReportTile(
          title: 'Suspicious Activity',
          location: 'Riverside Park, North Gate',
          status: 'Resolved',
          time: '5h ago',
          resolved: true,
        ),
        const _ReportTile(
          title: 'Medical Emergency',
          location: '88 Westbrook Blvd',
          status: 'Resolved',
          time: '1d ago',
          resolved: true,
        ),
      ],
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.displayName,
    required this.onSignOut,
  });

  final String displayName;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'WELCOME BACK',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                displayName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        IconButton.filled(
          onPressed: () {},
          icon: const Icon(Icons.notifications_none_rounded),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: onSignOut,
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
    );
  }
}

class _ReportIncidentCard extends StatelessWidget {
  const _ReportIncidentCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 128),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [AppTheme.primaryRed, AppTheme.deepRed],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryRed.withValues(alpha: 0.3),
              blurRadius: 26,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.emergency_share_outlined,
                color: AppTheme.textPrimary,
                size: 34,
              ),
            ),
            const SizedBox(width: 20),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TAP TO',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Report Incident',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                      height: 1.08,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Anonymous - Secure - Fast',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 32),
          ],
        ),
      ),
    );
  }
}

class _Call112Card extends StatelessWidget {
  const _Call112Card({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF17130F),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.amber.withValues(alpha: 0.56)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppTheme.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.phone_in_talk_outlined,
                color: AppTheme.amber,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CALL 112',
                    style: TextStyle(
                      color: AppTheme.amber,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Use for immediate danger or urgent emergency response.',
                    style: TextStyle(height: 1.35),
                  ),
                ],
              ),
            ),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.amber,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.call_rounded,
                color: Color(0xFF17130F),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyGuidanceCard extends StatelessWidget {
  const _EmergencyGuidanceCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF26324C)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppTheme.textMuted),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Crime and Emergency Report does not replace live dispatch. If someone is in immediate danger, call 112 first, then submit details here when it is safe.',
              style: TextStyle(
                color: AppTheme.textMuted,
                height: 1.42,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AreaAlertCard extends StatelessWidget {
  const _AreaAlertCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF17130F),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF6A4700)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: AppTheme.amber),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AREA ALERT',
                  style: TextStyle(
                    color: AppTheme.amber,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'High incident rate reported nearby. Exercise caution.',
                  style: TextStyle(height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MyReportsCard extends StatelessWidget {
  const _MyReportsCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF222D44)),
        ),
        child: const Row(
          children: [
            Icon(Icons.assignment_outlined, color: AppTheme.amber),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Reports',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Track drafts, pending uploads, and case updates',
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: SizedBox(
        width: 74,
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF2A3550)),
              ),
              child: Icon(icon, color: AppTheme.cyan),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({
    required this.title,
    required this.location,
    required this.status,
    required this.time,
    this.resolved = false,
  });

  final String title;
  final String location;
  final String status;
  final String time;
  final bool resolved;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF222D44)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.amber),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  location,
                  style: const TextStyle(color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: resolved
                      ? const Color(0xFF0E3A2D)
                      : const Color(0xFF0D3545),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: resolved ? AppTheme.green : AppTheme.cyan,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                time,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportsTab extends StatelessWidget {
  const _ReportsTab({
    required this.ownerId,
    required this.onReportIncident,
  });

  final String ownerId;
  final VoidCallback onReportIncident;

  @override
  Widget build(BuildContext context) {
    final store = LocalReportStore();

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
      children: [
        ValueListenableBuilder(
          valueListenable: store.listenable(),
          builder: (context, _, __) {
            final reports = store.reportsForOwner(ownerId);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'My Reports',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${reports.length} local reports',
                            style: const TextStyle(color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: onReportIncident,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('New'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _ReportFilterChip(label: 'All', selected: true),
                    _ReportFilterChip(label: 'Draft'),
                    _ReportFilterChip(label: 'Pending'),
                    _ReportFilterChip(label: 'Failed'),
                  ],
                ),
                const SizedBox(height: 20),
                if (reports.isEmpty)
                  const _EmptyReportsCard()
                else
                  ...reports.map(
                    (report) => _ReportDetailCard(
                      title: report.category,
                      location: report.description ?? 'No description yet',
                      reportId: report.id,
                      status: report.status.label,
                      time: _relativeReportTime(report.updatedAt),
                      resolved: report.status == LocalReportStatus.submitted,
                      closed: report.status == LocalReportStatus.failed,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _EmptyReportsCard extends StatelessWidget {
  const _EmptyReportsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF222D44)),
      ),
      child: const Column(
        children: [
          Icon(Icons.assignment_outlined, color: AppTheme.textMuted, size: 42),
          SizedBox(height: 12),
          Text(
            'No local reports yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 6),
          Text(
            'Reports you create will appear here before upload.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ReportFilterChip extends StatelessWidget {
  const _ReportFilterChip({
    required this.label,
    this.selected = false,
  });

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      decoration: BoxDecoration(
        color: selected ? AppTheme.primaryRed : AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? AppTheme.primaryRed : const Color(0xFF2A3550),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _ReportDetailCard extends StatelessWidget {
  const _ReportDetailCard({
    required this.title,
    required this.location,
    required this.reportId,
    required this.status,
    required this.time,
    this.resolved = false,
    this.closed = false,
  });

  final String title;
  final String location;
  final String reportId;
  final String status;
  final String time;
  final bool resolved;
  final bool closed;

  @override
  Widget build(BuildContext context) {
    final statusColor = closed
        ? AppTheme.textMuted
        : resolved
            ? AppTheme.green
            : AppTheme.cyan;
    final statusBg = closed
        ? const Color(0xFF202A40)
        : resolved
            ? const Color(0xFF0E3A2D)
            : const Color(0xFF0D3545);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF222D44)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.circle,
                color: Color(0xFFFF851B),
                size: 10,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: AppTheme.textMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  location,
                  style: const TextStyle(color: AppTheme.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: Color(0xFF253049), height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                reportId,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 18),
              Text(
                time,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {},
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Details'),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.displayName,
    required this.isProtected,
    required this.onSignOut,
  });

  final String displayName;
  final bool isProtected;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
      children: [
        const Text(
          'Profile',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFF222D44)),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isProtected ? 'Protected reporter' : 'Citizen account',
                      style: const TextStyle(color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onSignOut,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sign Out'),
        ),
      ],
    );
  }
}

String _relativeReportTime(DateTime value) {
  final difference = DateTime.now().toUtc().difference(value.toUtc());

  if (difference.inMinutes < 1) return 'now';
  if (difference.inHours < 1) return '${difference.inMinutes}m ago';
  if (difference.inDays < 1) return '${difference.inHours}h ago';
  return '${difference.inDays}d ago';
}

extension _LocalReportStatusLabel on LocalReportStatus {
  String get label {
    switch (this) {
      case LocalReportStatus.draft:
        return 'Draft';
      case LocalReportStatus.pendingUpload:
        return 'Pending upload';
      case LocalReportStatus.uploading:
        return 'Uploading';
      case LocalReportStatus.submitted:
        return 'Submitted';
      case LocalReportStatus.failed:
        return 'Failed';
    }
  }
}
