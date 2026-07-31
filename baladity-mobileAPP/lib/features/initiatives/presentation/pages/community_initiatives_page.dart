import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/network/api_constants.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class CommunityInitiativesPage extends ConsumerStatefulWidget {
  final bool showAppBar;

  const CommunityInitiativesPage({super.key, this.showAppBar = true});

  @override
  ConsumerState<CommunityInitiativesPage> createState() =>
      _CommunityInitiativesPageState();
}

class _CommunityInitiativesPageState
    extends ConsumerState<CommunityInitiativesPage> {
  String _scope = 'available';
  String _status = '';
  bool _isLoading = false;
  List<_Initiative> _initiatives = const [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        ApiConstants.initiatives,
        queryParameters: {
          'scope': _scope,
          if (_status.isNotEmpty) 'status': _status,
          'per_page': 100,
        },
      );
      final raw = response.data['data'] ?? response.data;
      final list = raw is List ? raw : const [];
      if (!mounted) return;
      setState(() {
        _initiatives = list
            .whereType<Map>()
            .map((item) => _Initiative.fromJson(item))
            .toList(growable: false);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openDetails(_Initiative initiative) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('${ApiConstants.initiatives}/${initiative.id}');
      final detailed = _Initiative.fromJson(response.data['initiative'] ?? {});
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _InitiativeDetailsPage(
            initiative: detailed,
            onChanged: _load,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: widget.showAppBar
          ? Scaffold(
              appBar: AppBar(title: const Text('المبادرات والحملات')),
              body: body,
            )
          : body,
    );
  }

  Widget _buildBody() {
    const primaryGreen = Color(0xFF2E7D32);

    return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'available', label: Text('المتاحة')),
                        ButtonSegment(value: 'my', label: Text('مبادراتي')),
                      ],
                      selected: {_scope},
                      onSelectionChanged: (value) {
                        setState(() => _scope = value.first);
                        _load();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _status,
                    items: const [
                      DropdownMenuItem(value: '', child: Text('كل الحالات')),
                      DropdownMenuItem(value: 'published', child: Text('متاحة للتسجيل')),
                      DropdownMenuItem(value: 'registration_closed', child: Text('مغلقة')),
                      DropdownMenuItem(value: 'completed', child: Text('منتهية')),
                      DropdownMenuItem(value: 'cancelled', child: Text('ملغاة')),
                    ],
                    onChanged: (value) {
                      setState(() => _status = value ?? '');
                      _load();
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading && _initiatives.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _initiatives.isEmpty
                      ? const Center(child: Text('لا توجد مبادرات حالياً'))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _initiatives.length,
                            itemBuilder: (context, index) {
                              final initiative = _initiatives[index];
                              return _InitiativeCard(
                                initiative: initiative,
                                primaryGreen: primaryGreen,
                                onTap: () => _openDetails(initiative),
                              );
                            },
                          ),
                        ),
            ),
          ],
    );
  }
}

class _InitiativeDetailsPage extends ConsumerStatefulWidget {
  final _Initiative initiative;
  final Future<void> Function() onChanged;

  const _InitiativeDetailsPage({
    required this.initiative,
    required this.onChanged,
  });

  @override
  ConsumerState<_InitiativeDetailsPage> createState() =>
      _InitiativeDetailsPageState();
}

class _InitiativeDetailsPageState
    extends ConsumerState<_InitiativeDetailsPage> {
  late _Initiative _initiative;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _initiative = widget.initiative;
  }

  Future<void> _refresh() async {
    final dio = ref.read(dioProvider);
    final response = await dio.get('${ApiConstants.initiatives}/${_initiative.id}');
    if (!mounted) return;
    setState(() => _initiative = _Initiative.fromJson(response.data['initiative'] ?? {}));
  }

  Future<void> _register() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد التسجيل'),
        content: const Text('هل أنت متأكد من التسجيل؟ الالتزام بالحضور مطلوب.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('تسجيل')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() => ref.read(dioProvider).post('${ApiConstants.initiatives}/${_initiative.id}/register'));
  }

  Future<void> _cancelRegistration() async {
    await _run(() => ref.read(dioProvider).delete('${ApiConstants.initiatives}/${_initiative.id}/register'));
  }

  Future<void> _confirmAttendance() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showMessage('يرجى تفعيل خدمة الموقع أولاً.', isError: true);
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _showMessage('يرجى السماح للتطبيق باستخدام الموقع.', isError: true);
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        timeLimit: Duration(seconds: 12),
      ),
    );

    await _run(
      () => ref.read(dioProvider).post(
            '${ApiConstants.initiatives}/${_initiative.id}/attendance',
            data: {
              'latitude': position.latitude,
              'longitude': position.longitude,
            },
          ),
      successMessage: 'تم تسجيل حضورك بنجاح.',
    );
  }

  Future<void> _openInitiativeLocation() async {
    final latitude = _initiative.latitude;
    final longitude = _initiative.longitude;

    if (latitude == null || longitude == null) {
      _showMessage('لا توجد إحداثيات محفوظة لهذه المبادرة.', isError: true);
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

  Future<void> _run(
    Future<dynamic> Function() action, {
    String successMessage = 'تم تنفيذ العملية بنجاح.',
  }) async {
    setState(() => _isBusy = true);
    try {
      await action();
      await _refresh();
      await widget.onChanged();
      _showMessage(successMessage);
    } catch (e) {
      _showMessage(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[700] : Colors.green[700],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _absoluteUrl(_initiative.coverImageUrl);
    final completionImageUrl = _absoluteUrl(_initiative.completionImageUrl);
    const primaryGreen = Color(0xFF2E7D32);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(_initiative.title)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(imageUrl, height: 210, width: double.infinity, fit: BoxFit.cover),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _Chip(label: _initiative.statusLabel),
                  const SizedBox(width: 8),
                  _Chip(label: _initiative.typeLabel),
                ],
              ),
              const SizedBox(height: 12),
              Text(_initiative.description, style: const TextStyle(fontSize: 15)),
              if (_initiative.goal?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text('الهدف: ${_initiative.goal}'),
              ],
              if (_initiative.targetAudience?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text('الفئة المستهدفة: ${_initiative.targetAudience}'),
              ],
              if (_initiative.requirements?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text('المتطلبات: ${_initiative.requirements}'),
              ],
              const SizedBox(height: 16),
              _InfoRow(icon: Icons.calendar_today_outlined, text: _initiative.dateText),
              _InfoRow(icon: Icons.group_outlined, text: _initiative.capacityText),
              _InfoRow(icon: Icons.location_on_outlined, text: 'نطاق الحضور ${_initiative.radiusMeters} متر'),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openInitiativeLocation,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('عرض الموقع على الخريطة'),
                ),
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _initiative.capacityProgress,
                color: primaryGreen,
                backgroundColor: Colors.grey.withValues(alpha: 0.2),
              ),
              if (_initiative.cancelReason?.isNotEmpty == true) ...[
                const SizedBox(height: 16),
                Text('سبب الإلغاء: ${_initiative.cancelReason}', style: const TextStyle(color: Colors.red)),
              ],
              if (completionImageUrl != null) ...[
                const SizedBox(height: 16),
                const Text('صورة الإنجاز', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(completionImageUrl, height: 210, width: double.infinity, fit: BoxFit.cover),
                ),
              ],
              const SizedBox(height: 24),
              if (_initiative.isRegistered)
                FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('أنت مسجل'),
                ),
              const SizedBox(height: 8),
              if (_initiative.canRegister)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isBusy ? null : _register,
                    child: const Text('سجل كمتطوع'),
                  ),
                ),
              if (_initiative.canCancelRegistration)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _isBusy ? null : _cancelRegistration,
                    child: const Text('إلغاء التسجيل'),
                  ),
                ),
              if (_initiative.canConfirmAttendance)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isBusy ? null : _confirmAttendance,
                    icon: const Icon(Icons.my_location),
                    label: const Text('تأكيد الحضور'),
                  ),
                ),
              if (_initiative.hasAttended)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('تم تسجيل حضورك لهذه المبادرة.', style: TextStyle(color: primaryGreen)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InitiativeCard extends StatelessWidget {
  final _Initiative initiative;
  final Color primaryGreen;
  final VoidCallback onTap;

  const _InitiativeCard({
    required this.initiative,
    required this.primaryGreen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = _absoluteUrl(initiative.coverImageUrl);
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null)
              Image.network(imageUrl, height: 150, width: double.infinity, fit: BoxFit.cover),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          initiative.title,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryGreen),
                        ),
                      ),
                      _Chip(label: initiative.statusLabel),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(initiative.dateText, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: LinearProgressIndicator(value: initiative.capacityProgress, color: primaryGreen)),
                      const SizedBox(width: 10),
                      Text(initiative.capacityText, style: const TextStyle(fontSize: 12)),
                    ],
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

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

class _Chip extends StatelessWidget {
  final String label;

  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF2E7D32))),
    );
  }
}

class _Initiative {
  final int id;
  final String title;
  final String description;
  final String? goal;
  final String initiativeType;
  final String? coverImageUrl;
  final String? completionImageUrl;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final double? latitude;
  final double? longitude;
  final int radiusMeters;
  final int? maxCapacity;
  final String? targetAudience;
  final String? requirements;
  final String status;
  final String? cancelReason;
  final int registeredCount;
  final int attendeesCount;
  final bool isRegistered;
  final bool hasAttended;
  final bool canRegister;
  final bool canCancelRegistration;
  final bool canConfirmAttendance;

  const _Initiative({
    required this.id,
    required this.title,
    required this.description,
    required this.goal,
    required this.initiativeType,
    required this.coverImageUrl,
    required this.completionImageUrl,
    required this.startsAt,
    required this.endsAt,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.maxCapacity,
    required this.targetAudience,
    required this.requirements,
    required this.status,
    required this.cancelReason,
    required this.registeredCount,
    required this.attendeesCount,
    required this.isRegistered,
    required this.hasAttended,
    required this.canRegister,
    required this.canCancelRegistration,
    required this.canConfirmAttendance,
  });

  factory _Initiative.fromJson(Map<dynamic, dynamic> json) {
    return _Initiative(
      id: _int(json['id']),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      goal: json['goal']?.toString(),
      initiativeType: json['initiative_type']?.toString() ?? 'other',
      coverImageUrl: json['cover_image_url']?.toString(),
      completionImageUrl: json['completion_image_url']?.toString(),
      startsAt: _date(json['starts_at']),
      endsAt: _date(json['ends_at']),
      latitude: _doubleOrNull(json['latitude']),
      longitude: _doubleOrNull(json['longitude']),
      radiusMeters: _int(json['radius_meters'], fallback: 100),
      maxCapacity: _intOrNull(json['max_capacity']),
      targetAudience: json['target_audience']?.toString(),
      requirements: json['requirements']?.toString(),
      status: json['status']?.toString() ?? '',
      cancelReason: json['cancel_reason']?.toString(),
      registeredCount: _int(json['registered_count']),
      attendeesCount: _int(json['attendees_count']),
      isRegistered: json['is_registered'] == true,
      hasAttended: json['has_attended'] == true,
      canRegister: json['can_register'] == true,
      canCancelRegistration: json['can_cancel_registration'] == true,
      canConfirmAttendance: json['can_confirm_attendance'] == true,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'published':
        return 'متاحة للتسجيل';
      case 'registration_closed':
        return 'مغلقة التسجيل';
      case 'completed':
        return 'منتهية';
      case 'cancelled':
        return 'ملغاة';
      default:
        return status;
    }
  }

  String get typeLabel {
    switch (initiativeType) {
      case 'tree_planting':
        return 'تشجير';
      case 'cleaning':
        return 'نظافة';
      case 'painting':
        return 'طلاء';
      case 'awareness':
        return 'توعية';
      default:
        return 'أخرى';
    }
  }

  String get capacityText => maxCapacity == null
      ? '$registeredCount مسجل'
      : '$registeredCount/$maxCapacity متطوع';

  double? get capacityProgress {
    if (maxCapacity == null || maxCapacity == 0) return null;
    return (registeredCount / maxCapacity!).clamp(0, 1).toDouble();
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
}

String? _absoluteUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('http')) return url;
  final origin = ApiConstants.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
  return '$origin$url';
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}

int _int(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? _intOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double? _doubleOrNull(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

String _two(int value) => value.toString().padLeft(2, '0');

String _formatDateTime(DateTime value) {
  return '${value.year}-${_two(value.month)}-${_two(value.day)} ${_formatTime(value)}';
}

String _formatTime(DateTime value) {
  return '${_two(value.hour)}:${_two(value.minute)}';
}
