import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Domain Models
// ─────────────────────────────────────────────────────────────────────────────

enum TorrentStatus { queued, downloading, seeding, paused, completed, error }

class TorrentFile {
  final String name;
  final int size; // bytes
  bool selected;

  TorrentFile({required this.name, required this.size, this.selected = true});
}

class TorrentItem {
  final String id;
  String name;
  final String magnetLink;
  TorrentStatus status;
  double progress; // 0.0 → 1.0
  int downloadSpeed; // bytes/s
  int uploadSpeed; // bytes/s
  int totalSize; // bytes
  int downloaded; // bytes
  int peers;
  int seeds;
  String? savePath;
  List<TorrentFile> files;
  DateTime addedAt;
  String? error;

  TorrentItem({
    required this.id,
    required this.name,
    required this.magnetLink,
    this.status = TorrentStatus.queued,
    this.progress = 0.0,
    this.downloadSpeed = 0,
    this.uploadSpeed = 0,
    this.totalSize = 0,
    this.downloaded = 0,
    this.peers = 0,
    this.seeds = 0,
    this.savePath,
    List<TorrentFile>? files,
    DateTime? addedAt,
    this.error,
  })  : files = files ?? [],
        addedAt = addedAt ?? DateTime.now();

  TorrentItem copyWith({
    TorrentStatus? status,
    double? progress,
    int? downloadSpeed,
    int? uploadSpeed,
    int? totalSize,
    int? downloaded,
    int? peers,
    int? seeds,
    String? savePath,
    String? name,
    List<TorrentFile>? files,
    String? error,
  }) {
    return TorrentItem(
      id: id,
      name: name ?? this.name,
      magnetLink: magnetLink,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      uploadSpeed: uploadSpeed ?? this.uploadSpeed,
      totalSize: totalSize ?? this.totalSize,
      downloaded: downloaded ?? this.downloaded,
      peers: peers ?? this.peers,
      seeds: seeds ?? this.seeds,
      savePath: savePath ?? this.savePath,
      files: files ?? this.files,
      addedAt: addedAt,
      error: error ?? this.error,
    );
  }

  String get formattedSize => _formatBytes(totalSize);
  String get formattedDownloaded => _formatBytes(downloaded);
  String get formattedDownloadSpeed => '${_formatBytes(downloadSpeed)}/s';
  String get formattedUploadSpeed => '${_formatBytes(uploadSpeed)}/s';

  String get eta {
    if (status == TorrentStatus.completed) return 'Done';
    if (downloadSpeed == 0) return '∞';
    final remaining = totalSize - downloaded;
    final seconds = remaining ~/ downloadSpeed;
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m ${seconds % 60}s';
    return '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m';
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    int unitIndex = 0;
    double value = bytes.toDouble();
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ${units[unitIndex]}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Abstract TorrentManager Interface
// ─────────────────────────────────────────────────────────────────────────────

abstract class TorrentManager extends ChangeNotifier {
  List<TorrentItem> get torrents;
  int get globalDownloadSpeed; // bytes/s
  int get globalUploadSpeed; // bytes/s
  int get downloadSpeedLimit; // KB/s; 0 = unlimited
  int get uploadSpeedLimit; // KB/s; 0 = unlimited
  bool get seedingEnabled;

  Future<void> initialize();
  Future<TorrentItem?> addMagnetLink(String magnetUri);
  Future<void> pauseTorrent(String id);
  Future<void> resumeTorrent(String id);
  Future<void> removeTorrent(String id, {bool deleteFiles = false});
  Future<void> setDownloadSpeedLimit(int kbps);
  Future<void> setUploadSpeedLimit(int kbps);
  Future<void> setSeedingEnabled(bool enabled);
  @override
  void dispose();
}

// ─────────────────────────────────────────────────────────────────────────────
// Simulated TorrentManager (for UI testing & real device demo)
// ─────────────────────────────────────────────────────────────────────────────

class SimulatedTorrentManager extends TorrentManager {
  final _uuid = const Uuid();
  final _random = Random();

  final List<TorrentItem> _torrents = [];
  final Map<String, Timer> _simulators = {};

  int _downloadSpeedLimit = 0;
  int _uploadSpeedLimit = 0;
  bool _seedingEnabled = true;

  int _globalDownloadSpeed = 0;
  int _globalUploadSpeed = 0;

  @override
  List<TorrentItem> get torrents => List.unmodifiable(_torrents);

  @override
  int get globalDownloadSpeed => _globalDownloadSpeed;

  @override
  int get globalUploadSpeed => _globalUploadSpeed;

  @override
  int get downloadSpeedLimit => _downloadSpeedLimit;

  @override
  int get uploadSpeedLimit => _uploadSpeedLimit;

  @override
  bool get seedingEnabled => _seedingEnabled;

  @override
  Future<void> initialize() async {
    // Pre-populate with some demo torrents
    await addMagnetLink(
      'magnet:?xt=urn:btih:dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c&dn=Big+Buck+Bunny&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337',
    );
    await addMagnetLink(
      'magnet:?xt=urn:btih:08ada5a7a6183aae1e09d831df6748d566095a10&dn=Sintel&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337',
    );
  }

  @override
  Future<TorrentItem?> addMagnetLink(String magnetUri) async {
    // Parse display name from magnet URI
    final dnMatch = RegExp(r'[?&]dn=([^&]+)').firstMatch(magnetUri);
    String name = 'Unknown Torrent';
    if (dnMatch != null) {
      name = Uri.decodeComponent(dnMatch.group(1)!.replaceAll('+', ' '));
    }

    final id = _uuid.v4();
    final totalSize = (500 + _random.nextInt(9500)) * 1024 * 1024; // 500 MB–10 GB

    // Generate random file list
    final fileNames = _generateFileList(name);
    final files = fileNames.map((fn) {
      final size = (10 + _random.nextInt(990)) * 1024 * 1024;
      return TorrentFile(name: fn, size: size);
    }).toList();

    final savePath = await _getSavePath();

    final item = TorrentItem(
      id: id,
      name: name,
      magnetLink: magnetUri,
      status: TorrentStatus.downloading,
      progress: 0.0,
      totalSize: totalSize,
      downloaded: 0,
      peers: 5 + _random.nextInt(45),
      seeds: 2 + _random.nextInt(20),
      savePath: savePath,
      files: files,
    );

    _torrents.add(item);
    notifyListeners();

    // Start simulator
    _startSimulator(id);
    return item;
  }

  void _startSimulator(String id) {
    _simulators[id]?.cancel();
    _simulators[id] = Timer.periodic(const Duration(milliseconds: 500), (t) {
      final index = _torrents.indexWhere((e) => e.id == id);
      if (index < 0) {
        t.cancel();
        return;
      }

      final torrent = _torrents[index];
      if (torrent.status == TorrentStatus.paused ||
          torrent.status == TorrentStatus.completed) {
        return;
      }

      // Simulate fluctuating speed (1–8 MB/s download)
      final baseSpeed = (1024 + _random.nextInt(7 * 1024)) * 1024;
      final limitedSpeed = _downloadSpeedLimit > 0
          ? min(baseSpeed, _downloadSpeedLimit * 1024)
          : baseSpeed;

      final uploadSpeed =
          _seedingEnabled ? (100 + _random.nextInt(900)) * 1024 : 0;

      final newDownloaded =
          min(torrent.downloaded + limitedSpeed ~/ 2, torrent.totalSize);
      final newProgress = newDownloaded / torrent.totalSize;
      final isDone = newDownloaded >= torrent.totalSize;

      _torrents[index] = torrent.copyWith(
        downloaded: newDownloaded,
        progress: newProgress,
        downloadSpeed: isDone ? 0 : limitedSpeed,
        uploadSpeed: isDone && _seedingEnabled ? uploadSpeed : 0,
        status: isDone ? TorrentStatus.completed : TorrentStatus.downloading,
        peers: isDone ? 0 : (5 + _random.nextInt(45)),
        seeds: isDone ? 0 : (2 + _random.nextInt(20)),
      );

      // Recalculate global speeds
      _recalcGlobalSpeeds();
      notifyListeners();

      if (isDone) t.cancel();
    });
  }

  void _recalcGlobalSpeeds() {
    _globalDownloadSpeed = _torrents
        .where((t) => t.status == TorrentStatus.downloading)
        .fold(0, (s, t) => s + t.downloadSpeed);
    _globalUploadSpeed = _torrents
        .where((t) =>
            t.status == TorrentStatus.completed ||
            t.status == TorrentStatus.seeding)
        .fold(0, (s, t) => s + t.uploadSpeed);
  }

  @override
  Future<void> pauseTorrent(String id) async {
    final index = _torrents.indexWhere((t) => t.id == id);
    if (index < 0) return;
    _torrents[index] = _torrents[index].copyWith(
      status: TorrentStatus.paused,
      downloadSpeed: 0,
      uploadSpeed: 0,
    );
    _simulators[id]?.cancel();
    _recalcGlobalSpeeds();
    notifyListeners();
  }

  @override
  Future<void> resumeTorrent(String id) async {
    final index = _torrents.indexWhere((t) => t.id == id);
    if (index < 0) return;
    if (_torrents[index].progress >= 1.0) return;
    _torrents[index] = _torrents[index].copyWith(
      status: TorrentStatus.downloading,
    );
    _startSimulator(id);
    notifyListeners();
  }

  @override
  Future<void> removeTorrent(String id, {bool deleteFiles = false}) async {
    _simulators[id]?.cancel();
    _simulators.remove(id);
    _torrents.removeWhere((t) => t.id == id);
    _recalcGlobalSpeeds();
    notifyListeners();
  }

  @override
  Future<void> setDownloadSpeedLimit(int kbps) async {
    _downloadSpeedLimit = kbps;
    notifyListeners();
  }

  @override
  Future<void> setUploadSpeedLimit(int kbps) async {
    _uploadSpeedLimit = kbps;
    notifyListeners();
  }

  @override
  Future<void> setSeedingEnabled(bool enabled) async {
    _seedingEnabled = enabled;
    if (!enabled) {
      for (var i = 0; i < _torrents.length; i++) {
        if (_torrents[i].status == TorrentStatus.seeding) {
          _torrents[i] = _torrents[i].copyWith(uploadSpeed: 0);
        }
      }
    }
    notifyListeners();
  }

  @override
  void dispose() {
    for (final t in _simulators.values) {
      t.cancel();
    }
    super.dispose();
  }

  Future<String> _getSavePath() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return '${dir.path}/TorrentFlow';
    } catch (_) {
      return '/TorrentFlow';
    }
  }

  List<String> _generateFileList(String torrentName) {
    final base = torrentName.replaceAll(' ', '.');
    final count = 1 + _random.nextInt(5);
    if (count == 1) {
      return ['$base.mkv'];
    }
    return List.generate(count, (i) {
      final ext = ['mkv', 'mp4', 'avi', 'srt', 'nfo'][_random.nextInt(5)];
      return '${base}_part${i + 1}.$ext';
    });
  }
}
