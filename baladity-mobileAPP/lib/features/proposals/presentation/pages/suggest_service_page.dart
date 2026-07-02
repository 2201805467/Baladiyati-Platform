import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/proposal_entity.dart';
import '../controllers/proposals_controller.dart';
import '../controllers/proposals_state.dart';

class SuggestServicePage extends ConsumerStatefulWidget {
  final ProposalEntity? proposal;

  const SuggestServicePage({super.key, this.proposal});

  @override
  ConsumerState<SuggestServicePage> createState() => _SuggestServicePageState();
}

class _SuggestServicePageState extends ConsumerState<SuggestServicePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedCategory;

  bool get _isEditing => widget.proposal != null;

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
  void initState() {
    super.initState();
    final proposal = widget.proposal;
    if (proposal != null) {
      _titleController.text = proposal.title;
      _descriptionController.text = proposal.description;
      _selectedCategory = proposal.category.isEmpty ? null : proposal.category;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final controller = ref.read(proposalsControllerProvider.notifier);
    final success = _isEditing
        ? await controller.updateSuggestion(
            proposalId: widget.proposal!.id,
            title: _titleController.text.trim(),
            category: _selectedCategory!,
            description: _descriptionController.text.trim(),
          )
        : await controller.submitSuggestion(
            title: _titleController.text.trim(),
            category: _selectedCategory!,
            description: _descriptionController.text.trim(),
          );

    if (!mounted) return;
    if (success) {
      if (!_isEditing) {
        await controller.fetchProposals(refresh: true);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'تم تحديث المقترح بنجاح.'
                : 'تم إرسال المقترح بنجاح، ويمكنك متابعته من قسم مقترحاتي.',
          ),
        ),
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
        title: Text(_isEditing ? 'تعديل المقترح' : 'اقتراح مشروع'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'عنوان المقترح',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _titleController,
                  enabled: !isSubmitting,
                  decoration: _inputDecoration(
                    hintText: 'أدخل عنوان المقترح...',
                    isDark: isDark,
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty
                          ? 'يرجى إدخال العنوان'
                          : null,
                ),
                const SizedBox(height: 24),
                const Text(
                  'تصنيف المقترح',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  decoration: _inputDecoration(
                    hintText: '',
                    isDark: isDark,
                  ),
                  hint: const Text('اختر التصنيف'),
                  initialValue: _selectedCategory,
                  items: _categories
                      .map((category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ))
                      .toList(),
                  onChanged: isSubmitting
                      ? null
                      : (value) => setState(() => _selectedCategory = value),
                  validator: (value) =>
                      value == null ? 'يرجى اختيار التصنيف' : null,
                ),
                const SizedBox(height: 24),
                const Text(
                  'وصف المقترح',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 5,
                  enabled: !isSubmitting,
                  decoration: _inputDecoration(
                    hintText: 'اشرح مقترحك بالتفصيل...',
                    isDark: isDark,
                  ),
                  validator: (value) =>
                      value == null || value.trim().length < 20
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
                        : Text(
                            _isEditing ? 'حفظ التعديلات' : 'إرسال المقترح',
                            style: const TextStyle(
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

  InputDecoration _inputDecoration({
    required String hintText,
    required bool isDark,
  }) {
    return InputDecoration(
      hintText: hintText.isEmpty ? null : hintText,
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
