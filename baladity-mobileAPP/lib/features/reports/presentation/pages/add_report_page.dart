import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../domain/entities/report_image_classification_entity.dart';
import '../controllers/reports_controller.dart';
import '../controllers/reports_state.dart';
import 'location_selection_page.dart';

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
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _voicePreviewPlayer = AudioPlayer();
  StreamSubscription<void>? _voicePreviewCompleteSubscription;
  bool _isRecordingVoice = false;
  bool _isPlayingVoicePreview = false;
  String? _voiceNotePath;
  @override
  void initState() {
    super.initState();
    _voicePreviewCompleteSubscription = _voicePreviewPlayer.onPlayerComplete
        .listen((_) {
          if (mounted) {
            setState(() => _isPlayingVoicePreview = false);
          }
        });
    Future.microtask(() {
      ref.read(reportsControllerProvider.notifier).clearImageClassification();
      ref.read(reportsControllerProvider.notifier).fetchCategories();
    });
  }

  @override
  void dispose() {
    _voicePreviewCompleteSubscription?.cancel();
    _voicePreviewPlayer.dispose();
    _audioRecorder.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _toggleVoiceRecording() async {
    try {
      if (_isRecordingVoice) {
        final path = await _audioRecorder.stop();
        if (!mounted) return;
        setState(() {
          _isRecordingVoice = false;
          _voiceNotePath = path;
        });
        return;
      }

      await _voicePreviewPlayer.stop();
      if (mounted) {
        setState(() => _isPlayingVoicePreview = false);
      }

      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'يرجى السماح باستخدام الميكروفون لتسجيل رسالة صوتية.',
            ),
          ),
        );
        return;
      }

      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/report_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      if (!mounted) return;
      setState(() {
        _isRecordingVoice = true;
        _voiceNotePath = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRecordingVoice = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تسجيل الرسالة الصوتية: $e')),
      );
    }
  }

  Future<void> _toggleVoicePreview() async {
    final path = _voiceNotePath;
    if (path == null || _isRecordingVoice) return;

    try {
      if (_isPlayingVoicePreview) {
        await _voicePreviewPlayer.stop();
        if (mounted) {
          setState(() => _isPlayingVoicePreview = false);
        }
        return;
      }

      await _voicePreviewPlayer.play(DeviceFileSource(path));
      if (mounted) {
        setState(() => _isPlayingVoicePreview = true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPlayingVoicePreview = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تشغيل الرسالة الصوتية: $e')),
      );
    }
  }

  Future<void> _removeVoiceNote() async {
    await _voicePreviewPlayer.stop();
    setState(() {
      _isPlayingVoicePreview = false;
      _voiceNotePath = null;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile == null) return;

      ref.read(reportsControllerProvider.notifier).clearImageClassification();
      setState(() {
        _imageFile = pickedFile;
        _selectedCategory = null;
      });

      if (ref.read(reportsControllerProvider).categories.isEmpty) {
        await ref.read(reportsControllerProvider.notifier).fetchCategories();
      }

      final classification = await ref
          .read(reportsControllerProvider.notifier)
          .classifyImage(imagePath: pickedFile.path);

      if (!mounted || classification == null) return;

      var matchedCategoryId = _matchSuggestedCategoryId(classification);
      if (classification.hasConfidentCategory && matchedCategoryId == null) {
        await ref.read(reportsControllerProvider.notifier).fetchCategories();
        if (!mounted) return;
        matchedCategoryId = _matchSuggestedCategoryId(classification);
      }

      debugPrint(
        '[AI_CLASSIFICATION] provider=${classification.provider}, '
        'categoryId=${classification.categoryId}, '
        'categoryName=${classification.categoryName}, '
        'confidence=${classification.confidence}, '
        'needsManualReview=${classification.needsManualReview}, '
        'matchedCategoryId=$matchedCategoryId',
      );

      if (classification.hasConfidentCategory && matchedCategoryId != null) {
        setState(() => _selectedCategory = matchedCategoryId.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم اقتراح التصنيف: ${classification.categoryName} '
              '(${classification.confidence}%)',
            ),
          ),
        );
      } else if (classification.hasConfidentCategory) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'اقترح الذكاء الاصطناعي "${classification.categoryName ?? 'تصنيفاً'}" '
              'لكن هذا التصنيف غير موجود في القائمة الحالية.',
            ),
          ),
        );
      } else {
        final providerFailureReason = classification.providerFailureReason;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              providerFailureReason == null
                  ? 'لم يتم التعرف بثقة على التصنيف، يرجى اختياره يدوياً.'
                  : 'تعذر استخدام مزود الذكاء الاصطناعي حالياً ($providerFailureReason)، يرجى اختيار التصنيف يدوياً.',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  int? _matchSuggestedCategoryId(
    ReportImageClassificationEntity classification,
  ) {
    final categories = ref.read(reportsControllerProvider).categories;

    for (final category in categories) {
      if (category.id == classification.categoryId) {
        return category.id;
      }
    }

    final suggestedName = _normalizeCategoryName(classification.categoryName);
    if (suggestedName.isEmpty) return null;

    for (final category in categories) {
      if (_normalizeCategoryName(category.name) == suggestedName) {
        return category.id;
      }
    }

    for (final category in categories) {
      final categoryName = _normalizeCategoryName(category.name);
      if (categoryName.contains(suggestedName) ||
          suggestedName.contains(categoryName)) {
        return category.id;
      }
    }

    return null;
  }

  String _normalizeCategoryName(String? value) {
    return (value ?? '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s_\-]+'), '')
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي');
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('خدمة الموقع غير مفعلة.')));
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
              'تم رفض أذونات الموقع بشكل دائم، يرجى تفعيلها من الإعدادات.',
            ),
          ),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('جاري تحديد موقعك...')));
    }

    try {
      var position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (position.accuracy > 100) {
        final streamPosition = await Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 0,
          ),
        ).first.timeout(const Duration(seconds: 12));

        if (streamPosition.accuracy <= position.accuracy) {
          position = streamPosition;
        }
      }

      if (!mounted) return;
      final location = LatLng(position.latitude, position.longitude);
      setState(() => _pickedLocation = location);
      _getAddressFromLatLng(location);

      if (position.isMocked && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تنبيه: الجهاز يستخدم موقعاً تجريبياً/Mock، لذلك قد لا يكون موقعك الحقيقي.',
            ),
          ),
        );
      }
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
        latLng.latitude,
        latLng.longitude,
      );
      final place = placemarks[0];
      if (mounted) {
        setState(() {
          _locationAddress =
              '${place.street}, ${place.subLocality}, ${place.locality}, ${place.country}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _locationAddress =
              'الموقع: ${latLng.latitude}, ${latLng.longitude}',
        );
      }
    }
  }

  Future<void> _openLocationPickerMap() async {
    final categoryId = int.tryParse(_selectedCategory ?? '');
    final LatLng? result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationSelectionPage(
          initialLocation: _pickedLocation,
          categoryId: categoryId,
        ),
      ),
    );
    if (!mounted) return;
    if (result != null) {
      setState(() => _pickedLocation = result);
      _getAddressFromLatLng(result);
    }
  }

  Future<void> _submit() async {
    if (_isRecordingVoice) {
      final path = await _audioRecorder.stop();
      if (!mounted) return;
      setState(() {
        _isRecordingVoice = false;
        _voiceNotePath = path;
      });
    }

    if (!_formKey.currentState!.validate()) return;
    final success = await ref
        .read(reportsControllerProvider.notifier)
        .submitReport(
          category: _selectedCategory!,
          description: _descriptionController.text.trim(),
          latitude: _pickedLocation?.latitude,
          longitude: _pickedLocation?.longitude,
          locationAddress: _locationAddress,
          imagePath: _imageFile?.path,
          voiceNotePath: _voiceNotePath,
        );
    if (!mounted) return;
    if (success) {
      ref.read(reportsControllerProvider.notifier).clearImageClassification();
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
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
    final isClassifyingImage = ref.watch(
      reportsControllerProvider.select((s) => s.isClassifyingImage),
    );
    final imageClassification = ref.watch(
      reportsControllerProvider.select((s) => s.imageClassification),
    );
    final categories = ref.watch(
      reportsControllerProvider.select((s) => s.categories),
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
                const Text(
                  'إرفاق صورة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                _ImageUploadPlaceholder(
                  primaryColor: primaryGreen,
                  imageFile: _imageFile,
                  isClassifying: isClassifyingImage,
                  onTap: isSubmitting || isClassifyingImage
                      ? () {}
                      : _showPickerOptions,
                ),
                if (imageClassification != null) ...[
                  const SizedBox(height: 10),
                  _ClassificationHint(classification: imageClassification),
                ],
                const SizedBox(height: 24),
                const Text(
                  'تصنيف المشكلة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  isExpanded: true,
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
                  items: categories
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.id.toString(),
                          child: Text(
                            c.departmentName == null
                                ? c.name
                                : '${c.name} - ${c.departmentName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: isSubmitting
                      ? null
                      : (value) => setState(() => _selectedCategory = value),
                  validator: (value) =>
                      value == null ? 'يرجى اختيار التصنيف' : null,
                ),
                const SizedBox(height: 24),
                const Text(
                  'وصف المشكلة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
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
                  validator: (value) {
                    final hasDescription = value?.trim().isNotEmpty == true;
                    final hasVoiceNote = _voiceNotePath != null;
                    if (!hasDescription && !hasVoiceNote) {
                      return 'يرجى كتابة وصف أو تسجيل رسالة صوتية';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _VoiceNoteRecorder(
                  isRecording: _isRecordingVoice,
                  hasVoiceNote: _voiceNotePath != null,
                  isPlayingPreview: _isPlayingVoicePreview,
                  onToggleRecording: isSubmitting
                      ? () {}
                      : _toggleVoiceRecording,
                  onTogglePreview: isSubmitting ? () {} : _toggleVoicePreview,
                  onRemove: isSubmitting ? () {} : _removeVoiceNote,
                ),
                const SizedBox(height: 24),
                const Text(
                  'تحديد الموقع',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                _LocationPickerPlaceholder(
                  primaryColor: primaryGreen,
                  pickedLocation: _pickedLocation,
                  locationAddress: _locationAddress,
                  onAutoLocate: isSubmitting ? () {} : _getCurrentLocation,
                  onManualLocate: isSubmitting ? () {} : _openLocationPickerMap,
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
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'إرسال البلاغ',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
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

class _VoiceNoteRecorder extends StatelessWidget {
  final bool isRecording;
  final bool hasVoiceNote;
  final bool isPlayingPreview;
  final VoidCallback onToggleRecording;
  final VoidCallback onTogglePreview;
  final VoidCallback onRemove;

  const _VoiceNoteRecorder({
    required this.isRecording,
    required this.hasVoiceNote,
    required this.isPlayingPreview,
    required this.onToggleRecording,
    required this.onTogglePreview,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isRecording ? Colors.red : const Color(0xFF2E7D32);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isRecording ? Icons.graphic_eq : Icons.mic_none,
            color: activeColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isRecording
                  ? 'جاري التسجيل... اضغط إيقاف عند الانتهاء'
                  : hasVoiceNote
                      ? 'تم حفظ رسالة صوتية مع البلاغ'
                      : 'رسالة صوتية اختيارية بدلاً من كتابة الوصف',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (hasVoiceNote && !isRecording) ...[
            IconButton(
              tooltip: isPlayingPreview ? 'إيقاف الاستماع' : 'استماع للتسجيل',
              onPressed: onTogglePreview,
              icon: Icon(
                isPlayingPreview
                    ? Icons.stop_circle_outlined
                    : Icons.play_circle_outline,
                color: activeColor,
              ),
            ),
            IconButton(
              tooltip: 'حذف التسجيل',
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
            ),
          ],
          TextButton.icon(
            onPressed: onToggleRecording,
            icon: Icon(isRecording ? Icons.stop : Icons.mic),
            label: Text(isRecording ? 'إيقاف' : 'تسجيل'),
            style: TextButton.styleFrom(foregroundColor: activeColor),
          ),
        ],
      ),
    );
  }
}

class _ImageUploadPlaceholder extends StatelessWidget {
  final Color primaryColor;
  final XFile? imageFile;
  final bool isClassifying;
  final VoidCallback onTap;

  const _ImageUploadPlaceholder({
    required this.primaryColor,
    required this.imageFile,
    required this.isClassifying,
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
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(File(imageFile!.path), fit: BoxFit.cover),
                    if (isClassifying)
                      ColoredBox(
                        color: Colors.black.withValues(alpha: 0.45),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: Colors.white),
                              SizedBox(height: 12),
                              Text(
                                'جاري تحليل الصورة...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      color: primaryColor,
                      size: 40,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'اضغط لإضافة صورة',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ClassificationHint extends StatelessWidget {
  final ReportImageClassificationEntity classification;

  const _ClassificationHint({required this.classification});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isConfident = classification.hasConfidentCategory;
    final color = isConfident ? Colors.green : Colors.orange;
    final title = isConfident ? 'اقتراح التصنيف' : 'التصنيف يحتاج مراجعة يدوية';
    final category =
        classification.providerFailureReason ??
        classification.categoryName ??
        'غير واضح';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(
            isConfident ? Icons.auto_awesome : Icons.info_outline,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$title: $category (${classification.confidence}%)',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: TextButton(
                  onPressed: onManualLocate,
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    pickedLocation == null ? 'الخريطة' : 'تغيير',
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
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
