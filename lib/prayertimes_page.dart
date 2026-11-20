import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:flutter_svg/flutter_svg.dart';
import 'design.dart';
import 'adhkar_page.dart';
import 'home_page.dart';

class PrayerTimesPage extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String locationName;

  const PrayerTimesPage({
    Key? key,
    required this.latitude,
    required this.longitude,
    required this.locationName,
  }) : super(key: key);

  @override
  State<PrayerTimesPage> createState() => _PrayerTimesPageState();
}

class _PrayerTimesPageState extends State<PrayerTimesPage> {
  PrayerTimes? _prayerTimes;
  bool _isLoading = true;
  String? _error;

  // Left to right, as shown in the nav bar
  static const _tabs = [
    NavTab.svg('assets/icons/adhkar.svg', 'الأذكار'),
    NavTab(Icons.schedule, 'الصلاة'),
  ];
  static const _adhkarTab = 0;
  static const _prayerTab = 1;
  int _selectedTab = _prayerTab;
  // Refreshes the countdown to the next prayer
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _fetchPrayerTimes();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _fetchPrayerTimes() async {
    try {
      final now = DateTime.now();
      final dateString = DateFormat('dd-MM-yyyy').format(now);

      // Using Aladhan API - Free Islamic Prayer Times API
      final url = Uri.parse(
        'https://api.aladhan.com/v1/timings/$dateString?latitude=${widget.latitude}&longitude=${widget.longitude}&method=2',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _prayerTimes = PrayerTimes.fromJson(data['data']);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'فشل في تحميل مواقيت الصلاة';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'حدث خطأ في الاتصال';
        _isLoading = false;
      });
      print('Error fetching prayer times: $e');
    }
  }

  String _getNextPrayer() {
    if (_prayerTimes == null) return '';

    final now = DateTime.now();
    final currentTime = TimeOfDay.now();

    final prayers = [
      {'name': 'الفجر', 'time': _prayerTimes!.fajr},
      {'name': 'الصبح', 'time': _prayerTimes!.sunrise},
      {'name': 'الظهر', 'time': _prayerTimes!.dhuhr},
      {'name': 'العصر', 'time': _prayerTimes!.asr},
      {'name': 'المغرب', 'time': _prayerTimes!.maghrib},
      {'name': 'العشاء', 'time': _prayerTimes!.isha},
    ];

    for (var prayer in prayers) {
      final prayerTime = _parseTime(prayer['time'] as String);
      if (_isTimeAfter(prayerTime, currentTime)) {
        return prayer['name'] as String;
      }
    }

    return 'الفجر'; // If all prayers passed, next is Fajr tomorrow
  }

  TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  bool _isTimeAfter(TimeOfDay time1, TimeOfDay time2) {
    if (time1.hour > time2.hour) return true;
    if (time1.hour == time2.hour && time1.minute > time2.minute) return true;
    return false;
  }

  String _getTimeUntilNextPrayer() {
    if (_prayerTimes == null) return '';

    final now = DateTime.now();
    final nextPrayerName = _getNextPrayer();

    String? nextPrayerTimeStr;
    switch (nextPrayerName) {
      case 'الفجر':
        nextPrayerTimeStr = _prayerTimes!.fajr;
        break;
      case 'الصبح':
        nextPrayerTimeStr = _prayerTimes!.sunrise;
        break;
      case 'الظهر':
        nextPrayerTimeStr = _prayerTimes!.dhuhr;
        break;
      case 'العصر':
        nextPrayerTimeStr = _prayerTimes!.asr;
        break;
      case 'المغرب':
        nextPrayerTimeStr = _prayerTimes!.maghrib;
        break;
      case 'العشاء':
        nextPrayerTimeStr = _prayerTimes!.isha;
        break;
    }

    if (nextPrayerTimeStr == null) return '';

    final nextPrayerTime = _parseTime(nextPrayerTimeStr);
    var nextPrayerDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      nextPrayerTime.hour,
      nextPrayerTime.minute,
    );

    // If prayer is tomorrow
    if (nextPrayerDateTime.isBefore(now)) {
      nextPrayerDateTime = nextPrayerDateTime.add(const Duration(days: 1));
    }

    // Round up to whole minutes so it says "1 minute" until the prayer starts
    final totalMinutes = (nextPrayerDateTime.difference(now).inSeconds / 60)
        .ceil();
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (totalMinutes <= 0) return 'حان الآن';
    final parts = [
      if (hours > 0) _arabicCount(hours, 'ساعة', 'ساعتين', 'ساعات'),
      if (minutes > 0) _arabicCount(minutes, 'دقيقة', 'دقيقتين', 'دقائق'),
    ];
    return 'بعد ${parts.join(' و')}';
  }

  // Arabic counted noun: 1 ساعة, 2 ساعتين, 3-10 ساعات, 11+ ساعة
  String _arabicCount(int n, String one, String two, String few) {
    if (n == 1) return one;
    if (n == 2) return two;
    if (n <= 10) return '$n $few';
    return '$n $one';
  }

  String _convertTo12Hour(String time24) {
    final parts = time24.split(':');
    int hour = int.parse(parts[0]);
    final minute = parts[1];

    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const _LoadingView();

    return Scaffold(
      backgroundColor: AppColors.background,
      // Bottom handled per page so content can pass under the glass bar
      body: SafeArea(
        bottom: false,
        child: TabSlideSwitcher(
          index: _selectedTab,
          child: _selectedTab == _prayerTab
              ? Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: _error != null ? _buildError() : _buildContent(),
                    ),
                  ],
                )
              : _selectedTab == _adhkarTab
              ? const AdhkarPage()
              : ComingSoonView(tab: _tabs[_selectedTab]),
        ),
      ),
      // The glass bar floats over the content, which scrolls behind it
      extendBody: kUseGlassNavBar,
      bottomNavigationBar: kUseGlassNavBar
          ? AppGlassNavBar(
              tabs: _tabs,
              selectedIndex: _selectedTab,
              onTap: (i) => setState(() => _selectedTab = i),
            )
          : AppBottomNavBar(
              tabs: _tabs,
              selectedIndex: _selectedTab,
              onTap: (i) => setState(() => _selectedTab = i),
            ),
    );
  }

  // When the app opened directly on this page (saved location) there is no
  // location page underneath to go back to, so open it instead.
  void _changeLocation() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const LocationPermissionPage()),
      );
    }
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 17, 15, 0),
      child: SizedBox(
        height: 24,
        child: Row(
          textDirection: TextDirection.ltr,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _changeLocation,
              child: Text(
                'تغيير',
                style: TextStyle(
                  fontSize: 16,
                  leadingDistribution: TextLeadingDistribution.even,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.zinc700,
                ),
              ),
            ),
            // Light / dark toggle: shows the mode a tap switches to (moon in
            // light mode, sun in dark mode)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: AppTheme.toggle,
              child: Padding(
                padding: const EdgeInsets.only(left: 11, right: 4),
                child: SvgPicture.asset(
                  AppTheme.isDark
                      ? 'assets/icons/sun.svg'
                      : 'assets/icons/moon.svg',
                  width: 22,
                  height: 22,
                  colorFilter: ColorFilter.mode(
                    AppColors.zinc700,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.locationName,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  leadingDistribution: TextLeadingDistribution.even,
                  height: 1.5,
                  color: AppColors.zinc400,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.my_location, size: 22, color: AppColors.zinc500),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _error!,
            style: const TextStyle(fontSize: 18, color: AppColors.red500),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _error = null;
              });
              _fetchPrayerTimes();
            },
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  // Content is anchored to the bottom, above the nav bar, like the design.
  // Scrolls only if the screen is too short to fit it.
  Widget _buildContent() {
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            children: [
              const Spacer(),
              _buildNextPrayerCard(),
              const SizedBox(height: 20),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 15),
                child: SizedBox(
                  height: 32,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'مواقيت الصلاة',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontSize: 24,
                        height: 32 / 24,
                        leadingDistribution: TextLeadingDistribution.even,
                        fontWeight: FontWeight.w700,
                        color: AppColors.zinc600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildPrayerTimeItem(
                'الفجر',
                _convertTo12Hour(_prayerTimes!.fajr),
                hasNotification: true,
              ),
              _buildPrayerTimeItem(
                'الصبح',
                _convertTo12Hour(_prayerTimes!.sunrise),
                hasNotification: false,
              ),
              _buildPrayerTimeItem(
                'الظهر',
                _convertTo12Hour(_prayerTimes!.dhuhr),
                hasNotification: false,
              ),
              _buildPrayerTimeItem(
                'العصر',
                _convertTo12Hour(_prayerTimes!.asr),
                hasNotification: false,
              ),
              _buildPrayerTimeItem(
                'المغرب',
                _convertTo12Hour(_prayerTimes!.maghrib),
                hasNotification: true,
              ),
              _buildPrayerTimeItem(
                'العشاء',
                _convertTo12Hour(_prayerTimes!.isha),
                hasNotification: true,
              ),
              // Keeps the list above the nav bar (glass bar floats over).
              // Builder reads the padding from inside the Scaffold, which
              // includes the bar's height.
              Builder(
                builder: (context) => SizedBox(
                  height: 14 + MediaQuery.paddingOf(context).bottom,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNextPrayerCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.zinc100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 23,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'الصلاة القادمة إن شاء الله',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontSize: 16,
                  height: 23 / 16,
                  leadingDistribution: TextLeadingDistribution.even,
                  fontWeight: FontWeight.w500,
                  color: AppColors.zinc600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 28,
            child: Row(
              textDirection: TextDirection.ltr,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  _getTimeUntilNextPrayer(),
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 14,
                    height: 22 / 14,
                    leadingDistribution: TextLeadingDistribution.even,
                    fontWeight: FontWeight.w500,
                    color: AppColors.zinc500,
                  ),
                ),
                Text(
                  _getNextPrayer(),
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontSize: 18,
                    height: 28 / 18,
                    leadingDistribution: TextLeadingDistribution.even,
                    fontWeight: FontWeight.w600,
                    color: AppColors.zinc600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerTimeItem(
    String name,
    String time, {
    bool hasNotification = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 13, right: 15),
      child: SizedBox(
        height: 38.66,
        child: Row(
          textDirection: TextDirection.ltr,
          children: [
            Icon(
              hasNotification
                  ? Icons.volume_up_outlined
                  : Icons.volume_off_outlined,
              color: hasNotification ? AppColors.zinc600 : AppColors.zinc300,
              size: 22,
            ),
            const SizedBox(width: 13),
            Text(
              time,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.zinc600,
              ),
            ),
            const Spacer(),
            Text(
              name,
              textDirection: TextDirection.rtl,
              style: TextStyle(fontSize: 16, color: AppColors.zinc400),
            ),
          ],
        ),
      ),
    );
  }
}

// Shown full screen while prayer times are loading
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          // Design places the group 2.5pt below the screen's center
          padding: EdgeInsets.only(top: 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 40,
                child: Center(
                  child: Text(
                    'السلام عليكم 🌿',
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
              SizedBox(height: 8.5),
              SizedBox(
                height: 24,
                child: Center(
                  child: Text(
                    'امنحنا دقيقة، نحن نُهيّئ كل شيء لك بهدوء.',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 16,
                      height: 24 / 16,
                      leadingDistribution: TextLeadingDistribution.even,
                      color: AppColors.zinc400,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16.25),
              ArcSpinner(),
            ],
          ),
        ),
      ),
    );
  }
}

class PrayerTimes {
  final String fajr;
  final String sunrise;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;

  PrayerTimes({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  factory PrayerTimes.fromJson(Map<String, dynamic> json) {
    final timings = json['timings'];
    return PrayerTimes(
      fajr: timings['Fajr'].toString().substring(0, 5),
      sunrise: timings['Sunrise'].toString().substring(0, 5),
      dhuhr: timings['Dhuhr'].toString().substring(0, 5),
      asr: timings['Asr'].toString().substring(0, 5),
      maghrib: timings['Maghrib'].toString().substring(0, 5),
      isha: timings['Isha'].toString().substring(0, 5),
    );
  }
}
