import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/facilities_controller.dart';
import '../controllers/facilities_state.dart';
import '../../domain/entities/facility_entity.dart';

class PublicFacilitiesPage extends ConsumerStatefulWidget {
  const PublicFacilitiesPage({super.key});

  @override
  ConsumerState<PublicFacilitiesPage> createState() =>
      _PublicFacilitiesPageState();
}

class _PublicFacilitiesPageState extends ConsumerState<PublicFacilitiesPage> {
  String? _selectedMunicipalityName;
  int? _selectedMunicipalityId;
  String _selectedFacilityType = 'الكل';

  final List<String> _facilityTypes = [
    'الكل',
    'مستشفى',
    'حديقة',
    'مدرسة',
    'مركز شرطة',
    'مكتب بريد',
  ];

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
    ref.read(facilitiesControllerProvider.notifier).fetchFacilities(
          type: _selectedFacilityType,
          municipalityId: _selectedMunicipalityId,
          refresh: refresh,
        );
  }

  void _openInGoogleMaps(double lat, double lng) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('جاري فتح الموقع في الخرائط: $lat, $lng')),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF2E7D32);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final facilitiesState = ref.watch(facilitiesControllerProvider);

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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'البلدية',
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
                      setState(() {
                        _selectedMunicipalityName = newValue;
                        _selectedMunicipalityId = _municipalities
                            .firstWhere(
                                (m) => m['name'] == newValue)['id'] as int?;
                      });
                      _load(refresh: true);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
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
                    items: _facilityTypes
                        .map((t) => DropdownMenuItem<String>(
                              value: t,
                              child: Text(t),
                            ))
                        .toList(),
                    onChanged: (newValue) {
                      if (newValue == null) return;
                      setState(() => _selectedFacilityType = newValue);
                      _load(refresh: true);
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: facilitiesState.isLoading && facilitiesState.facilities.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : facilitiesState.facilities.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.not_interested_outlined,
                                size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              _selectedFacilityType == 'الكل'
                                  ? 'لا توجد مرافق لـ "$_selectedMunicipalityName"'
                                  : 'لا توجد مرافق من نوع "$_selectedFacilityType" في "$_selectedMunicipalityName"',
                              style: const TextStyle(
                                  fontSize: 18, color: Colors.black54),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => _load(refresh: true),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: facilitiesState.facilities.length +
                              (facilitiesState.hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == facilitiesState.facilities.length) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: facilitiesState.isLoading
                                      ? const CircularProgressIndicator()
                                      : TextButton(
                                          onPressed: _load,
                                          child: const Text('تحميل المزيد'),
                                        ),
                                ),
                              );
                            }
                            return _buildFacilityCard(
                              facilitiesState.facilities[index],
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
      FacilityEntity facility, Color primaryColor, bool isDark) {
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            Text(facility.name,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(facility.description,
                style:
                    const TextStyle(fontSize: 13, color: Colors.grey),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const Divider(height: 20),
            _buildDetailRow(
                Icons.location_on_outlined, facility.address, isDark),
            _buildDetailRow(
                Icons.access_time, facility.openingHours, isDark),
            _buildDetailRow(Icons.phone, facility.phone, isDark),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () =>
                    _openInGoogleMaps(facility.latitude, facility.longitude),
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('عرض على خرائط Google',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                  side: BorderSide(
                      color: primaryColor.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
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
