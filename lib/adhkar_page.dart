import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'adhkar_data.dart';
import 'design.dart';

// Adhkar tab. Has its own navigator so pages opened from it keep the bottom
// nav bar visible, with the platform slide and swipe-back gesture.
// Flow: categories → chapters of a category → swipeable dhikr cards.
class AdhkarPage extends StatefulWidget {
  const AdhkarPage({super.key});

  @override
  State<AdhkarPage> createState() => _AdhkarPageState();
}

class _AdhkarPageState extends State<AdhkarPage> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    // Android back button pops inside the tab first
    return NavigatorPopHandler(
      onPopWithResult: (_) => _navigatorKey.currentState?.maybePop(),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Navigator(
          key: _navigatorKey,
          onGenerateRoute: (_) =>
              CupertinoPageRoute(builder: (_) => const _CategoriesView()),
        ),
      ),
    );
  }
}

void _openChapter(BuildContext context, DhikrChapter chapter) {
  Navigator.of(context).push(
    CupertinoPageRoute(builder: (_) => _DhikrReaderView(chapter: chapter)),
  );
}

// ─── Categories ─────────────────────────────────────────────────────────────

class _CategoriesView extends StatefulWidget {
  const _CategoriesView();

  @override
  State<_CategoriesView> createState() => _CategoriesViewState();
}

class _CategoriesViewState extends State<_CategoriesView> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DhikrChapter>>(
      future: HisnAlMuslim.chapters(),
      builder: (context, snapshot) {
        final chapters = {
          for (final c in snapshot.data ?? const <DhikrChapter>[]) c.id: c,
        };
        final query = _query.trim();

        final List<Widget> cards;
        if (query.isEmpty) {
          cards = [
            for (final category in adhkarCategories)
              AdhkarCard(
                title: category.title,
                subtitle: adhkarCountLabel(
                  category.chapterIds.fold(
                    0,
                    (sum, id) => sum + (chapters[id]?.adhkar.length ?? 0),
                  ),
                ),
                image: category.image,
                imageLabel: category.coverLabel,
                onTap: chapters.isEmpty
                    ? null
                    : () => Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (_) => _ChaptersView(
                            title: category.title,
                            chapters: [
                              for (final id in category.chapterIds)
                                if (chapters[id] != null) chapters[id]!,
                            ],
                          ),
                        ),
                      ),
              ),
          ];
        } else {
          // While searching, show matching chapters from the whole book
          cards = [
            for (final chapter in chapters.values)
              if (chapter.title.contains(query)) _ChapterCard(chapter: chapter),
          ];
        }

        return AdhkarListScaffold(
          title: 'أذكار',
          onSearch: (value) => setState(() => _query = value),
          cards: cards,
        );
      },
    );
  }
}

// ─── Chapters of a category ─────────────────────────────────────────────────

class _ChaptersView extends StatefulWidget {
  final String title;
  final List<DhikrChapter> chapters;

  const _ChaptersView({required this.title, required this.chapters});

  @override
  State<_ChaptersView> createState() => _ChaptersViewState();
}

class _ChaptersViewState extends State<_ChaptersView> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim();
    return AdhkarListScaffold(
      title: widget.title,
      showBack: true,
      onSearch: (value) => setState(() => _query = value),
      cards: [
        for (final chapter in widget.chapters)
          if (chapter.title.contains(query)) _ChapterCard(chapter: chapter),
      ],
    );
  }
}

class _ChapterCard extends StatelessWidget {
  final DhikrChapter chapter;
  const _ChapterCard({required this.chapter});

  @override
  Widget build(BuildContext context) {
    return AdhkarCard(
      title: chapter.title,
      subtitle: adhkarCountLabel(chapter.adhkar.length),
      onTap: () => _openChapter(context, chapter),
    );
  }
}

// ─── Dhikr reader ───────────────────────────────────────────────────────────

// Swipe through the adhkar of a chapter. Tapping a card counts one
// repetition; once all repetitions are done it moves to the next card.
class _DhikrReaderView extends StatefulWidget {
  final DhikrChapter chapter;
  const _DhikrReaderView({required this.chapter});

  @override
  State<_DhikrReaderView> createState() => _DhikrReaderViewState();
}

class _DhikrReaderViewState extends State<_DhikrReaderView> {
  final _pageController = PageController();
  late final List<int> _remaining = [
    for (final d in widget.chapter.adhkar) d.repeat,
  ];

  List<Dhikr> get _adhkar => widget.chapter.adhkar;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _count(int index) {
    if (_remaining[index] == 0) return;
    HapticFeedback.lightImpact();
    setState(() => _remaining[index]--);
    if (_remaining[index] == 0 && index < _adhkar.length - 1) {
      Future.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        _pageController.nextPage(
          duration: kTabTransitionDuration,
          curve: kTabTransitionCurve,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AdhkarHeader(title: widget.chapter.title, showBack: true),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _adhkar.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _DhikrCard(
                    dhikr: _adhkar[index],
                    remaining: _remaining[index],
                    position: index + 1,
                    total: _adhkar.length,
                    onTap: () => _count(index),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _DhikrCard extends StatelessWidget {
  final Dhikr dhikr;
  final int remaining;
  final int position;
  final int total;
  final VoidCallback onTap;

  const _DhikrCard({
    required this.dhikr,
    required this.remaining,
    required this.position,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final done = remaining == 0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
        decoration: BoxDecoration(
          color: AppColors.zinc100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Text(dhikr.text, style: AppTextStyles.dhikr),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    done ? 'تم ✓' : repeatLabel(remaining),
                    key: ValueKey(remaining),
                    style: AppTextStyles.dhikrMeta,
                  ),
                ),
                const Spacer(),
                Text('$total/$position', style: AppTextStyles.dhikrMeta),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared adhkar layout ───────────────────────────────────────────────────

// Optional back chevron and the page title
class AdhkarHeader extends StatelessWidget {
  final String title;
  final bool showBack;

  const AdhkarHeader({super.key, required this.title, this.showBack = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showBack) ...[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: const SizedBox(
              width: 36,
              height: 36,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                // Chevron icons auto-mirror in RTL; force LTR so it points
                // right like the design
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Icon(
                    Icons.chevron_right,
                    size: 28,
                    color: AppColors.zinc700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.pageTitle,
            ),
          ),
        ),
      ],
    );
  }
}

// Header, search field and a list of cards
class AdhkarListScaffold extends StatelessWidget {
  final String title;
  final bool showBack;
  final ValueChanged<String> onSearch;
  final List<Widget> cards;

  const AdhkarListScaffold({
    super.key,
    required this.title,
    required this.onSearch,
    required this.cards,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: GestureDetector(
        // Tap outside the field to dismiss the keyboard
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            AdhkarHeader(title: title, showBack: showBack),
            const SizedBox(height: 18),
            AppSearchField(onChanged: onSearch),
            const SizedBox(height: 24),
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              cards[i],
            ],
          ],
        ),
      ),
    );
  }
}

class AppSearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const AppSearchField({super.key, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsetsDirectional.only(start: 14, end: 16),
      decoration: BoxDecoration(
        color: AppColors.zinc100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 24, color: AppColors.zinc400),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              cursorColor: AppColors.zinc600,
              style: AppTextStyles.input,
              decoration: const InputDecoration(
                hintText: 'البحث',
                hintStyle: AppTextStyles.hint,
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Grey rounded card with a title, a subtitle and optional artwork. Grows
// taller when the title wraps to two lines.
class AdhkarCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? image;
  // Text written in the middle of the artwork
  final String? imageLabel;
  final VoidCallback? onTap;

  const AdhkarCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.image,
    this.imageLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 92),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.zinc100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            if (image != null) ...[
              _buildArtwork(image!),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.cardTitle,
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.cardSubtitle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtwork(String image) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              image,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
            ),
            if (imageLabel != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(imageLabel!, style: AppTextStyles.coverLabel),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
