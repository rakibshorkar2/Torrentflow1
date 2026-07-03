import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages all persistent app settings for TorrentFlow.
/// Provides dark/light mode, seeding toggle, speed limits,
/// and connection settings with reactive ChangeNotifier updates.
class SettingsProvider extends ChangeNotifier {
  static const _keyThemeMode = 'theme_mode';
  static const _keySeedingEnabled = 'seeding_enabled';
  static const _keyDownloadSpeedLimit = 'download_speed_limit';
  static const _keyUploadSpeedLimit = 'upload_speed_limit';
  static const _keyMaxConnections = 'max_connections';
  static const _keyDhtEnabled = 'dht_enabled';
  static const _keySavePath = 'save_path';

  late SharedPreferences _prefs;
  bool _initialized = false;

  // ── Theme ──────────────────────────────────────────────────────────────────
  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;

  // ── Seeding ─────────────────────────────────────────────────────────────────
  bool _seedingEnabled = true;
  bool get seedingEnabled => _seedingEnabled;

  // ── Speed Limits (KB/s; 0 = unlimited) ─────────────────────────────────────
  int _downloadSpeedLimit = 0;
  int get downloadSpeedLimit => _downloadSpeedLimit;

  int _uploadSpeedLimit = 0;
  int get uploadSpeedLimit => _uploadSpeedLimit;

  // ── Connection ──────────────────────────────────────────────────────────────
  int _maxConnections = 200;
  int get maxConnections => _maxConnections;

  bool _dhtEnabled = true;
  bool get dhtEnabled => _dhtEnabled;

  // ── Save path ───────────────────────────────────────────────────────────────
  String _savePath = '';
  String get savePath => _savePath;

  bool get isInitialized => _initialized;

  // ── Initialization ──────────────────────────────────────────────────────────
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _themeMode = ThemeMode.values[_prefs.getInt(_keyThemeMode) ?? ThemeMode.dark.index];
    _seedingEnabled = _prefs.getBool(_keySeedingEnabled) ?? true;
    _downloadSpeedLimit = _prefs.getInt(_keyDownloadSpeedLimit) ?? 0;
    _uploadSpeedLimit = _prefs.getInt(_keyUploadSpeedLimit) ?? 0;
    _maxConnections = _prefs.getInt(_keyMaxConnections) ?? 200;
    _dhtEnabled = _prefs.getBool(_keyDhtEnabled) ?? true;
    _savePath = _prefs.getString(_keySavePath) ?? '';
    _initialized = true;
    notifyListeners();
  }

  // ── Setters with persistence ────────────────────────────────────────────────
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setInt(_keyThemeMode, mode.index);
    notifyListeners();
  }

  Future<void> setSeedingEnabled(bool value) async {
    _seedingEnabled = value;
    await _prefs.setBool(_keySeedingEnabled, value);
    notifyListeners();
  }

  Future<void> setDownloadSpeedLimit(int kbps) async {
    _downloadSpeedLimit = kbps;
    await _prefs.setInt(_keyDownloadSpeedLimit, kbps);
    notifyListeners();
  }

  Future<void> setUploadSpeedLimit(int kbps) async {
    _uploadSpeedLimit = kbps;
    await _prefs.setInt(_keyUploadSpeedLimit, kbps);
    notifyListeners();
  }

  Future<void> setMaxConnections(int count) async {
    _maxConnections = count;
    await _prefs.setInt(_keyMaxConnections, count);
    notifyListeners();
  }

  Future<void> setDhtEnabled(bool value) async {
    _dhtEnabled = value;
    await _prefs.setBool(_keyDhtEnabled, value);
    notifyListeners();
  }

  Future<void> setSavePath(String path) async {
    _savePath = path;
    await _prefs.setString(_keySavePath, path);
    notifyListeners();
  }

  /// Human-readable speed string for a given KB/s limit.
  static String formatSpeedLimit(int kbps) {
    if (kbps == 0) return 'Unlimited';
    if (kbps >= 1024) {
      return '${(kbps / 1024).toStringAsFixed(1)} MB/s';
    }
    return '$kbps KB/s';
  }
}
