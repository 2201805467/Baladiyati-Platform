import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/network/api_constants.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class GeoBroadcastsPage extends ConsumerStatefulWidget {
  final bool showAppBar;

  const GeoBroadcastsPage({super.key, this.showAppBar = true});

  @override
  ConsumerState<GeoBroadcastsPage> createState() => _GeoBroadcastsPageState();
}

class _GeoBroadcastsPageState extends ConsumerState<GeoBroadcastsPage> {
  bool _isLoading = false;
  List<_GeoBroadcast> _broadcasts = const [];

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _syncCurrentLocationIfAllowed();
      await _load();
    });
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final response = await ref.read(dioProvider).get(
        ApiConstants.geoBroadcasts,
        queryParameters: {'per_page': 100},
      );
      final raw = response.data['data'] ?? response.data;
      final list = raw is List ? raw : const [];
      if (!mounted) return;
      setState(() {
        _broadcasts = list
            .whereType<Map>()
            .map((item) => _GeoBroadcast.fromJson(item))
            .toList(growable: false);
      });
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _syncCurrentLocationIfAllowed() async {
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
          timeLimit: Duration(seconds: 10),
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
      // Silent sync. The page can still show broadcasts received by home location.
    }
  }

  Future<void> _saveHomeLocation() async {
    final selected = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(builder: (_) => const _HomeLocationPickerPage()),
    );
    if (selected == null) return;

    try {
      await ref.read(dioProvider).put(
        ApiConstants.geoBroadcastHomeLocation,
        data: {
          'home_latitude': selected.latitude,
          'home_longitude': selected.longitude,
          'location_sharing_enabled': true,
        },
      );
      _showMessage('تم حفظ موقع السكن بنجاح.');
      await _load();
    } catch (e) {
      _showMessage(e.toString(), isError: true);
    }
  }

  Future<void> _openBroadcastLocation(_GeoBroadcast broadcast) async {
    final latitude = broadcast.latitude;
    final longitude = broadcast.longitude;
    if (latitude == null || longitude == null) {
      _showMessage('لا توجد إحداثيات لهذا التنبيه.', isError: true);
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
    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saveHomeLocation,
                  icon: const Icon(Icons.home_work_outlined),
                  label: const Text('تحديد موقع السكن'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                tooltip: 'تحديث',
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading && _broadcasts.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _broadcasts.isEmpty
                  ? const Center(
                      child: Text('لا توجد تنبيهات جغرافية مرتبطة بموقعك حالياً'),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _broadcasts.length,
                        itemBuilder: (context, index) {
                          final broadcast = _broadcasts[index];
                          return _GeoBroadcastCard(
                            broadcast: broadcast,
                            onMap: () => _openBroadcastLocation(broadcast),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: widget.showAppBar
          ? Scaffold(
              appBar: AppBar(title: const Text('التنبيهات الجغرافية')),
              body: body,
            )
          : body,
    );
  }
}

class _GeoBroadcastCard extends StatelessWidget {
  final _GeoBroadcast broadcast;
  final VoidCallback onMap;

  const _GeoBroadcastCard({required this.broadcast, required this.onMap});

  @override
  Widget build(BuildContext context) {
    final color = broadcast.typeColor;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.warning_amber_rounded, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    broadcast.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _Chip(label: broadcast.typeLabel, color: color),
              ],
            ),
            const SizedBox(height: 10),
            Text(broadcast.body),
            const SizedBox(height: 10),
            _InfoRow(icon: Icons.schedule, text: broadcast.dateText),
            _InfoRow(icon: Icons.radar, text: 'النطاق: ${broadcast.radiusMeters} متر'),
            if (broadcast.cancelReason?.isNotEmpty == true)
              _InfoRow(icon: Icons.cancel_outlined, text: 'سبب الإلغاء: ${broadcast.cancelReason}'),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onMap,
                icon: const Icon(Icons.map_outlined),
                label: const Text('عرض الموقع على الخريطة'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeLocationPickerPage extends StatefulWidget {
  const _HomeLocationPickerPage();

  @override
  State<_HomeLocationPickerPage> createState() => _HomeLocationPickerPageState();
}

class _HomeLocationPickerPageState extends State<_HomeLocationPickerPage> {
  static const _tripoli = LatLng(32.8872, 13.1913);
  LatLng? _selectedLocation;

  void _onTap(TapPosition _, LatLng latLng) {
    setState(() => _selectedLocation = latLng);
  }

  @override
  Widget build(BuildContext context) {
    final center = _selectedLocation ?? _tripoli;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تحديد موقع السكن'),
          actions: [
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _selectedLocation == null
                  ? null
                  : () => Navigator.pop(context, _selectedLocation),
            ),
          ],
        ),
        body: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 13,
                minZoom: 3,
                maxZoom: 18,
                onTap: _onTap,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.baladity',
                ),
                if (_selectedLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selectedLocation!,
                        width: 48,
                        height: 48,
                        child: const Icon(
                          Icons.home_work_outlined,
                          color: Color(0xFF2E7D32),
                          size: 44,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.touch_app,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('اضغط على الخريطة لتحديد موقع السكن'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: FilledButton(
                onPressed: _selectedLocation == null
                    ? null
                    : () => Navigator.pop(context, _selectedLocation),
                child: const Text('حفظ موقع السكن'),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
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
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _GeoBroadcast {
  final int id;
  final String title;
  final String body;
  final String broadcastType;
  final double? latitude;
  final double? longitude;
  final int radiusMeters;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String status;
  final String? cancelReason;

  const _GeoBroadcast({
    required this.id,
    required this.title,
    required this.body,
    required this.broadcastType,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.cancelReason,
  });

  factory _GeoBroadcast.fromJson(Map<dynamic, dynamic> json) {
    return _GeoBroadcast(
      id: _int(json['id']),
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      broadcastType: json['broadcast_type']?.toString() ?? 'info',
      latitude: _doubleOrNull(json['latitude']),
      longitude: _doubleOrNull(json['longitude']),
      radiusMeters: _int(json['radius_meters'], fallback: 500),
      startsAt: _date(json['starts_at']),
      endsAt: _date(json['ends_at']),
      status: json['status']?.toString() ?? '',
      cancelReason: json['cancel_reason']?.toString(),
    );
  }

  String get typeLabel {
    switch (broadcastType) {
      case 'critical':
        return 'طارئ';
      case 'service':
        return 'خدمي';
      case 'works':
        return 'أعمال';
      case 'weather':
        return 'طقس';
      default:
        return 'معلومة';
    }
  }

  Color get typeColor {
    switch (broadcastType) {
      case 'critical':
        return Colors.red;
      case 'service':
        return Colors.blue;
      case 'works':
        return Colors.orange;
      case 'weather':
        return Colors.indigo;
      default:
        return const Color(0xFF2E7D32);
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
