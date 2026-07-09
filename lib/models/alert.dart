/// 告警事件类型
enum AlertType {
  presenceAppeared,
  presenceDisappeared,
  motionStarted,
  motionStopped,
  personCountChanged,
  signalLow,
  hrHigh,
  hrLow,
  brHigh,
  brLow,
}

extension AlertTypeLabel on AlertType {
  String get labelKey {
    switch (this) {
      case AlertType.presenceAppeared:
        return 'alert_presence_appeared';
      case AlertType.presenceDisappeared:
        return 'alert_presence_disappeared';
      case AlertType.motionStarted:
        return 'alert_motion_started';
      case AlertType.motionStopped:
        return 'alert_motion_stopped';
      case AlertType.personCountChanged:
        return 'alert_person_count_changed';
      case AlertType.signalLow:
        return 'alert_signal_low';
      case AlertType.hrHigh:
        return 'alert_hr_high_label';
      case AlertType.hrLow:
        return 'alert_hr_low_label';
      case AlertType.brHigh:
        return 'alert_br_high_label';
      case AlertType.brLow:
        return 'alert_br_low_label';
    }
  }

  String get descKey {
    switch (this) {
      case AlertType.presenceAppeared:
        return 'alert_presence_appeared_desc';
      case AlertType.presenceDisappeared:
        return 'alert_presence_disappeared_desc';
      case AlertType.motionStarted:
        return 'alert_motion_started_desc';
      case AlertType.motionStopped:
        return 'alert_motion_stopped_desc';
      case AlertType.personCountChanged:
        return 'alert_person_count_changed_desc';
      case AlertType.signalLow:
        return 'alert_signal_low_desc';
      case AlertType.hrHigh:
        return 'alert_hr_high_desc';
      case AlertType.hrLow:
        return 'alert_hr_low_desc';
      case AlertType.brHigh:
        return 'alert_br_high_desc';
      case AlertType.brLow:
        return 'alert_br_low_desc';
    }
  }

  /// Default Chinese label for service-layer use (debugPrint, notifications)
  String get label {
    switch (this) {
      case AlertType.presenceAppeared:
        return '人员进入';
      case AlertType.presenceDisappeared:
        return '人员离开';
      case AlertType.motionStarted:
        return '运动开始';
      case AlertType.motionStopped:
        return '人员静止';
      case AlertType.personCountChanged:
        return '人数变化';
      case AlertType.signalLow:
        return '信号质量低';
      case AlertType.hrHigh:
        return '心率过高';
      case AlertType.hrLow:
        return '心率过低';
      case AlertType.brHigh:
        return '呼吸过快';
      case AlertType.brLow:
        return '呼吸过慢';
    }
  }

  /// Default Chinese description for service-layer use
  String get description {
    switch (this) {
      case AlertType.presenceAppeared:
        return '检测到人员进入监控区域';
      case AlertType.presenceDisappeared:
        return '人员已离开监控区域';
      case AlertType.motionStarted:
        return '检测到人员开始运动';
      case AlertType.motionStopped:
        return '人员已停止运动，处于静止状态';
      case AlertType.personCountChanged:
        return '区域内人数发生变化';
      case AlertType.signalLow:
        return '信号质量较低，可能影响检测精度';
      case AlertType.hrHigh:
        return '心率超过设定上限值';
      case AlertType.hrLow:
        return '心率低于设定下限值';
      case AlertType.brHigh:
        return '呼吸率超过设定上限值';
      case AlertType.brLow:
        return '呼吸率低于设定下限值';
    }
  }
}

/// 告警事件 (类型 + 时间 + 详情)
class Alert {
  final AlertType type;
  final DateTime time;
  final String details;

  const Alert({required this.type, required this.time, this.details = ''});
}
