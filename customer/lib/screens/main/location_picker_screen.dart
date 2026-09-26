import 'package:flutter/material.dart';
import 'package:mappls_gl/mappls_gl.dart';

class LocationPickerScreen extends StatefulWidget {
  final String? initialLocation;

  const LocationPickerScreen({
    super.key,
    this.initialLocation,
  });

  @override
  State<LocationPickerScreen> createState() =>
      _LocationPickerScreenState();
}

class _LocationPickerScreenState
    extends State<LocationPickerScreen> {
  static const Color primaryRed = Color(0xFF9F0101);

  static const LatLng _defaultLocation = LatLng(
    13.0827,
    80.2707,
  );

  // This location is currently fixed for the first Mappls test.
  static const LatLng _selectedLocation =
      _defaultLocation;

  void _onMapCreated(
    MapplsMapController controller,
  ) {
    debugPrint(
      'EVENTRA: Mappls map created successfully.',
    );
  }

  void _confirmLocation() {
    Navigator.of(context).pop(
      <String, dynamic>{
        'latitude': _selectedLocation.latitude,
        'longitude': _selectedLocation.longitude,
        'address': 'Selected Event Location',
      },
    );
  }

  void _useCurrentLocation() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Current location will be enabled in the next step.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // ==========================================================
      // APP BAR
      // ==========================================================

      appBar: AppBar(
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Select Event Location',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      // ==========================================================
      // BODY
      // ==========================================================

      body: Stack(
        children: [
          // ======================================================
          // MAP
          // ======================================================

          Positioned.fill(
            child: MapplsMap(
              initialCameraPosition:
                  const CameraPosition(
                target: _defaultLocation,
                zoom: 13.0,
              ),
              onMapCreated: _onMapCreated,
              onMapError: (code, message) {
                debugPrint(
                  'EVENTRA MAPPLS ERROR: '
                  '$code - $message',
                );
              },
            ),
          ),

          // ======================================================
          // CENTER LOCATION PIN
          // ======================================================

          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: 35,
                ),
                child: Icon(
                  Icons.location_pin,
                  color: primaryRed,
                  size: 52,
                ),
              ),
            ),
          ),

          // ======================================================
          // TOP INFO
          // ======================================================

          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              decoration:
                  BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 12,
                    offset: Offset(0, 4),
                    color: Colors.black12,
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.touch_app,
                    color: primaryRed,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Select your event location on the map',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ======================================================
          // CURRENT LOCATION BUTTON
          // ======================================================

          Positioned(
            right: 16,
            bottom: 175,
            child: Material(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(14),
              elevation: 5,
              child: InkWell(
                borderRadius:
                    BorderRadius.circular(14),
                onTap: _useCurrentLocation,
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Icon(
                    Icons.my_location,
                    color: primaryRed,
                    size: 25,
                  ),
                ),
              ),
            ),
          ),

          // ======================================================
          // COORDINATES
          // ======================================================

          Positioned(
            left: 16,
            right: 16,
            bottom: 110,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration:
                  BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 10,
                    offset: Offset(0, 3),
                    color: Colors.black12,
                  ),
                ],
              ),
              child: Text(
                'Lat: '
                '${_selectedLocation.latitude.toStringAsFixed(6)}   '
                'Lng: '
                '${_selectedLocation.longitude.toStringAsFixed(6)}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // ======================================================
          // CONFIRM BUTTON
          // ======================================================

          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _confirmLocation,
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      primaryRed,
                  foregroundColor:
                      Colors.white,
                  elevation: 4,
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                  ),
                ),
                icon: const Icon(
                  Icons.check_circle_outline,
                ),
                label: const Text(
                  'Confirm Location',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}