import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool _mapReady = false;
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

      if (_mapReady) _fitBounds();
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

  // ── Map launch helpers ────────────────────────────────────────────────────

  /// Opens Google Maps app directly via deep link.
  /// Falls back to browser if the app is not installed.
  Future<void> _openGoogleMaps() async {
    final dst = "${widget.jobLat},${widget.jobLng}";
    final origin = _myLocation != null
        ? "${_myLocation!.latitude},${_myLocation!.longitude}"
        : null;

    // Try the native Google Maps URI scheme first (opens the app, not browser)
    final appUri = Platform.isIOS
        ? Uri.parse(
            "comgooglemaps://?daddr=$dst"
            "${origin != null ? '&saddr=$origin' : ''}"
            "&directionsmode=driving",
          )
        : Uri.parse(
            "google.navigation:q=$dst"
            "${origin != null ? '&origin=$origin' : ''}"
            "&mode=d",
          );

    if (await canLaunchUrl(appUri)) {
      await launchUrl(appUri);
      return;
    }

    // Fallback — browser URL (always works, opens web Google Maps)
    final webUri = Uri.parse(
      "https://www.google.com/maps/dir/?api=1"
      "&destination=$dst"
      "${origin != null ? '&origin=$origin' : ''}"
      "&travelmode=driving",
    );
    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  /// Opens the device's default maps app via the standard geo: URI.
  /// On Android this shows a chooser; on iOS falls back to Apple Maps.
  Future<void> _openNativeMaps() async {
    final dst = "${widget.jobLat},${widget.jobLng}";

    if (Platform.isIOS) {
      // Apple Maps deep link
      final appleUri = Uri.parse(
        "https://maps.apple.com/?daddr=$dst&dirflg=d",
      );
      if (await canLaunchUrl(appleUri)) {
        await launchUrl(appleUri, mode: LaunchMode.externalApplication);
        return;
      }
    }

    // Android geo: intent — shows native maps chooser
    final geoUri = Uri.parse(
      "geo:$dst?q=$dst(Job+Location)",
    );
    if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri);
      return;
    }

    // Last resort
    await _openGoogleMaps();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  List<Marker> get _markers {
    final markers = <Marker>[
      Marker(
        point: _jobLatLng,
        width: 48,
        height: 56,
        alignment: Alignment.topCenter,
        child: const Icon(Icons.location_pin, color: Colors.red, size: 48),
      ),
    ];

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
          // ── Map ──────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _jobLatLng,
              initialZoom: 14,
              onMapReady: () {
                _mapReady = true;
                if (_myLocation != null) _fitBounds();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.skill_renting_app',
                maxZoom: 19,
              ),
              PolylineLayer(polylines: _polylines),
              MarkerLayer(markers: _markers),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),

          // ── Bottom panel ─────────────────────────────────────────────────
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
                  // Destination row
                  Row(children: [
                    Container(
                      width: 44, height: 44,
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
                          Text(widget.seekerName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 2),
                          Text(widget.jobAddress,
                              style: TextStyle(
                                  color: Colors.grey.shade600, fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ]),

                  const SizedBox(height: 6),

                  Padding(
                    padding: const EdgeInsets.only(left: 56),
                    child: Text(
                      "${widget.jobLat.toStringAsFixed(6)}, "
                      "${widget.jobLng.toStringAsFixed(6)}",
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                          fontFamily: 'monospace'),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Navigation buttons
                  Row(children: [
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        onPressed: _openGoogleMaps,
                        icon: const Icon(Icons.navigation_rounded),
                        label: const Text("Google Maps"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: OutlinedButton.icon(
                        onPressed: _openNativeMaps,
                        icon: const Icon(Icons.map_outlined),
                        label: Text(Platform.isIOS ? "Apple Maps" : "Maps"),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ]),

                  if (_loadingMyLocation) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(width: 8),
                        Text("Getting your location…",
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 12)),
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
