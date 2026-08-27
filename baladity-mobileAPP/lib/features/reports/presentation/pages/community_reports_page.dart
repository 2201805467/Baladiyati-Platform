import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/network/api_constants.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/models/report_comment_model.dart';
import '../../data/models/report_model.dart';
import '../../domain/entities/report_comment_entity.dart';
import '../../domain/entities/report_entity.dart';

String _apiOrigin() {
  final baseUrl = ApiConstants.baseUrl;
  if (baseUrl.endsWith('/api/')) {
    return baseUrl.substring(0, baseUrl.length - 5);
  }
  if (baseUrl.endsWith('/api')) {
    return baseUrl.substring(0, baseUrl.length - 4);
  }
  return baseUrl;
}

String? _absoluteImageUrl(String? value) {
  if (value == null || value.isEmpty) return null;
  if (value.startsWith('http')) return value;

  final base = _apiOrigin();
  return value.startsWith('/') ? '$base$value' : '$base/$value';
}

class CommunityReportsPage extends ConsumerStatefulWidget {
  const CommunityReportsPage({super.key});

  @override
  ConsumerState<CommunityReportsPage> createState() =>
      _CommunityReportsPageState();
}

class _CommunityReportsPageState extends ConsumerState<CommunityReportsPage> {
  final List<ReportEntity> _reports = [];
  double _radiusKm = 5;
  bool _isLoading = false;
  String? _error;
  Position? _position;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadReports);
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _position ??= await _currentPositionOrNull();
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        ApiConstants.communityReports,
        queryParameters: {
          'radius_km': _radiusKm,
          if (_position != null) 'latitude': _position!.latitude,
          if (_position != null) 'longitude': _position!.longitude,
        },
      );

      final raw = response.data['data'] ?? response.data;
      final items = raw is List ? raw : const [];
      final reports = items
          .whereType<Map>()
          .map((e) => ReportModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      if (!mounted) return;
      setState(() {
        _reports
          ..clear()
          ..addAll(reports);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = _messageFromError(e);
      });
    }
  }

  Future<Position?> _currentPositionOrNull() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _openDetails(ReportEntity report) async {
    final updated = await Navigator.of(context).push<ReportEntity>(
      MaterialPageRoute(
        builder: (_) => CommunityReportDetailsPage(report: report),
      ),
    );

    if (updated != null) {
      _replaceReport(updated);
    }
  }

  void _replaceReport(ReportEntity report) {
    final index = _reports.indexWhere((item) => item.id == report.id);
    if (index == -1) return;
    setState(() {
      _reports[index] = report;
    });
  }

  @override
  Widget build(BuildContext context) {
    final reportsWithLocation = _reports
        .where((report) => report.latitude != null && report.longitude != null)
        .toList();
    final mapCenter = _position != null
        ? LatLng(_position!.latitude, _position!.longitude)
        : reportsWithLocation.isNotEmpty
            ? LatLng(
                reportsWithLocation.first.latitude!,
                reportsWithLocation.first.longitude!,
              )
            : const LatLng(32.8872, 13.1913);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('بلاغات قريبة'),
          centerTitle: true,
        ),
        body: RefreshIndicator(
          onRefresh: _loadReports,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
            children: [
              _CommunityReportsMap(
                center: mapCenter,
                reports: reportsWithLocation,
                radiusKm: _radiusKm,
                userLocation: _position == null
                    ? null
                    : LatLng(_position!.latitude, _position!.longitude),
                onOpenReport: _openDetails,
              ),
              const SizedBox(height: 10),
              _RadiusSelector(
                radiusKm: _radiusKm,
                onChanged: (value) {
                  setState(() => _radiusKm = value);
                  _loadReports();
                },
              ),
              if (_position == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'لم يتم تحديد موقعك حالياً، لذلك قد تظهر أحدث البلاغات المتاحة بدلاً من الأقرب إليك.',
                    style: TextStyle(
                      fontSize: 12,
                      color: _secondaryTextColor(context),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.only(top: 80),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                )
              else if (_error != null)
                _EmptyState(
                  icon: Icons.wifi_off_rounded,
                  title: 'تعذر تحميل بلاغات الجيران',
                  subtitle: _error!,
                  actionLabel: 'إعادة المحاولة',
                  onAction: _loadReports,
                )
              else if (_reports.isEmpty)
                const _EmptyState(
                  icon: Icons.location_off_outlined,
                  title: 'لا توجد بلاغات قريبة حالياً',
                  subtitle: 'جرّب توسيع نطاق البحث أو تحديث الصفحة.',
                )
              else
                ..._reports.map(
                  (report) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CommunityReportCard(
                      report: report,
                      onTap: () => _openDetails(report),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommunityReportsMap extends StatelessWidget {
  const _CommunityReportsMap({
    required this.center,
    required this.reports,
    required this.radiusKm,
    required this.onOpenReport,
    this.userLocation,
  });

  final LatLng center;
  final LatLng? userLocation;
  final List<ReportEntity> reports;
  final double radiusKm;
  final ValueChanged<ReportEntity> onOpenReport;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final overlayColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xDD0B1B15)
        : colorScheme.surface.withOpacity(0.92);
    final overlayTextColor = colorScheme.onSurface;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 235,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 12,
                minZoom: 3,
                maxZoom: 18,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.baladity',
                ),
                MarkerLayer(
                  markers: [
                    if (userLocation != null)
                      Marker(
                        point: userLocation!,
                        width: 42,
                        height: 42,
                        child: Icon(
                          Icons.my_location_rounded,
                          color: colorScheme.primary,
                          size: 30,
                        ),
                      ),
                    ...reports.map(
                      (report) => Marker(
                        point: LatLng(report.latitude!, report.longitude!),
                        width: 44,
                        height: 44,
                        child: GestureDetector(
                          onTap: () => _showMapReport(context, report),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: _reportAccentColor(report),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black38,
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.report_problem_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: overlayColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _subtleBorderColor(context)),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.near_me_outlined,
                        color: overlayTextColor.withOpacity(0.72),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          reports.isEmpty
                              ? 'داخل نطاق ${_formatRadius(radiusKm)} كم'
                              : 'داخل نطاق ${_formatRadius(radiusKm)} كم · ${reports.length} بلاغ',
                          style: TextStyle(
                            color: overlayTextColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: reports.isEmpty
                            ? null
                            : () => onOpenReport(reports.first),
                        icon: Icon(
                          Icons.gps_fixed_rounded,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMapReport(BuildContext context, ReportEntity report) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                report.category.isEmpty ? 'بلاغ خدمي' : report.category,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                report.description.isEmpty ? 'بدون وصف' : report.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _secondaryTextColor(context)),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onOpenReport(report);
                  },
                  child: const Text('عرض التفاصيل'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CommunityReportDetailsPage extends ConsumerStatefulWidget {
  const CommunityReportDetailsPage({super.key, required this.report});

  final ReportEntity report;

  @override
  ConsumerState<CommunityReportDetailsPage> createState() =>
      _CommunityReportDetailsPageState();
}

class _CommunityReportDetailsPageState
    extends ConsumerState<CommunityReportDetailsPage> {
  final _commentController = TextEditingController();
  late ReportEntity _report = widget.report;
  bool _isLoading = false;
  bool _isSendingComment = false;
  bool _isVoting = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadDetails);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    final id = _report.id;
    if (id == null) return;

    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('${ApiConstants.communityReports}/$id');
      final data = response.data['report'] ?? response.data;
      if (!mounted || data is! Map) return;
      setState(() {
        _report = ReportModel.fromJson(Map<String, dynamic>.from(data));
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(e);
    }
  }

  Future<void> _sendComment() async {
    final id = _report.id;
    final text = _commentController.text.trim();
    if (id == null || text.isEmpty) return;

    setState(() => _isSendingComment = true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '${ApiConstants.communityReports}/$id/comments',
        data: {'comment_text': text},
      );
      final data = response.data['comment'];
      if (!mounted || data is! Map) return;

      final comment = ReportCommentModel.fromJson(
        Map<String, dynamic>.from(data),
      );
      setState(() {
        _commentController.clear();
        _report = _copyReport(
          _report,
          comments: [..._report.comments, comment],
        );
        _isSendingComment = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSendingComment = false);
      _showError(e);
    }
  }

  Future<void> _vote(String voteType) async {
    final id = _report.id;
    if (id == null || _isVoting) return;

    setState(() => _isVoting = true);
    try {
      final dio = ref.read(dioProvider);
      final response = _report.viewerVote == voteType
          ? await dio.delete('${ApiConstants.communityReports}/$id/vote')
          : await dio.post(
              '${ApiConstants.communityReports}/$id/vote',
              data: {'vote_type': voteType},
            );
      final data = response.data['report'];
      if (!mounted || data is! Map) return;
      setState(() {
        _report = ReportModel.fromJson(Map<String, dynamic>.from(data));
        _isVoting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isVoting = false);
      _showError(e);
    }
  }

  Future<void> _openReportLocation() async {
    final latitude = _report.latitude;
    final longitude = _report.longitude;

    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد إحداثيات محفوظة لهذا البلاغ')),
      );
      return;
    }

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

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_messageFromError(error)),
        backgroundColor: Colors.red[700],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _absoluteImageUrl(_report.imageUrl);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تفاصيل بلاغ جار'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(_report),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _report.category.isEmpty
                                      ? 'بلاغ خدمي'
                                      : _report.category,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              _StatusBadge(label: _report.status),
                            ],
                          ),
                          if (imageUrl != null) ...[
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                imageUrl,
                                height: 210,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Text(
                            _report.description.isEmpty
                                ? 'بدون وصف'
                                : _report.description,
                            style: const TextStyle(height: 1.5),
                          ),
                          if (_report.latitude != null &&
                              _report.longitude != null) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _openReportLocation,
                              icon: const Icon(Icons.map_outlined),
                              label: const Text('العرض على الخريطة'),
                            ),
                          ],
                          if (_report.distanceKm != null) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.near_me_outlined, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  '${_report.distanceKm!.toStringAsFixed(2)} كم تقريباً',
                                ),
                              ],
                            ),
                          ],
                          const Divider(height: 28),
                          _VoteBar(
                            report: _report,
                            isVoting: _isVoting,
                            onVote: _vote,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _CommunityComments(
                    comments: _report.comments,
                    controller: _commentController,
                    isSubmitting: _isSendingComment,
                    onSend: _sendComment,
                  ),
                ],
              ),
      ),
    );
  }
}

class _RadiusSelector extends StatelessWidget {
  const _RadiusSelector({required this.radiusKm, required this.onChanged});

  final double radiusKm;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: _adaptiveCardColor(context),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: _subtleBorderColor(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(
              Icons.social_distance_outlined,
              color: Color(0xFF22C55E),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'نطاق بلاغات الجيران',
              ),
            ),
            DropdownButton<double>(
              value: radiusKm,
              dropdownColor: _adaptiveCardColor(context),
              style: TextStyle(color: colorScheme.onSurface),
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(value: 1.0, child: Text('1 كم')),
                DropdownMenuItem(value: 3.0, child: Text('3 كم')),
                DropdownMenuItem(value: 5.0, child: Text('5 كم')),
                DropdownMenuItem(value: 10.0, child: Text('10 كم')),
                DropdownMenuItem(value: 25.0, child: Text('25 كم')),
              ],
              onChanged: (value) {
                if (value != null) onChanged(value);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityReportCard extends StatelessWidget {
  const _CommunityReportCard({required this.report, required this.onTap});

  final ReportEntity report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _absoluteImageUrl(report.imageUrl);
    final accent = _reportAccentColor(report);
    final colorScheme = Theme.of(context).colorScheme;
    final secondaryTextColor = _secondaryTextColor(context);

    return Card(
      color: _adaptiveCardColor(context),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: accent.withOpacity(0.35)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    imageUrl,
                    height: 86,
                    width: 92,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      height: 86,
                      width: 92,
                      color: colorScheme.onSurface.withOpacity(0.08),
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: secondaryTextColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _CompactBadge(label: report.status, color: accent),
                        const Spacer(),
                        if (report.createdAt != null)
                          Text(
                            _shortTime(report.createdAt!),
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      report.category.isEmpty ? 'بلاغ خدمي' : report.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report.description.isEmpty
                          ? 'بدون وصف'
                          : report.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Icon(
                          Icons.thumb_up_alt_outlined,
                          size: 16,
                          color: Colors.green[400],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${report.upvotesCount}',
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.thumb_down_alt_outlined,
                          size: 16,
                          color: Colors.red[300],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${report.downvotesCount}',
                          style: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        if (report.distanceKm != null)
                          Text(
                            '${report.distanceKm!.toStringAsFixed(1)} كم',
                            style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoteBar extends StatelessWidget {
  const _VoteBar({
    required this.report,
    required this.isVoting,
    required this.onVote,
  });

  final ReportEntity report;
  final bool isVoting;
  final ValueChanged<String> onVote;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isVoting ? null : () => onVote('up'),
            icon: Icon(
              Icons.thumb_up_alt_rounded,
              color: report.viewerVote == 'up' ? Colors.green[700] : null,
            ),
            label: Text('أؤيد الحل (${report.upvotesCount})'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isVoting ? null : () => onVote('down'),
            icon: Icon(
              Icons.thumb_down_alt_rounded,
              color: report.viewerVote == 'down' ? Colors.red[700] : null,
            ),
            label: Text('لا أؤيد (${report.downvotesCount})'),
          ),
        ),
      ],
    );
  }
}

class _CompactBadge extends StatelessWidget {
  const _CompactBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}

class _CommunityComments extends StatelessWidget {
  const _CommunityComments({
    required this.comments,
    required this.controller,
    required this.isSubmitting,
    required this.onSend,
  });

  final List<ReportCommentEntity> comments;
  final TextEditingController controller;
  final bool isSubmitting;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'التعليقات المجتمعية',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (comments.isEmpty)
              const Text('لا توجد تعليقات بعد. كن أول من يضيف ملاحظة مفيدة.')
            else
              ...comments.map(
                (comment) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${comment.authorName} - ${comment.authorRole}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(comment.text),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'اكتب تعليقاً يساعد على توضيح البلاغ...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isSubmitting ? null : onSend,
                icon: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: const Text('إرسال التعليق'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Icon(icon, size: 54, color: colorScheme.primary),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: _secondaryTextColor(context)),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

ReportEntity _copyReport(
  ReportEntity current, {
  List<ReportCommentEntity>? comments,
}) {
  return ReportEntity(
    id: current.id,
    category: current.category,
    description: current.description,
    latitude: current.latitude,
    longitude: current.longitude,
    locationAddress: current.locationAddress,
    imageUrl: current.imageUrl,
    completionImageUrl: current.completionImageUrl,
    completionReport: current.completionReport,
    status: current.status,
    createdAt: current.createdAt,
    comments: comments ?? current.comments,
    ratingStars: current.ratingStars,
    ratingComment: current.ratingComment,
    upvotesCount: current.upvotesCount,
    downvotesCount: current.downvotesCount,
    viewerVote: current.viewerVote,
    distanceKm: current.distanceKm,
  );
}

Color _adaptiveCardColor(BuildContext context) {
  final theme = Theme.of(context);
  if (theme.brightness == Brightness.dark) {
    return const Color(0xFF0D1A14);
  }
  return theme.cardColor;
}

Color _subtleBorderColor(BuildContext context) {
  return Theme.of(context).colorScheme.outline.withOpacity(0.18);
}

Color _secondaryTextColor(BuildContext context) {
  return Theme.of(context).colorScheme.onSurface.withOpacity(0.68);
}

Color _reportAccentColor(ReportEntity report) {
  final status = report.status.toLowerCase();
  final category = report.category.toLowerCase();

  if (status.contains('مغل') ||
      status.contains('closed') ||
      status.contains('resolved')) {
    return const Color(0xFF22C55E);
  }
  if (status.contains('مراج') || status.contains('review')) {
    return const Color(0xFFF59E0B);
  }
  if (status.contains('محال') || status.contains('assigned')) {
    return const Color(0xFF38BDF8);
  }
  if (status.contains('معالج') || status.contains('progress')) {
    return const Color(0xFFA855F7);
  }
  if (category.contains('طريق') || category.contains('road')) {
    return const Color(0xFFF97316);
  }
  if (category.contains('إنارة') || category.contains('light')) {
    return const Color(0xFF3B82F6);
  }
  if (category.contains('نظاف') || category.contains('garbage')) {
    return const Color(0xFF10B981);
  }
  return const Color(0xFF8B5CF6);
}

String _shortTime(DateTime value) {
  final now = DateTime.now();
  final diff = now.difference(value);
  if (diff.inMinutes < 1) return 'الآن';
  if (diff.inMinutes < 60) return '${diff.inMinutes} د';
  if (diff.inHours < 24) return '${diff.inHours} س';
  return '${diff.inDays} ي';
}

String _formatRadius(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toStringAsFixed(1);
}

String _messageFromError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    if (error.type == DioExceptionType.connectionError) {
      return 'تعذر الاتصال بالخادم';
    }
  }
  return error.toString();
}
