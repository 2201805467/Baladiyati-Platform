import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/facility_entity.dart';
import '../controllers/facilities_controller.dart';
import '../controllers/facilities_state.dart';

class PublicFacilitiesPage extends ConsumerStatefulWidget {
  const PublicFacilitiesPage({super.key});

  @override
  ConsumerState<PublicFacilitiesPage> createState() =>
      _PublicFacilitiesPageState();
}

class _PublicFacilitiesPageState extends ConsumerState<PublicFacilitiesPage> {
  String? _selectedFacilityType;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _load(refresh: true));
  }

  void _load({bool refresh = false}) {
    ref
        .read(facilitiesControllerProvider.notifier)
        .fetchFacilities(refresh: refresh);
  }

  Future<void> _openInOpenStreetMap(FacilityEntity facility) async {
    final lat = facility.latitude;
    final lng = facility.longitude;
    final uri = Uri.https('www.openstreetmap.org', '/', {
      'mlat': lat.toString(),
      'mlon': lng.toString(),
    }).replace(fragment: 'map=18/$lat/$lng');

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (opened) return;

      final fallbackOpened = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
      );
      if (fallbackOpened) return;
    } catch (_) {
      // Show the user-facing error below.
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تعذر فتح الخريطة')));
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF2E7D32);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final facilitiesState = ref.watch(facilitiesControllerProvider);
    final facilityTypes =
        facilitiesState.facilities
            .map((facility) => facility.facilityType.trim())
            .where((type) => type.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final visibleFacilities = _selectedFacilityType == null
        ? facilitiesState.facilities
        : facilitiesState.facilities
              .where(
                (facility) => facility.facilityType == _selectedFacilityType,
              )
              .toList();

    ref.listen<FacilitiesState>(facilitiesControllerProvider, (_, next) {
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
          if (facilityTypes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: DropdownButtonFormField<String?>(
                decoration: InputDecoration(
                  labelText: 'نوع المرفق',
                  filled: true,
                  fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                initialValue: _selectedFacilityType,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('كل المرافق'),
                  ),
                  ...facilityTypes.map(
                    (type) => DropdownMenuItem<String?>(
                      value: type,
                      child: Text(type),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _selectedFacilityType = value);
                },
              ),
            ),
          Expanded(
            child:
                facilitiesState.isLoading && facilitiesState.facilities.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : visibleFacilities.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.not_interested_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _selectedFacilityType == null
                              ? 'لا توجد مرافق حالياً'
                              : 'لا توجد مرافق من نوع "$_selectedFacilityType"',
                          style: TextStyle(
                            fontSize: 18,
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async => _load(refresh: true),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: visibleFacilities.length,
                      itemBuilder: (context, index) {
                        return _buildFacilityCard(
                          visibleFacilities[index],
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

  Widget _buildFacilityCard(
    FacilityEntity facility,
    Color primaryColor,
    bool isDark,
  ) {
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
                Text(
                  facility.facilityType,
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: facility.isOpen
                        ? Colors.green[100]
                        : Colors.red[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    facility.isOpen ? 'مفتوح' : 'مغلق',
                    style: TextStyle(
                      color: facility.isOpen
                          ? Colors.green[700]
                          : Colors.red[700],
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              facility.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (facility.description.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                facility.description,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const Divider(height: 20),
            _buildDetailRow(Icons.access_time, facility.openingHours, isDark),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openInOpenStreetMap(facility),
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text(
                  'عرض على OpenStreetMap',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                  side: BorderSide(color: primaryColor.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text, bool isDark) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

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
