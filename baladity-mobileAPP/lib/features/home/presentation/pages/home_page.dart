import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/network/api_constants.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../theme_manager.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../emergency/presentation/pages/emergency_numbers_page.dart';
import '../../../profile/presentation/controllers/profile_controller.dart';
import '../../../reports/domain/entities/report_entity.dart';
import '../../../reports/presentation/controllers/reports_controller.dart';
import '../../../reports/presentation/pages/add_report_page.dart';
import '../../../reports/presentation/pages/community_reports_page.dart';
import '../../../reports/presentation/pages/report_details_page.dart';
import '../../../reports/presentation/pages/reports_page.dart';
import '../../../proposals/presentation/controllers/proposals_controller.dart';
import '../../../proposals/presentation/pages/suggest_service_page.dart';
import '../../../proposals/presentation/pages/citizen_proposals_page.dart';
import '../../../proposals/presentation/pages/proposal_details_page.dart';
import '../../../facilities/presentation/pages/public_facilities_page.dart';
import '../../../geo_broadcasts/presentation/pages/geo_broadcasts_page.dart';
import '../../../initiatives/presentation/pages/community_initiatives_page.dart';
import '../../../lost_found/presentation/pages/lost_found_page.dart';
import '../../../polls/presentation/pages/polls_page.dart';
import '../../../projects/presentation/pages/municipal_projects_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  static const _primaryGreen = Color(0xFF2E7D32);

  List<_CitizenNotification> _notifications = const [];
  List<_HomeGeoBroadcast> _activeGeoBroadcasts = const [];
  bool _isLoadingNotifications = false;
  String? _notificationsError;
  Timer? _geoBroadcastTimer;
  int _geoBroadcastIndex = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(profileControllerProvider.notifier).fetchProfile();
      ref.read(reportsControllerProvider.notifier).fetchReports(refresh: true);
      _syncGeoBroadcastLocationIfAllowed().whenComplete(() {
        _fetchNotifications();
        _fetchActiveGeoBroadcasts();
      });
    });
  }

  @override
  void dispose() {
    _geoBroadcastTimer?.cancel();
    super.dispose();
  }

  Future<void> _syncGeoBroadcastLocationIfAllowed() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );

      await ref.read(dioProvider).patch(
        ApiConstants.geoBroadcastLocation,
        data: {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
      );
    } catch (_) {
      // Silent sync: the normal notifications flow should not be interrupted.
    }
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

  Future<void> _fetchActiveGeoBroadcasts() async {
    try {
      final response = await ref.read(dioProvider).get(
        ApiConstants.geoBroadcasts,
        queryParameters: {'active_only': true, 'per_page': 20},
      );
      final raw = response.data['data'] ?? response.data;
      final list = raw is List ? raw : const [];
      final broadcasts = list
          .whereType<Map>()
          .map((item) => _HomeGeoBroadcast.fromJson(item))
          .where((item) => item.status != 'cancelled')
          .toList()
        ..sort((a, b) => a.priority.compareTo(b.priority));

      if (!mounted) return;
      setState(() {
        _activeGeoBroadcasts = broadcasts.toList(growable: false);
        _geoBroadcastIndex = 0;
      });
      _startGeoBroadcastRotation();
    } catch (_) {
      if (!mounted) return;
      setState(() => _activeGeoBroadcasts = const []);
      _geoBroadcastTimer?.cancel();
    }
  }

  void _startGeoBroadcastRotation() {
    _geoBroadcastTimer?.cancel();
    if (_activeGeoBroadcasts.length <= 1) return;

    _geoBroadcastTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _activeGeoBroadcasts.isEmpty) return;
      setState(() {
        _geoBroadcastIndex =
            (_geoBroadcastIndex + 1) % _activeGeoBroadcasts.length;
      });
    });
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

  Future<void> _markNotificationAsRead(
    _CitizenNotification notification,
  ) async {
    if (notification.isRead) return;

    try {
      final dio = ref.read(dioProvider);
      await dio.patch('${ApiConstants.notifications}/${notification.id}/read');
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map(
              (item) => item.id == notification.id
                  ? item.copyWith(isRead: true)
                  : item,
            )
            .toList(growable: false);
      });
    } catch (_) {
      // Navigation should still work even if the read marker request fails.
    }
  }

  Future<void> _openNotificationTarget(
    _CitizenNotification notification,
  ) async {
    await _markNotificationAsRead(notification);
    if (!mounted) return;

    Navigator.of(context).pop();

    final relatedId = notification.relatedId;
    final relatedType = notification.relatedType.toLowerCase();

    if (relatedId == null) return;

    if (relatedType.contains('suggestion')) {
      await ref
          .read(proposalsControllerProvider.notifier)
          .fetchProposals(refresh: true);
      if (!mounted) return;

      final proposals = ref.read(proposalsControllerProvider).proposals;
      final proposal = proposals
          .where((item) => item.id == relatedId.toString())
          .firstOrNull;

      if (proposal != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProposalDetailsPage(proposal: proposal),
          ),
        );
      } else {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const CitizenProposalsPage()));
      }
      return;
    }

    if (relatedType.contains('initiative')) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const CommunityInitiativesPage()));
      return;
    }

    if (relatedType.contains('geobroadcast') ||
        relatedType.contains('geo_broadcast')) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const GeoBroadcastsPage()));
      return;
    }

    if (relatedType.contains('lostfound') ||
        relatedType.contains('lost_found') ||
        relatedType.contains('lostfounditem') ||
        relatedType.contains('lostfoundchatthread')) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const LostFoundPage()));
      return;
    }

    if (relatedType.contains('poll')) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const PollsPage()));
      return;
    }

    if (relatedType.contains('report')) {
      await ref
          .read(reportsControllerProvider.notifier)
          .fetchReports(refresh: true);
      if (!mounted) return;

      final reports = ref.read(reportsControllerProvider).reports;
      final report = reports.where((item) => item.id == relatedId).firstOrNull;

      if (report != null) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ReportDetailsPage(report: report)),
        );
      } else {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ReportsPage()));
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
      builder: (sheetContext) => Directionality(
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
                                if (sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop();
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
                          onTap: () => _openNotificationTarget(notification),
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
      length: 9,
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
                Tab(text: 'المبادرات'),
                Tab(text: 'التنبيهات الجغرافية'),
                Tab(text: 'مفقودات وموجودات'),
                Tab(text: 'استطلاعات الرأي'),
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
                activeGeoBroadcast: _activeGeoBroadcasts.isEmpty
                    ? null
                    : _activeGeoBroadcasts[
                        _geoBroadcastIndex % _activeGeoBroadcasts.length
                      ],
              ),
              const PublicFacilitiesPage(),
              const MunicipalProjectsPage(),
              const CommunityInitiativesPage(showAppBar: false),
              const GeoBroadcastsPage(showAppBar: false),
              const LostFoundPage(showAppBar: false),
              const PollsPage(showAppBar: false),
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
  final _HomeGeoBroadcast? activeGeoBroadcast;

  const _HomeTabContent({
    required this.primaryGreen,
    required this.displayName,
    required this.reports,
    required this.activeGeoBroadcast,
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
          if (activeGeoBroadcast != null) ...[
            _ActiveGeoBroadcastBanner(
              broadcast: activeGeoBroadcast!,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => _HomeGeoBroadcastDetailsPage(
                    broadcast: activeGeoBroadcast!,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = Color.alphaBlend(
      color.withValues(alpha: isDark ? 0.12 : 0.06),
      cardBg,
    );

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: background,
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

class _ActiveGeoBroadcastBanner extends StatelessWidget {
  final _HomeGeoBroadcast broadcast;
  final VoidCallback onTap;

  const _ActiveGeoBroadcastBanner({
    required this.broadcast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = broadcast.displayColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: Material(
        key: ValueKey(broadcast.id),
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? color.withValues(alpha: 0.12)
                  : color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color, width: 1.2),
            ),
            child: Row(
              children: [
                Icon(broadcast.icon, color: color, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        broadcast.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        broadcast.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  broadcast.typeLabel,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_left, color: color, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeGeoBroadcastDetailsPage extends StatelessWidget {
  final _HomeGeoBroadcast broadcast;

  const _HomeGeoBroadcastDetailsPage({required this.broadcast});

  Future<void> _openLocation() async {
    final latitude = broadcast.latitude;
    final longitude = broadcast.longitude;
    if (latitude == null || longitude == null) return;

    final geoUri = Uri.parse('geo:$latitude,$longitude?q=$latitude,$longitude');
    final webUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );

    if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      return;
    }
    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final color = broadcast.displayColor;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تفاصيل التنبيه')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color, width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(broadcast.icon, color: color, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          broadcast.title,
                          style: TextStyle(
                            color: color,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(broadcast.body, style: const TextStyle(fontSize: 15)),
                  const SizedBox(height: 16),
                  _GeoDetailRow(
                    icon: Icons.category_outlined,
                    text: 'النوع: ${broadcast.typeLabel}',
                  ),
                  _GeoDetailRow(
                    icon: Icons.schedule,
                    text: broadcast.dateText,
                  ),
                  _GeoDetailRow(
                    icon: Icons.radar,
                    text: 'النطاق: ${broadcast.radiusMeters} متر',
                  ),
                  if (broadcast.latitude != null && broadcast.longitude != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _openLocation,
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('عرض الموقع على الخريطة'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GeoDetailRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _GeoDetailRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
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
          Icons.groups_2_outlined,
          'بلاغات الجيران',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CommunityReportsPage(),
            ),
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
          Icons.volunteer_activism_outlined,
          'المبادرات',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CommunityInitiativesPage(),
            ),
          ),
        ),
        _actionItem(
          context,
          Icons.radar_outlined,
          'التنبيهات الجغرافية',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const GeoBroadcastsPage()),
          ),
        ),
        _actionItem(
          context,
          Icons.manage_search_rounded,
          'مفقودات وموجودات',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LostFoundPage()),
          ),
        ),
        _actionItem(
          context,
          Icons.poll_outlined,
          'استطلاعات الرأي',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PollsPage()),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final background = Color.alphaBlend(
      primaryColor.withValues(alpha: isDark ? 0.12 : 0.05),
      cardColor,
    );

    return Material(
      color: background,
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
                textAlign: TextAlign.center,
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
  final int? relatedId;
  final String relatedType;
  final bool isRead;
  final DateTime? createdAt;

  const _CitizenNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.relatedId,
    this.relatedType = '',
    required this.isRead,
    this.createdAt,
  });

  factory _CitizenNotification.fromJson(Map<dynamic, dynamic> json) {
    return _CitizenNotification(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      relatedId: _intOrNull(json['related_id']),
      relatedType: json['related_type']?.toString() ?? '',
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
      relatedId: relatedId,
      relatedType: relatedType,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  static int? _intOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}

class _HomeGeoBroadcast {
  final int id;
  final String title;
  final String body;
  final String broadcastType;
  final String status;
  final double? latitude;
  final double? longitude;
  final int radiusMeters;
  final DateTime? startsAt;
  final DateTime? endsAt;

  const _HomeGeoBroadcast({
    required this.id,
    required this.title,
    required this.body,
    required this.broadcastType,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.startsAt,
    required this.endsAt,
  });

  factory _HomeGeoBroadcast.fromJson(Map<dynamic, dynamic> json) {
    return _HomeGeoBroadcast(
      id: _intOrZero(json['id']),
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      broadcastType: json['broadcast_type']?.toString() ?? 'info',
      status: json['status']?.toString() ?? '',
      latitude: _doubleOrNull(json['latitude']),
      longitude: _doubleOrNull(json['longitude']),
      radiusMeters: _intOrZero(json['radius_meters'], fallback: 500),
      startsAt: _dateOrNull(json['starts_at']),
      endsAt: _dateOrNull(json['ends_at']),
    );
  }

  Color get displayColor {
    switch (broadcastType) {
      case 'critical':
        return Colors.red;
      case 'service':
        return Colors.orange;
      case 'works':
        return Colors.amber;
      case 'weather':
        return Colors.lightBlue;
      default:
        return Colors.blue.shade800;
    }
  }

  IconData get icon {
    switch (broadcastType) {
      case 'critical':
        return Icons.warning_amber_rounded;
      case 'service':
        return Icons.water_drop_outlined;
      case 'works':
        return Icons.construction_outlined;
      case 'weather':
        return Icons.cloud_outlined;
      default:
        return Icons.info_outline;
    }
  }

  int get priority {
    switch (broadcastType) {
      case 'critical':
        return 0;
      case 'service':
        return 1;
      case 'works':
        return 2;
      case 'weather':
        return 3;
      default:
        return 4;
    }
  }

  String get typeLabel {
    switch (broadcastType) {
      case 'critical':
        return 'طارئ';
      case 'service':
        return 'خدمي';
      case 'works':
        return 'صيانة';
      case 'weather':
        return 'جوي';
      default:
        return 'إعلام عام';
    }
  }

  String get dateText {
    final start = startsAt;
    final end = endsAt;
    if (start == null) return '-';
    final startText = _formatDateTime(start);
    if (end == null) return 'من $startText';
    final sameDay = start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;
    final endText = sameDay ? _formatTime(end) : _formatDateTime(end);
    return 'من $startText إلى $endText';
  }

  static int _intOrZero(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double? _doubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static DateTime? _dateOrNull(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  static String _formatDateTime(DateTime value) {
    return '${value.year}-${_two(value.month)}-${_two(value.day)} ${_formatTime(value)}';
  }

  static String _formatTime(DateTime value) {
    return '${_two(value.hour)}:${_two(value.minute)}';
  }
}
