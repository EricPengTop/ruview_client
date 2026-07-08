enum AlertType {
  presenceAppeared,
  presenceDisappeared,
  motionStarted,
  motionStopped,
  personCountChanged,
  signalLow,
}

extension AlertTypeLabel on AlertType {
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
    }
  }

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
    }
  }
}

class Alert {
  final AlertType type;
  final DateTime time;
  final String details;

  const Alert({
    required this.type,
    required this.time,
    this.details = '',
  });
}
