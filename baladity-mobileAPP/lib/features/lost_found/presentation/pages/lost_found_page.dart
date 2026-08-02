import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/network/api_constants.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../reports/presentation/pages/location_selection_page.dart' as report_map;

String _apiOrigin() {
  final baseUrl = ApiConstants.baseUrl;
  if (baseUrl.endsWith('/api/')) return baseUrl.substring(0, baseUrl.length - 5);
  if (baseUrl.endsWith('/api')) return baseUrl.substring(0, baseUrl.length - 4);
  return baseUrl;
}

String? _absoluteUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('http')) return url;
  final base = _apiOrigin();
  return url.startsWith('/') ? '$base$url' : '$base/$url';
}

class LostFoundPage extends ConsumerStatefulWidget {
  final bool showAppBar;

  const LostFoundPage({super.key, this.showAppBar = true});

  @override
  ConsumerState<LostFoundPage> createState() => _LostFoundPageState();
}

class _LostFoundPageState extends ConsumerState<LostFoundPage> {
  String _scope = 'found';
  String _category = '';
  bool _isLoading = false;
  List<_LostFoundItem> _items = const [];
  List<_LostFoundThread> _threads = const [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    if (_scope == 'threads') {
      await _loadThreads();
      return;
    }

    setState(() => _isLoading = true);
    try {
      final path = _scope == 'my'
          ? '${ApiConstants.lostFound}/my-items'
          : ApiConstants.lostFound;
      final response = await ref.read(dioProvider).get(
        path,
        queryParameters: {
          'per_page': 50,
          if (_scope == 'found' || _scope == 'lost') 'item_type': _scope,
          if (_category.isNotEmpty) 'category': _category,
        },
      );
      final raw = response.data['data'] ?? response.data;
      final list = raw is List ? raw : const [];
      if (!mounted) return;
      setState(() {
        _items = list
            .whereType<Map>()
            .map((item) => _LostFoundItem.fromJson(item))
            .toList(growable: false);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(e);
    }
  }

  Future<void> _loadThreads() async {
    setState(() => _isLoading = true);
    try {
      final response = await ref.read(dioProvider).get(
        '${ApiConstants.lostFound}/threads',
        queryParameters: {'per_page': 50},
      );
      final raw = response.data['data'] ?? response.data;
      final list = raw is List ? raw : const [];
      if (!mounted) return;
      setState(() {
        _threads = list
            .whereType<Map>()
            .map((item) => _LostFoundThread.fromJson(item))
            .toList(growable: false);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(e);
    }
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const _LostFoundCreatePage()),
    );
    if (created == true) await _load();
  }

  Future<void> _openItem(_LostFoundItem item) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _LostFoundDetailsPage(item: item)),
    );
    if (changed == true) await _load();
  }

  Future<void> _openThread(_LostFoundThread thread) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _LostFoundChatPage(thread: thread)),
    );
    await _loadThreads();
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_messageFromError(error)), backgroundColor: Colors.red[700]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Column(
            children: [
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'found', label: Text('موجودات')),
                  ButtonSegment(value: 'lost', label: Text('مفقودات')),
                  ButtonSegment(value: 'my', label: Text('منشوراتي')),
                  ButtonSegment(value: 'threads', label: Text('دردشاتي')),
                ],
                selected: {_scope},
                onSelectionChanged: (value) {
                  setState(() => _scope = value.first);
                  _load();
                },
              ),
              if (_scope != 'threads') ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'التصنيف',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('كل التصنيفات')),
                    ..._LostFoundItem.categoryLabels.entries.map(
                      (entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value)),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _category = value ?? '');
                    _load();
                  },
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _scope == 'threads' ? _threadsList() : _itemsList(),
                ),
        ),
      ],
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: widget.showAppBar
          ? Scaffold(
              appBar: AppBar(title: const Text('مفقودات وموجودات الحي')),
              body: body,
              floatingActionButton: FloatingActionButton.extended(
                onPressed: _openCreate,
                icon: const Icon(Icons.add),
                label: const Text('نشر'),
              ),
            )
          : Scaffold(
              body: body,
              floatingActionButton: FloatingActionButton(
                onPressed: _openCreate,
                child: const Icon(Icons.add),
              ),
            ),
    );
  }

  Widget _itemsList() {
    if (_items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SizedBox(height: 120),
          Center(child: Text('لا توجد منشورات حالياً')),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (context, index) => _LostFoundItemCard(
        item: _items[index],
        onTap: () => _openItem(_items[index]),
      ),
    );
  }

  Widget _threadsList() {
    if (_threads.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SizedBox(height: 120),
          Center(child: Text('لا توجد محادثات حالياً')),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _threads.length,
      itemBuilder: (context, index) {
        final thread = _threads[index];
        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.chat_outlined)),
            title: Text(thread.itemTitle),
            subtitle: Text(thread.lastMessage?.isNotEmpty == true
                ? thread.lastMessage!
                : 'ابدأ المحادثة بشكل مجهول'),
            trailing: Text(thread.otherAlias),
            onTap: () => _openThread(thread),
          ),
        );
      },
    );
  }
}

class _LostFoundCreatePage extends ConsumerStatefulWidget {
  const _LostFoundCreatePage();

  @override
  ConsumerState<_LostFoundCreatePage> createState() => _LostFoundCreatePageState();
}

class _LostFoundCreatePageState extends ConsumerState<_LostFoundCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _area = TextEditingController();
  final _petType = TextEditingController();
  final _petMarks = TextEditingController();
  final _picker = ImagePicker();
  String _itemType = 'found';
  String _category = 'keys';
  DateTime? _incidentDate;
  LatLng? _location;
  XFile? _image;
  bool _petHasCollar = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _area.dispose();
    _petType.dispose();
    _petMarks.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image != null && mounted) setState(() => _image = image);
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => report_map.LocationSelectionPage(initialLocation: _location),
      ),
    );
    if (result != null && mounted) setState(() => _location = result);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_location == null) {
      _showMessage('يرجى تحديد الموقع على الخريطة.', isError: true);
      return;
    }
    if (_itemType == 'found' && _image == null) {
      _showMessage('الصورة إجبارية عند نشر غرض موجود.', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final form = FormData.fromMap({
        'item_type': _itemType,
        'category': _category,
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'latitude': _location!.latitude,
        'longitude': _location!.longitude,
        if (_area.text.trim().isNotEmpty) 'area_name': _area.text.trim(),
        if (_incidentDate != null) 'incident_date': _incidentDate!.toIso8601String().split('T').first,
        if (_category == 'pet' && _petType.text.trim().isNotEmpty) 'pet_type': _petType.text.trim(),
        if (_category == 'pet' && _petMarks.text.trim().isNotEmpty) 'pet_identifying_marks': _petMarks.text.trim(),
        if (_category == 'pet') 'pet_has_collar': _petHasCollar ? 1 : 0,
        if (_image != null) 'image': await MultipartFile.fromFile(_image!.path, filename: 'lost-found.jpg'),
      });

      final response = await ref.read(dioProvider).post(ApiConstants.lostFound, data: form);
      final warning = response.data is Map ? response.data['documents_warning']?.toString() : null;
      if (!mounted) return;
      Navigator.of(context).pop(true);
      if (warning?.isNotEmpty == true) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(warning!)));
      }
    } catch (e) {
      _showMessage(_messageFromError(e), isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? Colors.red[700] : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('نشر مفقود أو موجود')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'found', label: Text('موجود لدي')),
                  ButtonSegment(value: 'lost', label: Text('أبحث عنه')),
                ],
                selected: {_itemType},
                onSelectionChanged: (value) => setState(() => _itemType = value.first),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'تصنيف الغرض', border: OutlineInputBorder()),
                items: _LostFoundItem.categoryLabels.entries
                    .map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value)))
                    .toList(),
                onChanged: (value) => setState(() => _category = value ?? 'keys'),
              ),
              if (_category == 'documents')
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'تنبيه: الوثائق الرسمية تحتاج أيضاً إلى تبليغ الجهات المختصة. التطبيق مكمل وليس بديلاً عن الإجراء الرسمي.',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'العنوان', border: OutlineInputBorder()),
                validator: (value) => value == null || value.trim().isEmpty ? 'العنوان مطلوب' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'الوصف', border: OutlineInputBorder()),
                validator: (value) => value == null || value.trim().isEmpty ? 'الوصف مطلوب' : null,
              ),
              if (_category == 'pet') ...[
                const SizedBox(height: 12),
                TextField(controller: _petType, decoration: const InputDecoration(labelText: 'نوع الحيوان', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: _petMarks, decoration: const InputDecoration(labelText: 'علامات مميزة', border: OutlineInputBorder())),
                SwitchListTile(
                  value: _petHasCollar,
                  onChanged: (value) => setState(() => _petHasCollar = value),
                  title: const Text('يحمل طوق تعريف'),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _area,
                decoration: const InputDecoration(labelText: 'الحي أو الموقع التقريبي', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickLocation,
                icon: const Icon(Icons.map_outlined),
                label: Text(_location == null ? 'تحديد الموقع على الخريطة' : 'تم تحديد الموقع'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _incidentDate ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _incidentDate = picked);
                },
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(_incidentDate == null ? 'تاريخ العثور/الفقدان التقريبي' : _formatDate(_incidentDate!)),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image_outlined),
                label: Text(_image == null ? 'اختيار صورة' : 'تم اختيار الصورة'),
              ),
              if (_image != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(File(_image!.path), height: 170, fit: BoxFit.cover),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting ? const CircularProgressIndicator() : const Text('نشر'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LostFoundDetailsPage extends ConsumerStatefulWidget {
  final _LostFoundItem item;

  const _LostFoundDetailsPage({required this.item});

  @override
  ConsumerState<_LostFoundDetailsPage> createState() => _LostFoundDetailsPageState();
}

class _LostFoundDetailsPageState extends ConsumerState<_LostFoundDetailsPage> {
  final _commentController = TextEditingController();
  late _LostFoundItem _item = widget.item;
  bool _isLoading = false;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final response = await ref.read(dioProvider).get('${ApiConstants.lostFound}/${_item.id}');
      if (!mounted) return;
      setState(() {
        _item = _LostFoundItem.fromJson(response.data['item'] ?? {});
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(e);
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() => _isBusy = true);
    try {
      await ref.read(dioProvider).post(
        '${ApiConstants.lostFound}/${_item.id}/comments',
        data: {'comment_text': text},
      );
      _commentController.clear();
      await _load();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _startChat() async {
    setState(() => _isBusy = true);
    try {
      final response = await ref.read(dioProvider).post('${ApiConstants.lostFound}/${_item.id}/threads');
      final thread = _LostFoundThread.fromJson(response.data['thread'] ?? {});
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => _LostFoundChatPage(thread: thread)),
      );
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _resolve() async {
    await _runOwnerAction('${ApiConstants.lostFound}/${_item.id}/resolve');
  }

  Future<void> _republish() async {
    await _runOwnerAction('${ApiConstants.lostFound}/${_item.id}/republish');
  }

  Future<void> _runOwnerAction(String path) async {
    setState(() => _isBusy = true);
    try {
      await ref.read(dioProvider).post(path);
      await _load();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _reportItem() async {
    final reason = await _askReason(context);
    if (reason == null || reason.trim().isEmpty) return;
    try {
      await ref.read(dioProvider).post(
        '${ApiConstants.lostFound}/report-abuse',
        data: {'reportable_type': 'item', 'reportable_id': _item.id, 'reason': reason},
      );
      _showMessage('تم إرسال البلاغ للمراجعة.');
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _openLocation() async {
    if (_item.latitude == null || _item.longitude == null) return;
    final lat = _item.latitude!;
    final lng = _item.longitude!;
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showError(Object error) => _showMessage(_messageFromError(error), isError: true);

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? Colors.red[700] : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _absoluteUrl(_item.imageUrl);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_item.title),
          actions: [
            IconButton(onPressed: _reportItem, icon: const Icon(Icons.flag_outlined)),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (imageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(imageUrl, height: 220, width: double.infinity, fit: BoxFit.cover),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _Chip(label: _item.typeLabel),
                      const SizedBox(width: 8),
                      _Chip(label: _item.categoryLabel),
                      const Spacer(),
                      _Chip(label: _item.statusLabel),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(_item.description, style: const TextStyle(height: 1.5)),
                  if (_item.areaName?.isNotEmpty == true) ...[
                    const SizedBox(height: 10),
                    Text('الموقع التقريبي: ${_item.areaName}'),
                  ],
                  if (_item.petType?.isNotEmpty == true) Text('نوع الحيوان: ${_item.petType}'),
                  if (_item.petIdentifyingMarks?.isNotEmpty == true) Text('علامات مميزة: ${_item.petIdentifyingMarks}'),
                  if (_item.category == 'documents')
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text('تنبيه: يفضل التبليغ عن الوثائق الرسمية لدى الجهات المختصة أيضاً.', style: TextStyle(color: Colors.orange)),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(onPressed: _openLocation, icon: const Icon(Icons.map_outlined), label: const Text('عرض الموقع على الخريطة')),
                  const SizedBox(height: 12),
                  if (!_item.isOwner && _item.status == 'active')
                    FilledButton.icon(
                      onPressed: _isBusy ? null : _startChat,
                      icon: const Icon(Icons.lock_outline),
                      label: const Text('أتواصل مع الناشر بشكل مجهول'),
                    ),
                  if (_item.isOwner && _item.status == 'active')
                    FilledButton(onPressed: _isBusy ? null : _resolve, child: const Text('تم الحل')),
                  if (_item.isOwner && _item.status == 'expired')
                    FilledButton(onPressed: _isBusy ? null : _republish, child: const Text('إعادة النشر')),
                  const SizedBox(height: 20),
                  const Text('التعليقات العامة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  if (_item.comments.isEmpty)
                    const Text('لا توجد تعليقات بعد.')
                  else
                    ..._item.comments.map(
                      (comment) => Card(
                        child: ListTile(
                          title: Text(comment.authorAlias),
                          subtitle: Text(comment.commentText),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _commentController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(hintText: 'اكتب تعليقاً عاماً...', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _isBusy ? null : _sendComment,
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('إرسال تعليق'),
                  ),
                ],
              ),
      ),
    );
  }
}

class _LostFoundChatPage extends ConsumerStatefulWidget {
  final _LostFoundThread thread;

  const _LostFoundChatPage({required this.thread});

  @override
  ConsumerState<_LostFoundChatPage> createState() => _LostFoundChatPageState();
}

class _LostFoundChatPageState extends ConsumerState<_LostFoundChatPage> {
  final _controller = TextEditingController();
  late _LostFoundThread _thread = widget.thread;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final response = await ref.read(dioProvider).get('${ApiConstants.lostFound}/threads/${_thread.id}');
      if (!mounted) return;
      setState(() {
        _thread = _LostFoundThread.fromJson(response.data['thread'] ?? {});
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_messageFromError(e))));
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    try {
      await ref.read(dioProvider).post(
        '${ApiConstants.lostFound}/threads/${_thread.id}/messages',
        data: {'message_text': text},
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_messageFromError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(_thread.itemTitle)),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('المحادثة مجهولة: أنت تظهر باسم "${_thread.viewerAlias}" والطرف الآخر باسم "${_thread.otherAlias}".'),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _thread.messages.length,
                      itemBuilder: (context, index) {
                        final message = _thread.messages[index];
                        return Align(
                          alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            constraints: const BoxConstraints(maxWidth: 280),
                            decoration: BoxDecoration(
                              color: message.isMine
                                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                                  : Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(message.senderAlias, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(message.messageText),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(hintText: 'اكتب رسالة...', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(onPressed: _send, icon: const Icon(Icons.send_rounded)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LostFoundItemCard extends StatelessWidget {
  final _LostFoundItem item;
  final VoidCallback onTap;

  const _LostFoundItemCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final imageUrl = _absoluteUrl(item.imageUrl);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null)
              Image.network(imageUrl, height: 160, width: double.infinity, fit: BoxFit.cover),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                      _Chip(label: item.typeLabel),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(item.categoryLabel, style: const TextStyle(fontSize: 12)),
                      const Spacer(),
                      if (item.areaName?.isNotEmpty == true) Text(item.areaName!, style: const TextStyle(fontSize: 12)),
                      if (item.distanceKm != null) Text(' · ${item.distanceKm!.toStringAsFixed(1)} كم', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;

  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary)),
    );
  }
}

class _LostFoundItem {
  static const categoryLabels = {
    'keys': 'مفاتيح',
    'documents': 'وثائق/هوية',
    'pet': 'حيوان أليف',
    'electronics': 'إلكترونيات',
    'wallet_money': 'محفظة/أموال',
    'other': 'أخرى',
  };

  final int id;
  final String itemType;
  final String category;
  final String title;
  final String description;
  final String? imageUrl;
  final double? latitude;
  final double? longitude;
  final String? areaName;
  final String status;
  final bool isOwner;
  final double? distanceKm;
  final String? petType;
  final String? petIdentifyingMarks;
  final List<_LostFoundComment> comments;

  const _LostFoundItem({
    required this.id,
    required this.itemType,
    required this.category,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.areaName,
    required this.status,
    required this.isOwner,
    required this.distanceKm,
    required this.petType,
    required this.petIdentifyingMarks,
    required this.comments,
  });

  factory _LostFoundItem.fromJson(Map<dynamic, dynamic> json) {
    final rawComments = json['comments'];
    final comments = rawComments is List
        ? rawComments.whereType<Map>().map((item) => _LostFoundComment.fromJson(item)).toList(growable: false)
        : <_LostFoundComment>[];

    return _LostFoundItem(
      id: _int(json['id']),
      itemType: json['item_type']?.toString() ?? 'found',
      category: json['category']?.toString() ?? 'other',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      imageUrl: json['image_url']?.toString(),
      latitude: _doubleOrNull(json['latitude']),
      longitude: _doubleOrNull(json['longitude']),
      areaName: json['area_name']?.toString(),
      status: json['status']?.toString() ?? '',
      isOwner: json['is_owner'] == true,
      distanceKm: _doubleOrNull(json['distance_km']),
      petType: json['pet_type']?.toString(),
      petIdentifyingMarks: json['pet_identifying_marks']?.toString(),
      comments: comments,
    );
  }

  String get typeLabel => itemType == 'lost' ? 'مفقود' : 'موجود';
  String get categoryLabel => categoryLabels[category] ?? category;
  String get statusLabel {
    switch (status) {
      case 'active':
        return 'نشط';
      case 'resolved':
        return 'تم الحل';
      case 'expired':
        return 'منتهي';
      case 'removed':
        return 'محذوف';
      default:
        return status;
    }
  }
}

class _LostFoundComment {
  final int id;
  final String commentText;
  final String authorAlias;

  const _LostFoundComment({required this.id, required this.commentText, required this.authorAlias});

  factory _LostFoundComment.fromJson(Map<dynamic, dynamic> json) {
    return _LostFoundComment(
      id: _int(json['id']),
      commentText: json['comment_text']?.toString() ?? '',
      authorAlias: json['author_alias']?.toString() ?? 'مواطن',
    );
  }
}

class _LostFoundThread {
  final int id;
  final String itemTitle;
  final String itemType;
  final String viewerAlias;
  final String otherAlias;
  final String? lastMessage;
  final List<_LostFoundMessage> messages;

  const _LostFoundThread({
    required this.id,
    required this.itemTitle,
    required this.itemType,
    required this.viewerAlias,
    required this.otherAlias,
    required this.lastMessage,
    required this.messages,
  });

  factory _LostFoundThread.fromJson(Map<dynamic, dynamic> json) {
    final rawMessages = json['messages'];
    final messages = rawMessages is List
        ? rawMessages.whereType<Map>().map((item) => _LostFoundMessage.fromJson(item)).toList(growable: false)
        : <_LostFoundMessage>[];
    return _LostFoundThread(
      id: _int(json['id']),
      itemTitle: json['item_title']?.toString() ?? '',
      itemType: json['item_type']?.toString() ?? '',
      viewerAlias: json['viewer_alias']?.toString() ?? 'أنت',
      otherAlias: json['other_alias']?.toString() ?? 'الطرف الآخر',
      lastMessage: json['last_message']?.toString(),
      messages: messages,
    );
  }
}

class _LostFoundMessage {
  final int id;
  final String messageText;
  final bool isMine;
  final String senderAlias;

  const _LostFoundMessage({
    required this.id,
    required this.messageText,
    required this.isMine,
    required this.senderAlias,
  });

  factory _LostFoundMessage.fromJson(Map<dynamic, dynamic> json) {
    return _LostFoundMessage(
      id: _int(json['id']),
      messageText: json['message_text']?.toString() ?? '',
      isMine: json['is_mine'] == true,
      senderAlias: json['sender_alias']?.toString() ?? '',
    );
  }
}

Future<String?> _askReason(BuildContext context) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('سبب الإبلاغ'),
      content: TextField(
        controller: controller,
        minLines: 2,
        maxLines: 4,
        decoration: const InputDecoration(hintText: 'اكتب سبب الإبلاغ...'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('إرسال')),
      ],
    ),
  );
  controller.dispose();
  return result;
}

String _messageFromError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) return data['message'].toString();
    if (error.type == DioExceptionType.connectionError) return 'تعذر الاتصال بالخادم';
  }
  return error.toString();
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double? _doubleOrNull(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

String _formatDate(DateTime value) {
  return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
