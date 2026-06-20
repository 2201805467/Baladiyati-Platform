import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../theme_manager.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../emergency/presentation/pages/emergency_numbers_page.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../../reports/domain/entities/report_entity.dart';
import '../../../reports/presentation/controllers/reports_controller.dart';
import '../../../reports/presentation/pages/add_report_page.dart';
import '../../../reports/presentation/pages/reports_page.dart';
import '../../../proposals/presentation/pages/suggest_service_page.dart';
import '../../../proposals/presentation/pages/citizen_proposals_page.dart';
import '../../../facilities/presentation/pages/public_facilities_page.dart';
import '../../../projects/presentation/pages/municipal_projects_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  static const _primaryGreen = Color(0xFF2E7D32);

  List<_CitizenNotification> _notifications = const [];
  bool _isLoadingNotifications = false;
  String? _notificationsError;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(profileControllerProvider.notifier).fetchProfile();
      ref.read(reportsControllerProvider.notifier).fetchReports(refresh: true);
      _fetchNotifications();
    });
  }

  Future<void> _fetchNotifications() async {
    if (_isLoadingNotifications) return;
    setState(() {
      _isLoadingNotifications = true;
      _notificationsError = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get(ApiConstants.notifications);
      final raw = res.data['data'] ?? res.data;
      final list = raw is List ? raw : const [];
      final notifications = list
          .whereType<Map>()
          .map((e) => _CitizenNotification.fromJson(e))
          .toList();

      if (!mounted) return;
      setState(() {
        _notifications = notifications;
        _isLoadingNotifications = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingNotifications = false;
        _notificationsError = e.toString();
      });
    }
  }

  Future<void> _markAllNotificationsAsRead({bool showError = true}) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('${ApiConstants.notifications}/read-all');
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map((n) => n.copyWith(isRead: true))
            .toList(growable: false);
      });
    } catch (e) {
      if (!mounted) return;
      if (showError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  Future<void> _showNotificationsSheet() async {
    await _fetchNotifications();
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.65,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'الإشعارات',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _notifications.any((n) => !n.isRead)
                            ? () async {
                                await _markAllNotificationsAsRead();
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              }
                            : null,
                        child: const Text('تحديد الكل كمقروء'),
                      ),
                    ],
                  ),
                ),
                if (_isLoadingNotifications)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_notificationsError != null)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _notificationsError!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  )
                else if (_notifications.isEmpty)
                  const Expanded(
                    child: Center(child: Text('لا توجد إشعارات حالياً')),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: _notifications.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final notification = _notifications[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            notification.isRead
                                ? Icons.notifications_none
                                : Icons.notifications_active,
                            color: notification.isRead
                                ? Colors.grey
                                : _primaryGreen,
                          ),
                          title: Text(
                            notification.title,
                            style: TextStyle(
                              fontWeight: notification.isRead
                                  ? FontWeight.w500
                                  : FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(notification.body),
                          trailing: notification.createdAt == null
                              ? null
                              : Text(
                                  _relativeTime(notification.createdAt!),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!mounted) return;
    if (_notifications.any((notification) => !notification.isRead)) {
      await _markAllNotificationsAsRead(showError: false);
    }
  }

  String _relativeTime(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inHours < 1) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inDays < 1) return 'منذ ${diff.inHours} ساعة';
    return 'منذ ${diff.inDays} يوم';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryGreen = Color(0xFF2E7D32);
    final user = ref.watch(profileControllerProvider).user;
    final reports = ref.watch(reportsControllerProvider).reports;
    final unreadNotifications = _notifications
        .where((notification) => !notification.isRead)
        .length;
    final displayName = user?.name.trim().isNotEmpty == true
        ? user!.name.trim()
        : 'مستخدم';

    return DefaultTabController(
      length: 5,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: colorScheme.surface,
          appBar: AppBar(
            backgroundColor: colorScheme.surface,
            elevation: 0,
            title: const Text(
              'منصة بلديتي',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: false,
            actions: [
              IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                ),
                onPressed: () => ThemeManager.toggleTheme(!isDark),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: unreadNotifications > 0
                    ? Badge(
                        label: Text('$unreadNotifications'),
                        child: const Icon(Icons.notifications_none_rounded),
                      )
                    : const Icon(Icons.notifications_none_rounded),
                onPressed: _showNotificationsSheet,
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => context.go(AppRoutes.profile),
                child: const CircleAvatar(
                  radius: 18,
                  backgroundColor: primaryGreen,
                  child: Icon(Icons.person, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 16),
            ],
            bottom: TabBar(
              isScrollable: true,
              indicatorColor: primaryGreen,
              labelColor: primaryGreen,
              unselectedLabelColor: colorScheme.onSurface.withValues(
                alpha: 0.6,
              ),
              tabs: const [
                Tab(text: 'الرئيسية'),
                Tab(text: 'مرافق البلدية'),
                Tab(text: 'مشاريع البلدية'),
                Tab(text: 'مقترحات المواطنين'),
                Tab(text: 'أرقام الطوارئ'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _HomeTabContent(
                primaryGreen: primaryGreen,
                displayName: displayName,
                reports: reports,
              ),
              const PublicFacilitiesPage(),
              const MunicipalProjectsPage(),
              const CitizenProposalsPage(),
              const EmergencyNumbersView(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeTabContent extends StatelessWidget {
  final Color primaryGreen;
  final String displayName;
  final List<ReportEntity> reports;

  const _HomeTabContent({
    required this.primaryGreen,
    required this.displayName,
    required this.reports,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'أهلاً بك، $displayName',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const Text(
            'كيف يمكننا مساعدتك في مدينتك اليوم؟',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          if (reports.isNotEmpty) ...[
            _NotificationPreview(report: reports.first),
            const SizedBox(height: 24),
          ],
          _StatisticsSection(primaryColor: primaryGreen, reports: reports),
          const SizedBox(height: 24),
          Text(
            'إجراءات سريعة',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _ActionGrid(primaryColor: primaryGreen),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'آخر البلاغات',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ReportsPage()),
                ),
                child: Text('عرض الكل', style: TextStyle(color: primaryGreen)),
              ),
            ],
          ),
          _ReportsFeed(reports: reports.take(3).toList()),
        ],
      ),
    );
  }
}

class _StatisticsSection extends StatelessWidget {
  final Color primaryColor;
  final List<ReportEntity> reports;

  const _StatisticsSection({required this.primaryColor, required this.reports});

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;
    return Row(
      children: [
        _statCard(
          context,
          'إجمالي البلاغات',
          '${reports.length}',
          primaryColor,
          cardColor,
        ),
        const SizedBox(width: 12),
        _statCard(
          context,
          'قيد الانتظار',
          '${reports.where((r) => !_isClosed(r.status)).length}',
          Colors.orange,
          cardColor,
        ),
        const SizedBox(width: 12),
        _statCard(
          context,
          'تم الحل',
          '${reports.where((r) => _isClosed(r.status)).length}',
          Colors.blue,
          cardColor,
        ),
      ],
    );
  }

  Widget _statCard(
    BuildContext context,
    String label,
    String value,
    Color color,
    Color cardBg,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border(bottom: BorderSide(color: color, width: 4)),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  bool _isClosed(String status) {
    final normalized = status.toLowerCase();
    return normalized == 'closed' ||
        normalized == 'resolved' ||
        normalized.contains('مغلق') ||
        normalized.contains('تم الحل');
  }
}

class _ActionGrid extends StatelessWidget {
  final Color primaryColor;
  const _ActionGrid({required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _actionItem(
          context,
          Icons.add_chart_rounded,
          'بلاغ جديد',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddReportPage()),
          ),
        ),
        _actionItem(
          context,
          Icons.list_alt_rounded,
          'بلاغاتي',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ReportsPage()),
          ),
        ),
        _actionItem(
          context,
          Icons.lightbulb_outline_rounded,
          'مقترح مشروع',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SuggestServicePage()),
          ),
        ),
        _actionItem(
          context,
          Icons.emergency_outlined,
          'أرقام الطوارئ',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EmergencyNumbersPage(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionItem(
    BuildContext context,
    IconData icon,
    String label, {
    VoidCallback? onTap,
  }) {
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: onTap ?? () {},
        borderRadius: BorderRadius.circular(12),
        child: SizedBox.expand(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: primaryColor, size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportsFeed extends StatelessWidget {
  final List<ReportEntity> reports;
  const _ReportsFeed({required this.reports});

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return const Center(child: Text('لا توجد بلاغات حالياً'));
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: reports.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final report = reports[index];
        final statusColor = _statusColor(report.status);
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.description_outlined, color: statusColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.category.isNotEmpty
                          ? report.category
                          : 'بلاغ #${report.id ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _reportSubtitle(report),
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              _statusBadge(_statusLabel(report.status), statusColor),
            ],
          ),
        );
      },
    );
  }

  String _reportSubtitle(ReportEntity report) {
    final parts = <String>[];
    if (report.createdAt != null) {
      parts.add(_relativeTime(report.createdAt!));
    }
    if (report.locationAddress?.trim().isNotEmpty == true) {
      parts.add(report.locationAddress!.trim());
    }
    if (parts.isEmpty && report.description.trim().isNotEmpty) {
      parts.add(report.description.trim());
    }
    return parts.isEmpty ? 'لا توجد تفاصيل إضافية' : parts.join(' • ');
  }

  String _relativeTime(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inHours < 1) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inDays < 1) return 'منذ ${diff.inHours} ساعة';
    return 'منذ ${diff.inDays} يوم';
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return 'جديد';
      case 'under_review':
        return 'قيد المراجعة';
      case 'transferred':
        return 'محال للقسم';
      case 'in_progress':
        return 'قيد التنفيذ';
      case 'pending':
        return 'معلّق';
      case 'closed':
        return 'مغلق';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'closed':
        return Colors.blue;
      case 'in_progress':
      case 'transferred':
        return Colors.green;
      case 'pending':
      case 'under_review':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _NotificationPreview extends StatelessWidget {
  final ReportEntity report;
  const _NotificationPreview({required this.report});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.amber.withValues(alpha: 0.1)
            : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? Colors.amber.withValues(alpha: 0.3)
              : Colors.amber.shade200,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.amber, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'آخر تحديث لبلاغك #${report.id ?? '-'}: ${report.status}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _CitizenNotification {
  final int id;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime? createdAt;

  const _CitizenNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    this.createdAt,
  });

  factory _CitizenNotification.fromJson(Map<dynamic, dynamic> json) {
    return _CitizenNotification(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      isRead: json['is_read'] == true || json['is_read'] == 1,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
    );
  }

  _CitizenNotification copyWith({bool? isRead}) {
    return _CitizenNotification(
      id: id,
      title: title,
      body: body,
      type: type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}
