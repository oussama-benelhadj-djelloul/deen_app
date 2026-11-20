import 'package:deen_app/prayertimes_page.dart';
import 'package:deen_app/design.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';

class LocationPermissionPage extends StatefulWidget {
  const LocationPermissionPage({Key? key}) : super(key: key);

  @override
  State<LocationPermissionPage> createState() => _LocationPermissionPageState();
}

class _LocationPermissionPageState extends State<LocationPermissionPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<LocationSuggestion> _suggestions = [];
  bool _isSearching = false;
  bool _showSuggestions = false;
  LocationSuggestion? _selectedLocation;
  Timer? _debounce;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();

    // The listener also fires on cursor/selection changes; only react to new text
    if (query == _lastQuery) return;
    _lastQuery = query;

    _debounce?.cancel();

    // Text was set by selecting a suggestion, don't search again
    if (_selectedLocation != null && query == _selectedLocation!.city) return;
    _selectedLocation = null;

    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    // Debounce the search
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchLocation(query);
    });
  }

  Future<void> _searchLocation(String query) async {
    List<LocationSuggestion> results = [];
    try {
      // Using Open-Meteo geocoding API - Free and no API key required
      final url = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
        'name': query,
        'count': '3', // Max 3 so the list never overlaps the button below
        'language': 'ar',
        'format': 'json',
      });

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> items = data['results'] ?? [];
        results = items
            .map((item) {
              final name = item['name'] ?? '';
              final country = item['country'] ?? '';
              final region = item['admin1'] ?? '';
              return LocationSuggestion(
                displayName: country.isNotEmpty ? '$name، $country' : name,
                latitude: (item['latitude'] as num).toDouble(),
                longitude: (item['longitude'] as num).toDouble(),
                city: name,
                region: region,
                country: country,
              );
            })
            .take(3)
            .toList();
      } else {
        print('Location search failed: HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('Error searching location: $e');
    }

    // Ignore stale responses if the user kept typing
    if (!mounted || query != _searchController.text.trim()) return;

    setState(() {
      _suggestions = results;
      _showSuggestions = results.isNotEmpty;
      _isSearching = false;
    });
  }

  void _selectLocation(LocationSuggestion location) {
    _debounce?.cancel();
    setState(() {
      _selectedLocation = location;
      _searchController.text = location.city;
      _showSuggestions = false;
      _suggestions = [];
      _isSearching = false;
    });
    _focusNode.unfocus();
  }

  void _handleNext() {
    final location = _selectedLocation;
    if (location == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrayerTimesPage(
          latitude: location.latitude,
          longitude: location.longitude,
          locationName: location.headerName,
        ),
      ),
    );
  }

  void _useCurrentLocation() async {
    // You'll need to add location permission package
    // For now, this is a placeholder
    // You can use geolocator package: https://pub.dev/packages/geolocator
    print('Use current location');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _focusNode.unfocus();
        setState(() {
          _showSuggestions = false;
        });
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: SizedBox(
                  height: 40,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'أين أنت الآن؟ 🗺️',
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
              ),
              const SizedBox(height: 9),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'نحتاج عنوانك لضبط مواقيت الصلاة والقبلة إن شاء الله.',
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: AppColors.zinc400,
                  ),
                ),
              ),

              // Search field, centered in the free space. Suggestions open
              // below it without moving it.
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        Positioned(
                          top: (constraints.maxHeight / 2 - 23).clamp(
                            0.0,
                            double.infinity,
                          ),
                          left: 16,
                          right: 16,
                          bottom: 0,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildSearchField(),
                              if (_showSuggestions && _suggestions.isNotEmpty)
                                Flexible(child: _buildSuggestions()),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _selectedLocation != null ? _handleNext : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.foreground,
                      foregroundColor: AppColors.background,
                      disabledBackgroundColor: AppColors.zinc200,
                      disabledForegroundColor: AppColors.zinc400,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      // Buttons don't inherit the app font, so set it here
                      textStyle: const TextStyle(
                        fontFamily: 'IBMPlexArabic',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    child: const Text(
                      'التالي',
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 46,
      padding: const EdgeInsets.only(left: 12, right: 12),
      decoration: BoxDecoration(
        color: AppColors.zinc100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          // Spinner takes the icon's place while searching
          SizedBox(
            width: 23,
            height: 23,
            child: _isSearching
                ? const Center(child: ArcSpinner())
                : Icon(
                    Icons.my_location,
                    size: 23,
                    color: AppColors.zinc400,
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              cursorColor: AppColors.zinc700,
              style: TextStyle(
                fontFamily: 'IBMPlexArabic',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.zinc700,
              ),
              decoration: InputDecoration.collapsed(
                hintText: 'أدخل مدينتك من فضلك.',
                hintTextDirection: TextDirection.rtl,
                hintStyle: TextStyle(
                  fontFamily: 'IBMPlexArabic',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.zinc400,
                ),
              ),
              onTap: () {
                setState(() {
                  if (_suggestions.isNotEmpty) {
                    _showSuggestions = true;
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: AppColors.zinc100,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _suggestions.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          thickness: 1,
          indent: 16,
          endIndent: 16,
          color: AppColors.zinc200,
        ),
        itemBuilder: (context, index) {
          final suggestion = _suggestions[index];
          return InkWell(
            onTap: () => _selectLocation(suggestion),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    suggestion.city.isNotEmpty
                        ? suggestion.city
                        : suggestion.displayName,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.zinc700,
                    ),
                  ),
                  if (suggestion.country.isNotEmpty)
                    Text(
                      [
                        suggestion.region,
                        suggestion.country,
                      ].where((s) => s.isNotEmpty).toSet().join('، '),
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.zinc400,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class LocationSuggestion {
  final String displayName;
  final double latitude;
  final double longitude;
  final String city;
  final String region;
  final String country;

  LocationSuggestion({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.region,
    required this.country,
  });

  // "City, Region" as shown in the prayer times header
  String get headerName {
    if (city.isEmpty) return displayName;
    if (region.isEmpty || region == city) return city;
    return '$city, $region';
  }
}
