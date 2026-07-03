import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'torrent_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design Tokens — iOS 26 Liquid Glass Palette
// ─────────────────────────────────────────────────────────────────────────────

class TFColors {
  TFColors._();

  // Dark background gradients
  static const bgDark1 = Color(0xFF070B14);
  static const bgDark2 = Color(0xFF0D1220);

  // Blob accent colors (for animated background)
  static const blob1 = Color(0xFF1A0A3C); // deep indigo
  static const blob2 = Color(0xFF0A2030); // ocean teal
  static const blob3 = Color(0xFF1C0828); // violet dark

  // Glass surface
  static const glassDark = Color(0x1AFFFFFF);    // 10% white
  static const glassBorder = Color(0x33FFFFFF);   // 20% white
  static const glassLight = Color(0x1A000000);    // 10% black
  static const glassBorderLight = Color(0x26000000);

  // Accent / neon
  static const accentCyan = Color(0xFF00D4FF);
  static const accentViolet = Color(0xFFB06EFF);
  static const accentGreen = Color(0xFF00F5A0);
  static const accentAmber = Color(0xFFFFBB00);
  static const accentRed = Color(0xFFFF4D6D);

  // Text
  static const textPrimary = Color(0xFFF0F4FF);
  static const textSecondary = Color(0x99F0F4FF);
  static const textTertiary = Color(0x55F0F4FF);

  // Light mode
  static const bgLight1 = Color(0xFFF0F4FF);
  static const bgLight2 = Color(0xFFE0E8FF);
  static const textPrimaryLight = Color(0xFF0D1020);
  static const textSecondaryLight = Color(0x88070B14);
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated Liquid Background
// ─────────────────────────────────────────────────────────────────────────────

class LiquidBackground extends StatefulWidget {
  final Widget child;
  final bool isDark;

  const LiquidBackground({super.key, required this.child, this.isDark = true});

  @override
  State<LiquidBackground> createState() => _LiquidBackgroundState();
}

class _LiquidBackgroundState extends State<LiquidBackground>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl1;
  late final AnimationController _ctrl2;
  late final AnimationController _ctrl3;

  @override
  void initState() {
    super.initState();
    _ctrl1 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _ctrl2 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
    _ctrl3 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl1.dispose();
    _ctrl2.dispose();
    _ctrl3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_ctrl1, _ctrl2, _ctrl3]),
      builder: (context, _) {
        final isDark = widget.isDark;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [TFColors.bgDark1, TFColors.bgDark2]
                  : [TFColors.bgLight1, TFColors.bgLight2],
            ),
          ),
          child: Stack(
            children: [
              // Blob 1
              Positioned(
                left: -100 + 200 * _ctrl1.value,
                top: -80 + 160 * _ctrl2.value,
                child: _GlowBlob(
                  color: isDark ? TFColors.blob1 : const Color(0xFFD0C0FF),
                  size: 350,
                  opacity: 0.55,
                ),
              ),
              // Blob 2
              Positioned(
                right: -80 + 180 * _ctrl2.value,
                bottom: 100 + 200 * _ctrl1.value,
                child: _GlowBlob(
                  color: isDark ? TFColors.blob2 : const Color(0xFFC0E0FF),
                  size: 300,
                  opacity: 0.5,
                ),
              ),
              // Blob 3
              Positioned(
                left: 50 + 100 * _ctrl3.value,
                bottom: -60 + 160 * _ctrl3.value,
                child: _GlowBlob(
                  color: isDark ? TFColors.blob3 : const Color(0xFFE8C0FF),
                  size: 280,
                  opacity: 0.45,
                ),
              ),
              widget.child,
            ],
          ),
        );
      },
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;

  const _GlowBlob({required this.color, required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: opacity), Colors.transparent],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glass Card Widget
// ─────────────────────────────────────────────────────────────────────────────

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blurSigma;
  final bool isDark;
  final VoidCallback? onTap;
  final Color? accentBorderColor;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.blurSigma = 20,
    this.isDark = true,
    this.onTap,
    this.accentBorderColor,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0x1DFFFFFF),
                      const Color(0x08FFFFFF),
                    ]
                  : [
                      const Color(0xBBFFFFFF),
                      const Color(0x88FFFFFF),
                    ],
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: accentBorderColor ??
                  (isDark ? TFColors.glassBorder : TFColors.glassBorderLight),
              width: accentBorderColor != null ? 1.2 : 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              if (accentBorderColor != null)
                BoxShadow(
                  color: accentBorderColor!.withValues(alpha: 0.15),
                  blurRadius: 24,
                  spreadRadius: -4,
                ),
            ],
          ),
          padding:
              padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      card = GestureDetector(onTap: onTap, child: card);
    }

    if (margin != null) {
      card = Padding(padding: margin!, child: card);
    }

    return card;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Neon Progress Bar
// ─────────────────────────────────────────────────────────────────────────────

class NeonProgressBar extends StatelessWidget {
  final double progress; // 0.0 → 1.0
  final Color color;
  final double height;
  final bool isDark;

  const NeonProgressBar({
    super.key,
    required this.progress,
    this.color = TFColors.accentCyan,
    this.height = 5,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Container(
          height: height,
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0x22FFFFFF)
                : const Color(0x20000000),
            borderRadius: BorderRadius.circular(height / 2),
          ),
          child: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                width: width * progress.clamp(0.0, 1.0),
                height: height,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.8),
                      color,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(height / 2),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 8,
                      spreadRadius: -1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glass Text Field
// ─────────────────────────────────────────────────────────────────────────────

class GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final Widget? prefix;
  final Widget? suffix;
  final bool isDark;
  final VoidCallback? onSubmitted;
  final TextInputType keyboardType;

  const GlassTextField({
    super.key,
    required this.controller,
    required this.placeholder,
    this.prefix,
    this.suffix,
    this.isDark = true,
    this.onSubmitted,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: CupertinoTextField(
          controller: controller,
          placeholder: placeholder,
          keyboardType: keyboardType,
          onSubmitted: (_) => onSubmitted?.call(),
          prefix: prefix != null
              ? Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: prefix,
                )
              : null,
          suffix: suffix != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: suffix,
                )
              : null,
          placeholderStyle: TextStyle(
            color: isDark ? TFColors.textTertiary : TFColors.textSecondaryLight,
            fontSize: 15,
          ),
          style: TextStyle(
            color: isDark ? TFColors.textPrimary : TFColors.textPrimaryLight,
            fontSize: 15,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0x22FFFFFF), const Color(0x0AFFFFFF)]
                  : [const Color(0xBBFFFFFF), const Color(0x88FFFFFF)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? TFColors.glassBorder : TFColors.glassBorderLight,
              width: 0.8,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Liquid Glass Button
// ─────────────────────────────────────────────────────────────────────────────

class GlassButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? accentColor;
  final bool isDark;
  final EdgeInsetsGeometry padding;

  const GlassButton({
    super.key,
    required this.child,
    this.onTap,
    this.accentColor,
    this.isDark = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  });

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _press, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _press.forward(),
      onTapUp: (_) {
        _press.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _press.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: widget.padding,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.accentColor != null
                      ? [
                          widget.accentColor!.withValues(alpha: 0.35),
                          widget.accentColor!.withValues(alpha: 0.15),
                        ]
                      : widget.isDark
                          ? [
                              const Color(0x33FFFFFF),
                              const Color(0x11FFFFFF),
                            ]
                          : [
                              const Color(0xCCFFFFFF),
                              const Color(0x88FFFFFF),
                            ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: widget.accentColor?.withValues(alpha: 0.6) ??
                      (widget.isDark
                          ? TFColors.glassBorder
                          : TFColors.glassBorderLight),
                  width: 0.8,
                ),
                boxShadow: widget.accentColor != null
                    ? [
                        BoxShadow(
                          color: widget.accentColor!.withValues(alpha: 0.25),
                          blurRadius: 16,
                          spreadRadius: -2,
                        )
                      ]
                    : [],
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Speed Indicator Chip
// ─────────────────────────────────────────────────────────────────────────────

class SpeedChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isDark;

  const SpeedChip({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;

  const SectionHeader({super.key, required this.title, this.isDark = true});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 0, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: isDark ? TFColors.textTertiary : TFColors.textSecondaryLight,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Returns status icon data and color for a torrent status.
({IconData icon, Color color}) torrentStatusBadge(TorrentStatus status) {
  return switch (status) {
    TorrentStatus.downloading =>
      (icon: CupertinoIcons.arrow_down_circle_fill, color: TFColors.accentCyan),
    TorrentStatus.seeding =>
      (icon: CupertinoIcons.arrow_up_circle_fill, color: TFColors.accentGreen),
    TorrentStatus.paused =>
      (icon: CupertinoIcons.pause_circle_fill, color: TFColors.accentAmber),
    TorrentStatus.completed =>
      (icon: CupertinoIcons.checkmark_circle_fill, color: TFColors.accentGreen),
    TorrentStatus.queued =>
      (icon: CupertinoIcons.clock_fill, color: TFColors.textTertiary),
    TorrentStatus.error =>
      (icon: CupertinoIcons.exclamationmark_circle_fill, color: TFColors.accentRed),
  };
}

// TorrentStatus is imported from torrent_service.dart above.
