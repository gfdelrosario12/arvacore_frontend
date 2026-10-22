import 'package:flutter/material.dart';

/// ArvaLink Design System — Aqua Blue × Cyan × Smart Irrigation
class AppColors {
  AppColors._();

  // ─── Brand ───────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF00B4D8);
  static const Color secondary = accent;
  static const Color primaryDark = Color(0xFF0077B6);
  static const Color primaryLight = Color(0xFF90E0EF);
  static const Color accent = Color(0xFF48CAE4);

  // ─── Dark Theme ──────────────────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF071A2B);
  static const Color darkSurface = Color(0xFF102A43);
  static const Color darkSurfaceLight = Color(0xFF1E3A56);
  static const Color darkBorder = Color(0xFF2A4A6B);
  static const Color darkTextPrimary = Color(0xFFF8F9FA);
  static const Color darkTextSecondary = Color(0xFFADB5BD);
  static const Color darkTextMuted = Color(0xFF6C757D);

  // ─── Light Theme ─────────────────────────────────────────────────────────
  static const Color lightBackground = Color(0xFFF4F7F6);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceLight = Color(0xFFE9ECEF);
  static const Color lightBorder = Color(0xFFDEE2E6);
  static const Color lightTextPrimary = Color(0xFF1D2D44);
  static const Color lightTextSecondary = Color(0xFF495057);
  static const Color lightTextMuted = Color(0xFF8D99AE);

  // ─── Zone / Soil ─────────────────────────────────────────────────────────
  static const Color zoneOptimal = Color(0xFF10B981);
  static const Color zoneLow = Color(0xFFF59E0B);
  static const Color zoneCritical = Color(0xFFEF4444);
  static const Color zoneOffline = Color(0xFF6B7280);

  // ─── Irrigation ──────────────────────────────────────────────────────────
  static const Color irrigationSafe = Color(0xFF06B6D4);
  static const Color irrigationRefluxNeeded = Color(0xFFF97316);
  static const Color irrigationFlooded = Color(0xFF3B82F6);

  // ─── Pump / Valve ────────────────────────────────────────────────────────
  static const Color pumpActive = Color(0xFF14B8A6);
  static const Color pumpIdle = Color(0xFF64748B);
  static const Color valveOpen = Color(0xFF2563EB);
  static const Color valveClosed = Color(0xFF475569);

  // ─── Device ──────────────────────────────────────────────────────────────
  static const Color deviceBatteryGood = Color(0xFF22C55E);
  static const Color deviceBatteryLow = Color(0xFFEAB308);
  static const Color deviceLoRaConnected = Color(0xFF6366F1);
  static const Color deviceLoRaWeak = Color(0xFFEC4899);

  // ─── Alerts ──────────────────────────────────────────────────────────────
  static const Color alertInfo = Color(0xFF3B82F6);
  static const Color alertSuccess = Color(0xFF10B981);
  static const Color alertWarning = Color(0xFFF59E0B);
  static const Color alertError = Color(0xFFEF4444);
}
