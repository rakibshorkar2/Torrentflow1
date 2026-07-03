import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'liquid_glass_ui_helpers.dart';
import 'settings_provider.dart';
import 'storage_helper.dart';
import 'torrent_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry Point
// ─────────────────────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize settings
  final settings = SettingsProvider();
  await settings.initialize();

  runApp(TorrentFlowApp(settings: settings));
}

// ─────────────────────────────────────────────────────────────────────────────
// App Root
// ─────────────────────────────────────────────────────────────────────────────

class TorrentFlowApp extends StatefulWidget {
  final SettingsProvider settings;

  const TorrentFlowApp({super.key, required this.settings});

  @override
  State<TorrentFlowApp> createState() => _TorrentFlowAppState();
}

class _TorrentFlowAppState extends State<TorrentFlowApp> {
  late final SimulatedTorrentManager _torrentManager;

  @override
  void initState() {
    super.initState();
    _torrentManager = SimulatedTorrentManager();
    _torrentManager.initialize();
    widget.settings.addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    _torrentManager.setDownloadSpeedLimit(widget.settings.downloadSpeedLimit);
    _torrentManager.setUploadSpeedLimit(widget.settings.uploadSpeedLimit);
    _torrentManager.setSeedingEnabled(widget.settings.seedingEnabled);
    setState(() {});
  }

  @override
  void dispose() {
    widget.settings.removeListener(_onSettingsChanged);
    _torrentManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.settings.themeMode == ThemeMode.dark ||
        (widget.settings.themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return CupertinoApp(
      title: 'TorrentFlow',
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primaryColor: TFColors.accentCyan,
        scaffoldBackgroundColor: Colors.transparent,
        textTheme: CupertinoTextThemeData(
          primaryColor: isDark ? TFColors.textPrimary : TFColors.textPrimaryLight,
          textStyle: TextStyle(
            fontFamily: '.SF Pro Display',
            color: isDark ? TFColors.textPrimary : TFColors.textPrimaryLight,
          ),
        ),
      ),
      home: MainShell(
        settings: widget.settings,
        torrentManager: _torrentManager,
        isDark: isDark,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Shell with Tab Bar
// ─────────────────────────────────────────────────────────────────────────────

class MainShell extends StatefulWidget {
  final SettingsProvider settings;
  final SimulatedTorrentManager torrentManager;
  final bool isDark;

  const MainShell({
    super.key,
    required this.settings,
    required this.torrentManager,
    required this.isDark,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final statusBarStyle =
        isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;

    SystemChrome.setSystemUIOverlayStyle(statusBarStyle.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: statusBarStyle,
      child: LiquidBackground(
        isDark: isDark,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          extendBodyBehindAppBar: true,
          body: IndexedStack(
            index: _selectedTab,
            children: [
              DownloadsTab(
                torrentManager: widget.torrentManager,
                isDark: isDark,
              ),
              SettingsTab(
                settings: widget.settings,
                isDark: isDark,
              ),
            ],
          ),
          bottomNavigationBar: _GlassTabBar(
            selectedIndex: _selectedTab,
            isDark: isDark,
            onTap: (i) => setState(() => _selectedTab = i),
            torrentManager: widget.torrentManager,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glassmorphic Tab Bar
// ─────────────────────────────────────────────────────────────────────────────

class _GlassTabBar extends StatelessWidget {
  final int selectedIndex;
  final bool isDark;
  final ValueChanged<int> onTap;
  final SimulatedTorrentManager torrentManager;

  const _GlassTabBar({
    required this.selectedIndex,
    required this.isDark,
    required this.onTap,
    required this.torrentManager,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [
                      const Color(0x1AFFFFFF),
                      const Color(0x30000000),
                    ]
                  : [
                      const Color(0xBBFFFFFF),
                      const Color(0xDDFFFFFF),
                    ],
            ),
            border: Border(
              top: BorderSide(
                color: isDark ? TFColors.glassBorder : TFColors.glassBorderLight,
                width: 0.5,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 60,
              child: Row(
                children: [
                  _TabItem(
                    icon: CupertinoIcons.arrow_down_circle,
                    activeIcon: CupertinoIcons.arrow_down_circle_fill,
                    label: 'Downloads',
                    isSelected: selectedIndex == 0,
                    isDark: isDark,
                    onTap: () => onTap(0),
                    badge: ListenableBuilder(
                      listenable: torrentManager,
                      builder: (context, _) {
                        final active = torrentManager.torrents
                            .where((t) => t.status == TorrentStatus.downloading)
                            .length;
                        if (active == 0) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: TFColors.accentCyan,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$active',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  _TabItem(
                    icon: CupertinoIcons.settings,
                    activeIcon: CupertinoIcons.settings_solid,
                    label: 'Settings',
                    isSelected: selectedIndex == 1,
                    isDark: isDark,
                    onTap: () => onTap(1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;
  final Widget? badge;

  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? TFColors.accentCyan
        : (isDark ? TFColors.textTertiary : TFColors.textSecondaryLight);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(6),
                  decoration: isSelected
                      ? BoxDecoration(
                          color: TFColors.accentCyan.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: TFColors.accentCyan.withOpacity(0.2),
                              blurRadius: 12,
                              spreadRadius: -2,
                            ),
                          ],
                        )
                      : null,
                  child: Icon(
                    isSelected ? activeIcon : icon,
                    color: color,
                    size: 22,
                  ),
                ),
                if (badge != null)
                  Builder(builder: (ctx) {
                    final badgeText = badge!;
                    return Positioned(
                      right: -4,
                      top: -4,
                      child: badgeText,
                    );
                  }),
              ],
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.2,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Downloads Tab
// ─────────────────────────────────────────────────────────────────────────────

class DownloadsTab extends StatefulWidget {
  final SimulatedTorrentManager torrentManager;
  final bool isDark;

  const DownloadsTab({
    super.key,
    required this.torrentManager,
    required this.isDark,
  });

  @override
  State<DownloadsTab> createState() => _DownloadsTabState();
}

class _DownloadsTabState extends State<DownloadsTab>
    with SingleTickerProviderStateMixin {
  final TextEditingController _magnetCtrl = TextEditingController();
  bool _showMagnetInput = false;
  late final AnimationController _inputAnim;
  late final Animation<double> _inputFade;
  late final Animation<Offset> _inputSlide;

  @override
  void initState() {
    super.initState();
    _inputAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _inputFade = CurvedAnimation(parent: _inputAnim, curve: Curves.easeOut);
    _inputSlide = Tween<Offset>(
      begin: const Offset(0, -0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _inputAnim, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _magnetCtrl.dispose();
    _inputAnim.dispose();
    super.dispose();
  }

  void _toggleMagnetInput() {
    setState(() {
      _showMagnetInput = !_showMagnetInput;
      if (_showMagnetInput) {
        _inputAnim.forward();
      } else {
        _inputAnim.reverse();
        _magnetCtrl.clear();
      }
    });
    HapticFeedback.lightImpact();
  }

  void _addMagnet() {
    final link = _magnetCtrl.text.trim();
    if (link.isEmpty || !link.startsWith('magnet:')) return;
    widget.torrentManager.addMagnetLink(link);
    _magnetCtrl.clear();
    _toggleMagnetInput();
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final topPadding = MediaQuery.of(context).padding.top;

    return ListenableBuilder(
      listenable: widget.torrentManager,
      builder: (context, _) {
        final torrents = widget.torrentManager.torrents;
        final downloading = torrents
            .where((t) =>
                t.status == TorrentStatus.downloading ||
                t.status == TorrentStatus.queued)
            .toList();
        final completed = torrents
            .where((t) => t.status == TorrentStatus.completed)
            .toList();
        final paused = torrents
            .where((t) => t.status == TorrentStatus.paused)
            .toList();

        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // ── Header ────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TorrentFlow',
                                style: TextStyle(
                                  color: isDark
                                      ? TFColors.textPrimary
                                      : TFColors.textPrimaryLight,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.8,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${torrents.length} torrent${torrents.length != 1 ? 's' : ''}',
                                style: TextStyle(
                                  color: isDark
                                      ? TFColors.textSecondary
                                      : TFColors.textSecondaryLight,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GlassButton(
                          isDark: isDark,
                          accentColor: _showMagnetInput
                              ? TFColors.accentRed
                              : TFColors.accentCyan,
                          onTap: _toggleMagnetInput,
                          padding: const EdgeInsets.all(12),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              _showMagnetInput
                                  ? CupertinoIcons.xmark
                                  : CupertinoIcons.plus,
                              key: ValueKey(_showMagnetInput),
                              color: _showMagnetInput
                                  ? TFColors.accentRed
                                  : TFColors.accentCyan,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // ── Global Speed Bar ─────────────────────────────────
                    const SizedBox(height: 16),
                    _GlobalSpeedCard(
                      torrentManager: widget.torrentManager,
                      isDark: isDark,
                    ),

                    // ── Magnet Input ─────────────────────────────────────
                    SlideTransition(
                      position: _inputSlide,
                      child: FadeTransition(
                        opacity: _inputFade,
                        child: _showMagnetInput
                            ? Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: GlassCard(
                                  isDark: isDark,
                                  accentBorderColor: TFColors.accentCyan,
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Add Magnet Link',
                                        style: TextStyle(
                                          color: isDark
                                              ? TFColors.textPrimary
                                              : TFColors.textPrimaryLight,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      GlassTextField(
                                        controller: _magnetCtrl,
                                        placeholder: 'magnet:?xt=urn:btih:...',
                                        isDark: isDark,
                                        keyboardType: TextInputType.url,
                                        onSubmitted: _addMagnet,
                                        prefix: Icon(
                                          CupertinoIcons.link,
                                          color: TFColors.accentCyan,
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: GlassButton(
                                              isDark: isDark,
                                              accentColor: TFColors.accentCyan,
                                              onTap: _addMagnet,
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                    CupertinoIcons
                                                        .arrow_down_circle_fill,
                                                    color: TFColors.accentCyan,
                                                    size: 16,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Start Download',
                                                    style: TextStyle(
                                                      color: TFColors.accentCyan,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Downloading ───────────────────────────────────────────────
            if (downloading.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: SectionHeader(
                    title: 'Downloading (${downloading.length})',
                    isDark: isDark,
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _TorrentCard(
                    torrent: downloading[i],
                    isDark: isDark,
                    torrentManager: widget.torrentManager,
                  ),
                  childCount: downloading.length,
                ),
              ),
            ],

            // ── Paused ────────────────────────────────────────────────────
            if (paused.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: SectionHeader(
                    title: 'Paused (${paused.length})',
                    isDark: isDark,
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _TorrentCard(
                    torrent: paused[i],
                    isDark: isDark,
                    torrentManager: widget.torrentManager,
                  ),
                  childCount: paused.length,
                ),
              ),
            ],

            // ── Completed ─────────────────────────────────────────────────
            if (completed.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: SectionHeader(
                    title: 'Completed (${completed.length})',
                    isDark: isDark,
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _TorrentCard(
                    torrent: completed[i],
                    isDark: isDark,
                    torrentManager: widget.torrentManager,
                  ),
                  childCount: completed.length,
                ),
              ),
            ],

            // ── Empty State ───────────────────────────────────────────────
            if (torrents.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(isDark: isDark, onAdd: _toggleMagnetInput),
              ),

            // Bottom padding for tab bar
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Global Speed Card
// ─────────────────────────────────────────────────────────────────────────────

class _GlobalSpeedCard extends StatelessWidget {
  final SimulatedTorrentManager torrentManager;
  final bool isDark;

  const _GlobalSpeedCard({required this.torrentManager, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      isDark: isDark,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Download',
                  style: TextStyle(
                    color: isDark ? TFColors.textTertiary : TFColors.textSecondaryLight,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                _SpeedReadout(
                  speed: torrentManager.globalDownloadSpeed,
                  color: TFColors.accentCyan,
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 36,
            color: isDark ? TFColors.glassBorder : TFColors.glassBorderLight,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upload',
                    style: TextStyle(
                      color: isDark ? TFColors.textTertiary : TFColors.textSecondaryLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  _SpeedReadout(
                    speed: torrentManager.globalUploadSpeed,
                    color: TFColors.accentViolet,
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 1,
            height: 36,
            color: isDark ? TFColors.glassBorder : TFColors.glassBorderLight,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active',
                  style: TextStyle(
                    color: isDark ? TFColors.textTertiary : TFColors.textSecondaryLight,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${torrentManager.torrents.where((t) => t.status == TorrentStatus.downloading).length}',
                  style: TextStyle(
                    color: TFColors.accentGreen,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedReadout extends StatelessWidget {
  final int speed;
  final Color color;

  const _SpeedReadout({required this.speed, required this.color});

  @override
  Widget build(BuildContext context) {
    final str = _formatSpeed(speed);
    final parts = str.split(' ');
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: parts[0],
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
          ),
          if (parts.length > 1)
            TextSpan(
              text: ' ${parts[1]}',
              style: TextStyle(
                color: color.withOpacity(0.7),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  static String _formatSpeed(int bytesPerSec) {
    if (bytesPerSec < 1024) return '$bytesPerSec B/s';
    if (bytesPerSec < 1024 * 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(2)} MB/s';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Torrent Card
// ─────────────────────────────────────────────────────────────────────────────

class _TorrentCard extends StatelessWidget {
  final TorrentItem torrent;
  final bool isDark;
  final SimulatedTorrentManager torrentManager;

  const _TorrentCard({
    required this.torrent,
    required this.isDark,
    required this.torrentManager,
  });

  Color get _progressColor {
    return switch (torrent.status) {
      TorrentStatus.downloading => TFColors.accentCyan,
      TorrentStatus.completed => TFColors.accentGreen,
      TorrentStatus.seeding => TFColors.accentGreen,
      TorrentStatus.paused => TFColors.accentAmber,
      TorrentStatus.error => TFColors.accentRed,
      TorrentStatus.queued => TFColors.textTertiary,
    };
  }

  void _showActions(BuildContext context) {
    HapticFeedback.mediumImpact();
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        title: Text(
          torrent.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (torrent.status == TorrentStatus.downloading)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                torrentManager.pauseTorrent(torrent.id);
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.pause_circle, color: CupertinoColors.systemOrange),
                  SizedBox(width: 8),
                  Text('Pause', style: TextStyle(color: CupertinoColors.systemOrange)),
                ],
              ),
            ),
          if (torrent.status == TorrentStatus.paused)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                torrentManager.resumeTorrent(torrent.id);
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.play_circle, color: CupertinoColors.activeBlue),
                  SizedBox(width: 8),
                  Text('Resume', style: TextStyle(color: CupertinoColors.activeBlue)),
                ],
              ),
            ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              torrentManager.removeTorrent(torrent.id);
            },
            child: const Text('Remove Torrent'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final badge = torrentStatusBadge(torrent.status);

    return GlassCard(
      isDark: isDark,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      padding: const EdgeInsets.all(16),
      accentBorderColor: torrent.status == TorrentStatus.downloading
          ? TFColors.accentCyan.withOpacity(0.3)
          : null,
      onTap: () => _showActions(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Name + Status Icon ─────────────────────────────────────────
          Row(
            children: [
              Icon(badge.icon, color: badge.color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  torrent.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark
                        ? TFColors.textPrimary
                        : TFColors.textPrimaryLight,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${(torrent.progress * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  color: _progressColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          // ── Progress Bar ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: NeonProgressBar(
              progress: torrent.progress,
              color: _progressColor,
              height: 5,
              isDark: isDark,
            ),
          ),

          // ── Size & Speed Chips ────────────────────────────────────────
          Row(
            children: [
              Text(
                '${torrent.formattedDownloaded} / ${torrent.formattedSize}',
                style: TextStyle(
                  color: isDark
                      ? TFColors.textSecondary
                      : TFColors.textSecondaryLight,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              if (torrent.status == TorrentStatus.downloading) ...[
                SpeedChip(
                  label: torrent.formattedDownloadSpeed,
                  icon: CupertinoIcons.arrow_down,
                  color: TFColors.accentCyan,
                  isDark: isDark,
                ),
                const SizedBox(width: 6),
                SpeedChip(
                  label: 'ETA ${torrent.eta}',
                  icon: CupertinoIcons.clock,
                  color: TFColors.accentAmber,
                  isDark: isDark,
                ),
              ],
              if (torrent.status == TorrentStatus.completed)
                SpeedChip(
                  label: 'Done',
                  icon: CupertinoIcons.checkmark,
                  color: TFColors.accentGreen,
                  isDark: isDark,
                ),
              if (torrent.status == TorrentStatus.paused)
                SpeedChip(
                  label: 'Paused',
                  icon: CupertinoIcons.pause,
                  color: TFColors.accentAmber,
                  isDark: isDark,
                ),
            ],
          ),

          // ── Peers & Seeds ─────────────────────────────────────────────
          if (torrent.status == TorrentStatus.downloading) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  CupertinoIcons.person_2,
                  color: isDark ? TFColors.textTertiary : TFColors.textSecondaryLight,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  '${torrent.peers} peers · ${torrent.seeds} seeds',
                  style: TextStyle(
                    color: isDark
                        ? TFColors.textTertiary
                        : TFColors.textSecondaryLight,
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                SpeedChip(
                  label: torrent.formattedUploadSpeed,
                  icon: CupertinoIcons.arrow_up,
                  color: TFColors.accentViolet,
                  isDark: isDark,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isDark;
  final VoidCallback onAdd;

  const _EmptyState({required this.isDark, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  TFColors.accentCyan.withOpacity(0.12),
                  Colors.transparent,
                ],
              ),
              border: Border.all(
                color: TFColors.accentCyan.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: const Icon(
              CupertinoIcons.arrow_down_circle,
              color: TFColors.accentCyan,
              size: 56,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No Torrents',
            style: TextStyle(
              color: isDark ? TFColors.textPrimary : TFColors.textPrimaryLight,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add a magnet link',
            style: TextStyle(
              color: isDark ? TFColors.textSecondary : TFColors.textSecondaryLight,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 28),
          GlassButton(
            isDark: isDark,
            accentColor: TFColors.accentCyan,
            onTap: onAdd,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.plus, color: TFColors.accentCyan, size: 16),
                SizedBox(width: 8),
                Text(
                  'Add Magnet Link',
                  style: TextStyle(
                    color: TFColors.accentCyan,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings Tab
// ─────────────────────────────────────────────────────────────────────────────

class SettingsTab extends StatefulWidget {
  final SettingsProvider settings;
  final bool isDark;

  const SettingsTab({super.key, required this.settings, required this.isDark});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  StorageInfo? _storageInfo;
  bool _loadingStorage = true;

  @override
  void initState() {
    super.initState();
    _loadStorage();
  }

  Future<void> _loadStorage() async {
    final info = await StorageHelper.getStorageInfo();
    if (mounted) {
      setState(() {
        _storageInfo = info;
        _loadingStorage = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final settings = widget.settings;
    final topPadding = MediaQuery.of(context).padding.top;

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, topPadding + 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings',
                      style: TextStyle(
                        color: isDark
                            ? TFColors.textPrimary
                            : TFColors.textPrimaryLight,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'TorrentFlow v1.0',
                      style: TextStyle(
                        color: isDark
                            ? TFColors.textSecondary
                            : TFColors.textSecondaryLight,
                        fontSize: 14,
                      ),
                    ),

                    // ── Storage Info ───────────────────────────────────
                    SectionHeader(title: 'Storage', isDark: isDark),
                    _StorageCard(
                      info: _storageInfo,
                      loading: _loadingStorage,
                      isDark: isDark,
                      onRefresh: _loadStorage,
                    ),

                    // ── Appearance ─────────────────────────────────────
                    SectionHeader(title: 'Appearance', isDark: isDark),
                    _AppearanceCard(settings: settings, isDark: isDark),

                    // ── Torrenting ─────────────────────────────────────
                    SectionHeader(title: 'Torrenting', isDark: isDark),
                    _TorrentingCard(settings: settings, isDark: isDark),

                    // ── Speed Limits ───────────────────────────────────
                    SectionHeader(title: 'Speed Limits', isDark: isDark),
                    _SpeedLimitsCard(settings: settings, isDark: isDark),

                    // ── Connection ─────────────────────────────────────
                    SectionHeader(title: 'Connection', isDark: isDark),
                    _ConnectionCard(settings: settings, isDark: isDark),

                    // ── About ──────────────────────────────────────────
                    SectionHeader(title: 'About', isDark: isDark),
                    _AboutCard(isDark: isDark),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings Cards
// ─────────────────────────────────────────────────────────────────────────────

class _StorageCard extends StatelessWidget {
  final StorageInfo? info;
  final bool loading;
  final bool isDark;
  final VoidCallback onRefresh;

  const _StorageCard({
    required this.info,
    required this.loading,
    required this.isDark,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return GlassCard(
        isDark: isDark,
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: CupertinoActivityIndicator(),
          ),
        ),
      );
    }

    final si = info;
    if (si == null) {
      return GlassCard(
        isDark: isDark,
        child: const Text('Storage info unavailable'),
      );
    }

    return GlassCard(
      isDark: isDark,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.device_phone_portrait,
                color: TFColors.accentViolet,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'iPhone Storage',
                style: TextStyle(
                  color: isDark ? TFColors.textPrimary : TFColors.textPrimaryLight,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onRefresh,
                child: Icon(
                  CupertinoIcons.refresh,
                  color: isDark ? TFColors.textTertiary : TFColors.textSecondaryLight,
                  size: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Storage bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                Flexible(
                  flex: si.usedPercent,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [TFColors.accentViolet, TFColors.accentCyan],
                      ),
                    ),
                  ),
                ),
                Flexible(
                  flex: si.freePercent.clamp(1, 100),
                  child: Container(
                    height: 10,
                    color: isDark
                        ? const Color(0x22FFFFFF)
                        : const Color(0x22000000),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
          Row(
            children: [
              _StorageLegend(
                label: 'Used',
                value: si.usedFormatted,
                color: TFColors.accentViolet,
                isDark: isDark,
              ),
              const Spacer(),
              _StorageLegend(
                label: 'Free',
                value: si.freeFormatted,
                color: TFColors.accentGreen,
                isDark: isDark,
              ),
              const Spacer(),
              _StorageLegend(
                label: 'Total',
                value: si.totalFormatted,
                color: isDark ? TFColors.textSecondary : TFColors.textSecondaryLight,
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StorageLegend extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _StorageLegend({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isDark ? TFColors.textTertiary : TFColors.textSecondaryLight,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: isDark ? TFColors.textPrimary : TFColors.textPrimaryLight,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _AppearanceCard extends StatelessWidget {
  final SettingsProvider settings;
  final bool isDark;

  const _AppearanceCard({required this.settings, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      isDark: isDark,
      padding: const EdgeInsets.all(4),
      child: Column(
        children: [
          _SettingsRow(
            icon: CupertinoIcons.moon_stars_fill,
            iconColor: TFColors.accentViolet,
            label: 'Dark Mode',
            isDark: isDark,
            trailing: CupertinoSwitch(
              value: settings.themeMode == ThemeMode.dark,
              activeTrackColor: TFColors.accentViolet,
              onChanged: (v) => settings.setThemeMode(
                v ? ThemeMode.dark : ThemeMode.light,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TorrentingCard extends StatelessWidget {
  final SettingsProvider settings;
  final bool isDark;

  const _TorrentingCard({required this.settings, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      isDark: isDark,
      padding: const EdgeInsets.all(4),
      child: Column(
        children: [
          _SettingsRow(
            icon: CupertinoIcons.arrow_up_arrow_down_circle_fill,
            iconColor: TFColors.accentGreen,
            label: 'Seeding',
            subtitle: settings.seedingEnabled
                ? 'Share downloaded data with peers'
                : 'Not sharing data after download',
            isDark: isDark,
            trailing: CupertinoSwitch(
              value: settings.seedingEnabled,
              activeTrackColor: TFColors.accentGreen,
              onChanged: settings.setSeedingEnabled,
            ),
          ),
          _Divider(isDark: isDark),
          _SettingsRow(
            icon: CupertinoIcons.dot_radiowaves_right,
            iconColor: TFColors.accentCyan,
            label: 'DHT Network',
            subtitle: 'Distributed hash table for peer discovery',
            isDark: isDark,
            trailing: CupertinoSwitch(
              value: settings.dhtEnabled,
              activeTrackColor: TFColors.accentCyan,
              onChanged: settings.setDhtEnabled,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedLimitsCard extends StatelessWidget {
  final SettingsProvider settings;
  final bool isDark;

  const _SpeedLimitsCard({required this.settings, required this.isDark});

  void _showSpeedPicker(BuildContext context, bool isDownload) {
    final options = [0, 128, 256, 512, 1024, 2048, 5120, 10240];
    final current = isDownload
        ? settings.downloadSpeedLimit
        : settings.uploadSpeedLimit;

    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 280,
        color: isDark ? const Color(0xFF1A1A2E) : CupertinoColors.white,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isDownload ? 'Download Limit' : 'Upload Limit',
                    style: TextStyle(
                      color: isDark
                          ? TFColors.textPrimary
                          : TFColors.textPrimaryLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Text('Done'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                scrollController: FixedExtentScrollController(
                  initialItem: options.contains(current)
                      ? options.indexOf(current)
                      : 0,
                ),
                itemExtent: 44,
                onSelectedItemChanged: (i) {
                  final kbps = options[i];
                  if (isDownload) {
                    settings.setDownloadSpeedLimit(kbps);
                  } else {
                    settings.setUploadSpeedLimit(kbps);
                  }
                },
                children: options
                    .map(
                      (o) => Center(
                        child: Text(
                          SettingsProvider.formatSpeedLimit(o),
                          style: TextStyle(
                            color: isDark
                                ? TFColors.textPrimary
                                : TFColors.textPrimaryLight,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      isDark: isDark,
      padding: const EdgeInsets.all(4),
      child: Column(
        children: [
          _SettingsRow(
            icon: CupertinoIcons.arrow_down_circle_fill,
            iconColor: TFColors.accentCyan,
            label: 'Download Limit',
            isDark: isDark,
            trailing: GestureDetector(
              onTap: () => _showSpeedPicker(context, true),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    SettingsProvider.formatSpeedLimit(settings.downloadSpeedLimit),
                    style: TextStyle(
                      color: isDark
                          ? TFColors.textSecondary
                          : TFColors.textSecondaryLight,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    CupertinoIcons.chevron_right,
                    color: isDark
                        ? TFColors.textTertiary
                        : TFColors.textSecondaryLight,
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
          _Divider(isDark: isDark),
          _SettingsRow(
            icon: CupertinoIcons.arrow_up_circle_fill,
            iconColor: TFColors.accentViolet,
            label: 'Upload Limit',
            isDark: isDark,
            trailing: GestureDetector(
              onTap: () => _showSpeedPicker(context, false),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    SettingsProvider.formatSpeedLimit(settings.uploadSpeedLimit),
                    style: TextStyle(
                      color: isDark
                          ? TFColors.textSecondary
                          : TFColors.textSecondaryLight,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    CupertinoIcons.chevron_right,
                    color: isDark
                        ? TFColors.textTertiary
                        : TFColors.textSecondaryLight,
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  final SettingsProvider settings;
  final bool isDark;

  const _ConnectionCard({required this.settings, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      isDark: isDark,
      padding: const EdgeInsets.all(4),
      child: Column(
        children: [
          _SettingsRow(
            icon: CupertinoIcons.link_circle_fill,
            iconColor: TFColors.accentAmber,
            label: 'Max Connections',
            isDark: isDark,
            trailing: Text(
              '${settings.maxConnections}',
              style: TextStyle(
                color: isDark
                    ? TFColors.textSecondary
                    : TFColors.textSecondaryLight,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  final bool isDark;

  const _AboutCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      isDark: isDark,
      padding: const EdgeInsets.all(4),
      child: Column(
        children: [
          _SettingsRow(
            icon: CupertinoIcons.info_circle_fill,
            iconColor: TFColors.accentCyan,
            label: 'Version',
            isDark: isDark,
            trailing: Text(
              '1.0.0',
              style: TextStyle(
                color: isDark
                    ? TFColors.textSecondary
                    : TFColors.textSecondaryLight,
                fontSize: 14,
              ),
            ),
          ),
          _Divider(isDark: isDark),
          _SettingsRow(
            icon: CupertinoIcons.shield_fill,
            iconColor: TFColors.accentGreen,
            label: 'Engine',
            isDark: isDark,
            trailing: Text(
              'dtorrent (Dart)',
              style: TextStyle(
                color: isDark
                    ? TFColors.textSecondary
                    : TFColors.textSecondaryLight,
                fontSize: 14,
              ),
            ),
          ),
          _Divider(isDark: isDark),
          _SettingsRow(
            icon: CupertinoIcons.device_phone_portrait,
            iconColor: TFColors.accentViolet,
            label: 'Platform',
            isDark: isDark,
            trailing: Text(
              'iOS 26 · iPhone 15 Pro',
              style: TextStyle(
                color: isDark
                    ? TFColors.textSecondary
                    : TFColors.textSecondaryLight,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable Settings Row and Divider
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final Widget trailing;
  final bool isDark;

  const _SettingsRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.trailing,
    required this.isDark,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isDark
                        ? TFColors.textPrimary
                        : TFColors.textPrimaryLight,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: isDark
                          ? TFColors.textTertiary
                          : TFColors.textSecondaryLight,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final bool isDark;

  const _Divider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 52),
      child: Container(
        height: 0.5,
        color: isDark ? TFColors.glassBorder : TFColors.glassBorderLight,
      ),
    );
  }
}
