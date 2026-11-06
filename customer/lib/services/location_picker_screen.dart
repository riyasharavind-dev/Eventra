import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationPickerScreen extends StatefulWidget {
  final String? initialLocation;
  final LatLng? initialCoordinates;
  final TileProvider? tileProvider;
  const LocationPickerScreen({
    super.key,
    this.initialLocation,
    this.initialCoordinates,
    this.tileProvider,
  });
  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static const primaryRed = Color(0xFF9F0101);
  final _map = MapController();
  late final _address = TextEditingController(
    text: widget.initialLocation ?? '',
  );
  late LatLng _point =
      widget.initialCoordinates ?? const LatLng(13.0827, 80.2707);
  late bool _selected = widget.initialCoordinates != null;
  bool _locating = false;
  String? _mapError;
  @override
  void dispose() {
    _map.dispose();
    _address.dispose();
    super.dispose();
  }

  void _message(String value) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));
  void _select(LatLng value) {
    setState(() {
      _point = value;
      _selected = true;
    });
  }

  Future<void> _locate() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError(
          'Turn on Location Services, or select a point on the map.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Location Permission'),
            content: const Text(
              'Enable location permission in App Settings, or select your location manually on the map.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(c);
                  Geolocator.openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
        return;
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        throw StateError(
          'Location permission denied. You can still select a point on the map.',
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      final point = LatLng(position.latitude, position.longitude);
      _map.move(point, 16);
      _select(point);
      if (_address.text.trim().isEmpty) {
        _address.text =
            'GPS Location (${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)})';
      }
    } catch (e) {
      if (mounted) _message(e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _editAddress() async {
    var value = _address.text;
    final result = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Enter Event Location'),
        content: TextFormField(
          initialValue: value,
          onChanged: (text) => value = text,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Example: Kumbakonam Marriage Hall',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (value.trim().isNotEmpty) Navigator.pop(c, value.trim());
            },
            child: const Text('Use Location'),
          ),
        ],
      ),
    );
    if (mounted && result != null) setState(() => _address.text = result);
  }

  void _confirm() {
    if (_address.text.trim().isEmpty) {
      _message('Please enter the event location.');
      return;
    }
    if (!_selected) {
      _message('Tap or move the map to select the exact location.');
      return;
    }
    Navigator.pop(context, <String, dynamic>{
      'latitude': _point.latitude,
      'longitude': _point.longitude,
      'address': _address.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: primaryRed,
      foregroundColor: Colors.white,
      title: const Text(
        'Select Event Location',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    body: Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: _point,
            initialZoom: widget.initialCoordinates == null ? 13 : 16,
            minZoom: 3,
            maxZoom: 19,
            onTap: (_, point) {
              _map.move(point, _map.camera.zoom);
              _select(point);
            },
            onPositionChanged: (camera, gesture) {
              if (gesture) _select(camera.center);
            },
          ),
          children: [
            TileLayer(
              tileProvider: widget.tileProvider,
              urlTemplate: const String.fromEnvironment(
                'EVENTOR_MAP_TILE_URL',
                defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              ),
              userAgentPackageName: 'com.eventor.customer',
              maxNativeZoom: 19,
              panBuffer: 0,
              errorTileCallback: (_, _, _) {
                if (!mounted || _mapError != null) return;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(
                      () => _mapError =
                          'Map tiles could not load. Check your connection.',
                    );
                  }
                });
              },
            ),
            RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              attributions: [
                TextSourceAttribution(
                  'OpenStreetMap contributors',
                  onTap: () => launchUrl(
                    Uri.parse('https://www.openstreetmap.org/copyright'),
                  ),
                ),
              ],
            ),
          ],
        ),
        const IgnorePointer(
          child: Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 35),
              child: Icon(Icons.location_on, size: 48, color: primaryRed),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(14),
                color: Colors.white,
                child: ListTile(
                  onTap: _locating ? null : _editAddress,
                  leading: const Icon(
                    Icons.location_on_rounded,
                    color: primaryRed,
                  ),
                  title: const Text(
                    'Event Location',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  subtitle: Text(
                    _address.text.trim().isEmpty
                        ? 'Tap here to enter location'
                        : _address.text.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(
                    Icons.edit_location_alt_outlined,
                    color: primaryRed,
                  ),
                ),
              ),
              if (_mapError != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(_mapError!),
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 110,
          child: FloatingActionButton(
            tooltip: 'Use current location',
            backgroundColor: primaryRed,
            foregroundColor: Colors.white,
            onPressed: _locating ? null : _locate,
            child: _locating
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Icon(Icons.my_location),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 30,
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _locating ? null : _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.check),
                label: const Text('Confirm Location'),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
