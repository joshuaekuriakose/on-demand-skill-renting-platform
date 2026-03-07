import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shows the job location on a map and lets the provider open
/// Google Maps / Waze / native maps for turn-by-turn navigation.
/// Uses OpenStreetMap — free, no API key required.
class NavigationScreen extends StatefulWidget {
  final double jobLat;
  final double jobLng;
  final String seekerName;
  final String jobAddress;

  const NavigationScreen({
    super.key,
    required this.jobLat,
    required this.jobLng,
    required this.seekerName,
    required this.jobAddress,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final MapController _mapController = MapController();

  LatLng? _myLocation;
  bool _loadingMyLocation = true;
  late final LatLng _jobLatLng;

  @override
  void initState() {
    super.initState();
    _jobLatLng = LatLng(widget.jobLat, widget.jobLng);
    _loadMyLocation();
  }

  Future<void> _loadMyLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _loadingMyLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        setState(() => _loadingMyLocation = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _myLocation = LatLng(pos.latitude, pos.longitude);
        _loadingMyLocation = false;
      });

      // Fit both markers in view
      _fitBounds();
    } catch (_) {
      setState(() => _loadingMyLocation = false);
    }
  }

  void _fitBounds() {
    if (_myLocation == null) {
      _mapController.move(_jobLatLng, 15);
      return;
    }

    final bounds = LatLngBounds(
      LatLng(
        _myLocation!.latitude < _jobLatLng.latitude
            ? _myLocation!.latitude
            : _jobLatLng.latitude,
        _myLocation!.longitude < _jobLatLng.longitude
            ? _myLocation!.longitude
            : _jobLatLng.longitude,
      ),
      LatLng(
        _myLocation!.latitude > _jobLatLng.latitude
            ? _myLocation!.latitude
            : _jobLatLng.latitude,
        _myLocation!.longitude > _jobLatLng.longitude
            ? _myLocation!.longitude
            : _jobLatLng.longitude,
      ),
    );

    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80)),
    );
  }

  /// Opens Google Maps app for turn-by-turn navigation.
  Future<void> _openGoogleMaps() async {
    final origin = _myLocation != null
        ? "&origin=${_myLocation!.latitude},${_myLocation!.longitude}"
        : "";

    final uri = Uri.parse(
      "https://www.google.com/maps/dir/?api=1"
      "&destination=${widget.jobLat},${widget.jobLng}"
      "$origin"
      "&travelmode=driving",
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnack("Could not open Google Maps");
    }
  }

  /// Opens the native geo intent — works with any maps app on the device.
  Future<void> _openNativeMaps() async {
    final uri = Uri.parse(
      "geo:${widget.jobLat},${widget.jobLng}"
      "?q=${widget.jobLat},${widget.jobLng}(Job+Location)",
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _openGoogleMaps();
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  List<Marker> get _markers {
    final markers = <Marker>[
      // Job location — red pin
      Marker(
        point: _jobLatLng,
        width: 48,
        height: 56,
        alignment: Alignment.topCenter,
        child: const Icon(Icons.location_pin, color: Colors.red, size: 48),
      ),
    ];

    // Provider location — blue dot
    if (_myLocation != null) {
      markers.add(
        Marker(
          point: _myLocation!,
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.4),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 18),
          ),
        ),
      );
    }

    return markers;
  }

  List<Polyline> get _polylines {
    if (_myLocation == null) return [];
    return [
      Polyline(
        points: [_myLocation!, _jobLatLng],
        color: Colors.blue.shade600,
        strokeWidth: 3,
        isDotted: true,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Navigate to ${widget.seekerName}"),
        actions: [
          IconButton(
            icon: const Icon(Icons.fit_screen),
            tooltip: "Fit both locations",
            onPressed: _fitBounds,
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── OpenStreetMap ──────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _jobLatLng,
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.skill_renting_app',
                maxZoom: 19,
              ),

              // Dashed line from provider → job
              PolylineLayer(polylines: _polylines),

              // Markers
              MarkerLayer(markers: _markers),

              // OSM attribution
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),

          // ── Bottom navigation panel ────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
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
                  // Destination card
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.location_pin,
                            color: Colors.red, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.seekerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.jobAddress,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // GPS coords
                  Padding(
                    padding: const EdgeInsets.only(left: 56),
                    child: Text(
                      "${widget.jobLat.toStringAsFixed(6)}, "
                      "${widget.jobLng.toStringAsFixed(6)}",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade400,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Navigation buttons
                  Row(
                    children: [
                      // Google Maps (primary)
                      Expanded(
                        flex: 3,
                        child: ElevatedButton.icon(
                          onPressed: _openGoogleMaps,
                          icon: const Icon(Icons.navigation_rounded),
                          label: const Text("Open in Google Maps"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      // Native maps fallback
                      Expanded(
                        flex: 2,
                        child: OutlinedButton.icon(
                          onPressed: _openNativeMaps,
                          icon: const Icon(Icons.map_outlined),
                          label: const Text("Maps App"),
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (_loadingMyLocation) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Getting your location…",
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
