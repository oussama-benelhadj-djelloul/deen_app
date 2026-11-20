import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// Light / dark mode. Colors below read [AppTheme.isDark], so flipping it and
// rebuilding the tree recolors every page.
class AppTheme {
  static final ValueNotifier<bool> isDarkNotifier = ValueNotifier(
    WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark,
  );

  static bool get isDark => isDarkNotifier.value;

  static void toggle() {
    isDarkNotifier.value = !isDarkNotifier.value;
    // Many widgets are const and would otherwise skip the rebuild, so mark
    // the whole tree dirty to pick up the new colors.
    void rebuild(Element e) {
      e.markNeedsBuild();
      e.visitChildren(rebuild);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(rebuild);
  }
}

// Design colors, Tailwind zinc scale only. Each light shade maps to its
// mirrored zinc shade in dark mode.
class AppColors {
  static const _zinc50 = Color(0xFFFAFAFA);
  static const _zinc100 = Color(0xFFF4F4F5);
  static const _zinc200 = Color(0xFFE4E4E7);
  static const _zinc300 = Color(0xFFD4D4D8);
  static const _zinc400 = Color(0xFF9F9FA9);
  static const _zinc500 = Color(0xFF71717B);
  static const _zinc600 = Color(0xFF52525C);
  static const _zinc700 = Color(0xFF3F3F47);
  static const _zinc800 = Color(0xFF27272A);
  static const _zinc900 = Color(0xFF18181B);
  static const _zinc950 = Color(0xFF09090B);

  static Color _pick(Color light, Color dark) => AppTheme.isDark ? dark : light;

  // Page background and strongest text
  static Color get background => _pick(Colors.white, _zinc950);
  static Color get foreground => _pick(Colors.black, Colors.white);

  static Color get zinc50 => _pick(_zinc50, _zinc900);
  static Color get zinc100 => _pick(_zinc100, _zinc900);
  static Color get zinc200 => _pick(_zinc200, _zinc800);
  static Color get zinc300 => _pick(_zinc300, _zinc700);
  static Color get zinc400 => _pick(_zinc400, _zinc500);
  static Color get zinc500 => _pick(_zinc500, _zinc400);
  static Color get zinc600 => _pick(_zinc600, _zinc300);
  static Color get zinc700 => _pick(_zinc700, _zinc200);

  // Tailwind red-500, for error messages
  static const red500 = Color(0xFFEF4444);
}

// Three-quarter ring that rotates, as in the design
class ArcSpinner extends StatefulWidget {
  const ArcSpinner({super.key});

  @override
  State<ArcSpinner> createState() => _ArcSpinnerState();
}

class _ArcSpinnerState extends State<ArcSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          value: 0.75,
          strokeWidth: 2,
          strokeCap: StrokeCap.round,
          color: AppColors.zinc300,
          backgroundColor: Colors.transparent,
        ),
      ),
    );
  }
}

class NavTab {
  final IconData? icon;
  // Asset path of a custom SVG icon, used instead of [icon] when set
  final String? svg;
  // Filled variants shown when the tab is selected
  final IconData? selectedIcon;
  final String? selectedSvg;
  final String label;
  const NavTab(IconData this.icon, this.label, {this.selectedIcon})
    : svg = null,
      selectedSvg = null;
  const NavTab.svg(String this.svg, this.label, {this.selectedSvg})
    : icon = null,
      selectedIcon = null;
}

// Draws a tab's icon (material or SVG) at a given size and color. When
// [selected], uses the tab's filled variant if it has one.
class NavTabIcon extends StatelessWidget {
  final NavTab tab;
  final double size;
  final Color color;
  final bool selected;

  const NavTabIcon({
    super.key,
    required this.tab,
    required this.size,
    required this.color,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final svg = selected ? (tab.selectedSvg ?? tab.svg) : tab.svg;
    if (svg == null) {
      final icon = selected ? (tab.selectedIcon ?? tab.icon) : tab.icon;
      return Icon(icon, size: size, color: color);
    }
    // SVGs are drawn on an 18pt grid with almost no padding, while material
    // icons have ~2pt padding in their box, so scale down to match visually
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: SvgPicture.asset(
          svg,
          width: size * 0.9,
          height: size * 0.9,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        ),
      ),
    );
  }
}

// Shared timing so the nav pill and the page slide move together
const kTabTransitionDuration = Duration(milliseconds: 380);
const kTabTransitionCurve = Curves.easeInOutCubic;

// Bottom navigation: the selected tab is a pill with its label, others are
// icons. On change the pill background slides from the old tab to the new one
// while the old label collapses and the new one expands.
class AppBottomNavBar extends StatefulWidget {
  final List<NavTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const AppBottomNavBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  State<AppBottomNavBar> createState() => _AppBottomNavBarState();
}

class _AppBottomNavBarState extends State<AppBottomNavBar>
    with TickerProviderStateMixin {
  static const _iconWidth = 42.0;
  static const _gap = 8.0;
  static const _labelLeft = 12.0;
  static const _iconRight = 11.0;
  static const _iconSize = 20.0;
  static const _labelIconGap = 6.0;
  static const _labelSlideDistance = 36.0;
  // Text gets its own, slower animation so the slide is easy to see
  static const _labelDuration = Duration(milliseconds: 650);
  static TextStyle get _labelStyle => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.zinc600,
  );

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: kTabTransitionDuration,
    value: 1,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: kTabTransitionCurve,
  );
  late final AnimationController _labelController = AnimationController(
    vsync: this,
    duration: _labelDuration,
    value: 1,
  );
  late final Animation<double> _labelT = CurvedAnimation(
    parent: _labelController,
    curve: Curves.easeOutCubic,
  );

  // Snapshot of the layout when the current animation started, so a tap
  // mid-animation continues smoothly from wherever things are.
  List<double>? _startWidths;
  double _startPillLeft = 0;
  double _startPillWidth = 0;
  List<double> _fullWidths = const [];

  @override
  void didUpdateWidget(AppBottomNavBar old) {
    super.didUpdateWidget(old);
    if (old.selectedIndex != widget.selectedIndex) {
      final widths = _currentWidths();
      _startPillLeft = _currentPillLeft(widths);
      _startPillWidth = _currentPillWidth(widths);
      _startWidths = widths;
      _controller.forward(from: 0);
      _labelController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _labelController.dispose();
    super.dispose();
  }

  List<double> _targetWidths() => [
    for (var i = 0; i < widget.tabs.length; i++)
      i == widget.selectedIndex ? _fullWidths[i] : _iconWidth,
  ];

  List<double> _currentWidths() {
    final target = _targetWidths();
    final start = _startWidths;
    if (start == null) return target;
    final t = _t.value;
    return [
      for (var i = 0; i < target.length; i++)
        start[i] + (target[i] - start[i]) * t,
    ];
  }

  double _leftOf(int index, List<double> widths) {
    var x = 0.0;
    for (var i = 0; i < index; i++) {
      x += widths[i] + _gap;
    }
    return x;
  }

  double _currentPillLeft(List<double> widths) {
    final target = _leftOf(widget.selectedIndex, widths);
    if (_startWidths == null) return target;
    return _startPillLeft + (target - _startPillLeft) * _t.value;
  }

  double _currentPillWidth(List<double> widths) {
    final target = widths[widget.selectedIndex];
    if (_startWidths == null) return target;
    return _startPillWidth + (target - _startPillWidth) * _t.value;
  }

  List<double> _measureFullWidths(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(_labelStyle);
    final scaler = MediaQuery.textScalerOf(context);
    return [
      for (final tab in widget.tabs)
        _labelLeft +
            (TextPainter(
              text: TextSpan(text: tab.label, style: style),
              textDirection: TextDirection.rtl,
              textScaler: scaler,
              maxLines: 1,
            )..layout()).width.ceilToDouble() +
            _labelIconGap +
            _iconSize +
            _iconRight,
    ];
  }

  @override
  Widget build(BuildContext context) {
    _fullWidths = _measureFullWidths(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.zinc50,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // Background extends under the home indicator, items stay above it
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 12),
          // heightFactor keeps the bar as tall as its content instead of
          // expanding to fill the screen
          child: Center(
            heightFactor: 1,
            child: AnimatedBuilder(
              animation: Listenable.merge([_t, _labelT]),
              builder: (context, _) => _buildRow(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow() {
    final widths = _currentWidths();
    final total =
        widths.fold<double>(0, (a, b) => a + b) + _gap * (widths.length - 1);

    return SizedBox(
      width: total,
      height: 32,
      child: Stack(
        textDirection: TextDirection.ltr,
        children: [
          // Sliding pill background
          Positioned(
            left: _currentPillLeft(widths),
            top: 0,
            bottom: 0,
            width: _currentPillWidth(widths),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.zinc200,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          for (var i = 0; i < widget.tabs.length; i++)
            Positioned(
              left: _leftOf(i, widths),
              top: 0,
              bottom: 0,
              width: widths[i],
              child: _buildItem(i, widths[i]),
            ),
        ],
      ),
    );
  }

  Widget _buildItem(int i, double width) {
    final tab = widget.tabs[i];
    // 0 = icon only, 1 = fully expanded with label
    final expanded = ((width - _iconWidth) / (_fullWidths[i] - _iconWidth))
        .clamp(0.0, 1.0);
    // The selected label follows the slower text animation; the label being
    // left just collapses with the pill.
    final labelIn = i == widget.selectedIndex ? _labelT.value : expanded;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onTap(i),
      child: ClipRect(
        child: Stack(
          clipBehavior: Clip.hardEdge,
          textDirection: TextDirection.ltr,
          children: [
            Positioned(
              left: _labelLeft,
              top: 0,
              bottom: 0,
              child: Center(
                // Label slides in from the right (from the icon side) to its
                // place, and slides back out to the right when collapsing
                child: Transform.translate(
                  offset: Offset(_labelSlideDistance * (1 - labelIn), 0),
                  child: Opacity(
                    opacity: labelIn,
                    child: Text(
                      tab.label,
                      maxLines: 1,
                      softWrap: false,
                      textDirection: TextDirection.rtl,
                      style: _labelStyle,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: _iconRight,
              top: 0,
              bottom: 0,
              child: NavTabIcon(
                tab: tab,
                size: _iconSize,
                color: Color.lerp(
                  AppColors.zinc500,
                  AppColors.zinc600,
                  expanded,
                )!,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// The app uses the iOS-style floating glass tab bar. Set to false to use the
// previous flat bar ([AppBottomNavBar]) instead.
const kUseGlassNavBar = true;

// Floating glass pill with one segment per tab (icon over label), in the
// style of iOS tab bars: mostly transparent, blurs and saturates what passes
// behind it, with a bright rim. The selected segment gets a soft pill that
// slides between tabs.
class AppGlassNavBar extends StatelessWidget {
  final List<NavTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const AppGlassNavBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onTap,
  });

  static const _height = 64.0;
  static const _inset = 4.0;
  static const _segmentWidth = 112.0;
  // Space between the bar and the home indicator area
  static const _bottomGap = 21.0;

  // Boosts colour of the content behind the glass, like iOS materials
  static const _saturate = ColorFilter.matrix([
    1.28, -0.25, -0.03, 0, 0, //
    -0.07, 1.10, -0.03, 0, 0, //
    -0.07, -0.25, 1.32, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final width = _segmentWidth * tabs.length + _inset * 2;
    final radius = BorderRadius.circular(_height / 2);

    return Padding(
      padding: EdgeInsets.only(bottom: bottom + _bottomGap),
      child: Center(
        heightFactor: 1,
        child: Container(
          width: width,
          height: _height,
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.5 : 0.12),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.compose(
                outer: _saturate,
                inner: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
              ),
              child: CustomPaint(
                // Bright rim on top of everything, like light on a glass edge
                foregroundPainter: _GlassRimPainter(dark: dark),
                child: DecoratedBox(
                  // Thin tint: the content behind stays visible
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: dark
                          ? [
                              Colors.white.withValues(alpha: 0.10),
                              AppColors.background.withValues(alpha: 0.25),
                            ]
                          : [
                              Colors.white.withValues(alpha: 0.55),
                              Colors.white.withValues(alpha: 0.25),
                            ],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(_inset),
                    child: Stack(
                      textDirection: TextDirection.ltr,
                      children: [
                        // Sliding selection pill
                        AnimatedPositioned(
                          duration: kTabTransitionDuration,
                          curve: kTabTransitionCurve,
                          left: _segmentWidth * selectedIndex,
                          top: 0,
                          bottom: 0,
                          width: _segmentWidth,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: dark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : AppColors.zinc200.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(_height / 2),
                            ),
                          ),
                        ),
                        Row(
                          textDirection: TextDirection.ltr,
                          children: [
                            for (var i = 0; i < tabs.length; i++)
                              _buildSegment(i),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSegment(int i) {
    final selected = i == selectedIndex;
    final color = selected ? AppColors.foreground : AppColors.zinc600;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(i),
      child: SizedBox(
        width: _segmentWidth,
        child: TweenAnimationBuilder<Color?>(
          duration: kTabTransitionDuration,
          tween: ColorTween(end: color),
          builder: (context, c, _) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              NavTabIcon(
                tab: tabs[i],
                size: 24,
                color: c ?? color,
                selected: selected,
              ),
              const SizedBox(height: 2),
              Text(
                tabs[i].label,
                maxLines: 1,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontSize: 12,
                  height: 16 / 12,
                  leadingDistribution: TextLeadingDistribution.even,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: c ?? color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Glass edge: a 1pt rim brightest at the top-left, fading along the sides
// and catching light again at the bottom-right, plus a faint outer line so
// the bar still reads on a white page.
class _GlassRimPainter extends CustomPainter {
  final bool dark;
  const _GlassRimPainter({required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.5),
      Radius.circular(size.height / 2),
    );

    // Faint outline for contrast on light backgrounds
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = dark
            ? Colors.white.withValues(alpha: 0.08)
            : AppColors.zinc300.withValues(alpha: 0.5),
    );

    // Specular highlight
    final hi = dark ? 0.35 : 1.0;
    canvas.drawRRect(
      rrect.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.9 * hi),
            Colors.white.withValues(alpha: 0.15 * hi),
            Colors.white.withValues(alpha: 0.05 * hi),
            Colors.white.withValues(alpha: 0.6 * hi),
          ],
          stops: const [0, 0.35, 0.65, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_GlassRimPainter old) => old.dark != dark;
}

// Slides pages horizontally like a carousel: going to a tab on the right
// pushes the current page out to the left, and vice versa.
class TabSlideSwitcher extends StatefulWidget {
  final int index;
  final Widget child;

  const TabSlideSwitcher({super.key, required this.index, required this.child});

  @override
  State<TabSlideSwitcher> createState() => _TabSlideSwitcherState();
}

class _TabSlideSwitcherState extends State<TabSlideSwitcher> {
  int _direction = 1;

  @override
  void didUpdateWidget(TabSlideSwitcher old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _direction = widget.index > old.index ? 1 : -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedSwitcher(
        duration: kTabTransitionDuration,
        switchInCurve: kTabTransitionCurve,
        switchOutCurve: kTabTransitionCurve,
        layoutBuilder: (current, previous) =>
            Stack(fit: StackFit.expand, children: [...previous, ?current]),
        transitionBuilder: (child, animation) {
          final incoming = child.key == ValueKey(widget.index);
          // Incoming runs 0→1 from the far side; outgoing runs 1→0 toward
          // the opposite side.
          final offset = Tween<Offset>(
            begin: Offset(
              incoming ? _direction.toDouble() : -_direction.toDouble(),
              0,
            ),
            end: Offset.zero,
          ).animate(animation);
          return SlideTransition(position: offset, child: child);
        },
        child: KeyedSubtree(key: ValueKey(widget.index), child: widget.child),
      ),
    );
  }
}

// Placeholder for sections that aren't built yet, styled like the loading screen
class ComingSoonView extends StatelessWidget {
  final NavTab tab;
  const ComingSoonView({super.key, required this.tab});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NavTabIcon(tab: tab, size: 40, color: AppColors.zinc300),
            const SizedBox(height: 16),
            SizedBox(
              height: 40,
              child: Center(
                child: Text(
                  'قريباً 🌿',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 32,
                    height: 40 / 32,
                    leadingDistribution: TextLeadingDistribution.even,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8.5),
            Text(
              'نعمل بهدوء على تجهيز قسم ${tab.label}، ترقّبه قريباً بإذن الله.',
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                height: 24 / 16,
                leadingDistribution: TextLeadingDistribution.even,
                color: AppColors.zinc400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Shared text styles so every page uses the same type scale and colors
class AppTextStyles {
  static TextStyle get pageTitle => TextStyle(
    fontSize: 24,
    height: 36 / 24,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w700,
    color: AppColors.zinc600,
  );
  static TextStyle get cardTitle => TextStyle(
    fontSize: 18,
    height: 28 / 18,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w600,
    color: AppColors.zinc700,
  );
  static TextStyle get cardSubtitle => TextStyle(
    fontSize: 14,
    height: 22 / 14,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w500,
    color: AppColors.zinc400,
  );
  // Body text of a dhikr in the reader
  static TextStyle get dhikr => TextStyle(
    fontSize: 20,
    height: 32 / 20,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w500,
    color: AppColors.zinc700,
  );
  // Repeat count and progress at the bottom of a dhikr card
  static TextStyle get dhikrMeta => TextStyle(
    fontSize: 18,
    height: 28 / 18,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w600,
    color: AppColors.zinc400,
  );
  // Category name written over the cover painting
  static TextStyle get coverLabel => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    shadows: [Shadow(color: Color(0x59000000), blurRadius: 6)],
  );
  static TextStyle get input => TextStyle(
    fontFamily: 'IBMPlexArabic',
    fontSize: 16,
    color: AppColors.zinc700,
  );
  static TextStyle get hint => TextStyle(
    fontFamily: 'IBMPlexArabic',
    fontSize: 16,
    color: AppColors.zinc400,
  );
}
