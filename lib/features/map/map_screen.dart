import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../balloon/balloon_cubit.dart';
import '../balloon/balloon_model.dart';
import '../balloon/create_balloon_sheet.dart';
import '../balloon/balloon_content_sheet.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BalloonCubit(),
      child: const _MapScreenContent(),
    );
  }
}

class _MapScreenContent extends StatefulWidget {
  const _MapScreenContent();

  @override
  State<_MapScreenContent> createState() => _MapScreenContentState();
}

class _MapScreenContentState extends State<_MapScreenContent> {
  MapboxMap? _mapboxMap;
  CircleAnnotationManager? _circleAnnotationManager;
  final Map<String, String> _annotationToBalloonId = {};
  final Map<String, CircleAnnotation> _balloonIdToAnnotation = {};

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    await Permission.locationWhenInUse.request();
    await Permission.microphone.request();
  }

  _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _circleAnnotationManager = await mapboxMap.annotations.createCircleAnnotationManager();
    _circleAnnotationManager?.tapEvents(onTap: (annotation) {
      final balloonId = _annotationToBalloonId[annotation.id];
      if (balloonId != null && mounted) {
        final state = context.read<BalloonCubit>().state;
        try {
          final balloon = state.balloons.firstWhere((b) => b.id == balloonId);
          showCupertinoModalPopup(
            context: context,
            builder: (ctx) => BalloonContentSheet(balloon: balloon),
          );
        } catch (_) {}
      }
    });
    _customizeMapStyle();
  }

  Future<void> _customizeMapStyle() async {
    if (_mapboxMap != null) {
      // Outdoors 插画风格，尽量简化
      await _mapboxMap?.loadStyleURI('mapbox://styles/mapbox/outdoors-v12');
      
      // 隐藏大量图层，只保留 land/water/landcover 等基础色块
      final layersToHide = [
        'poi-label', 'road-label', 'road-label-simple', 'road-number-shield',
        'road-exit-shield', 'transit-label', 'airport-label',
        'poi-scalerank1', 'poi-scalerank2', 'poi-scalerank3',
        'building', 'building-extrusion', 'building-underground',
        'place-city-label-major', 'place-city-label-minor', 'place-town-label',
        'place-village-label', 'place-suburb-label', 'place-neighborhood-label',
        'place-hamlet-label', 'waterway-label', 'natural-point-label',
        'natural-line-label', 'water-point-label', 'water-line-label',
        'bridge-label', 'tunnel-label', 'admin-0-boundary', 'admin-1-boundary',
        'admin-2-boundary',
        'contour-line', 'hillshade', 'national-park_tint-band',
        'waterway-shadow', 'water-shadow', 'water-depth', 'wetland-pattern',
        'land-structure-polygon', 'land-structure-line',
        'aeroway-polygon', 'aeroway-line', 'pitch-outline',
        'ferry', 'ferry-auto', 'cliff',
        'road-pedestrian-polygon-fill', 'road-pedestrian-polygon-pattern',
        'road-path-bg', 'road-steps-bg', 'road-pedestrian-case', 'road-path-trail',
        'road-path-cycleway-piste', 'road-path', 'road-steps', 'road-pedestrian',
        'road-minor-case', 'road-minor', 'road-street-case', 'road-street',
        'road-secondary-tertiary-case', 'road-secondary-tertiary',
        'road-primary-case', 'road-primary', 'road-motorway-trunk-case',
        'road-motorway-trunk', 'road-construction',
      ];

      for (final layerId in layersToHide) {
        try {
          if (await _mapboxMap?.style.styleLayerExists(layerId) ?? false) {
             await _mapboxMap?.style.setStyleLayerProperty(layerId, 'visibility', 'none');
          }
        } catch (_) {}
      }

      await _mapboxMap?.location.updateSettings(
        LocationComponentSettings(
          enabled: false, // 隐藏定位蓝点
          pulsingEnabled: false,
          showAccuracyRing: false,
          pulsingColor: 0xFF007AFF,
        ),
      );
      await _mapboxMap?.compass.updateSettings(CompassSettings(enabled: false));
      await _mapboxMap?.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
      await _mapboxMap?.logo.updateSettings(LogoSettings(enabled: false));
      await _mapboxMap?.attribution.updateSettings(AttributionSettings(enabled: false));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<BalloonCubit, BalloonState>(
        listener: (context, state) {
          _updateMarkers(state.balloons);
        },
        child: CupertinoPageScaffold(
          child: Stack(
            fit: StackFit.expand,
            children: [
              MapWidget(
                onMapCreated: _onMapCreated,
                styleUri: 'mapbox://styles/mapbox/outdoors-v12',
                cameraOptions: CameraOptions(
                  center: Point(coordinates: Position(116.397, 39.909)),
                  zoom: 11.0,
                ),
              ),
              _buildTopOverlay(),
              _buildFloatingButtons(context),
            ],
          ),
        ),
      );
  }

  Widget _buildTopOverlay() {
    final topPadding = MediaQuery.of(context).padding.top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: SizedBox(
          height: topPadding,
          child: Platform.isIOS
              ? UiKitView(
                  viewType: 'BlurOverlay',
                  layoutDirection: TextDirection.ltr,
                )
              : ClipRect(
                  clipBehavior: Clip.hardEdge,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      height: topPadding,
                      decoration: BoxDecoration(
                        color: CupertinoColors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildFloatingButtons(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Positioned(
      right: 16,
      bottom: bottomPadding + 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildFloatingButton(
            icon: CupertinoIcons.location_fill,
            onPressed: () => _animateToUserLocation(),
          ),
          const SizedBox(height: 12),
          _buildFloatingButton(
            icon: CupertinoIcons.add,
            onPressed: () => _showCreateBalloonSheet(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
          child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: CupertinoColors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, size: 22, color: CupertinoColors.activeBlue),
          ),
        ),
      ),
    );
  }

  Future<void> _animateToUserLocation() async {
    geo.Position? position;
    try {
      position = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(accuracy: geo.LocationAccuracy.medium),
      );
    } catch (_) {}
    if (position != null && _mapboxMap != null) {
      await _mapboxMap?.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(position.longitude, position.latitude)),
          zoom: 15.0,
        ),
        MapAnimationOptions(duration: 800, startDelay: 0),
      );
    }
  }

  void _showCreateBalloonSheet(BuildContext context) async {
    geo.Position? position;
    try {
      position = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(accuracy: geo.LocationAccuracy.medium),
      );
    } catch (_) {}

    final double lat = position?.latitude ?? 39.909;
    final double lng = position?.longitude ?? 116.397;

    if (!context.mounted) return;

    final cubit = context.read<BalloonCubit>();

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CreateBalloonSheet(
        latitude: lat,
        longitude: lng,
        onRelease: (balloon) {
          cubit.addBalloon(balloon);
        },
      ),
    );
  }

  Future<void> _updateMarkers(List<BalloonModel> balloons) async {
    if (_circleAnnotationManager == null) return;

    // 1. Identify which balloons need to be added, updated, or removed
    final incomingIds = balloons.map((b) => b.id).toSet();
    final existingIds = _balloonIdToAnnotation.keys.toSet();

    final toAdd = incomingIds.difference(existingIds);
    final toRemove = existingIds.difference(incomingIds);
    final toUpdate = incomingIds.intersection(existingIds);

    // 2. Remove old balloons
    if (toRemove.isNotEmpty) {
      final annotationsToRemove = <CircleAnnotation>[];
      for (final id in toRemove) {
        final annotation = _balloonIdToAnnotation[id];
        if (annotation != null) {
          annotationsToRemove.add(annotation);
          _annotationToBalloonId.remove(annotation.id);
        }
        _balloonIdToAnnotation.remove(id);
      }
      for (final annotation in annotationsToRemove) {
        await _circleAnnotationManager?.delete(annotation);
      }
    }

    // 3. Add new balloons
    for (final id in toAdd) {
      final balloon = balloons.firstWhere((b) => b.id == id);
      final annotation = await _circleAnnotationManager?.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(balloon.longitude, balloon.latitude)),
          circleColor: 0xFFFF3B30,
          circleRadius: 14.0,
          circleStrokeWidth: 0.0,
          circleOpacity: 0.9,
          circleBlur: 0.1,
        ),
      );
      if (annotation != null) {
        _balloonIdToAnnotation[id] = annotation;
        _annotationToBalloonId[annotation.id] = id;
      }
    }

    // 4. Update existing balloons (move them)
    for (final id in toUpdate) {
      final balloon = balloons.firstWhere((b) => b.id == id);
      final annotation = _balloonIdToAnnotation[id];
      if (annotation != null) {
        annotation.geometry = Point(coordinates: Position(balloon.longitude, balloon.latitude));
        await _circleAnnotationManager?.update(annotation);
      }
    }
  }
}
