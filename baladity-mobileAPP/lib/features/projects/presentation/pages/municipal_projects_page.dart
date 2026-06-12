import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/projects_controller.dart';
import '../controllers/projects_state.dart';
import '../../domain/entities/project_entity.dart';

class MunicipalProjectsPage extends ConsumerStatefulWidget {
  const MunicipalProjectsPage({super.key});

  @override
  ConsumerState<MunicipalProjectsPage> createState() =>
      _MunicipalProjectsPageState();
}

class _MunicipalProjectsPageState
    extends ConsumerState<MunicipalProjectsPage> {
  String? _selectedMunicipalityName;
  int? _selectedMunicipalityId;

  final List<Map<String, dynamic>> _municipalities = [
    {'id': 1, 'name': 'بلدية طرابلس المركز'},
    {'id': 2, 'name': 'بلدية بنغازي'},
    {'id': 3, 'name': 'بلدية مصراتة'},
    {'id': 4, 'name': 'بلدية سبها'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedMunicipalityName = _municipalities.first['name'] as String;
    _selectedMunicipalityId = _municipalities.first['id'] as int;
    Future.microtask(() => _load(refresh: true));
  }

  void _load({bool refresh = false}) {
    ref.read(projectsControllerProvider.notifier).fetchProjects(
          municipalityId: _selectedMunicipalityId,
          refresh: refresh,
        );
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF2E7D32);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final projectsState = ref.watch(projectsControllerProvider);

    ref.listen<ProjectsState>(projectsControllerProvider, (_, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'اختر البلدية',
                filled: true,
                fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              initialValue: _selectedMunicipalityName,
              items: _municipalities
                  .map((m) => DropdownMenuItem<String>(
                        value: m['name'] as String,
                        child: Text(m['name'] as String),
                      ))
                  .toList(),
              onChanged: (newValue) {
                if (newValue == null) return;
                setState(() {
                  _selectedMunicipalityName = newValue;
                  _selectedMunicipalityId = _municipalities
                      .firstWhere((m) => m['name'] == newValue)['id'] as int?;
                });
                _load(refresh: true);
              },
            ),
          ),
          Expanded(
            child: projectsState.isLoading && projectsState.projects.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : projectsState.projects.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.construction_outlined,
                                size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'لا توجد مشاريع لـ "$_selectedMunicipalityName"',
                              style: TextStyle(
                                fontSize: 18,
                                color: isDark
                                    ? Colors.white54
                                    : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => _load(refresh: true),
                        child: ListView.builder(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: projectsState.projects.length +
                              (projectsState.hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == projectsState.projects.length) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: projectsState.isLoading
                                      ? const CircularProgressIndicator()
                                      : TextButton(
                                          onPressed: _load,
                                          child: const Text('تحميل المزيد'),
                                        ),
                                ),
                              );
                            }
                            return _buildProjectCard(
                              projectsState.projects[index],
                              primaryGreen,
                              isDark,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(
      ProjectEntity project, Color primaryColor, bool isDark) {
    final Color statusColor;
    switch (project.status) {
      case 'قيد التنفيذ':
        statusColor = Colors.blue;
      case 'مكتمل':
        statusColor = Colors.green;
      case 'متوقف':
        statusColor = Colors.red;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    project.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    project.status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              project.description,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : Colors.grey[700],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Divider(height: 20),
            _buildDetailRow(
              Icons.calendar_today_outlined,
              'تاريخ البدء: ${project.startDate.toLocal().toString().split(' ')[0]}',
              isDark,
            ),
            project.endDate != null
                ? _buildDetailRow(
                    Icons.check_circle_outline,
                    'تاريخ الانتهاء: ${project.endDate!.toLocal().toString().split(' ')[0]}',
                    isDark,
                  )
                : _buildDetailRow(
                    Icons.hourglass_empty,
                    'متوقع الانتهاء: غير محدد',
                    isDark,
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
