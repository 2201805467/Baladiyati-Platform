import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_constants.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

class PollsPage extends ConsumerStatefulWidget {
  final bool showAppBar;

  const PollsPage({super.key, this.showAppBar = true});

  @override
  ConsumerState<PollsPage> createState() => _PollsPageState();
}

class _PollsPageState extends ConsumerState<PollsPage> {
  String _status = 'active';
  bool _isLoading = false;
  List<_Poll> _polls = const [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final response = await ref.read(dioProvider).get(
        ApiConstants.polls,
        queryParameters: {
          'status': _status,
          'per_page': 50,
        },
      );
      final raw = response.data['data'] ?? response.data;
      final list = raw is List ? raw : const [];
      if (!mounted) return;
      setState(() {
        _polls = list
            .whereType<Map>()
            .map((item) => _Poll.fromJson(item))
            .toList(growable: false);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_messageFromError(e)), backgroundColor: Colors.red[700]),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openPoll(_Poll poll) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _PollDetailsPage(poll: poll)),
    );
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Column(
            children: [
              const _AdvisoryNotice(),
              const SizedBox(height: 10),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'active', label: Text('نشطة الآن')),
                  ButtonSegment(value: 'closed', label: Text('منتهية')),
                ],
                selected: {_status},
                onSelectionChanged: (value) {
                  setState(() => _status = value.first);
                  _load();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading && _polls.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _polls.isEmpty
                  ? const Center(child: Text('لا توجد استطلاعات حالياً'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _polls.length,
                        itemBuilder: (context, index) {
                          final poll = _polls[index];
                          return _PollCard(
                            poll: poll,
                            onTap: () => _openPoll(poll),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: widget.showAppBar
          ? Scaffold(
              appBar: AppBar(title: const Text('استطلاعات الرأي')),
              body: body,
            )
          : body,
    );
  }
}

class _PollDetailsPage extends ConsumerStatefulWidget {
  final _Poll poll;

  const _PollDetailsPage({required this.poll});

  @override
  ConsumerState<_PollDetailsPage> createState() => _PollDetailsPageState();
}

class _PollDetailsPageState extends ConsumerState<_PollDetailsPage> {
  late _Poll _poll;
  bool _isVoting = false;

  @override
  void initState() {
    super.initState();
    _poll = widget.poll;
    Future.microtask(_refresh);
  }

  Future<void> _refresh() async {
    try {
      final response = await ref.read(dioProvider).get('${ApiConstants.polls}/${_poll.id}');
      if (!mounted) return;
      setState(() => _poll = _Poll.fromJson(response.data['poll'] ?? {}));
    } catch (_) {
      // The list item already has enough data for the first render.
    }
  }

  Future<void> _vote(_PollOption option) async {
    if (_isVoting || !_poll.isOpen || _poll.hasVoted) return;
    setState(() => _isVoting = true);
    try {
      final response = await ref.read(dioProvider).post(
        '${ApiConstants.polls}/${_poll.id}/vote',
        data: {'poll_option_id': option.id},
      );
      if (!mounted) return;
      setState(() => _poll = _Poll.fromJson(response.data['poll'] ?? {}));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل صوتك بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_messageFromError(e)), backgroundColor: Colors.red[700]),
      );
    } finally {
      if (mounted) setState(() => _isVoting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الاستطلاع')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _AdvisoryNotice(),
            const SizedBox(height: 14),
            Text(
              _poll.question,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip(label: _poll.typeLabel),
                _Chip(label: _poll.statusLabel),
                _Chip(label: _poll.timeText),
              ],
            ),
            const SizedBox(height: 20),
            ..._poll.options.map((option) {
              final selected = _poll.selectedOptionId == option.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _poll.showResults
                    ? _ResultOption(
                        option: option,
                        selected: selected,
                        color: primary,
                      )
                    : OutlinedButton(
                        onPressed: _isVoting ? null : () => _vote(option),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                          alignment: Alignment.centerRight,
                        ),
                        child: Text(option.optionText),
                      ),
              );
            }),
            if (!_poll.showResults)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'لن تظهر النتائج قبل تسجيل صوتك لتجنب التأثير على اختيارك.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            if (_poll.showResults) ...[
              const SizedBox(height: 8),
              Text(
                'إجمالي الأصوات: ${_poll.totalVotes}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PollCard extends StatelessWidget {
  final _Poll poll;
  final VoidCallback onTap;

  const _PollCard({required this.poll, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      poll.question,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Icon(Icons.poll_outlined),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Chip(label: poll.typeLabel),
                  _Chip(label: poll.timeText),
                  if (poll.hasVoted) const _Chip(label: 'تم التصويت'),
                ],
              ),
              const SizedBox(height: 10),
              if (poll.showResults)
                ...poll.options.take(2).map((option) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ResultOption(option: option, selected: poll.selectedOptionId == option.id),
                    ))
              else
                Text(
                  '${poll.options.length} خيارات متاحة',
                  style: const TextStyle(color: Colors.grey),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultOption extends StatelessWidget {
  final _PollOption option;
  final bool selected;
  final Color? color;

  const _ResultOption({required this.option, required this.selected, this.color});

  @override
  Widget build(BuildContext context) {
    final primary = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: selected ? primary : Colors.transparent),
        color: selected ? primary.withValues(alpha: 0.08) : Theme.of(context).cardColor,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(option.optionText)),
              Text('${option.percentage.toStringAsFixed(1)}%'),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: option.percentage / 100,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('${option.votesCount} صوت', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}

class _AdvisoryNotice extends StatelessWidget {
  const _AdvisoryNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.45)),
      ),
      child: const Text(
        'هذا استطلاع رأي استشاري، ولا يمثل التزاماً تنفيذياً من البلدية.',
        style: TextStyle(fontSize: 12),
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
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary)),
    );
  }
}

class _Poll {
  final int id;
  final String question;
  final String pollType;
  final String status;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool isOpen;
  final bool hasVoted;
  final int? selectedOptionId;
  final bool showResults;
  final int totalVotes;
  final List<_PollOption> options;

  const _Poll({
    required this.id,
    required this.question,
    required this.pollType,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    required this.isOpen,
    required this.hasVoted,
    required this.selectedOptionId,
    required this.showResults,
    required this.totalVotes,
    required this.options,
  });

  factory _Poll.fromJson(Map<dynamic, dynamic> json) {
    final options = (json['options'] is List ? json['options'] as List : const [])
        .whereType<Map>()
        .map((item) => _PollOption.fromJson(item))
        .toList(growable: false);

    return _Poll(
      id: _int(json['id']),
      question: json['question']?.toString() ?? '',
      pollType: json['poll_type']?.toString() ?? 'quick',
      status: json['status']?.toString() ?? '',
      startsAt: DateTime.tryParse(json['starts_at']?.toString() ?? ''),
      endsAt: DateTime.tryParse(json['ends_at']?.toString() ?? ''),
      isOpen: json['is_open'] == true,
      hasVoted: json['has_voted'] == true,
      selectedOptionId: json['selected_option_id'] == null ? null : _int(json['selected_option_id']),
      showResults: json['show_results'] == true,
      totalVotes: _int(json['total_votes'] ?? json['votes_count']),
      options: options,
    );
  }

  String get typeLabel {
    switch (pollType) {
      case 'satisfaction':
        return 'استبيان رضا';
      case 'budgeting':
        return 'تصويت مشاريع';
      default:
        return 'استطلاع سريع';
    }
  }

  String get statusLabel {
    switch (status) {
      case 'active':
        return isOpen ? 'نشط' : 'لم يبدأ بعد';
      case 'closed':
        return 'منتهي';
      case 'cancelled':
        return 'ملغى';
      default:
        return status;
    }
  }

  String get timeText {
    if (status == 'closed') return 'منتهي';
    if (endsAt == null) return '';
    final now = DateTime.now();
    if (now.isAfter(endsAt!)) return 'منتهي';
    final diff = endsAt!.difference(now);
    if (diff.inDays >= 1) return 'سينتهي بعد ${diff.inDays} يوم';
    if (diff.inHours >= 1) return 'سينتهي بعد ${diff.inHours} ساعة';
    return 'سينتهي بعد ${diff.inMinutes.clamp(0, 59)} دقيقة';
  }
}

class _PollOption {
  final int id;
  final String optionText;
  final int votesCount;
  final double percentage;

  const _PollOption({
    required this.id,
    required this.optionText,
    required this.votesCount,
    required this.percentage,
  });

  factory _PollOption.fromJson(Map<dynamic, dynamic> json) {
    return _PollOption(
      id: _int(json['id']),
      optionText: json['option_text']?.toString() ?? '',
      votesCount: _int(json['votes_count']),
      percentage: _double(json['percentage']),
    );
  }
}

String _messageFromError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) return data['message'].toString();
    if (data is Map && data['errors'] is Map) {
      return (data['errors'] as Map).values.expand((value) => value is List ? value : [value]).join('\n');
    }
    if (error.type == DioExceptionType.connectionError) return 'تعذر الاتصال بالخادم';
  }
  return error.toString();
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _double(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
