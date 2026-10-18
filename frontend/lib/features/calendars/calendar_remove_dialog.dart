import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
import '../../models/calendar.dart';
import '../../providers/calendars_provider.dart';
import '../../providers/events_provider.dart';
import '../../shared/ds.dart';

/// J2·J3. 캘린더 나가기(참여자) · 캘린더 삭제(만든 사람) 확인 다이얼로그.
/// 실패하면 다이얼로그 안에 오류를 보여 주고 다시 시도할 수 있습니다.
Future<bool> showCalendarRemoval(
  BuildContext context,
  WidgetRef ref,
  SharedCalendar calendar, {
  required bool deleting,
}) => showDsConfirm(
  context,
  icon: deleting
      ? const DsIconTile(icon: DsIcons.trash)
      : const DsIconTile(
          icon: DsIcons.logout,
          background: AppColors.butterContainer,
          color: AppColors.onButterContainer,
        ),
  title: deleting
      ? '‘${calendar.name}’ 캘린더를 삭제할까요?'
      : '‘${calendar.name}’에서 나갈까요?',
  message: deleting
      ? '두 사람의 모든 일정과 초대코드가 삭제됩니다. 삭제한 캘린더는 복구할 수 없습니다.'
      : '내가 등록하거나 가져온 공유 일정이 삭제됩니다. 상대방 일정은 유지되며, 다시 참여하려면 새 초대코드가 필요합니다.',
  hint: '휴대폰에 저장된 원본 일정은 변경되지 않아요.',
  confirmLabel: deleting ? '삭제' : '나가기',
  confirmLoadingLabel: deleting ? '삭제 중…' : '나가는 중…',
  danger: true,
  errorText: extractErrorMessage,
  onConfirm: () async {
    final service = ref.read(calendarsServiceProvider);
    if (deleting) {
      await service.delete(calendar.id);
    } else {
      await service.leave(calendar.id);
    }
    ref.invalidate(calendarsProvider);
    ref.invalidate(calendarDetailProvider(calendar.id));
    ref.invalidate(eventsProvider);
  },
);
