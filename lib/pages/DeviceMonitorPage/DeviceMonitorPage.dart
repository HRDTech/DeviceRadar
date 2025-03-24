import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:flutter/services.dart';
import './models/MonitoredDeviceModel.dart';



class DeviceMonitorPage extends StatefulWidget{
  const DeviceMonitorPage({super.key});

  @override
  State<StatefulWidget> createState() {
    // TODO: implement createState
    return DeviceMonitorPageState();
  }
  
}
class DeviceMonitorPageState extends State<DeviceMonitorPage>{
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _deviceNameController = TextEditingController();
  final List<MonitoredDeviceModel> _devices = [];
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isScanning = false;
  String? _localIPAddress;
  Timer? _scanTimer;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadSavedDevices();
    _getLocalIPAddress();
  }

  Future<void> _getLocalIPAddress() async {
    try {
      final info = NetworkInfo();
      final ip = await info.getWifiIP();
      setState(() {
        _localIPAddress = ip;
      });
    } catch (e) {
      print('Error al obtener dirección IP local: $e');
    }
  }

  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
      },
    );
  }

  Future<void> _loadSavedDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final devicesList = prefs.getStringList('devices') ?? [];

      for (final deviceJson in devicesList) {
        final parts = deviceJson.split(';');
        if (parts.length == 2) {
          final device = MonitoredDeviceModel(
            name: parts[0],
            ipAddress: parts[1],
            isOnline: false,
            lastKnownState: false,
          );
          _devices.add(device);
        }
      }

      setState(() {});

      if (_devices.isNotEmpty) {
        _startMonitoring();
      }
    } catch (e) {
      print('Error al cargar dispositivos: $e');
    }
  }

  Future<void> _saveDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final devicesList = _devices.map((device) =>
      '${device.name};${device.ipAddress}'
      ).toList();

      await prefs.setStringList('devices', devicesList);
    } catch (e) {
      print('Error al guardar dispositivos: $e');
    }
  }

  void _startMonitoring() {
    if (_scanTimer != null) {
      _scanTimer!.cancel();
    }

    setState(() {
      _isScanning = true;
    });

    // Escanear cada 10 segundos
    _scanTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkAllDevices();
    });

    // Realizar un escaneo inicial inmediatamente
    _checkAllDevices();
  }

  void _stopMonitoring() {
    _scanTimer?.cancel();
    _scanTimer = null;

    setState(() {
      _isScanning = false;
    });
  }

  Future<void> _checkAllDevices() async {
    for (final device in _devices) {
      final isOnline = await _pingDevice(device.ipAddress);

      // Si el estado ha cambiado, notificar
      if (isOnline != device.lastKnownState) {
        _notifyStateChange(device, isOnline);

        setState(() {
          device.lastKnownState = isOnline;
        });
      }

      setState(() {
        device.isOnline = isOnline;
      });
    }
  }

  Future<bool> _pingDevice(String ip) async {
    try {
      final result = await Process.run('ping', ['-c', '1', '-W', '1', ip]);
      return result.exitCode == 0;
    } catch (e) {
      print('Error al hacer ping a $ip: $e');
      return false;
    }
  }

  Future<void> _notifyStateChange(MonitoredDeviceModel device, bool isOnline) async {
    final status = isOnline ? 'Encendido' : 'Apagado';

    // Notificación
    const androidDetails = AndroidNotificationDetails(
      'device_status_channel',
      'Estado de Dispositivos',
      channelDescription: 'Notificaciones de cambios en el estado de dispositivos',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      device.hashCode,
      'Cambio de Estado',
      '${device.name} ($status)',
      notificationDetails,
    );

    // Alerta sonora
    await _audioPlayer.play(AssetSource('sounds/alert.mp3'));
  }

  void _addDevice() {
    final name = _deviceNameController.text.trim();
    final ip = _ipController.text.trim();

    if (name.isEmpty || ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombre e IP son obligatorios')),
      );
      return;
    }

    if (!_isValidIPAddress(ip)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Formato de IP inválido')),
      );
      return;
    }

    // Verificar si ya existe
    if (_devices.any((device) => device.ipAddress == ip)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este dispositivo ya está siendo monitoreado')),
      );
      return;
    }

    final newDevice = MonitoredDeviceModel(
      name: name,
      ipAddress: ip,
      isOnline: false,
      lastKnownState: false,
    );

    setState(() {
      _devices.add(newDevice);
      _deviceNameController.clear();
      _ipController.clear();
    });

    _saveDevices();

    // Iniciar monitoreo si no está activo
    if (!_isScanning) {
      _startMonitoring();
    }
  }

  void _removeDevice(int index) {
    setState(() {
      _devices.removeAt(index);
    });

    _saveDevices();

    if (_devices.isEmpty) {
      _stopMonitoring();
    }
  }

  bool _isValidIPAddress(String ip) {
    final ipPattern = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$');
    if (!ipPattern.hasMatch(ip)) return false;

    final parts = ip.split('.');
    for (final part in parts) {
      final number = int.parse(part);
      if (number < 0 || number > 255) return false;
    }

    return true;
  }

  Future<void> _scanNetwork() async {
    if (_localIPAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se puede obtener la dirección IP local')),
      );
      return;
    }

    final ipBase = _localIPAddress!.substring(0, _localIPAddress!.lastIndexOf('.') + 1);
    final foundDevices = <String>[];
    final futures = <Future>[];

    setState(() {
      _isScanning = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Escaneando red, esto puede tardar un momento...')),
    );

    // Escanear los primeros 254 hosts en la red
    for (int i = 1; i <= 254; i++) {
      final ip = '$ipBase$i';
      futures.add(
          _pingDevice(ip).then((isReachable) {
            if (isReachable) {
              foundDevices.add(ip);
            }
          })
      );
    }

    await Future.wait(futures);

    setState(() {
      _isScanning = false;
    });

    if (!mounted) return;

    if (foundDevices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontraron dispositivos activos')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dispositivos Encontrados'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: foundDevices.length,
            itemBuilder: (context, index) {
              final ip = foundDevices[index];
              return ListTile(
                title: Text(ip),
                trailing: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    _ipController.text = ip;
                    Navigator.pop(context);
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cerrar'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _ipController.dispose();
    _deviceNameController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitor de Dispositivos'),
        actions: [
          _isScanning
              ? IconButton(
            icon: const Icon(Icons.stop),
            tooltip: 'Detener monitoreo',
            onPressed: _stopMonitoring,
          )
              : IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Iniciar monitoreo',
            onPressed: _startMonitoring,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _deviceNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del dispositivo',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _ipController,
                        decoration: const InputDecoration(
                          labelText: 'Dirección IP',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _addDevice,
                      icon: const Icon(Icons.add),
                      label: const Text('Añadir'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _scanNetwork,
                      icon: const Icon(Icons.search),
                      label: const Text('Escanear Red'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _devices.isEmpty
                ? const Center(
              child: Text('No hay dispositivos monitoreados'),
            )
                : ListView.builder(
              itemCount: _devices.length,
              itemBuilder: (context, index) {
                final device = _devices[index];
                return ListTile(
                  leading: Icon(
                    Icons.circle,
                    color: device.isOnline ? Colors.green : Colors.red,
                  ),
                  title: Text(device.name),
                  subtitle: Text(device.ipAddress),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _removeDevice(index),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _isScanning
          ? const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
            'Monitoreo activo',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.green),
          ),
        ),
      )
          : null,
    );
  }
  
}