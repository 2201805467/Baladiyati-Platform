import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/proposals_controller.dart';
import '../controllers/proposals_state.dart';

class SuggestServicePage extends ConsumerStatefulWidget {
  const SuggestServicePage({super.key});

  @override
  ConsumerState<SuggestServicePage> createState() => _SuggestServicePageState();
}

class _SuggestServicePageState extends ConsumerState<SuggestServicePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedCategory;

  final List<String> _categories = [
    'مرافق ترفيهية',
    'مرافق صحية',
    'مرافق تعليمية',
    'مرافق رياضية',
    'بنية تحتية',
    'نقل عام',
    'أخرى',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref
        .read(proposalsControllerProvider.notifier)
        .submitSuggestion(
          title: _titleController.text.trim(),
          category: _selectedCategory!,
          description: _descriptionController.text.trim(),
        );
    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال المقترح بنجاح ✓')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF2E7D32);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    ref.listen<ProposalsState>(proposalsControllerProvider, (previous, next) {
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
      proposalsControllerProvider.select((s) => s.isSubmitting),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('اقتراح مشروع'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('عنوان المقترح',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _titleController,
                  enabled: !isSubmitting,
                  decoration: _inputDecoration(
                    hintText: 'أدخل عنوان المقترح...',
                    isDark: isDark,
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'يرجى إدخال العنوان' : null,
                ),
                const SizedBox(height: 24),
                const Text('تصنيف المقترح',
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
                      : (v) => setState(() => _selectedCategory = v),
                  validator: (v) =>
                      v == null ? 'يرجى اختيار التصنيف' : null,
                ),
                const SizedBox(height: 24),
                const Text('وصف المقترح',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 5,
                  enabled: !isSubmitting,
                  decoration: _inputDecoration(
                    hintText: 'اشرح مقترحك بالتفصيل...',
                    isDark: isDark,
                  ),
                  validator: (v) => (v == null || v.length < 20)
                      ? 'يرجى كتابة وصف لا يقل عن 20 حرفاً'
                      : null,
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
                          borderRadius: BorderRadius.circular(12)),
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
                            'إرسال المقترح',
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

  InputDecoration _inputDecoration(
      {required String hintText, required bool isDark}) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }
}
