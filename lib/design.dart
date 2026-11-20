import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// Design colors (Tailwind zinc scale, as used in the Figma design)
class AppColors {
  static const zinc50 = Color(0xFFFAFAFA);
  static const zinc100 = Color(0xFFF4F4F5);
  static const zinc200 = Color(0xFFE4E4E7);
  static const zinc300 = Color(0xFFD4D4D8);
  static const zinc400 = Color(0xFF9F9FA9);
  static const zinc500 = Color(0xFF71717B);
  static const zinc600 = Color(0xFF52525C);
  static const zinc700 = Color(0xFF3F3F47);
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
      child: const SizedBox(
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
  final String label;
  const NavTab(IconData this.icon, this.label) : svg = null;
  const NavTab.svg(String this.svg, this.label) : icon = null;
}

// Draws a tab's icon (material or SVG) at a given size and color
class NavTabIcon extends StatelessWidget {
  final NavTab tab;
  final double size;
  final Color color;

  const NavTabIcon({
    super.key,
    required this.tab,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final svg = tab.svg;
    if (svg == null) return Icon(tab.icon, size: size, color: color);
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
  static const _labelStyle = TextStyle(
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
      decoration: const BoxDecoration(
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
            const SizedBox(
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
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8.5),
            Text(
              'نعمل بهدوء على تجهيز قسم ${tab.label}، ترقّبه قريباً بإذن الله.',
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: const TextStyle(
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
  static const pageTitle = TextStyle(
    fontSize: 24,
    height: 36 / 24,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w700,
    color: AppColors.zinc600,
  );
  static const cardTitle = TextStyle(
    fontSize: 18,
    height: 28 / 18,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w600,
    color: AppColors.zinc700,
  );
  static const cardSubtitle = TextStyle(
    fontSize: 14,
    height: 22 / 14,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w500,
    color: AppColors.zinc400,
  );
  // Body text of a dhikr in the reader
  static const dhikr = TextStyle(
    fontSize: 20,
    height: 32 / 20,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w500,
    color: AppColors.zinc700,
  );
  // Repeat count and progress at the bottom of a dhikr card
  static const dhikrMeta = TextStyle(
    fontSize: 18,
    height: 28 / 18,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w600,
    color: AppColors.zinc400,
  );
  // Category name written over the cover painting
  static const coverLabel = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    shadows: [Shadow(color: Color(0x59000000), blurRadius: 6)],
  );
  static const input = TextStyle(fontSize: 16, color: AppColors.zinc700);
  static const hint = TextStyle(fontSize: 16, color: AppColors.zinc400);
}
