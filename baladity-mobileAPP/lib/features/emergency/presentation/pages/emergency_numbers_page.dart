import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/network/api_constants.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

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

class EmergencyNumbersView extends ConsumerStatefulWidget {
  const EmergencyNumbersView({super.key});

  @override
  ConsumerState<EmergencyNumbersView> createState() =>
      _EmergencyNumbersViewState();
}

class _EmergencyNumbersViewState extends ConsumerState<EmergencyNumbersView> {
  List<_EmergencyContact> _contacts = const [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    Future.microtask(_fetchContacts);
  }

  Future<void> _fetchContacts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get(
        ApiConstants.emergencyContacts,
        queryParameters: {'per_page': 100},
      );
      final raw = res.data['data'] ?? res.data;
      final list = raw is List ? raw : const [];
      final contacts = list
          .whereType<Map>()
          .map((e) => _EmergencyContact.fromJson(e))
          .where((contact) => contact.phone.isNotEmpty)
          .toList();

      if (!mounted) return;
      setState(() {
        _contacts = contacts;
        _isLoading = false;
        _selectedCategory = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _call(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تعذر فتح الهاتف للرقم: $number'),
        backgroundColor: Colors.red[700],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        _contacts
            .map((contact) => contact.category)
            .where((category) => category.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final visibleContacts = _selectedCategory == null
        ? _contacts
        : _contacts
              .where((contact) => contact.category == _selectedCategory)
              .toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RefreshIndicator(
        onRefresh: _fetchContacts,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _EmergencyHeader(
                  categories: categories,
                  selectedCategory: _selectedCategory,
                  onCategoryChanged: (value) {
                    setState(() => _selectedCategory = value);
                  },
                ),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              SliverFillRemaining(
                child: _ErrorView(
                  message: _errorMessage!,
                  onRetry: _fetchContacts,
                ),
              )
            else if (visibleContacts.isEmpty)
              const SliverFillRemaining(
                child: Center(child: Text('لا توجد أرقام طوارئ حالياً')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                sliver: SliverList.separated(
                  itemCount: visibleContacts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final contact = visibleContacts[index];
                    return _ContactCard(
                      contact: contact,
                      onPrimaryCall: () => _call(contact.phone),
                      onAltCall: contact.altPhone == null
                          ? null
                          : () => _call(contact.altPhone!),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyHeader extends StatelessWidget {
  const _EmergencyHeader({
    required this.categories,
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String?> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.red[700],
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(Icons.emergency_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'أرقام الطوارئ المتاحة',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (categories.isNotEmpty) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            decoration: InputDecoration(
              labelText: 'فلترة حسب النوع',
              prefixIcon: const Icon(Icons.filter_list),
              filled: true,
              fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            initialValue: selectedCategory,
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('كل الأرقام'),
              ),
              ...categories.map(
                (category) => DropdownMenuItem<String?>(
                  value: category,
                  child: Text(category),
                ),
              ),
            ],
            onChanged: onCategoryChanged,
          ),
        ],
      ],
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.contact,
    required this.onPrimaryCall,
    this.onAltCall,
  });

  final _EmergencyContact contact;
  final VoidCallback onPrimaryCall;
  final VoidCallback? onAltCall;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _categoryColor(contact.category);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(_categoryIcon(contact.category), color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    contact.category.isEmpty ? 'طوارئ' : contact.category,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 6),
                  _PhoneLine(number: contact.phone),
                  if (contact.altPhone != null)
                    _PhoneLine(number: contact.altPhone!),
                  if (contact.description?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 6),
                    Text(
                      contact.description!.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[700],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.filled(
                  onPressed: onPrimaryCall,
                  icon: const Icon(Icons.phone),
                  tooltip: 'اتصال',
                  style: IconButton.styleFrom(backgroundColor: Colors.red[700]),
                ),
                if (onAltCall != null)
                  IconButton(
                    onPressed: onAltCall,
                    icon: const Icon(Icons.phone_forwarded),
                    tooltip: 'اتصال بالرقم البديل',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    final normalized = category.toLowerCase();
    if (normalized.contains('police') || category.contains('شرطة')) {
      return Icons.local_police_outlined;
    }
    if (normalized.contains('ambulance') || category.contains('إسعاف')) {
      return Icons.local_hospital_outlined;
    }
    if (normalized.contains('fire') || category.contains('مطاف')) {
      return Icons.local_fire_department_outlined;
    }
    if (category.contains('دفاع')) {
      return Icons.shield_outlined;
    }
    return Icons.emergency_outlined;
  }

  Color _categoryColor(String category) {
    final normalized = category.toLowerCase();
    if (normalized.contains('police') || category.contains('شرطة')) {
      return Colors.blue;
    }
    if (normalized.contains('ambulance') || category.contains('إسعاف')) {
      return Colors.red;
    }
    if (normalized.contains('fire') || category.contains('مطاف')) {
      return Colors.deepOrange;
    }
    if (category.contains('دفاع')) {
      return Colors.orange;
    }
    return const Color(0xFF2E7D32);
  }
}

class _PhoneLine extends StatelessWidget {
  const _PhoneLine({required this.number});

  final String number;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.phone_outlined, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(
          number,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[300]
                : Colors.grey[800],
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyContact {
  const _EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    this.altPhone,
    required this.category,
    this.description,
  });

  final int id;
  final String name;
  final String phone;
  final String? altPhone;
  final String category;
  final String? description;

  factory _EmergencyContact.fromJson(Map<dynamic, dynamic> json) {
    final altPhone = json['alt_phone']?.toString().trim();

    return _EmergencyContact(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? 'رقم طوارئ',
      phone: json['phone']?.toString() ?? '',
      altPhone: altPhone == null || altPhone.isEmpty ? null : altPhone,
      category: json['category']?.toString() ?? '',
      description: json['description']?.toString(),
    );
  }
}
