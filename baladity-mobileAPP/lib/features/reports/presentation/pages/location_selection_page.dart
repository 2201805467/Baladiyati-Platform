import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/network/api_constants.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/models/report_model.dart';
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

class LocationSelectionPage extends ConsumerStatefulWidget {
  final LatLng? initialLocation;
  final int? categoryId;

  const LocationSelectionPage({
    super.key,
    this.initialLocation,
    this.categoryId,
  });

  @override
  ConsumerState<LocationSelectionPage> createState() =>
      _LocationSelectionPageState();
}

class _LocationSelectionPageState extends ConsumerState<LocationSelectionPage> {
  static const _tripoliCenter = LatLng(32.8872, 13.1913);

  LatLng? _selectedLocation;
  List<ReportEntity> _similarReports = const [];
  bool _isLoadingSimilar = false;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    Future.microtask(_loadSimilarReports);
  }

  void _onTap(TapPosition _, LatLng latLng) {
    setState(() => _selectedLocation = latLng);
  }

  Future<void> _loadSimilarReports() async {
    if (widget.categoryId == null) {
      setState(() => _similarReports = const []);
      return;
    }

    setState(() => _isLoadingSimilar = true);

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        ApiConstants.communityReports,
        queryParameters: {'category_id': widget.categoryId, 'per_page': 50},
      );

      final raw = response.data['data'];
      final list = raw is List ? raw : const [];
      final reports = list
          .whereType<Map>()
          .map((item) => ReportModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      if (!mounted) return;
      setState(() {
        _similarReports = reports;
        _isLoadingSimilar = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _similarReports = const [];
        _isLoadingSimilar = false;
      });
    }
  }

  void _showSimilarReport(ReportEntity report) {
    final imageUrl = _absoluteImageUrl(report.imageUrl);

    showModalBottomSheet(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  report.category.isEmpty ? 'بلاغ مشابه' : report.category,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  report.description.isEmpty ? 'بدون وصف' : report.description,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF2E7D32);
    final initialCenter = _selectedLocation ?? _tripoliCenter;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تحديد الموقع على الخريطة'),
        centerTitle: true,
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
              initialCenter: initialCenter,
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
                    ..._similarReports
                        .where(
                          (report) =>
                              report.latitude != null &&
                              report.longitude != null,
                        )
                        .map(
                          (report) => Marker(
                            point: LatLng(report.latitude!, report.longitude!),
                            width: 42,
                            height: 42,
                            child: GestureDetector(
                              onTap: () => _showSimilarReport(report),
                              child: const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.orange,
                                size: 36,
                              ),
                            ),
                          ),
                        ),
                    Marker(
                      point: _selectedLocation!,
                      width: 48,
                      height: 48,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 44,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (_selectedLocation != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                color: Theme.of(context).colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        _similarReports.isEmpty
                            ? Icons.check_circle_outline
                            : Icons.warning_amber_rounded,
                        color: _similarReports.isEmpty
                            ? Colors.green
                            : Colors.orange,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _isLoadingSimilar
                              ? 'جاري تحميل البلاغات المشابهة...'
                              : widget.categoryId == null
                              ? 'اختر التصنيف قبل فتح الخريطة لعرض البلاغات القريبة المشابهة.'
                              : _similarReports.isEmpty
                              ? 'لا توجد بلاغات مشابهة مفتوحة من نفس التصنيف.'
                              : 'يوجد ${_similarReports.length} بلاغ مشابه من نفس التصنيف. اضغط على العلامات البرتقالية للتفاصيل.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_selectedLocation == null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                color: Theme.of(context).colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.touch_app,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'اضغط على الخريطة لتحديد الموقع',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
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
            child: ElevatedButton(
              onPressed: _selectedLocation != null
                  ? () => Navigator.pop(context, _selectedLocation)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'تأكيد الموقع',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
