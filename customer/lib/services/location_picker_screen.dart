import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
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
  // ============================================================
  // COLORS
  // ============================================================

  static const Color primaryRed =
      Color(0xFF9F0101);

  // ============================================================
  // DEFAULT LOCATION
  // ============================================================

  static const LatLng defaultLocation =
      LatLng(
    13.0827,
    80.2707,
  );

  // ============================================================
  // MAP CONTROLLER
  // ============================================================

  MapplsMapController? _mapController;

  // ============================================================
  // SELECTED LOCATION
  // ============================================================

  LatLng _selectedLocation =
      defaultLocation;

  // ============================================================
  // LOCATION NAME
  // ============================================================

  final TextEditingController
      _locationController =
      TextEditingController();

  // ============================================================
  // STATE
  // ============================================================

  bool _isGettingLocation = false;

  bool _hasSelectedLocation = false;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    final String initial =
        widget.initialLocation?.trim() ?? '';

    if (initial.isNotEmpty) {
      _locationController.text =
          initial;
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _locationController.dispose();

    super.dispose();
  }

  // ============================================================
  // MAP CREATED
  // ============================================================

  void _onMapCreated(
    MapplsMapController controller,
  ) {
    _mapController = controller;

    debugPrint(
      'EVENTRA: Mappls map created.',
    );
  }

  // ============================================================
  // CURRENT LOCATION
  // ============================================================

  Future<void> _useCurrentLocation() async {
    if (_isGettingLocation) {
      return;
    }

    setState(() {
      _isGettingLocation = true;
    });

    try {
      // --------------------------------------------------------
      // CHECK LOCATION SERVICE
      // --------------------------------------------------------

      final bool serviceEnabled =
          await Geolocator
              .isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (mounted) {
          _showMessage(
            'Please turn on Location Services.',
          );
        }

        return;
      }

      // --------------------------------------------------------
      // CHECK PERMISSION
      // --------------------------------------------------------

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission ==
          LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();
      }

      if (permission ==
          LocationPermission.denied) {
        if (mounted) {
          _showMessage(
            'Location permission denied.',
          );
        }

        return;
      }

      if (permission ==
          LocationPermission.deniedForever) {
        if (mounted) {
          await _showPermissionDialog();
        }

        return;
      }

      // --------------------------------------------------------
      // GET GPS
      // --------------------------------------------------------

      final Position position =
          await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(
          accuracy:
              LocationAccuracy.high,
          distanceFilter: 5,
        ),
      );

      final LatLng currentLocation =
          LatLng(
        position.latitude,
        position.longitude,
      );

      debugPrint(
        'EVENTRA GPS: '
        '${position.latitude}, '
        '${position.longitude}',
      );

      if (!mounted) {
        return;
      }

      // --------------------------------------------------------
      // UPDATE SELECTED LOCATION
      // --------------------------------------------------------

      setState(() {
        _selectedLocation =
            currentLocation;

        _hasSelectedLocation = true;
      });

      // --------------------------------------------------------
      // MOVE MAP
      // --------------------------------------------------------

      final MapplsMapController?
          controller =
          _mapController;

      if (controller != null) {
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(
            currentLocation,
            16.0,
          ),
        );
      }

      // --------------------------------------------------------
      // AUTOMATIC LOCATION NAME
      //
      // Without adding another package/API,
      // we use a readable GPS label.
      // User can manually replace it.
      // --------------------------------------------------------

      if (_locationController.text
          .trim()
          .isEmpty) {
        setState(() {
          _locationController.text =
              'GPS Location '
              '(${position.latitude.toStringAsFixed(6)}, '
              '${position.longitude.toStringAsFixed(6)})';
        });
      }

      _showMessage(
        'Current location selected.',
      );
    } catch (e) {
      debugPrint(
        'EVENTRA GPS ERROR: $e',
      );

      if (mounted) {
        _showMessage(
          'Unable to get current location.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGettingLocation = false;
        });
      }
    }
  }

  // ============================================================
  // MANUAL LOCATION
  // ============================================================

  Future<void> _editLocationName() async {
    if (_isGettingLocation) {
      return;
    }

    final TextEditingController
        controller =
        TextEditingController(
      text:
          _locationController.text,
    );

    final String? result =
        await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Enter Event Location',
          ),

          content: TextField(
            controller:
                controller,
            autofocus: true,
            maxLines: 3,
            textCapitalization:
                TextCapitalization
                    .sentences,
            decoration:
                const InputDecoration(
              hintText:
                  'Example: Kumbakonam Marriage Hall',
              border:
                  OutlineInputBorder(),
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),

            FilledButton(
              onPressed: () {
                final String value =
                    controller.text
                        .trim();

                if (value.isEmpty) {
                  return;
                }

                Navigator.pop(
                  context,
                  value,
                );
              },
              child: const Text(
                'Use Location',
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (!mounted ||
        result == null) {
      return;
    }

    setState(() {
      _locationController.text =
          result;
    });
  }

  // ============================================================
  // CONFIRM LOCATION
  // ============================================================

  void _confirmLocation() {
    final String address =
        _locationController.text
            .trim();

    // ----------------------------------------------------------
    // LOCATION NAME REQUIRED
    // ----------------------------------------------------------

    if (address.isEmpty) {
      _showMessage(
        'Please enter the event location.',
      );

      return;
    }

    // ----------------------------------------------------------
    // GPS REQUIRED
    // ----------------------------------------------------------

    if (!_hasSelectedLocation) {
      _showMessage(
        'Please select the location using GPS first.',
      );

      return;
    }

    // ----------------------------------------------------------
    // RETURN LOCATION
    // ----------------------------------------------------------

    Navigator.of(context).pop(
      <String, dynamic>{
        'latitude':
            _selectedLocation
                .latitude,

        'longitude':
            _selectedLocation
                .longitude,

        'address':
            address,
      },
    );
  }

  // ============================================================
  // PERMISSION DIALOG
  // ============================================================

  Future<void>
      _showPermissionDialog() async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Location Permission',
          ),

          content: const Text(
            'Location permission is permanently '
            'denied. Please enable it from App Settings.',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  context,
                ).pop();
              },
              child: const Text(
                'Cancel',
              ),
            ),

            FilledButton(
              onPressed: () async {
                Navigator.of(
                  context,
                ).pop();

                await Geolocator
                    .openAppSettings();
              },
              child: const Text(
                'Open Settings',
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content:
              Text(message),
          behavior:
              SnackBarBehavior
                  .floating,
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          Colors.white,

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        backgroundColor:
            primaryRed,
        foregroundColor:
            Colors.white,
        elevation: 0,

        title: const Text(
          'Select Event Location',
          style: TextStyle(
            fontWeight:
                FontWeight.w700,
          ),
        ),
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: Stack(
        children: [
          // ====================================================
          // MAP
          // ====================================================

          MapplsMap(
            initialCameraPosition:
                const CameraPosition(
              target:
                  defaultLocation,
              zoom: 13.0,
            ),

            onMapCreated:
                _onMapCreated,

            onMapError: (
              code,
              message,
            ) {
              debugPrint(
                'EVENTRA MAP ERROR: '
                '$code - $message',
              );
            },
          ),

          // ====================================================
          // CENTER LOCATION PIN
          // ====================================================

          const IgnorePointer(
            child: Center(
              child: Padding(
                padding:
                    EdgeInsets.only(
                  bottom: 35,
                ),
                child: Icon(
                  Icons.location_on,
                  size: 48,
                  color:
                      primaryRed,
                ),
              ),
            ),
          ),

          // ====================================================
          // LOCATION NAME CARD
          // ====================================================

          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: Material(
              elevation: 4,
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
              color: Colors.white,

              child: InkWell(
                onTap:
                    _editLocationName,

                borderRadius:
                    BorderRadius.circular(
                  14,
                ),

                child: Padding(
                  padding:
                      const EdgeInsets.all(
                    14,
                  ),

                  child: Row(
                    children: [
                      // ----------------------------------------
                      // ICON
                      // ----------------------------------------

                      Container(
                        width: 42,
                        height: 42,
                        decoration:
                            BoxDecoration(
                          color:
                              const Color(
                            0xFFF5D0D0,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            10,
                          ),
                        ),

                        child:
                            const Icon(
                          Icons
                              .location_on_rounded,
                          color:
                              primaryRed,
                        ),
                      ),

                      const SizedBox(
                        width: 12,
                      ),

                      // ----------------------------------------
                      // LOCATION TEXT
                      // ----------------------------------------

                      Expanded(
                        child:
                            Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,

                          children: [
                            const Text(
                              'Event Location',
                              style:
                                  TextStyle(
                                fontSize:
                                    12,
                                color:
                                    Colors.grey,
                              ),
                            ),

                            const SizedBox(
                              height: 3,
                            ),

                            Text(
                              _locationController
                                      .text
                                      .trim()
                                      .isEmpty
                                  ? 'Tap here to enter location'
                                  : _locationController
                                      .text
                                      .trim(),

                              maxLines: 2,

                              overflow:
                                  TextOverflow
                                      .ellipsis,

                              style:
                                  const TextStyle(
                                fontSize:
                                    14,
                                fontWeight:
                                    FontWeight
                                        .w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Icon(
                        Icons
                            .edit_location_alt_outlined,
                        color:
                            primaryRed,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ====================================================
          // GPS BUTTON
          // ====================================================

          Positioned(
            right: 16,
            bottom: 95,

            child:
                FloatingActionButton(
              backgroundColor:
                  primaryRed,

              foregroundColor:
                  Colors.white,

              onPressed:
                  _isGettingLocation
                      ? null
                      : _useCurrentLocation,

              child:
                  _isGettingLocation
                      ? const SizedBox(
                          width: 22,
                          height: 22,

                          child:
                              CircularProgressIndicator(
                            strokeWidth:
                                2.5,
                            color:
                                Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons
                              .my_location,
                        ),
            ),
          ),

          // ====================================================
          // CONFIRM BUTTON
          // ====================================================

          Positioned(
            left: 16,
            right: 16,
            bottom: 16,

            child: SafeArea(
              top: false,

              child: SizedBox(
                height: 52,

                child:
                    ElevatedButton
                        .icon(
                  onPressed:
                      _isGettingLocation
                          ? null
                          : _confirmLocation,

                  style:
                      ElevatedButton
                          .styleFrom(
                    backgroundColor:
                        primaryRed,

                    foregroundColor:
                        Colors.white,

                    elevation: 4,

                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        14,
                      ),
                    ),
                  ),

                  icon:
                      const Icon(
                    Icons.check,
                  ),

                  label:
                      const Text(
                    'Confirm Location',
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight.w700,
                    ),
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