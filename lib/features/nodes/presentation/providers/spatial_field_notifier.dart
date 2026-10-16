import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../../domain/models/models.dart';

class SpatialFieldStateData {
  final double fieldWidthMeters;
  final double fieldHeightMeters;
  final String? selectedNodeId;
  final String? hoveredNodeId;
  final bool showGridLines;
  final bool showCoordinates;
  final double zoomScale;

  const SpatialFieldStateData({
    this.fieldWidthMeters = 100.0,
    this.fieldHeightMeters = 100.0,
    this.selectedNodeId,
    this.hoveredNodeId,
    this.showGridLines = true,
    this.showCoordinates = true,
    this.zoomScale = 1.0,
  });

  SpatialFieldStateData copyWith({
    double? fieldWidthMeters,
    double? fieldHeightMeters,
    String? selectedNodeId,
    bool clearSelectedNode = false,
    String? hoveredNodeId,
    bool clearHoveredNode = false,
    bool? showGridLines,
    bool? showCoordinates,
    double? zoomScale,
  }) {
    return SpatialFieldStateData(
      fieldWidthMeters: fieldWidthMeters ?? this.fieldWidthMeters,
      fieldHeightMeters: fieldHeightMeters ?? this.fieldHeightMeters,
      selectedNodeId:
          clearSelectedNode ? null : (selectedNodeId ?? this.selectedNodeId),
      hoveredNodeId:
          clearHoveredNode ? null : (hoveredNodeId ?? this.hoveredNodeId),
      showGridLines: showGridLines ?? this.showGridLines,
      showCoordinates: showCoordinates ?? this.showCoordinates,
      zoomScale: zoomScale ?? this.zoomScale,
    );
  }
}

class SpatialFieldNotifier extends ChangeNotifier {
  SpatialFieldStateData _state;

  SpatialFieldNotifier({SpatialFieldStateData? initialState})
      : _state = initialState ?? const SpatialFieldStateData();

  SpatialFieldStateData get state => _state;

  void selectNode(String? nodeId) {
    if (nodeId == null) {
      _state = _state.copyWith(clearSelectedNode: true);
    } else {
      _state = _state.copyWith(selectedNodeId: nodeId);
    }
    notifyListeners();
  }

  void hoverNode(String? nodeId) {
    if (nodeId == null) {
      _state = _state.copyWith(clearHoveredNode: true);
    } else {
      _state = _state.copyWith(hoveredNodeId: nodeId);
    }
    notifyListeners();
  }

  /// Updates selection and hover references when a node is replaced.
  void handleNodeReplaced(String oldNodeId, String newNodeId) {
    var changed = false;
    var nextSelected = _state.selectedNodeId;
    var nextHovered = _state.hoveredNodeId;

    if (_state.selectedNodeId == oldNodeId) {
      nextSelected = newNodeId;
      changed = true;
    }
    if (_state.hoveredNodeId == oldNodeId) {
      nextHovered = newNodeId;
      changed = true;
    }
    if (changed) {
      _state = _state.copyWith(
        selectedNodeId: nextSelected,
        hoveredNodeId: nextHovered,
      );
      notifyListeners();
    }
  }

  void toggleGridLines() {
    _state = _state.copyWith(showGridLines: !_state.showGridLines);
    notifyListeners();
  }

  void toggleCoordinates() {
    _state = _state.copyWith(showCoordinates: !_state.showCoordinates);
    notifyListeners();
  }

  void setZoomScale(double scale) {
    _state = _state.copyWith(zoomScale: scale.clamp(0.5, 3.0));
    notifyListeners();
  }

  void updateFieldDimensions({required double width, required double height}) {
    _state = _state.copyWith(
      fieldWidthMeters: math.max(10.0, width),
      fieldHeightMeters: math.max(10.0, height),
    );
    notifyListeners();
  }

  /// Calculates normalized position (0.0 to 1.0) on the canvas for a node
  math.Point<double>? getNormalizedPosition(
    Esp32Node node, {
    List<Esp32Node> allNodes = const [],
  }) {
    final coords = node.coordinates;
    if (coords == null || (!coords.hasLocalCoordinates && !coords.hasGeoCoordinates)) {
      int zoneIdx = 1;
      if (node.assignedZoneId != null) {
        zoneIdx = int.tryParse(node.assignedZoneId!.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
      }
      final qX = (zoneIdx - 1) % 2 == 0 ? 0.3 : 0.7;
      final qY = ((zoneIdx - 1) ~/ 2) % 2 == 0 ? 0.3 : 0.7;
      return math.Point(qX, qY);
    }

    // 1. Prefer local Cartesian meters if available
    if (coords.hasLocalCoordinates) {
      final normX = (coords.localX! / _state.fieldWidthMeters).clamp(0.05, 0.95);
      // Invert Y so 0,0 is bottom-left
      final normY = (1.0 - (coords.localY! / _state.fieldHeightMeters)).clamp(0.05, 0.95);
      return math.Point(normX, normY);
    }

    // 2. Fall back to normalized GPS latitude & longitude among all nodes
    if (coords.hasGeoCoordinates) {
      final geoNodes = allNodes.where((n) => n.coordinates?.hasGeoCoordinates == true).toList();
      if (geoNodes.length < 2) {
        return const math.Point(0.5, 0.5);
      }

      var minLat = double.infinity;
      var maxLat = -double.infinity;
      var minLng = double.infinity;
      var maxLng = -double.infinity;

      for (final n in geoNodes) {
        final c = n.coordinates!;
        if (c.latitude! < minLat) minLat = c.latitude!;
        if (c.latitude! > maxLat) maxLat = c.latitude!;
        if (c.longitude! < minLng) minLng = c.longitude!;
        if (c.longitude! > maxLng) maxLng = c.longitude!;
      }

      final latSpan = (maxLat - minLat).abs();
      final lngSpan = (maxLng - minLng).abs();

      final normX = lngSpan > 0.00001
          ? 0.1 + 0.8 * ((coords.longitude! - minLng) / lngSpan)
          : 0.5;
      // Invert latitude so North is top
      final normY = latSpan > 0.00001
          ? 0.1 + 0.8 * (1.0 - ((coords.latitude! - minLat) / latSpan))
          : 0.5;

      return math.Point(normX.clamp(0.05, 0.95), normY.clamp(0.05, 0.95));
    }

    return null;
  }
}

