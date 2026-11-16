import 'package:deen_app/prayertimes_page.dart';
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
        'count': '5',
        'language': 'ar',
        'format': 'json',
      });

      final response =
          await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> items = data['results'] ?? [];
        results = items.map((item) {
          final name = item['name'] ?? '';
          final country = item['country'] ?? '';
          return LocationSuggestion(
            displayName: country.isNotEmpty ? '$name، $country' : name,
            latitude: (item['latitude'] as num).toDouble(),
            longitude: (item['longitude'] as num).toDouble(),
            city: name,
            country: country,
          );
        }).toList();
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
    if (_selectedLocation != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PrayerTimesPage(
            latitude: _selectedLocation!.latitude,
            longitude: _selectedLocation!.longitude,
            locationName: _selectedLocation!.city.isNotEmpty
                ? _selectedLocation!.city
                : _selectedLocation!.displayName,
          ),
        ),
      );
    }
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
        backgroundColor: Colors.grey.shade200,
        body: SafeArea(
          child: Column(
            children: [
              // Main content
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const SizedBox(height: 60),

                        // Title with icon and text
                        const Directionality(
                          textDirection: TextDirection.rtl,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "🗺️",
                                style: TextStyle(fontSize: 32),
                              ),
                              SizedBox(width: 8),
                              Text(
                                "أين أنت الآن؟",
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Subtitle
                        const Directionality(
                          textDirection: TextDirection.rtl,
                          child: Text(
                            "نحتاج عنوانك لضبط مواقيت الصلاة والقبلة إن شاء الله.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                              height: 1.5,
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Location search field
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Directionality(
                            textDirection: TextDirection.rtl,
                            child: TextField(
                              controller: _searchController,
                              focusNode: _focusNode,
                              textDirection: TextDirection.rtl,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                              decoration: InputDecoration(
                                hintText: "أدخِل مدينتك من فضلك.",
                                hintStyle: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade500,
                                ),
                                prefixIcon: const Padding(
                                  padding: EdgeInsets.only(right: 12, left: 12),
                                  child: Icon(
                                    Icons.my_location,
                                    color: Colors.grey,
                                    size: 24,
                                  ),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
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
                        ),

                        // Search suggestions
                        if (_showSuggestions && _suggestions.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _suggestions.length,
                              separatorBuilder: (context, index) => Divider(
                                height: 1,
                                color: Colors.grey.shade200,
                              ),
                              itemBuilder: (context, index) {
                                final suggestion = _suggestions[index];
                                return ListTile(
                                  onTap: () => _selectLocation(suggestion),
                                  title: Directionality(
                                    textDirection: TextDirection.rtl,
                                    child: Text(
                                      suggestion.city.isNotEmpty
                                          ? suggestion.city
                                          : suggestion.displayName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  subtitle: suggestion.city.isNotEmpty
                                      ? Directionality(
                                    textDirection: TextDirection.rtl,
                                    child: Text(
                                      suggestion.country,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  )
                                      : null,
                                  trailing: const Icon(
                                    Icons.location_on_outlined,
                                    color: Colors.grey,
                                  ),
                                );
                              },
                            ),
                          ),

                        if (_isSearching)
                          const Padding(
                            padding: EdgeInsets.only(top: 20),
                            child: CircularProgressIndicator(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom button
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _selectedLocation != null ? _handleNext : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedLocation != null
                          ? Colors.blue
                          : Colors.grey.shade300,
                      foregroundColor: _selectedLocation != null
                          ? Colors.white
                          : Colors.grey.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      disabledBackgroundColor: Colors.grey.shade300,
                      disabledForegroundColor: Colors.grey.shade600,
                    ),
                    child: const Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text(
                        "التالي",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
}

class LocationSuggestion {
  final String displayName;
  final double latitude;
  final double longitude;
  final String city;
  final String country;

  LocationSuggestion({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.country,
  });
}