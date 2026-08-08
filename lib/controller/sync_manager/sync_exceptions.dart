part of 'sync_manager.dart';

class NonAllowedMessageException implements Exception {
  final String deviceId;
  final MessageType type;
  NonAllowedMessageException(this.deviceId, this.type);

  @override
  String toString() => 'Message "${type.name}" Received from an untrusted device: $deviceId';
}

class BlockedMessageException implements Exception {
  final String deviceId;
  final MessageType type;
  BlockedMessageException(this.deviceId, this.type);

  @override
  String toString() => 'Message "${type.name}" Received from a blocked device: $deviceId';
}
