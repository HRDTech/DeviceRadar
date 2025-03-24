

class MonitoredDeviceModel {
  final String name;
  final String ipAddress;
  bool isOnline;
  bool lastKnownState;

  MonitoredDeviceModel({
    required this.name,
    required this.ipAddress,
    required this.isOnline,
    required this.lastKnownState,
  });
}