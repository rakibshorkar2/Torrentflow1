import 'package:flutter/services.dart';

/// Communicates with the native iOS Swift MethodChannel to retrieve
/// device storage information. Uses the AppDelegate-registered channel
/// `com.torrentflow.app/storage`.
class StorageHelper {
  static const MethodChannel _channel =
      MethodChannel('com.torrentflow.app/storage');

  /// Retrieves raw storage info from native iOS.
  /// Returns a [StorageInfo] with free/total bytes.
  /// Falls back to zero values if the platform channel fails.
  static Future<StorageInfo> getStorageInfo() async {
    try {
      final Map<dynamic, dynamic> result =
          await _channel.invokeMethod('getStorageInfo');
      final freeSpace = (result['freeSpace'] as int?) ?? 0;
      final totalSpace = (result['totalSpace'] as int?) ?? 0;
      return StorageInfo(freeBytes: freeSpace, totalBytes: totalSpace);
    } on PlatformException {
      // If running on simulator or channel not available, return mock
      return StorageInfo(
        freeBytes: 24 * 1024 * 1024 * 1024, // 24 GB mock
        totalBytes: 256 * 1024 * 1024 * 1024, // 256 GB mock
      );
    } on MissingPluginException {
      return StorageInfo(
        freeBytes: 24 * 1024 * 1024 * 1024,
        totalBytes: 256 * 1024 * 1024 * 1024,
      );
    }
  }
}

/// Holds free and total byte counts, with helpers for
/// human-readable formatting and percentage calculations.
class StorageInfo {
  final int freeBytes;
  final int totalBytes;

  const StorageInfo({required this.freeBytes, required this.totalBytes});

  int get usedBytes => totalBytes - freeBytes;

  /// 0.0 → 1.0 used fraction
  double get usedFraction =>
      totalBytes > 0 ? usedBytes / totalBytes : 0.0;

  double get freeFraction =>
      totalBytes > 0 ? freeBytes / totalBytes : 1.0;

  String get freeFormatted => _formatBytes(freeBytes);
  String get totalFormatted => _formatBytes(totalBytes);
  String get usedFormatted => _formatBytes(usedBytes);

  int get usedPercent => (usedFraction * 100).round();
  int get freePercent => (freeFraction * 100).round();

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    int unitIndex = 0;
    double value = bytes.toDouble();
    while (value >= 1000 && unitIndex < units.length - 1) {
      value /= 1000;
      unitIndex++;
    }
    if (value >= 100) {
      return '${value.toStringAsFixed(0)} ${units[unitIndex]}';
    } else if (value >= 10) {
      return '${value.toStringAsFixed(1)} ${units[unitIndex]}';
    } else {
      return '${value.toStringAsFixed(2)} ${units[unitIndex]}';
    }
  }

  @override
  String toString() =>
      'StorageInfo(free: $freeFormatted / $totalFormatted, $freePercent% free)';
}
