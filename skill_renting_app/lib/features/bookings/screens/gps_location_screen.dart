import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:skill_renting_app/features/bookings/booking_service.dart';
import 'package:skill_renting_app/core/widgets/app_scaffold.dart';

/// Screen that lets the seeker pick the exact GPS location of the job site.
/// Uses OpenStreetMap — completely free, no API key required.
class GpsLocationScreen extends StatefulWidget {
  final String bookingId;
  final String seekerName;

  const GpsLocationScreen({
    super.key,
    required this.bookingId,
    required this.seekerName,
  });

  @override
  State<GpsLocationScreen> createState() => _GpsLocationScreenState();
}

class _GpsLocationScreenState extends State<GpsLocationScreen> {
  final MapController _mapController = MapController();

  // Default to Kerala centre until GPS loads
  LatLng _pickedLocation = const LatLng(10.8505, 76.2711);
  bool _locationLoaded = false;
  bool _saveAsHome = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnack("Location services are disabled. Please enable GPS.");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnack("Location permission denied.");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnack("Location permission permanently denied. Enable in settings.");
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final latLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _pickedLocation = latLng;
        _locationLoaded = true;
      });

      _mapController.move(latLng, 17);
    } catch (e) {
      _showSnack("Could not get location: $e");
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final success = await BookingService.submitJobGps(
        bookingId: widget.bookingId,
        lat: _pickedLocation.latitude,
        lng: _pickedLocation.longitude,
        saveAsHome: _saveAsHome,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("📍 Location shared with provider!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        _showSnack("Failed to share location. Please try again.");
      }
    } catch (e) {
      _showSnack("Error: $e");
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _skip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Skip GPS?"),
        content: const Text(
          "The provider won't get navigation directions. "
          "Are you sure you want to skip?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Skip"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _submitting = true);
    try {
      await BookingService.skipJobGps(widget.bookingId);
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppScaffold(
      appBar: AppBar(
        title: const Text("Share Job Location"),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _skip,
            child: Text(
              "Skip",
              style: TextStyle(
                color: scheme.onSurfaceVariant.withOpacity(0.85),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── OpenStreetMap ──────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _pickedLocation,
              initialZoom: 15,
              onTap: (tapPosition, latLng) {
                setState(() => _pickedLocation = latLng);
              },
            ),
            children: [
              // OSM tile layer — free, no API key needed
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.skill_renting_app',
                maxZoom: 19,
              ),

              // Pin marker at picked location
              MarkerLayer(
                markers: [
                  Marker(
                    point: _pickedLocation,
                    width: 48,
                    height: 56,
                    alignment: Alignment.topCenter,
                    child: const Icon(
                      Icons.location_pin,
                      color: Colors.red,
                      size: 48,
                    ),
                  ),
                ],
              ),

              // OSM attribution — required by OpenStreetMap license
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),

          // ── Re-center to my location ───────────────────────────────────────
          Positioned(
            top: 12,
            right: 12,
            child: FloatingActionButton.small(
              heroTag: "recenter_gps",
              backgroundColor: scheme.surface,
              foregroundColor: scheme.onSurface,
              elevation: 4,
              onPressed: _loadCurrentLocation,
              tooltip: "My location",
              child: const Icon(Icons.my_location),
            ),
          ),

          // ── Bottom panel ───────────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Instruction
                  Row(
                    children: [
                      const Icon(Icons.touch_app,
                          color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          "Tap anywhere on the map to drop the pin",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Live coordinates
                  Text(
                    "${_pickedLocation.latitude.toStringAsFixed(6)}, "
                    "${_pickedLocation.longitude.toStringAsFixed(6)}",
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant.withOpacity(0.85),
                      fontFamily: 'monospace',
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Save as home toggle
                  Container(
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: scheme.primaryContainer),
                    ),
                    child: SwitchListTile(
                      dense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14),
                      title: const Text(
                        "Save as my home location",
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      subtitle: const Text(
                        "Future providers will get this automatically",
                        style: TextStyle(fontSize: 11),
                      ),
                      value: _saveAsHome,
                      onChanged: (v) => setState(() => _saveAsHome = v),
                      activeColor: Colors.blue,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        _submitting
                            ? "Sharing..."
                            : "Share Location with Provider",
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Loading overlay ────────────────────────────────────────────────
          if (!_locationLoaded)
            Container(
              color: Colors.black26,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text("Getting your location…"),
                      ],
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
