import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/network/api_constants.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../features/auth/presentation/controllers/auth_controller.dart';
import '../../../../features/reports/data/models/report_model.dart';
import '../../../../features/reports/domain/entities/report_entity.dart';

String _apiOrigin() {
  final baseUrl = ApiConstants.baseUrl;
  if (baseUrl.endsWith('/api/')) {
    return baseUrl.substring(0, baseUrl.length - 5);
  }
  if (baseUrl.endsWith('/api')) return baseUrl.substring(0, baseUrl.length - 4);
  return baseUrl;
}

class DepartmentReportsPage extends ConsumerStatefulWidget {
  const DepartmentReportsPage({super.key});

  @override
  ConsumerState<DepartmentReportsPage> createState() =>
      _DepartmentReportsPageState();
}

class _DepartmentReportsPageState extends ConsumerState<DepartmentReportsPage> {
  final List<ReportEntity> _reports = [];
  bool _isLoading = false;
  String _status = 'open';

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadReports);
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      final response = await ref
          .read(dioProvider)
          .get(
            ApiConstants.departmentReports,
            queryParameters: {'status': _status, 'per_page': 50},
          );
      final raw = response.data['data'] ?? response.data;
      final list = raw is List ? raw : const [];
      final reports = list
          .whereType<Map>()
          .map((item) => ReportModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      if (!mounted) return;
      setState(() {
        _reports
          ..clear()
          ..addAll(reports);
      });
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openDetails(ReportEntity report) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DepartmentReportDetailsPage(report: report),
      ),
    );
    if (changed == true) {
      _loadReports();
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    final departmentName = user?.departmentName;

    return Scaffold(
      appBar: AppBar(
        title: const Text('بلاغات القسم'),
        actions: [
          IconButton(
            tooltip: 'الملف الشخصي',
            onPressed: () => context.push(AppRoutes.profile),
            icon: const Icon(Icons.person_outline),
          ),
          IconButton(
            tooltip: 'تسجيل الخروج',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: RefreshIndicator(
          onRefresh: _loadReports,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                departmentName == null || departmentName.isEmpty
                    ? 'قسمك الفني'
                    : departmentName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'الحالة',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'open',
                    child: Text('البلاغات المفتوحة'),
                  ),
                  DropdownMenuItem(value: 'transferred', child: Text('محولة')),
                  DropdownMenuItem(
                    value: 'in_progress',
                    child: Text('قيد التنفيذ'),
                  ),
                  DropdownMenuItem(value: 'pending', child: Text('معلقة')),
                  DropdownMenuItem(value: 'closed', child: Text('مغلقة')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _status = value);
                  _loadReports();
                },
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_reports.isEmpty)
                const _EmptyState()
              else
                ..._reports.map(
                  (report) => _DepartmentReportCard(
                    report: report,
                    onTap: () => _openDetails(report),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class DepartmentReportDetailsPage extends ConsumerStatefulWidget {
  const DepartmentReportDetailsPage({super.key, required this.report});

  final ReportEntity report;

  @override
  ConsumerState<DepartmentReportDetailsPage> createState() =>
      _DepartmentReportDetailsPageState();
}

class _DepartmentReportDetailsPageState
    extends ConsumerState<DepartmentReportDetailsPage> {
  final _commentController = TextEditingController();
  final _finishNoteController = TextEditingController();
  final _blockedReasonController = TextEditingController();
  final _picker = ImagePicker();
  late ReportEntity _report = widget.report;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadDetails);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _finishNoteController.dispose();
    _blockedReasonController.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    final id = _report.id;
    if (id == null) return;
    setState(() => _isLoading = true);
    try {
      final response = await ref
          .read(dioProvider)
          .get('${ApiConstants.departmentReports}/$id');
      final data = response.data['report'] ?? response.data;
      if (!mounted) return;
      setState(
        () => _report = ReportModel.fromJson(Map<String, dynamic>.from(data)),
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Position?> _currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _showMessage('يرجى تفعيل خدمة الموقع.', isError: true);
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _showMessage('لا يمكن استخدام الموقع بدون الصلاحية.', isError: true);
      return null;
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  Future<XFile?> _chooseImage({
    required String title,
    required bool requiredImage,
  }) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(title: Text(title), enabled: false),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('التقاط بالكاميرا'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('اختيار من المعرض'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              if (!requiredImage)
                ListTile(
                  leading: const Icon(Icons.skip_next_outlined),
                  title: const Text('متابعة بدون صورة'),
                  onTap: () => Navigator.pop(context),
                ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return null;
    return _picker.pickImage(source: source, imageQuality: 80, maxWidth: 1600);
  }

  Future<bool> _confirmIfFar(Position position) async {
    if (_report.latitude == null || _report.longitude == null) return true;

    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      _report.latitude!,
      _report.longitude!,
    );
    if (distance <= 100) return true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تنبيه موقع'),
        content: Text(
          'أنت بعيد عن موقع البلاغ بحوالي ${distance.round()} متر. هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('متابعة'),
          ),
        ],
      ),
    );

    return confirmed == true;
  }

  Future<void> _startWork() async {
    final id = _report.id;
    if (id == null) return;
    final position = await _currentPosition();
    if (position == null) return;
    if (!await _confirmIfFar(position)) return;
    final image = await _chooseImage(
      title: 'صورة قبل التنفيذ',
      requiredImage: false,
    );

    await _sendMultipart(
      path: '${ApiConstants.departmentReports}/$id/field/start',
      fields: {'latitude': position.latitude, 'longitude': position.longitude},
      fileField: image == null ? null : 'before_image',
      file: image,
      successMessage: 'تم تسجيل بدء العمل.',
    );
  }

  Future<void> _finishWork() async {
    final id = _report.id;
    if (id == null) return;
    final position = await _currentPosition();
    if (position == null) return;
    final image = await _chooseImage(
      title: 'صورة بعد التنفيذ',
      requiredImage: true,
    );
    if (image == null) {
      _showMessage('صورة الإنجاز مطلوبة عند إنهاء العمل.', isError: true);
      return;
    }

    await _sendMultipart(
      path: '${ApiConstants.departmentReports}/$id/field/finish',
      fields: {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'note': _finishNoteController.text.trim(),
      },
      fileField: 'after_image',
      file: image,
      successMessage: 'تم إنهاء العمل وإغلاق البلاغ.',
      popAfterSuccess: true,
    );
  }

  Future<void> _cannotComplete() async {
    final id = _report.id;
    if (id == null) return;
    final reason = _blockedReasonController.text.trim();
    if (reason.isEmpty) {
      _showMessage('اكتب سبب تعذر الإتمام.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await ref
          .read(dioProvider)
          .post(
            '${ApiConstants.departmentReports}/$id/field/cannot-complete',
            data: {'reason': reason},
          );
      final data = response.data['report'] ?? response.data;
      if (!mounted) return;
      setState(
        () => _report = ReportModel.fromJson(Map<String, dynamic>.from(data)),
      );
      _showMessage('تم تسجيل تعذر الإتمام.');
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMultipart({
    required String path,
    required Map<String, Object?> fields,
    String? fileField,
    XFile? file,
    required String successMessage,
    bool popAfterSuccess = false,
  }) async {
    setState(() => _isLoading = true);
    try {
      final formData = FormData.fromMap({
        ...fields,
        if (fileField != null && file != null)
          fileField: await MultipartFile.fromFile(
            file.path,
            filename: file.name,
          ),
      });

      final response = await ref.read(dioProvider).post(path, data: formData);
      final data = response.data['report'] ?? response.data;
      if (!mounted) return;
      setState(
        () => _report = ReportModel.fromJson(Map<String, dynamic>.from(data)),
      );
      _showMessage(successMessage);
      if (popAfterSuccess && mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendComment() async {
    final id = _report.id;
    final text = _commentController.text.trim();
    if (id == null || text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await ref
          .read(dioProvider)
          .post(
            '${ApiConstants.departmentReports}/$id/comments',
            data: {'comment_text': text},
          );
      _commentController.clear();
      await _loadDetails();
      _showMessage('تم إرسال الرد.');
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openMap() async {
    final lat = _report.latitude;
    final lng = _report.longitude;
    if (lat == null || lng == null) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryImage = _absoluteImageUrl(_report.imageUrl);
    final afterImage = _absoluteImageUrl(_report.completionImageUrl);

    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل البلاغ')),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _InfoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _report.category,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          _StatusChip(status: _report.status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (primaryImage != null)
                        _NetworkImage(url: primaryImage),
                      const SizedBox(height: 12),
                      Text(
                        _report.description.isEmpty
                            ? 'بدون وصف'
                            : _report.description,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _openMap,
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('عرض الموقع على الخريطة'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _InfoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'الإجراءات الميدانية',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: _isClosed(_report.status)
                            ? null
                            : _startWork,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('بدء العمل على البلاغ'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _finishNoteController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظة الإنهاء الاختيارية',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _isClosed(_report.status)
                            ? null
                            : _finishWork,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('إنهاء العمل وإغلاق البلاغ'),
                      ),
                      const Divider(height: 24),
                      TextField(
                        controller: _blockedReasonController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'سبب تعذر الإتمام',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _isClosed(_report.status)
                            ? null
                            : _cannotComplete,
                        icon: const Icon(Icons.report_problem_outlined),
                        label: const Text('لا يمكن إتمام العمل حالياً'),
                      ),
                    ],
                  ),
                ),
                if (afterImage != null) ...[
                  const SizedBox(height: 12),
                  _InfoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'صورة الإنجاز',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        _NetworkImage(url: afterImage),
                        if ((_report.completionReport ?? '').isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(_report.completionReport!),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _InfoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'الرد على المواطن',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _commentController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'اكتب ردك هنا',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _sendComment,
                        icon: const Icon(Icons.send_outlined),
                        label: const Text('إرسال الرد'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _InfoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'سجل التعليقات',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (_report.comments.isEmpty)
                        const Text('لا توجد تعليقات بعد.')
                      else
                        ..._report.comments.map(
                          (comment) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(comment.authorName),
                            subtitle: Text(comment.text),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (_isLoading)
              Container(
                color: Colors.black.withValues(alpha: 0.12),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  bool _isClosed(String status) => status.toLowerCase() == 'closed';
}

class _DepartmentReportCard extends StatelessWidget {
  const _DepartmentReportCard({required this.report, required this.onTap});

  final ReportEntity report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        title: Text(
          report.category,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          report.description.isEmpty ? 'بدون وصف' : report.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: _StatusChip(status: report.status),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }
}

class _NetworkImage extends StatelessWidget {
  const _NetworkImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url,
        height: 190,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'transferred' => 'محولة',
      'in_progress' => 'قيد التنفيذ',
      'pending' => 'معلقة',
      'closed' => 'مغلقة',
      _ => status,
    };

    return Chip(label: Text(label), visualDensity: VisualDensity.compact);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Center(child: Text('لا توجد بلاغات حالياً.')),
    );
  }
}

String? _absoluteImageUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('http://') || url.startsWith('https://')) return url;
  return '${_apiOrigin()}$url';
}
