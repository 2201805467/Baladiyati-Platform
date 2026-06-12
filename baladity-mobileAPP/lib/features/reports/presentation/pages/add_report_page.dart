import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../facilities/presentation/pages/location_selection_page.dart';
import '../controllers/reports_controller.dart';
import '../controllers/reports_state.dart';

class AddReportPage extends ConsumerStatefulWidget {
  const AddReportPage({super.key});

  @override
  ConsumerState<AddReportPage> createState() => _AddReportPageState();
}

class _AddReportPageState extends ConsumerState<AddReportPage> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedCategory;
  final _descriptionController = TextEditingController();
  LatLng? _pickedLocation;
  String? _locationAddress;
  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();

  final List<String> _categories = [
    'نظافة عامة',
    'إنارة شوارع',
    'صرف صحي',
    'طرق وأرصفة',
    'مرافق عامة',
    'أخرى',
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) setState(() => _imageFile = pickedFile);
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('المعرض'),
              onTap: () {
                _pickImage(ImageSource.gallery);
                Navigator.of(ctx).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('الكاميرا'),
              onTap: () {
                _pickImage(ImageSource.camera);
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خدمة الموقع غير مفعلة.')),
        );
      }
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم رفض أذونات الموقع.')),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'تم رفض أذونات الموقع بشكل دائم، يرجى تفعيلها من الإعدادات.'),
          ),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('جاري تحديد موقعك...')),
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      if (!mounted) return;
      setState(
          () => _pickedLocation = LatLng(position.latitude, position.longitude));
      _getAddressFromLatLng(_pickedLocation!);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تحديد الموقع: ${e.toString()}')),
      );
    }
  }

  Future<void> _getAddressFromLatLng(LatLng latLng) async {
    try {
      final placemarks = await placemarkFromCoordinates(
          latLng.latitude, latLng.longitude);
      final place = placemarks[0];
      if (mounted) {
        setState(() {
          _locationAddress =
              '${place.street}, ${place.subLocality}, ${place.locality}, ${place.country}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _locationAddress =
            'الموقع: ${latLng.latitude}, ${latLng.longitude}');
      }
    }
  }

  Future<void> _openLocationPickerMap() async {
    final LatLng? result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            LocationSelectionPage(initialLocation: _pickedLocation),
      ),
    );
    if (!mounted) return;
    if (result != null) {
      setState(() => _pickedLocation = result);
      _getAddressFromLatLng(result);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final success =
        await ref.read(reportsControllerProvider.notifier).submitReport(
              category: _selectedCategory!,
              description: _descriptionController.text.trim(),
              latitude: _pickedLocation?.latitude,
              longitude: _pickedLocation?.longitude,
              locationAddress: _locationAddress,
              imagePath: _imageFile?.path,
            );
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال البلاغ بنجاح ✓')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF2E7D32);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen<ReportsState>(reportsControllerProvider, (previous, next) {
      if (next.errorMessage != null &&
          previous?.errorMessage != next.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    });

    final isSubmitting = ref.watch(
      reportsControllerProvider.select((s) => s.isSubmitting),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('إضافة بلاغ جديد'), centerTitle: true),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('تصنيف المشكلة',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  hint: const Text('اختر التصنيف'),
                  initialValue: _selectedCategory,
                  items: _categories
                      .map((c) =>
                          DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: isSubmitting
                      ? null
                      : (value) =>
                          setState(() => _selectedCategory = value),
                  validator: (value) =>
                      value == null ? 'يرجى اختيار التصنيف' : null,
                ),
                const SizedBox(height: 24),
                const Text('وصف المشكلة',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  enabled: !isSubmitting,
                  decoration: InputDecoration(
                    hintText: 'اكتب تفاصيل المشكلة هنا...',
                    filled: true,
                    fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (value) =>
                      (value == null || value.isEmpty)
                          ? 'يرجى كتابة الوصف'
                          : null,
                ),
                const SizedBox(height: 24),
                const Text('إرفاق صورة',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                _ImageUploadPlaceholder(
                  primaryColor: primaryGreen,
                  imageFile: _imageFile,
                  onTap: isSubmitting ? () {} : _showPickerOptions,
                ),
                const SizedBox(height: 24),
                const Text('تحديد الموقع',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                _LocationPickerPlaceholder(
                  primaryColor: primaryGreen,
                  pickedLocation: _pickedLocation,
                  locationAddress: _locationAddress,
                  onAutoLocate:
                      isSubmitting ? () {} : _getCurrentLocation,
                  onManualLocate:
                      isSubmitting ? () {} : _openLocationPickerMap,
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'إرسال البلاغ',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Private Widgets ──────────────────────────────────────────────────────────

class _ImageUploadPlaceholder extends StatelessWidget {
  final Color primaryColor;
  final XFile? imageFile;
  final VoidCallback onTap;

  const _ImageUploadPlaceholder({
    required this.primaryColor,
    required this.imageFile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? Colors.grey[850] : Colors.grey[100],
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
            ),
          ),
          child: imageFile != null
              ? Image.file(File(imageFile!.path), fit: BoxFit.cover)
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined,
                        color: primaryColor, size: 40),
                    const SizedBox(height: 8),
                    const Text('اضغط لإضافة صورة',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
        ),
      ),
    );
  }
}

class _LocationPickerPlaceholder extends StatelessWidget {
  final Color primaryColor;
  final LatLng? pickedLocation;
  final String? locationAddress;
  final VoidCallback onAutoLocate;
  final VoidCallback onManualLocate;

  const _LocationPickerPlaceholder({
    required this.primaryColor,
    this.pickedLocation,
    this.locationAddress,
    required this.onAutoLocate,
    required this.onManualLocate,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? Colors.grey[850] : Colors.grey[100],
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onAutoLocate,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.location_on_outlined, color: primaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  locationAddress ?? 'تحديد الموقع الحالي تلقائياً',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              if (pickedLocation != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: TextButton(
                    onPressed: onManualLocate,
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'تغيير',
                      style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold),
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
