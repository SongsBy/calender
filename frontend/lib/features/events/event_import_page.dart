import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config.dart';
import '../../core/api_exception.dart';
import '../../models/event.dart';
import '../../providers/app_providers.dart';
import '../../providers/events_provider.dart';
import '../../services/device_calendar_service.dart';

final deviceCalendarProvider = Provider((ref) => DeviceCalendarService());

class EventImportPage extends ConsumerStatefulWidget {
  const EventImportPage({
    super.key,
    required this.calendarId,
    required this.zone,
  });
  final String calendarId, zone;
  @override
  ConsumerState<EventImportPage> createState() => _EventImportPageState();
}

class _EventImportPageState extends ConsumerState<EventImportPage> {
  List<Map<String, dynamic>> calendars = [];
  List<DeviceEvent> events = [];
  final selected = <String>{};
  String? calendarId, error;
  bool busy = false, denied = false, loaded = false;
  late DateTimeRange range;
  DeviceCalendarService get service => ref.read(deviceCalendarProvider);
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    range = DateTimeRange(
      start: DateTime(now.year, now.month, now.day),
      end: DateTime(now.year, now.month, now.day + 30),
    );
  }

  Future<void> perform(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is PlatformException
              ? e.message
              : extractErrorMessage(e),
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> connect() => perform(() async {
    final allowed = await service.requestPermission();
    if (!mounted) return;
    setState(() => denied = !allowed);
    if (!allowed) return;
    final values = await service.calendars();
    if (mounted) {
      setState(() {
        calendars = values;
        calendarId = values.isEmpty ? null : values.first['id'] as String;
        loaded = true;
        events = [];
        selected.clear();
      });
    }
  });
  Future<void> read() => perform(() async {
    final values = await service.events(
      calendarId!,
      range.start,
      DateTime(range.end.year, range.end.month, range.end.day + 1),
    );
    if (mounted) {
      setState(() {
        events = values;
        selected.clear();
        if (values.isEmpty) error = '이 기간에 저장된 일정이 없습니다.';
      });
    }
  });
  Future<void> upload() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${selected.length}개 일정을 공유할까요?'),
        content: const Text(
          '선택한 일정의 제목·시간·설명이 상대방에게 공개됩니다. 원본 변경 및 삭제는 자동 반영되지 않습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('공유하기'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await perform(() async {
      final id = await service.installationId();
      final response = await ref
          .read(dioProvider)
          .post<Map<String, dynamic>>(
            '${AppConfig.apiPrefix}/calendars/${widget.calendarId}/events/import',
            data: {
              'installation_id': id,
              'events': events
                  .where((e) => selected.contains(e.key))
                  .map((e) => e.toJson())
                  .toList(),
            },
          );
      ref.invalidate(eventsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${response.data!['created_count']}개 가져옴 · 중복 ${response.data!['skipped_count']}개 건너뜀',
          ),
        ),
      );
      Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('기기 일정 가져오기')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            '안드로이드에 저장된 일정 중 선택한 일정만 복사합니다. 읽기 권한을 허용해도 자동으로 공유되지 않습니다.',
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: busy ? null : connect,
            child: Text(loaded ? '캘린더 다시 읽기' : '읽기 권한 허용하고 시작'),
          ),
          if (denied) ...[
            const Text('읽기 권한이 필요합니다. 권한 창이 나타나지 않으면 앱 설정에서 허용해주세요.'),
            TextButton(
              onPressed: busy ? null : () => perform(service.settings),
              child: const Text('앱 설정 열기'),
            ),
          ],
          if (loaded && calendars.isEmpty)
            const Text('기기에 캘린더가 없습니다. 기본 캘린더 앱에서 계정 동기화를 확인해주세요.'),
          if (calendars.isNotEmpty) ...[
            DropdownButton<String>(
              isExpanded: true,
              value: calendarId,
              items: calendars
                  .map(
                    (c) => DropdownMenuItem(
                      value: c['id'] as String,
                      child: Text('${c['name']} (${c['id']})'),
                    ),
                  )
                  .toList(),
              onChanged: busy
                  ? null
                  : (v) => setState(() {
                      calendarId = v;
                      events = [];
                      selected.clear();
                    }),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      final value = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(1900),
                        lastDate: DateTime(2100),
                        initialDateRange: range,
                        helpText: '최대 93일 · 종료일 포함',
                      );
                      if (value != null && mounted) {
                        setState(() {
                          if (value.duration.inDays >= 93) {
                            error = '기간은 최대 93일입니다.';
                            return;
                          }
                          range = value;
                          events = [];
                          selected.clear();
                          error = null;
                        });
                      }
                    },
              child: Text('${dateText(range.start)} ~ ${dateText(range.end)}'),
            ),
            OutlinedButton(
              onPressed: busy ? null : read,
              child: const Text('일정 조회'),
            ),
          ],
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (events.isNotEmpty) ...[
            Text('공유할 일정 선택 (${selected.length}/100) · ${widget.zone} 기준'),
            for (final e in events)
              CheckboxListTile(
                value: selected.contains(e.key),
                title: Text(e.event.title),
                subtitle: Text(
                  '${e.event.periodLabel(widget.zone)}${e.event.description?.isNotEmpty == true ? '\n${e.event.description}' : ''}',
                ),
                onChanged: busy
                    ? null
                    : (v) => setState(() {
                        if (v == true && selected.length < 100) {
                          selected.add(e.key);
                        } else if (v != true) {
                          selected.remove(e.key);
                        }
                      }),
              ),
            FilledButton(
              onPressed: busy || selected.isEmpty ? null : upload,
              child: Text('${selected.length}개 가져오기'),
            ),
          ],
        ],
      ),
    ),
  );
}
