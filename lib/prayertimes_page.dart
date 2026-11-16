import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart' hide TextDirection;

// Design colors (Tailwind zinc scale, as used in the Figma design)
const _zinc50 = Color(0xFFFAFAFA);
const _zinc100 = Color(0xFFF4F4F5);
const _zinc200 = Color(0xFFE4E4E7);
const _zinc300 = Color(0xFFD4D4D8);
const _zinc400 = Color(0xFF9F9FA9);
const _zinc500 = Color(0xFF71717B);
const _zinc600 = Color(0xFF52525C);
const _zinc700 = Color(0xFF3F3F47);

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

  @override
  void initState() {
    super.initState();
    _fetchPrayerTimes();
  }

  Future<void> _fetchPrayerTimes() async {
    try {
      final now = DateTime.now();
      final dateString = DateFormat('dd-MM-yyyy').format(now);

      // Using Aladhan API - Free Islamic Prayer Times API
      final url = Uri.parse(
        'http://api.aladhan.com/v1/timings/$dateString?latitude=${widget.latitude}&longitude=${widget.longitude}&method=2',
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
      {'name': 'الشروق', 'time': _prayerTimes!.sunrise},
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
      case 'الشروق':
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

    final difference = nextPrayerDateTime.difference(now);
    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;

    return '+${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _error != null ? _buildError() : _buildContent(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
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
              onTap: () => Navigator.pop(context),
              child: const Text(
                'تغيير',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: _zinc700,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                widget.locationName,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: _zinc400,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.my_location, size: 22, color: _zinc500),
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
            style: const TextStyle(fontSize: 18, color: Colors.red),
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
              const Padding(
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
                        fontWeight: FontWeight.w700,
                        color: _zinc600,
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
              const SizedBox(height: 14),
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
        color: _zinc100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(
            height: 23,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'الصلاة القادمة إن شاء الله',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: _zinc600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 22,
            child: Row(
              textDirection: TextDirection.ltr,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _getTimeUntilNextPrayer(),
                  style: const TextStyle(fontSize: 14, color: _zinc400),
                ),
                Text(
                  _getNextPrayer(),
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(fontSize: 14, color: _zinc400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: const BoxDecoration(
        color: _zinc50,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // Background extends under the home indicator, items stay above it
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 12),
          child: Row(
            textDirection: TextDirection.ltr,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildNavItem(Icons.dark_mode_outlined),
              const SizedBox(width: 8),
              _buildNavItem(Icons.audio_file_outlined),
              const SizedBox(width: 8),
              _buildNavItem(Icons.explore_outlined),
              const SizedBox(width: 8),
              _buildNavItem(Icons.history_edu_outlined),
              const SizedBox(width: 8),
              _buildSelectedNavItem(Icons.schedule, 'مواقيت الصلاة'),
            ],
          ),
        ),
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
              color: hasNotification ? _zinc600 : _zinc300,
              size: 22,
            ),
            const SizedBox(width: 13),
            Text(
              time,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _zinc600,
              ),
            ),
            const Spacer(),
            Text(
              name,
              textDirection: TextDirection.rtl,
              style: const TextStyle(fontSize: 16, color: _zinc400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon) {
    return SizedBox(
      width: 42,
      height: 32,
      child: Icon(icon, color: _zinc500, size: 20),
    );
  }

  Widget _buildSelectedNavItem(IconData icon, String label) {
    return Container(
      height: 32,
      padding: const EdgeInsets.only(left: 12, right: 11),
      decoration: BoxDecoration(
        color: _zinc200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: TextDirection.ltr,
        children: [
          Text(
            label,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: _zinc600,
            ),
          ),
          const SizedBox(width: 6),
          Icon(icon, color: _zinc600, size: 20),
        ],
      ),
    );
  }
}

// Shown full screen while prayer times are loading
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
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
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
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
                    style: TextStyle(fontSize: 16, color: _zinc400),
                  ),
                ),
              ),
              SizedBox(height: 16.25),
              _ArcSpinner(),
            ],
          ),
        ),
      ),
    );
  }
}

// Three-quarter ring that rotates, as in the design
class _ArcSpinner extends StatefulWidget {
  const _ArcSpinner();

  @override
  State<_ArcSpinner> createState() => _ArcSpinnerState();
}

class _ArcSpinnerState extends State<_ArcSpinner>
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
          color: _zinc300,
          backgroundColor: Colors.transparent,
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
