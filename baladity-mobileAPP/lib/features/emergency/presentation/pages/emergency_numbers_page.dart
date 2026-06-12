import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── Data Models ──────────────────────────────────────────────────────────────

class _EmergencyContact {
  final String serviceName;
  final String number;
  final IconData icon;
  final Color color;

  const _EmergencyContact({
    required this.serviceName,
    required this.number,
    required this.icon,
    required this.color,
  });
}

class _MunicipalityData {
  final int id;
  final String name;
  final List<_EmergencyContact> contacts;

  const _MunicipalityData({
    required this.id,
    required this.name,
    required this.contacts,
  });
}

// ─── Static Emergency Data ─────────────────────────────────────────────────────

const _emergencyData = [
  _MunicipalityData(
    id: 1,
    name: 'بلدية طرابلس المركز',
    contacts: [
      _EmergencyContact(
        serviceName: 'الشرطة',
        number: '1515',
        icon: Icons.local_police_outlined,
        color: Colors.blue,
      ),
      _EmergencyContact(
        serviceName: 'الإسعاف',
        number: '115',
        icon: Icons.local_hospital_outlined,
        color: Colors.red,
      ),
      _EmergencyContact(
        serviceName: 'الدفاع المدني',
        number: '191',
        icon: Icons.shield_outlined,
        color: Colors.orange,
      ),
      _EmergencyContact(
        serviceName: 'المطافي',
        number: '113',
        icon: Icons.local_fire_department_outlined,
        color: Colors.deepOrange,
      ),
      _EmergencyContact(
        serviceName: 'مركز الطوارئ',
        number: '021-3600000',
        icon: Icons.emergency_outlined,
        color: Color(0xFF2E7D32),
      ),
    ],
  ),
  _MunicipalityData(
    id: 2,
    name: 'بلدية بنغازي',
    contacts: [
      _EmergencyContact(
        serviceName: 'الشرطة',
        number: '1515',
        icon: Icons.local_police_outlined,
        color: Colors.blue,
      ),
      _EmergencyContact(
        serviceName: 'الإسعاف',
        number: '115',
        icon: Icons.local_hospital_outlined,
        color: Colors.red,
      ),
      _EmergencyContact(
        serviceName: 'الدفاع المدني',
        number: '191',
        icon: Icons.shield_outlined,
        color: Colors.orange,
      ),
      _EmergencyContact(
        serviceName: 'المطافي',
        number: '113',
        icon: Icons.local_fire_department_outlined,
        color: Colors.deepOrange,
      ),
      _EmergencyContact(
        serviceName: 'مركز الطوارئ',
        number: '061-9090000',
        icon: Icons.emergency_outlined,
        color: Color(0xFF2E7D32),
      ),
    ],
  ),
  _MunicipalityData(
    id: 3,
    name: 'بلدية مصراتة',
    contacts: [
      _EmergencyContact(
        serviceName: 'الشرطة',
        number: '1515',
        icon: Icons.local_police_outlined,
        color: Colors.blue,
      ),
      _EmergencyContact(
        serviceName: 'الإسعاف',
        number: '115',
        icon: Icons.local_hospital_outlined,
        color: Colors.red,
      ),
      _EmergencyContact(
        serviceName: 'الدفاع المدني',
        number: '191',
        icon: Icons.shield_outlined,
        color: Colors.orange,
      ),
      _EmergencyContact(
        serviceName: 'المطافي',
        number: '113',
        icon: Icons.local_fire_department_outlined,
        color: Colors.deepOrange,
      ),
      _EmergencyContact(
        serviceName: 'مركز الطوارئ',
        number: '051-2200000',
        icon: Icons.emergency_outlined,
        color: Color(0xFF2E7D32),
      ),
    ],
  ),
  _MunicipalityData(
    id: 4,
    name: 'بلدية سبها',
    contacts: [
      _EmergencyContact(
        serviceName: 'الشرطة',
        number: '1515',
        icon: Icons.local_police_outlined,
        color: Colors.blue,
      ),
      _EmergencyContact(
        serviceName: 'الإسعاف',
        number: '115',
        icon: Icons.local_hospital_outlined,
        color: Colors.red,
      ),
      _EmergencyContact(
        serviceName: 'الدفاع المدني',
        number: '191',
        icon: Icons.shield_outlined,
        color: Colors.orange,
      ),
      _EmergencyContact(
        serviceName: 'المطافي',
        number: '113',
        icon: Icons.local_fire_department_outlined,
        color: Colors.deepOrange,
      ),
      _EmergencyContact(
        serviceName: 'مركز الطوارئ',
        number: '071-6300000',
        icon: Icons.emergency_outlined,
        color: Color(0xFF2E7D32),
      ),
    ],
  ),
];

// ─── Standalone Page (with Scaffold) ─────────────────────────────────────────

class EmergencyNumbersPage extends StatelessWidget {
  const EmergencyNumbersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'أرقام الطوارئ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: const EmergencyNumbersView(),
    );
  }
}

// ─── Embeddable View (no Scaffold — used inside TabBarView) ───────────────────

class EmergencyNumbersView extends StatefulWidget {
  const EmergencyNumbersView({super.key});

  @override
  State<EmergencyNumbersView> createState() => _EmergencyNumbersViewState();
}

class _EmergencyNumbersViewState extends State<EmergencyNumbersView> {
  _MunicipalityData _selected = _emergencyData.first;

  Future<void> _call(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذّر فتح الهاتف للرقم: $number'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Municipality selector ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<_MunicipalityData>(
              decoration: InputDecoration(
                labelText: 'اختر البلدية',
                prefixIcon: const Icon(Icons.location_city_outlined),
                filled: true,
                fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              initialValue: _selected,
              items: _emergencyData
                  .map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(m.name),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selected = v);
              },
            ),
          ),

          // ── Municipality header ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red[700],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emergency_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'أرقام الطوارئ — ${_selected.name}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Contact list ─────────────────────────────────────────────────
          Expanded(
            child: ListView.separated(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: _selected.contacts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final contact = _selected.contacts[index];
                return _ContactCard(
                  contact: contact,
                  onCall: () => _call(contact.number),
                  isDark: isDark,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Contact Card ─────────────────────────────────────────────────────────────

class _ContactCard extends StatelessWidget {
  final _EmergencyContact contact;
  final VoidCallback onCall;
  final bool isDark;

  const _ContactCard({
    required this.contact,
    required this.onCall,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Service icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: contact.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(contact.icon, color: contact.color, size: 24),
            ),
            const SizedBox(width: 14),

            // Service name + number
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.serviceName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        contact.number,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Call button
            ElevatedButton.icon(
              onPressed: onCall,
              icon: const Icon(Icons.phone, size: 16),
              label: const Text('اتصال الآن',
                  style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
