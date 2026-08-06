import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/network/api_constants.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class MunicipalityChatPage extends ConsumerStatefulWidget {
  const MunicipalityChatPage({super.key});

  @override
  ConsumerState<MunicipalityChatPage> createState() =>
      _MunicipalityChatPageState();
}

class _MunicipalityChatPageState extends ConsumerState<MunicipalityChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();
  _MunicipalityChatThread? _thread;
  XFile? _selectedImage;
  Position? _selectedLocation;
  bool _isLoading = true;
  bool _isSending = false;
  bool _outsideWorkingHours = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _load();
      _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (!_isSending) _refresh();
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    await _refresh(showLoader: true, showErrors: true);
  }

  Future<void> _refresh({
    bool showLoader = false,
    bool showErrors = false,
  }) async {
    try {
      final response = await ref.read(dioProvider).get(
            ApiConstants.municipalityChat,
          );
      if (!mounted) return;
      setState(() {
        _thread = _MunicipalityChatThread.fromJson(response.data['thread']);
        _outsideWorkingHours =
            response.data['outside_working_hours'] == true;
        if (showLoader) _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      if (showLoader) setState(() => _isLoading = false);
      if (showErrors) _showMessage(_messageFromError(e), isError: true);
    }
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (image == null) return;
    setState(() => _selectedImage = image);
  }

  Future<void> _attachLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showMessage('يرجى تفعيل خدمة الموقع أولاً.', isError: true);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage('تعذر الحصول على إذن الموقع.', isError: true);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      setState(() => _selectedLocation = position);
      _showMessage('تم إرفاق الموقع.');
    } catch (e) {
      _showMessage(_messageFromError(e), isError: true);
    }
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _selectedImage == null && _selectedLocation == null) {
      return;
    }

    setState(() => _isSending = true);
    try {
      final form = FormData();
      if (text.isNotEmpty) {
        form.fields.add(MapEntry('message_text', text));
      }
      if (_selectedLocation != null) {
        form.fields.add(
          MapEntry('latitude', _selectedLocation!.latitude.toString()),
        );
        form.fields.add(
          MapEntry('longitude', _selectedLocation!.longitude.toString()),
        );
      }
      if (_selectedImage != null) {
        form.files.add(
          MapEntry(
            'image',
            await MultipartFile.fromFile(
              _selectedImage!.path,
              filename: _selectedImage!.name,
            ),
          ),
        );
      }

      final response = await ref
          .read(dioProvider)
          .post(ApiConstants.municipalityChatMessages, data: form);
      if (!mounted) return;
      setState(() {
        _thread = _MunicipalityChatThread.fromJson(response.data['thread']);
        _outsideWorkingHours =
            response.data['outside_working_hours'] == true;
        _messageController.clear();
        _selectedImage = null;
        _selectedLocation = null;
      });
      _scrollToBottom();
      await _refresh();
    } catch (e) {
      _showMessage(_messageFromError(e), isError: true);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _openMap(_ChatMessage message) async {
    final lat = message.latitude;
    final lng = message.longitude;
    if (lat == null || lng == null) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[700] : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final green = Colors.green[700]!;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('خدمة العملاء')),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.55),
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 10,
                          color: _thread?.staffOnline == true
                              ? Colors.green
                              : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _thread?.staffOnline == true
                                ? 'موظف البلدية متصل الآن'
                                : 'سيتم الرد خلال ساعات العمل الرسمية',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Text(
                          _thread?.statusLabel ?? '',
                          style: TextStyle(
                            color: green,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_outsideWorkingHours)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      color: Colors.amber.withValues(alpha: 0.16),
                      child: const Text(
                        'خارج ساعات الدوام: 9 صباحاً - 3 مساءً، الأحد-الخميس.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _thread?.messages.length ?? 0,
                      itemBuilder: (context, index) {
                        final message = _thread!.messages[index];
                        return _MessageBubble(
                          message: message,
                          onOpenMap: () => _openMap(message),
                        );
                      },
                    ),
                  ),
                  _Composer(
                    controller: _messageController,
                    selectedImage: _selectedImage,
                    hasLocation: _selectedLocation != null,
                    isSending: _isSending,
                    onPickImage: _pickImage,
                    onAttachLocation: _attachLocation,
                    onClearImage: () => setState(() => _selectedImage = null),
                    onClearLocation: () =>
                        setState(() => _selectedLocation = null),
                    onSend: _send,
                  ),
                ],
              ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  final VoidCallback onOpenMap;

  const _MessageBubble({required this.message, required this.onOpenMap});

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;
    final imageUrl = _absoluteUrl(message.imageUrl);

    return Align(
      alignment: message.isSystem
          ? Alignment.center
          : isMine
              ? Alignment.centerRight
              : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: message.isSystem
              ? Colors.blueGrey.withValues(alpha: 0.12)
              : isMine
                  ? Colors.green.withValues(alpha: 0.16)
                  : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: message.isSystem
                ? Colors.blueGrey.withValues(alpha: 0.25)
                : isMine
                    ? Colors.green.withValues(alpha: 0.25)
                    : Colors.black12,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.senderLabel,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            if (message.text?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(message.text!, style: const TextStyle(height: 1.45)),
            ],
            if (imageUrl != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  imageUrl,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            if (message.latitude != null && message.longitude != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onOpenMap,
                icon: const Icon(Icons.location_on_outlined, size: 18),
                label: const Text('عرض الموقع'),
              ),
            ],
            if (message.createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                _formatDateTime(message.createdAt!),
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final XFile? selectedImage;
  final bool hasLocation;
  final bool isSending;
  final VoidCallback onPickImage;
  final VoidCallback onAttachLocation;
  final VoidCallback onClearImage;
  final VoidCallback onClearLocation;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.selectedImage,
    required this.hasLocation,
    required this.isSending,
    required this.onPickImage,
    required this.onAttachLocation,
    required this.onClearImage,
    required this.onClearLocation,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: const Border(top: BorderSide(color: Colors.black12)),
        ),
        child: Column(
          children: [
            if (selectedImage != null || hasLocation)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (selectedImage != null)
                      InputChip(
                        label: Text(selectedImage!.name),
                        avatar: const Icon(Icons.image_outlined, size: 18),
                        onDeleted: onClearImage,
                      ),
                    if (hasLocation)
                      InputChip(
                        label: const Text('موقع مرفق'),
                        avatar: const Icon(Icons.location_on_outlined, size: 18),
                        onDeleted: onClearLocation,
                      ),
                  ],
                ),
              ),
            Row(
              children: [
                IconButton(
                  onPressed: isSending ? null : onPickImage,
                  icon: const Icon(Icons.image_outlined),
                ),
                IconButton(
                  onPressed: isSending ? null : onAttachLocation,
                  icon: const Icon(Icons.location_on_outlined),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'اكتب رسالتك...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: isSending ? null : onSend,
                  child: isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MunicipalityChatThread {
  final int id;
  final String statusLabel;
  final bool staffOnline;
  final List<_ChatMessage> messages;

  _MunicipalityChatThread({
    required this.id,
    required this.statusLabel,
    required this.staffOnline,
    required this.messages,
  });

  factory _MunicipalityChatThread.fromJson(dynamic json) {
    final data = json is Map ? json : {};
    final rawMessages = data['messages'];
    return _MunicipalityChatThread(
      id: int.tryParse(data['id']?.toString() ?? '') ?? 0,
      statusLabel: data['status_label']?.toString() ?? '',
      staffOnline: data['staff_online'] == true,
      messages: rawMessages is List
          ? rawMessages
              .whereType<Map>()
              .map((item) => _ChatMessage.fromJson(item))
              .toList()
          : const [],
    );
  }
}

class _ChatMessage {
  final int id;
  final String senderLabel;
  final String? text;
  final String? imageUrl;
  final double? latitude;
  final double? longitude;
  final bool isSystem;
  final bool isMine;
  final DateTime? createdAt;

  _ChatMessage({
    required this.id,
    required this.senderLabel,
    required this.text,
    required this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.isSystem,
    required this.isMine,
    required this.createdAt,
  });

  factory _ChatMessage.fromJson(Map json) {
    return _ChatMessage(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      senderLabel: json['sender_label']?.toString() ?? '',
      text: json['message_text']?.toString(),
      imageUrl: json['image_url']?.toString(),
      latitude: double.tryParse(json['latitude']?.toString() ?? ''),
      longitude: double.tryParse(json['longitude']?.toString() ?? ''),
      isSystem: json['is_system'] == true,
      isMine: json['is_mine'] == true,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

String? _absoluteUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('http')) return url;
  final origin = ApiConstants.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
  return '$origin${url.startsWith('/') ? url : '/$url'}';
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _messageFromError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
  }
  return error.toString();
}
