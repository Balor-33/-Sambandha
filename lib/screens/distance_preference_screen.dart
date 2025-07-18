import 'package:flutter/material.dart';
import '../model/profile_setup_data.dart';
import '../widgets/next_button.dart';
import 'relationship_target_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:location/location.dart';

Future<GeoPoint?> getCurrentGeoPoint() async {
  Location location = Location();

  // Check if location services are enabled
  bool serviceEnabled = await location.serviceEnabled();
  if (!serviceEnabled) {
    serviceEnabled = await location.requestService();
    if (!serviceEnabled) return null;
  }

  // Check for permission
  PermissionStatus permissionGranted = await location.hasPermission();
  if (permissionGranted == PermissionStatus.denied) {
    permissionGranted = await location.requestPermission();
    if (permissionGranted != PermissionStatus.granted) return null;
  }

  // Get the location data
  LocationData locationData = await location.getLocation();

  if (locationData.latitude != null && locationData.longitude != null) {
    return GeoPoint(locationData.latitude!, locationData.longitude!);
  } else {
    return null;
  }
}

class DistancePreferenceScreen extends StatefulWidget {
  const DistancePreferenceScreen({super.key, required this.data});

  final ProfileSetupData data;

  @override
  State<DistancePreferenceScreen> createState() =>
      _DistancePreferenceScreenState();
}

class _DistancePreferenceScreenState extends State<DistancePreferenceScreen> {
  double _distanceValue = 70.0;
  final double _minDistance = 1.0;
  final double _maxDistance = 100.0;

  void _continueToNext() async {
    // Save distance preference to profile data
    widget.data.distancePreference = _distanceValue.round();

    // Get current location and save to profile data
    try {
      final currentLocation = await getCurrentGeoPoint();
      if (currentLocation != null) {
        widget.data.currentLocation = currentLocation;
      }
    } catch (e) {
      // If location fails, continue without it
      print('Failed to get location: $e');
    }

    // Navigate to relationship target screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RelationshipTargetScreen(data: widget.data),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back_ios,
                  size: 24,
                  color: Colors.black,
                ),
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),

              const SizedBox(height: 60),

              // Main title
              const Text(
                "YOUR DISTANCE\nPREFERENCE?",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  height: 1.2,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 24),

              // Description text
              Text(
                'Use slider to set the maximum distance you want your potential matches to be located.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 60),

              // Distance preference section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Distance Preference',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        '${_distanceValue.round()} KM',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Custom slider
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.red.shade400,
                      inactiveTrackColor: Colors.grey.shade300,
                      thumbColor: Colors.red.shade400,
                      overlayColor: Colors.red.shade400.withOpacity(0.2),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 12.0,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 20.0,
                      ),
                      trackHeight: 4.0,
                    ),
                    child: Slider(
                      value: _distanceValue,
                      min: _minDistance,
                      max: _maxDistance,
                      onChanged: (double value) {
                        setState(() {
                          _distanceValue = value;
                        });
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 60),

              // Settings note
              Center(
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                    children: [
                      const TextSpan(
                        text: 'You can change preferences\nlater from ',
                      ),
                      TextSpan(
                        text: 'Settings',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Spacer to push button to bottom
              const Spacer(),

              // Next button
              NextButton(label: 'NEXT', onPressed: _continueToNext),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
