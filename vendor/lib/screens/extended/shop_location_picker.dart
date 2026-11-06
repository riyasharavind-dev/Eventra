import '../../widgets/common/app_shimmer.dart';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class ShopLocationPicker extends StatefulWidget {
  final LatLng? initialLocation;
  final LatLng? cityCenter;
  final TileProvider? tileProvider;
  const ShopLocationPicker({
    super.key,
    this.initialLocation,
    this.cityCenter,
    this.tileProvider,
  });
  @override
  State<ShopLocationPicker> createState() => _ShopLocationPickerState();
}

class _ShopLocationPickerState extends State<ShopLocationPicker> {
  final controller = MapController();
  late LatLng point =
      widget.initialLocation ??
      widget.cityCenter ??
      const LatLng(20.594, 78.963);
  late bool selected = widget.initialLocation != null;
  bool locating = false;
  String? message;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> locate() async {
    if (locating) return;
    setState(() {
      locating = true;
      message = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError(
          'Turn on device location, or move the map to your shop.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (![
        LocationPermission.always,
        LocationPermission.whileInUse,
      ].contains(permission)) {
        throw StateError(
          'Location access is unavailable. You can still select your shop on the map.',
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      final next = LatLng(position.latitude, position.longitude);
      controller.move(next, 18);
      setState(() {
        point = next;
        selected = true;
        message =
            'GPS accuracy: about ${position.accuracy.round()} m. Adjust the pin to your shop entrance.';
      });
    } catch (e) {
      if (mounted) {
        setState(() => message = e.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mark your shop')),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(14),
          child: Text(
            'Move the map or tap your shop. Place the pin at the exact shop entrance.',
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: controller,
                options: MapOptions(
                  initialCenter: point,
                  initialZoom: widget.initialLocation != null
                      ? 17
                      : widget.cityCenter != null
                      ? 12
                      : 5,
                  minZoom: 3,
                  maxZoom: 19,
                  onTap: (_, location) {
                    controller.move(location, controller.camera.zoom);
                    setState(() {
                      point = location;
                      selected = true;
                    });
                  },
                  onPositionChanged: (camera, gesture) {
                    if (gesture) {
                      setState(() {
                        point = camera.center;
                        selected = true;
                      });
                    }
                  },
                ),
                children: [
                  TileLayer(
                    tileProvider: widget.tileProvider,
                    urlTemplate: const String.fromEnvironment(
                      'EVENTRA_MAP_TILE_URL',
                      defaultValue:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    ),
                    userAgentPackageName: 'EventraVendor.ShopLocationPicker',
                    maxNativeZoom: 19,
                    panBuffer: 0,
                    errorTileCallback: (_, error, stack) {
                      if (!mounted ||
                          message ==
                              'Map unavailable. Check your connection and try again.') {
                        return;
                      }
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(
                            () => message = 'Map unavailable. Check your connection and try again.',
                          );
                        }
                      });
                    },
                  ),
                ],
              ),
              Center(
                child: IgnorePointer(
                  child: Transform.translate(
                    offset: Offset(0, -20),
                    child: Icon(
                      Icons.location_pin,
                      color: Color(0xFF80152C),
                      size: 44,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: FloatingActionButton.small(
                  heroTag: 'shop-gps',
                  onPressed: locating ? null : locate,
                  child: locating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: AppShimmerIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Material(
                  color: Colors.white,
                  child: TextButton(
                    onPressed: () async {
                      await launchUrl(
                        Uri.parse('https://www.openstreetmap.org/copyright'),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    child: const Text(
                      '© OpenStreetMap contributors',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(message!),
                ),
              Text(
                selected
                    ? '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}'
                    : 'Select the exact shop location to continue',
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: !selected || locating
                      ? null
                      : () => Navigator.pop(context, point),
                  icon: const Icon(Icons.check),
                  label: const Text('Use this shop location'),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
