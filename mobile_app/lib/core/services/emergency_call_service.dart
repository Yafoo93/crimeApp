import 'package:flutter/services.dart';

class EmergencyCallService {
  static const _channel = MethodChannel('safealert/emergency_call');

  Future<bool> dial112() async {
    final result = await _channel.invokeMethod<bool>('dial112');
    return result ?? false;
  }
}
