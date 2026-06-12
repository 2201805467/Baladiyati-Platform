import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../theme_manager.dart';
import '../../../emergency/presentation/pages/emergency_numbers_page.dart';
import '../../../reports/presentation/pages/add_report_page.dart';
import '../../../reports/presentation/pages/reports_page.dart';
import '../../../proposals/presentation/pages/suggest_service_page.dart';
import '../../../proposals/presentation/pages/citizen_proposals_page.dart';
import '../../../facilities/presentation/pages/public_facilities_page.dart';
import '../../../projects/presentation/pages/municipal_projects_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryGreen = Color(0xFF2E7D32);

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
                icon: const Badge(
                  label: Text('2'),
                  child: Icon(Icons.notifications_none_rounded),
                ),
                onPressed: () {},
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
              unselectedLabelColor:
                  colorScheme.onSurface.withValues(alpha: 0.6),
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
              _HomeTabContent(primaryGreen: primaryGreen),
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
  const _HomeTabContent({required this.primaryGreen});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'أهلاً بك، أحمد',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const Text(
            'كيف يمكننا مساعدتك في مدينتك اليوم؟',
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          const _NotificationPreview(),
          const SizedBox(height: 24),
          _StatisticsSection(primaryColor: primaryGreen),
          const SizedBox(height: 24),
          Text(
            'إجراءات سريعة',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _ActionGrid(primaryColor: primaryGreen),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'آخر البلاغات',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
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
          const _ReportsFeed(reports: []),
        ],
      ),
    );
  }
}


class _StatisticsSection extends StatelessWidget {
  final Color primaryColor;

  const _StatisticsSection({required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;
    return Row(
      children: [
        _statCard(context, 'إجمالي البلاغات', '0', primaryColor, cardColor),
        const SizedBox(width: 12),
        _statCard(context, 'قيد الانتظار', '0', Colors.orange, cardColor),
        const SizedBox(width: 12),
        _statCard(context, 'تم الحل', '0', Colors.blue, cardColor),
      ],
    );
  }

  Widget _statCard(BuildContext context, String label, String value,
      Color color, Color cardBg) {
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
                  fontSize: 20, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodySmall?.color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
                builder: (context) => const EmergencyNumbersPage()),
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
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportsFeed extends StatelessWidget {
  final List<dynamic> reports;
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
                  color: (report['color'] as Color).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.description_outlined,
                  color: report['color'] as Color,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report['title'] as String,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'منذ ساعتين • طرابلس، ليبيا',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              _statusBadge(
                  report['label'] as String, report['color'] as Color),
            ],
          ),
        );
      },
    );
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
            color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}


class _NotificationPreview extends StatelessWidget {
  const _NotificationPreview();

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
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.amber, size: 20),
          SizedBox(width: 8),
          Text(
            'تم تحديث حالة بلاغك #1204 إلى "تم الحل"',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
