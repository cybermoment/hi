import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:mapbox_gl/mapbox_gl.dart';

const String mapboxAccessToken = String.fromEnvironment(
  'MAPBOX_ACCESS_TOKEN',
  defaultValue: 'YOUR_MAPBOX_ACCESS_TOKEN',
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MapExplorerApp());
}

class MapExplorerApp extends StatelessWidget {
  const MapExplorerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mapbox Explorer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MapHomePage(),
    );
  }
}

class MapHomePage extends StatefulWidget {
  const MapHomePage({super.key});

  @override
  State<MapHomePage> createState() => _MapHomePageState();
}

class _MapHomePageState extends State<MapHomePage> {
  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(31.2304, 121.4737), // 上海
    zoom: 11,
  );

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  MapboxMapController? _mapController;
  Timer? _debounce;
  List<MapSearchResult> _suggestions = <MapSearchResult>[];
  MapStyleOption _currentStyle = MapStyleOption.day;
  bool _isFetchingLocation = false;

  bool get _hasValidToken =>
      mapboxAccessToken.isNotEmpty &&
      !mapboxAccessToken.contains('YOUR_MAPBOX_ACCESS_TOKEN');

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onMapCreated(MapboxMapController controller) {
    _mapController = controller;
  }

  Future<void> _goToMyLocation() async {
    if (!_hasValidToken) {
      _showSnack('请先配置 Mapbox Access Token');
      return;
    }

    setState(() => _isFetchingLocation = true);
    try {
      final position = await _determinePosition();
      final target = LatLng(position.latitude, position.longitude);
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(target, 15),
      );
    } catch (error) {
      _showSnack(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
  }

  Future<Position> _determinePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('请开启系统定位服务');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('定位权限被拒绝，请到系统设置中授予权限');
    }

    return Geolocator.getCurrentPosition();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _suggestions = <MapSearchResult>[]);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () {
      _searchPlaces(value.trim());
    });
  }

  Future<void> _searchPlaces(String query) async {
    if (!_hasValidToken) {
      return;
    }

    try {
      final url = Uri.https(
        'api.mapbox.com',
        '/geocoding/v5/mapbox.places/$query.json',
        <String, String>{
          'access_token': mapboxAccessToken,
          'limit': '5',
          'language': 'zh',
          'autocomplete': 'true',
        },
      );

      final response = await http.get(url);
      if (response.statusCode != 200) {
        throw Exception('搜索失败：${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final features = (json['features'] as List<dynamic>? ?? <dynamic>[])
          .cast<Map<String, dynamic>>();
      final results = features
          .map(MapSearchResult.fromFeature)
          .whereType<MapSearchResult>()
          .toList();

      setState(() => _suggestions = results);
    } catch (error) {
      _showSnack('搜索出错：$error');
    }
  }

  Future<void> _flyToResult(MapSearchResult result) async {
    _searchController.text = result.title;
    _searchFocusNode.unfocus();
    setState(() => _suggestions = <MapSearchResult>[]);

    await _mapController?.clearSymbols();
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(result.location, 14),
    );
    await _mapController?.addSymbol(
      SymbolOptions(
        geometry: result.location,
        iconImage: 'marker-15',
        iconSize: 1.5,
        textField: result.title,
        textOffset: const Offset(0, 1.5),
      ),
    );
  }

  Future<void> _changeStyle(MapStyleOption option) async {
    if (_currentStyle == option) return;

    setState(() => _currentStyle = option);
    await _mapController?.setMapStyleUrlFuture(option.styleUri);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: MapboxMap(
              accessToken: mapboxAccessToken,
              onMapCreated: _onMapCreated,
              styleString: _currentStyle.styleUri,
              initialCameraPosition: _initialCameraPosition,
              myLocationEnabled: true,
              myLocationRenderMode: MyLocationRenderMode.GPS,
              myLocationTrackingMode: MyLocationTrackingMode.TrackingCompass,
              compassEnabled: true,
              rotateGesturesEnabled: true,
              tiltGesturesEnabled: true,
              zoomGesturesEnabled: true,
              minMaxZoomPreference: const MinMaxZoomPreference(3, 20),
            ),
          ),
          if (!_hasValidToken) _buildTokenWarning(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _SearchBar(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _onSearchChanged,
                    onClear: () {
                      _searchController.clear();
                      setState(() => _suggestions = <MapSearchResult>[]);
                    },
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _RoundIconButton(
                      icon: Icons.my_location,
                      tooltip: '定位到当前位置',
                      isLoading: _isFetchingLocation,
                      onPressed: _isFetchingLocation ? null : _goToMyLocation,
                    ),
                  ),
                  const Spacer(),
                  _StyleSelector(
                    current: _currentStyle,
                    onChanged: _changeStyle,
                  ),
                ],
              ),
            ),
          ),
          if (_suggestions.isNotEmpty)
            Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: _SearchResults(
                results: _suggestions,
                onTap: _flyToResult,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTokenWarning() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.red.shade600,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            '未检测到有效的 Mapbox Access Token，请在打包或运行时提供。',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

enum MapStyleOption { day, traffic, satellite }

extension on MapStyleOption {
  String get label {
    switch (this) {
      case MapStyleOption.day:
        return '标准';
      case MapStyleOption.traffic:
        return '探索';
      case MapStyleOption.satellite:
        return '卫星';
    }
  }

  String get styleUri {
    switch (this) {
      case MapStyleOption.day:
        return MapboxStyles.MAPBOX_STREETS;
      case MapStyleOption.traffic:
        return MapboxStyles.OUTDOORS;
      case MapStyleOption.satellite:
        return MapboxStyles.SATELLITE_STREETS;
    }
  }
}

class MapSearchResult {
  const MapSearchResult({
    required this.title,
    required this.location,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final LatLng location;

  static MapSearchResult? fromFeature(Map<String, dynamic> feature) {
    final center = feature['center'] as List<dynamic>? ?? <dynamic>[];
    if (center.length != 2) {
      return null;
    }

    return MapSearchResult(
      title: feature['text'] as String? ?? '未知地点',
      subtitle: feature['place_name'] as String?,
      location: LatLng(
        (center[1] as num).toDouble(),
        (center[0] as num).toDouble(),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(16),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          return TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: '搜索地点、地标或地址',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: value.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: onClear,
                    ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          );
        },
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.results,
    required this.onTap,
  });

  final List<MapSearchResult> results;
  final ValueChanged<MapSearchResult> onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        shrinkWrap: true,
        itemCount: results.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = results[index];
          return ListTile(
            title: Text(item.title),
            subtitle: item.subtitle != null ? Text(item.subtitle!) : null,
            onTap: () => onTap(item),
          );
        },
      ),
    );
  }
}

class _StyleSelector extends StatelessWidget {
  const _StyleSelector({
    required this.current,
    required this.onChanged,
  });

  final MapStyleOption current;
  final ValueChanged<MapStyleOption> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              blurRadius: 12,
              color: Colors.black12,
            )
          ],
        ),
        child: Wrap(
          spacing: 12,
          children: MapStyleOption.values
              .map(
                (style) => ChoiceChip(
                  label: Text(style.label),
                  selected: current == style,
                  onSelected: (_) => onChanged(style),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    this.tooltip,
    this.onPressed,
    this.isLoading = false,
  });

  final IconData icon;
  final String? tooltip;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final button = FloatingActionButton(
      heroTag: tooltip,
      mini: true,
      onPressed: onPressed,
      child: isLoading
          ? const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }

    return button;
  }
}
