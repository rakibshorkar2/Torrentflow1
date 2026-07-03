import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:dtorrent_parser/dtorrent_parser.dart';
import 'package:dtorrent_task/dtorrent_task.dart';
import 'package:dtorrent_tracker/dtorrent_tracker.dart';
import 'package:dtorrent_common/dtorrent_common.dart';
import 'package:events_emitter2/events_emitter2.dart';

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
// Internal handle for a live TorrentTask
// ─────────────────────────────────────────────────────────────────────────────

class _TorrentHandle {
  final String id;
  final TorrentTask task;
  EventsListener<TaskEvent>? listener;
  Timer? pollTimer;

  _TorrentHandle({required this.id, required this.task});

  void cancel() {
    pollTimer?.cancel();
    listener?.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Real TorrentManager — uses dtorrent_task for actual P2P downloading
// ─────────────────────────────────────────────────────────────────────────────

class RealTorrentManager extends TorrentManager {
  final _uuid = const Uuid();

  final List<TorrentItem> _torrents = [];
  final Map<String, _TorrentHandle> _handles = {};

  // Trackers and downloaders during metadata resolution phase
  final Map<String, MetadataDownloader> _activeMetadataDownloaders = {};
  final Map<String, TorrentAnnounceTracker> _activeMetadataTrackers = {};
  final Map<String, StreamSubscription> _activeMetadataSubscriptions = {};

  int _downloadSpeedLimit = 0; // KB/s, 0 = unlimited
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
    // Loaded dynamically via manual user action
  }

  /// Convert standard base32 string to standard hex hash string
  static String _base32ToHex(String base32) {
    const chars = 'abcdefghijklmnopqrstuvwxyz234567';
    var bits = '';
    for (var i = 0; i < base32.length; i++) {
      final char = base32[i];
      final val = chars.indexOf(char);
      if (val < 0) continue;
      bits += val.toRadixString(2).padLeft(5, '0');
    }
    var hex = '';
    for (var i = 0; i + 4 <= bits.length; i += 4) {
      final chunk = bits.substring(i, i + 4);
      hex += int.parse(chunk, radix: 2).toRadixString(16);
    }
    return hex;
  }

  /// Extracts a lowercase hex info-hash from a magnet URI.
  String? _extractInfoHash(String magnetUri) {
    String? hash;
    final uri = Uri.tryParse(magnetUri);
    if (uri != null) {
      final xt = uri.queryParameters['xt'];
      if (xt != null && xt.startsWith('urn:btih:')) {
        hash = xt.substring('urn:btih:'.length).toLowerCase();
      }
    }
    if (hash == null) {
      final match = RegExp(r'urn:btih:([a-zA-Z0-9]{32,40})', caseSensitive: false)
          .firstMatch(magnetUri);
      hash = match?.group(1)?.toLowerCase();
    }

    if (hash == null) return null;

    if (hash.length == 32) {
      return _base32ToHex(hash);
    } else if (hash.length == 40) {
      return hash;
    }
    return null;
  }

  /// Extracts human-readable display name from a magnet URI.
  String _extractName(String magnetUri) {
    final uri = Uri.tryParse(magnetUri);
    if (uri != null) {
      final dn = uri.queryParameters['dn'];
      if (dn != null && dn.isNotEmpty) return dn;
    }
    final match = RegExp(r'[?&]dn=([^&]+)').firstMatch(magnetUri);
    if (match != null) {
      return Uri.decodeComponent(match.group(1)!.replaceAll('+', ' '));
    }
    return 'Unknown Torrent';
  }

  @override
  Future<TorrentItem?> addMagnetLink(String magnetUri) async {
    final infoHash = _extractInfoHash(magnetUri);
    if (infoHash == null || infoHash.isEmpty) {
      debugPrint('[TorrentManager] Invalid magnet URI: $magnetUri');
      return null;
    }

    if (_torrents.any((t) => _extractInfoHash(t.magnetLink) == infoHash)) {
      debugPrint('[TorrentManager] Duplicate: $infoHash');
      return null;
    }

    final id = _uuid.v4();
    final name = _extractName(magnetUri);
    final savePath = await _getSavePath();

    final item = TorrentItem(
      id: id,
      name: name,
      magnetLink: magnetUri,
      status: TorrentStatus.queued,
      savePath: savePath,
    );
    _torrents.add(item);
    notifyListeners();

    _startDownload(id, infoHash, magnetUri, savePath);
    return item;
  }

  void _updateItem(String id, TorrentItem Function(TorrentItem) fn) {
    final idx = _torrents.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    _torrents[idx] = fn(_torrents[idx]);
    _recalcGlobalSpeeds();
    notifyListeners();
  }

  Future<void> _startDownload(
    String id,
    String infoHash,
    String magnetUri,
    String savePath,
  ) async {
    debugPrint('[TorrentManager] Resolving metadata: $infoHash');

    try {
      // ── Step 1: Download torrent metadata via BEP-09 ──────────────────────
      final metaDl = MetadataDownloader(infoHash);
      final metaListener = metaDl.createListener();
      final metaCompleter = Completer<Torrent>();

      _activeMetadataDownloaders[id] = metaDl;

      metaListener
        ..on<MetaDataDownloadComplete>((event) async {
          if (metaCompleter.isCompleted) return;
          try {
            final model = await Torrent.parseFromBytes(
              Uint8List.fromList(event.data),
            );
            metaCompleter.complete(model);
          } catch (e) {
            if (!metaCompleter.isCompleted) {
              metaCompleter.completeError('Parse failed: $e');
            }
          }
        })
        ..on<MetaDataDownloadFailed>((event) {
          if (!metaCompleter.isCompleted) {
            metaCompleter.completeError('Metadata download failed');
          }
        });

      try {
        await metaDl.startDownload();
      } catch (e) {
        debugPrint('[TorrentManager] DHT bootstrap skipped: $e');
      }

      // ── Step 2: Use trackers to speed up peer discovery ───────────────────
      final infoHashBuffer = Uint8List.fromList(_hexToBytes(infoHash));
      final tracker = TorrentAnnounceTracker(metaDl);
      final trackerListener = tracker.createListener();

      _activeMetadataTrackers[id] = tracker;

      trackerListener.on<AnnouncePeerEventEvent>((event) {
        if (event.event == null) return;
        for (final peer in event.event!.peers) {
          metaDl.addNewPeerAddress(peer, PeerSource.tracker);
        }
      });

      // Add trackers from the magnet URI
      final magUri = Uri.tryParse(magnetUri);
      if (magUri != null) {
        for (final tr in (magUri.queryParametersAll['tr'] ?? [])) {
          final tUri = Uri.tryParse(tr);
          if (tUri != null) {
            tracker.runTracker(tUri, infoHashBuffer);
          }
        }
      }

      // Add popular default trackers immediately
      const defaultTrackers = [
        'udp://tracker.opentrackr.org:1337/announce',
        'udp://open.stealth.si:80/announce',
        'udp://tracker.coppersurfer.tk:6969/announce',
        'udp://exodus.desync.com:6969/announce',
        'udp://tracker.cyberia.is:6969/announce',
        'udp://tracker.torrent.eu.org:451/announce',
        'udp://tracker.moeking.me:6969/announce',
        'udp://9.rarbg.to:2710/announce',
      ];
      for (final tr in defaultTrackers) {
        final tUri = Uri.tryParse(tr);
        if (tUri != null) {
          tracker.runTracker(tUri, infoHashBuffer);
        }
      }

      // Fall back to public trackers list
      final trackersSubscription = findPublicTrackers().listen((urls) {
        if (metaCompleter.isCompleted) return;
        for (final u in urls) {
          try {
            tracker.runTracker(u, infoHashBuffer);
          } catch (_) {}
        }
      });
      _activeMetadataSubscriptions[id] = trackersSubscription;

      // ── Step 3: Await metadata (90 s timeout) ─────────────────────────────
      Torrent torrentModel;
      try {
        torrentModel =
            await metaCompleter.future.timeout(const Duration(seconds: 90));
      } catch (e) {
        debugPrint('[TorrentManager] Metadata failed: $e');
        trackersSubscription.cancel();
        tracker.stop(true);
        metaDl.stop();
        metaListener.dispose();
        trackerListener.dispose();
        
        _activeMetadataDownloaders.remove(id);
        _activeMetadataTrackers.remove(id);
        _activeMetadataSubscriptions.remove(id);

        _updateItem(
          id,
          (t) => t.copyWith(
            status: TorrentStatus.error,
            error: 'Could not fetch metadata. Check internet connection.',
          ),
        );
        return;
      }

      trackersSubscription.cancel();
      tracker.stop(true);
      metaDl.stop();
      metaListener.dispose();
      trackerListener.dispose();

      _activeMetadataDownloaders.remove(id);
      _activeMetadataTrackers.remove(id);
      _activeMetadataSubscriptions.remove(id);

      // Verify that the torrent was not removed by the user while loading metadata
      if (!_torrents.any((t) => t.id == id)) {
        return;
      }

      // Build file list from real metadata
      final torrentFiles = torrentModel.files.map((f) {
        return TorrentFile(name: f.name, size: f.length);
      }).toList();

      _updateItem(
        id,
        (t) => t.copyWith(
          name: torrentModel.name,
          status: TorrentStatus.downloading,
          totalSize: torrentModel.length,
          files: torrentFiles,
          savePath: savePath,
        ),
      );

      // ── Step 4: Start the download task ───────────────────────────────────
      final task = TorrentTask.newTask(torrentModel, savePath);
      final handle = _TorrentHandle(id: id, task: task);
      _handles[id] = handle;

      handle.listener = task.createListener();
      handle.listener!
        ..on<TaskCompleted>((event) {
          debugPrint('[TorrentManager] Completed: $id');
          handle.pollTimer?.cancel();
          _updateItem(
            id,
            (t) => t.copyWith(
              status: _seedingEnabled
                  ? TorrentStatus.seeding
                  : TorrentStatus.completed,
              progress: 1.0,
              downloadSpeed: 0,
              peers: 0,
            ),
          );
          if (!_seedingEnabled) task.stop();
        })
        ..on<TaskStopped>((event) {
          handle.pollTimer?.cancel();
        });

      await task.start();

      // ── Step 5: Poll stats every second ───────────────────────────────────
      handle.pollTimer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => _pollTask(id),
      );
    } catch (e, st) {
      debugPrint('[TorrentManager] Error: $e\n$st');
      _activeMetadataDownloaders.remove(id);
      _activeMetadataTrackers.remove(id);
      _activeMetadataSubscriptions.remove(id);

      _updateItem(
        id,
        (t) => t.copyWith(status: TorrentStatus.error, error: e.toString()),
      );
    }
  }

  void _pollTask(String id) {
    final handle = _handles[id];
    if (handle == null) return;

    final task = handle.task;
    final idx = _torrents.indexWhere((t) => t.id == id);
    if (idx < 0) return;

    final current = _torrents[idx];
    if (current.status == TorrentStatus.completed ||
        current.status == TorrentStatus.error) {
      return;
    }

    final rawDl = (task.currentDownloadSpeed * 1024).toInt();
    final rawUp = (task.uploadSpeed * 1024).toInt();

    final effectiveDl = _downloadSpeedLimit > 0
        ? rawDl.clamp(0, _downloadSpeedLimit * 1024)
        : rawDl;
    final effectiveUp = _seedingEnabled
        ? (_uploadSpeedLimit > 0
            ? rawUp.clamp(0, _uploadSpeedLimit * 1024)
            : rawUp)
        : 0;

    final progress = task.progress.clamp(0.0, 1.0);
    final totalSize = task.metaInfo.length;
    final downloaded = (progress * totalSize).toInt();

    final newStatus = current.status == TorrentStatus.paused
        ? TorrentStatus.paused
        : (progress >= 1.0
            ? (_seedingEnabled ? TorrentStatus.seeding : TorrentStatus.completed)
            : TorrentStatus.downloading);

    _torrents[idx] = current.copyWith(
      status: newStatus,
      progress: progress,
      downloadSpeed: effectiveDl,
      uploadSpeed: effectiveUp,
      totalSize: totalSize,
      downloaded: downloaded,
      peers: task.connectedPeersNumber,
      seeds: task.seederNumber,
    );

    _recalcGlobalSpeeds();
    notifyListeners();
  }

  @override
  Future<void> pauseTorrent(String id) async {
    // Stop metadata downloader if active
    final metaDl = _activeMetadataDownloaders.remove(id);
    final metaTracker = _activeMetadataTrackers.remove(id);
    final metaSub = _activeMetadataSubscriptions.remove(id);
    metaDl?.stop();
    metaTracker?.stop(true);
    metaSub?.cancel();

    _handles[id]?.task.pause();
    _updateItem(
      id,
      (t) => t.copyWith(
        status: TorrentStatus.paused,
        downloadSpeed: 0,
        uploadSpeed: 0,
      ),
    );
  }

  @override
  Future<void> resumeTorrent(String id) async {
    final idx = _torrents.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    if (_torrents[idx].progress >= 1.0) return;

    final handle = _handles[id];
    if (handle != null) {
      handle.task.resume();
      _updateItem(id, (t) => t.copyWith(status: TorrentStatus.downloading));
    } else {
      // If it was paused during metadata resolution, restart it
      final infoHash = _extractInfoHash(_torrents[idx].magnetLink);
      if (infoHash != null && infoHash.isNotEmpty) {
        _updateItem(id, (t) => t.copyWith(status: TorrentStatus.queued, error: null));
        _startDownload(id, infoHash, _torrents[idx].magnetLink, _torrents[idx].savePath ?? await _getSavePath());
      }
    }
  }

  @override
  Future<void> removeTorrent(String id, {bool deleteFiles = false}) async {
    // Abort metadata downloader if active
    final metaDl = _activeMetadataDownloaders.remove(id);
    final metaTracker = _activeMetadataTrackers.remove(id);
    final metaSub = _activeMetadataSubscriptions.remove(id);
    metaDl?.stop();
    metaTracker?.stop(true);
    metaSub?.cancel();

    final handle = _handles.remove(id);
    handle?.cancel();
    try {
      await handle?.task.stop();
      await handle?.task.dispose();
    } catch (_) {}
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
      for (final entry in _handles.entries) {
        final idx = _torrents.indexWhere((t) => t.id == entry.key);
        if (idx >= 0 && _torrents[idx].status == TorrentStatus.seeding) {
          entry.value.task.stop();
          _torrents[idx] = _torrents[idx].copyWith(
            status: TorrentStatus.completed,
            uploadSpeed: 0,
          );
        }
      }
      _recalcGlobalSpeeds();
      notifyListeners();
    }
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
  void dispose() {
    for (final handle in _handles.values) {
      handle.cancel();
      handle.task.stop();
    }
    _handles.clear();

    for (final d in _activeMetadataDownloaders.values) {
      d.stop();
    }
    for (final t in _activeMetadataTrackers.values) {
      t.stop(true);
    }
    for (final s in _activeMetadataSubscriptions.values) {
      s.cancel();
    }
    _activeMetadataDownloaders.clear();
    _activeMetadataTrackers.clear();
    _activeMetadataSubscriptions.clear();

    super.dispose();
  }

  Future<String> _getSavePath() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return dir.path;
    } catch (_) {
      return '/';
    }
  }

  static List<int> _hexToBytes(String hex) {
    final result = <int>[];
    for (var i = 0; i < hex.length - 1; i += 2) {
      result.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return result;
  }
}
