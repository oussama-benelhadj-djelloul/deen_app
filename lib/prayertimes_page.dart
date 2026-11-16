import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

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
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
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
              )
            : Column(
                children: [
                  // Header with location
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            'تغيير',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: Colors.grey,
                                size: 20,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  widget.locationName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Next Prayer Card
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'الصلاة القادمة إن شاء الله',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _getTimeUntilNextPrayer(),
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              _getNextPrayer(),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Prayer Times Title
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'مواقيت الصلاة',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),

                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Prayer Times List
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      children: [
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
                      ],
                    ),
                  ),

                  // Bottom Navigation Bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildNavItem(Icons.dark_mode_outlined, false),
                        _buildNavItem(Icons.mosque_outlined, false),
                        _buildNavItem(Icons.explore_outlined, false),
                        _buildNavItem(Icons.menu_book_outlined, false),
                        _buildNavItem(Icons.access_time, true),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildPrayerTimeItem(
    String name,
    String time, {
    bool hasNotification = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                hasNotification
                    ? Icons.notifications_active
                    : Icons.notifications_off_outlined,
                color: hasNotification
                    ? Colors.black87
                    : Colors.grey.shade400,
                size: 22,
              ),
              const SizedBox(width: 16),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          Text(
            name,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.grey.shade200 : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isSelected ? Colors.black87 : Colors.grey.shade600,
            size: 24,
          ),
          if (isSelected) ...[
            const SizedBox(width: 8),
            const Text(
              'مواقيت الصلاة',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ],
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
