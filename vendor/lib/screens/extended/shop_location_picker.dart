import 'package:eventor_vendor/core/theme/app_icon_colors.dart';

import '../../models/shop_region_boundary.dart';
import '../../widgets/vendor_page_scaffold.dart';
import '../../widgets/common/app_shimmer.dart';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class ShopLocationPicker extends StatefulWidget {
  final ShopRegionBoundary? boundary;
  final LatLng? initialLocation;
  final LatLng? cityCenter;
  final TileProvider? tileProvider;
  const ShopLocationPicker({
    super.key,
    this.boundary,
    this.initialLocation,
    this.cityCenter,
    this.tileProvider,
  });
  @override
  State<ShopLocationPicker> createState() => _ShopLocationPickerState();
}

class _ShopLocationPickerState extends State<ShopLocationPicker> {
  final controller = MapController();
  late LatLng point;
  late bool selected;
  @override
  void initState() {
    super.initState();
    final initial = widget.initialLocation;
    selected = initial != null && (widget.boundary?.contains(initial) ?? true);
    point = selected
        ? initial!
        : widget.boundary?.center ??
              widget.cityCenter ??
              const LatLng(20.594, 78.963);
  }

  void selectPoint(LatLng next) {
    setState(() {
      point = next;
      selected = widget.boundary?.contains(next) ?? true;
      message = selected
          ? null
          : 'Select your shop inside the highlighted ${widget.boundary!.name} border.';
    });
  }

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
      if (widget.boundary != null && !widget.boundary!.contains(next)) {
        throw StateError(
          'Your GPS location is outside ${widget.boundary!.name}. Select your shop inside the highlighted border.',
        );
      }
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
  Widget build(BuildContext context) => VendorPageScaffold(
    backgroundColor: const Color(0xFFF8F8FA),
    appBar: AppBar(
      title: const Text(
        'Mark your shop',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
      ),
      backgroundColor: const Color(0xFFF8F8FA),
      surfaceTintColor: Colors.transparent,
    ),
    body: Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF5E8EC),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: AppIconColors.standard,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.boundary == null
                      ? 'Move the map or tap your shop. Place the pin at the exact shop entrance.'
                      : 'Select your shop inside ${widget.boundary!.name}. Border source: ${widget.boundary!.sourceYear}.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF80152C),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: controller,
                options: MapOptions(
                  initialCenter: point,
                  initialCameraFit: widget.boundary != null && !selected
                      ? CameraFit.bounds(
                          bounds: LatLngBounds.fromPoints(
                            widget.boundary!.points.toList(),
                          ),
                          padding: const EdgeInsets.all(32),
                          maxZoom: 15,
                        )
                      : null,
                  cameraConstraint: widget.boundary == null
                      ? const CameraConstraint.unconstrained()
                      : CameraConstraint.containCenter(
                          bounds: LatLngBounds.fromPoints(
                            widget.boundary!.points.toList(),
                          ),
                        ),
                  initialZoom: widget.initialLocation != null
                      ? 17
                      : widget.cityCenter != null
                      ? 12
                      : 5,
                  minZoom: 3,
                  maxZoom: 19,
                  onTap: (_, location) {
                    controller.move(location, controller.camera.zoom);
                    selectPoint(location);
                  },
                  onPositionChanged: (camera, gesture) {
                    if (gesture) {
                      selectPoint(camera.center);
                    }
                  },
                ),
                children: [
                  TileLayer(
                    tileProvider: widget.tileProvider,
                    urlTemplate: const String.fromEnvironment(
                      'EVENTOR_MAP_TILE_URL',
                      defaultValue:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    ),
                    userAgentPackageName: 'EventorVendor.ShopLocationPicker',
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
                  if (widget.boundary != null)
                    PolygonLayer(
                      polygons: [
                        for (final polygon in widget.boundary!.polygons)
                          Polygon(
                            points: polygon.first,
                            holePointsList: polygon.skip(1).toList(),
                            color: const Color(0xFF80152C)
                                .withValues(alpha: 0.08),
                            borderColor: const Color(0xFF80152C),
                            borderStrokeWidth: 2.5,
                          ),
                      ],
                    ),
                ],
              ),
              Center(
                child: IgnorePointer(
                  child: Transform.translate(
                    offset: const Offset(0, -20),
                    child: const Icon(
                      Icons.location_pin,
                      color: Color(0xFF80152C),
                      size: 46,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 16,
                top: 16,
                child: FloatingActionButton.small(
                  heroTag: 'shop-gps',
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF80152C),
                  elevation: 3,
                  onPressed: locating ? null : locate,
                  child: locating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: AppShimmerIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF80152C),
                          ),
                        )
                      : const Icon(Icons.my_location),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Material(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                  ),
                  child: TextButton(
                    onPressed: () async {
                      await launchUrl(
                        Uri.parse('https://www.openstreetmap.org/copyright'),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    child: Text(
                      widget.boundary == null
                          ? '© OpenStreetMap contributors'
                          : '© OpenStreetMap · geoBoundaries (ODbL)',
                      style: TextStyle(fontSize: 10, color: Color(0xFF73737D)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF80152C).withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      message!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF73737D),
                      ),
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.pin_drop_outlined,
                      size: 16,
                      color: AppIconColors.standard,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      selected
                          ? '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}'
                          : 'Select shop location on map',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: selected
                            ? const Color(0xFF17171B)
                            : const Color(0xFF73737D),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF80152C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 2,
                      shadowColor: const Color(0xFF80152C)
                          .withValues(alpha: 0.3),
                    ),
                    onPressed:
                        !selected ||
                            locating ||
                            (widget.boundary != null &&
                                !widget.boundary!.contains(point))
                        ? null
                        : () => Navigator.pop(context, point),
                    icon: const Icon(Icons.check_circle_outline, size: 20),
                    label: const Text(
                      'Use this shop location',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
