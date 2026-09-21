import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Full-screen animated backdrop: soft blobs in the Inuka West colours
/// drifting slowly behind everything, heavily blurred so translucent
/// "glass" surfaces on top pick up gentle colour. Sits behind every route
/// (installed once via MaterialApp.builder).
class GlassBackground extends StatefulWidget {
  final Widget child;
  const GlassBackground({super.key, required this.child});

  @override
  State<GlassBackground> createState() => _GlassBackgroundState();
}

class _GlassBackgroundState extends State<GlassBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 28))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final base = dark
        ? const [Color(0xFF1A0F14), Color(0xFF101826), Color(0xFF0E1A14)]
        : const [Color(0xFFFFF4EC), Color(0xFFF1F6FF), Color(0xFFEEF9F1)];
    final blobs = dark
        ? [InukaColors.red.withValues(alpha: 0.55), InukaColors.orange.withValues(alpha: 0.45),
           InukaColors.green.withValues(alpha: 0.40), InukaColors.blue.withValues(alpha: 0.45)]
        : [InukaColors.red.withValues(alpha: 0.35), InukaColors.orange.withValues(alpha: 0.45),
           InukaColors.green.withValues(alpha: 0.30), InukaColors.blue.withValues(alpha: 0.30)];

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: base),
            ),
          ),
        ),
        Positioned.fill(
          child: RepaintBoundary(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final t = reduceMotion ? 0.0 : _controller.value * 2 * math.pi;
                  return CustomPaint(painter: _BlobPainter(t, blobs));
                },
              ),
            ),
          ),
        ),
        Positioned.fill(child: widget.child),
      ],
    );
  }
}

class _BlobPainter extends CustomPainter {
  final double t;
  final List<Color> colors;
  _BlobPainter(this.t, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    // Each blob orbits its own anchor on a slow, slightly different path.
    final specs = [
      (0.15, 0.12, 0.42, 1.0, 0.0),
      (0.90, 0.25, 0.38, 0.8, 1.7),
      (0.20, 0.80, 0.40, 1.2, 3.1),
      (0.85, 0.88, 0.36, 0.9, 4.4),
    ];
    for (var i = 0; i < specs.length; i++) {
      final (ax, ay, r, speed, phase) = specs[i];
      final dx = math.sin(t * speed + phase) * 0.08;
      final dy = math.cos(t * speed * 0.8 + phase) * 0.06;
      final center = Offset((ax + dx) * size.width, (ay + dy) * size.height);
      canvas.drawCircle(center, r * size.shortestSide, Paint()..color = colors[i]);
    }
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.t != t;
}

/// Frosted-glass panel: blurs what's behind it, with a translucent fill
/// and a light edge. Use for hero surfaces; plain Cards get a lighter
/// translucent treatment from the theme (cheaper to draw in long lists).
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Gradient? tint;
  final VoidCallback? onTap;
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.tint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final shape = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: shape,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: shape,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: shape,
                gradient: tint ??
                    LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: dark
                          ? [Colors.white.withValues(alpha: 0.12), Colors.white.withValues(alpha: 0.05)]
                          : [Colors.white.withValues(alpha: 0.75), Colors.white.withValues(alpha: 0.45)],
                    ),
                border: Border.all(color: Colors.white.withValues(alpha: dark ? 0.18 : 0.7), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: (dark ? Colors.black : InukaColors.red).withValues(alpha: dark ? 0.25 : 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class GlassNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const GlassNavItem(this.icon, this.selectedIcon, this.label);
}

/// The app's bottom menu: a floating frosted-glass pill. The selected item
/// sits on a sunrise-gradient capsule; changes animate smoothly.
class GlassNavBar extends StatelessWidget {
  final List<GlassNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  const GlassNavBar({super.key, required this.items, required this.selectedIndex, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 10 + bottomInset),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: (dark ? const Color(0xFF1C1720) : Colors.white).withValues(alpha: dark ? 0.62 : 0.72),
              border: Border.all(color: Colors.white.withValues(alpha: dark ? 0.14 : 0.85), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: (dark ? Colors.black : InukaColors.red).withValues(alpha: dark ? 0.35 : 0.12),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _NavButton(item: items[i], selected: i == selectedIndex, onTap: () => onSelected(i)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final GlassNavItem item;
  final bool selected;
  final VoidCallback onTap;
  const _NavButton({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(horizontal: selected ? 16 : 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: selected ? InukaColors.sunrise : null,
                borderRadius: BorderRadius.circular(16),
                boxShadow: selected
                    ? [BoxShadow(color: InukaColors.orange.withValues(alpha: 0.45), blurRadius: 12, offset: const Offset(0, 4))]
                    : null,
              ),
              child: AnimatedScale(
                scale: selected ? 1.08 : 1.0,
                duration: const Duration(milliseconds: 260),
                child: Icon(selected ? item.selectedIcon : item.icon, size: 22, color: selected ? Colors.white : muted),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? theme.colorScheme.primary : muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wraps a bottom NavigationBar in frosted glass.
class GlassBar extends StatelessWidget {
  final Widget child;
  const GlassBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: (dark ? const Color(0xFF15121A) : Colors.white).withValues(alpha: dark ? 0.55 : 0.6),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: dark ? 0.12 : 0.8))),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// The Inuka West logo on a soft glowing glass disc.
class InukaLogo extends StatelessWidget {
  final double size;
  const InukaLogo({super.key, this.size = 110});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.08),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.9),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: InukaColors.orange.withValues(alpha: 0.45), blurRadius: size * 0.35, spreadRadius: 2),
          BoxShadow(color: InukaColors.red.withValues(alpha: 0.2), blurRadius: size * 0.6),
        ],
      ),
      child: ClipOval(child: Image.asset('assets/branding/logo.png', fit: BoxFit.contain, filterQuality: FilterQuality.high)),
    );
  }
}

/// Fades and slides its child up once when first shown - a light touch of
/// motion for cards as a screen appears.
class Appear extends StatelessWidget {
  final Widget child;
  final int index;
  const Appear({super.key, required this.child, this.index = 0});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + 70 * index.clamp(0, 6)),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 18 * (1 - v)), child: child),
      ),
      child: child,
    );
  }
}
