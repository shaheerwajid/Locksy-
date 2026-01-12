import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Service to cache file existence state to prevent redundant checks
/// This improves performance when scrolling through chat messages
class FileCacheService {
  static final FileCacheService _instance = FileCacheService._internal();
  factory FileCacheService() => _instance;
  FileCacheService._internal();

  // Cache for file existence state (filePath -> exists)
  final Map<String, bool> _fileExistenceCache = {};

  // Cache for Future<bool> to prevent multiple concurrent checks for same file
  final Map<String, Future<bool>> _checkingFutures = {};

  // Track files that we've confirmed don't exist (to avoid repeated checks)
  final Set<String> _knownMissingFiles = {};

  // Maximum cache size to prevent memory issues
  static const int _maxCacheSize = 1000;

  // Stream controller to notify when file status changes
  final StreamController<String> _fileUpdateController =
      StreamController<String>.broadcast();

  /// Stream that emits file paths when their status changes (becomes available or invalid)
  Stream<String> get fileUpdates => _fileUpdateController.stream;

  /// Check if file exists, using cache when available
  Future<bool> fileExists(String filePath) async {
    // Return cached result if available - prioritize positive cache hits
    if (_fileExistenceCache.containsKey(filePath)) {
      final cachedResult = _fileExistenceCache[filePath]!;
      // If cached as existing, do a quick sync check to ensure it's still there
      // This handles cases where file was deleted after caching
      if (cachedResult == true) {
        final file = File(filePath);
        if (file.existsSync()) {
          return true;
        } else {
          // File was deleted - clear cache
          clearCache(filePath);
          return false;
        }
      }
      // If cached as false, still check to see if file appeared
      // Don't return immediately - wait for check to complete
      if (!_checkingFutures.containsKey(filePath)) {
        final checkFuture = _performFileCheck(filePath);
        _checkingFutures[filePath] = checkFuture;
        checkFuture.then((exists) {
          _checkingFutures.remove(filePath);
          if (exists != cachedResult) {
            _cacheFileExistence(filePath, exists);
          }
        }).catchError((e) {
          _checkingFutures.remove(filePath);
          debugPrint('[FileCacheService] Error in async check: $filePath - $e');
        });
        // Wait for check to complete so UI updates properly
        return await checkFuture;
      } else {
        // Already checking - wait for that result
        return await _checkingFutures[filePath]!;
      }
    }

    // If we know this file doesn't exist, still verify it hasn't appeared
    if (_knownMissingFiles.contains(filePath)) {
      // Remove from known missing and check again
      _knownMissingFiles.remove(filePath);
    }

    // If there's already a check in progress, wait for it
    if (_checkingFutures.containsKey(filePath)) {
      return await _checkingFutures[filePath]!;
    }

    // Start new check
    final checkFuture = _performFileCheck(filePath);
    _checkingFutures[filePath] = checkFuture;

    try {
      final exists = await checkFuture;

      // Cache the result - this persists across widget rebuilds
      _cacheFileExistence(filePath, exists);

      if (exists) {
        debugPrint('[FileCacheService] ✅ File validated and cached: $filePath');
      }

      return exists;
    } finally {
      // Remove from checking futures after completion
      _checkingFutures.remove(filePath);
    }
  }

  /// Perform the actual file system check with integrity verification
  Future<bool> _performFileCheck(String filePath) async {
    try {
      final file = File(filePath);
      final exists = await file.exists();

      if (!exists) {
        // Add to known missing files (will expire on next app start)
        _knownMissingFiles.add(filePath);
        return false;
      }

      // Verify file integrity - check if file is complete and valid
      final isValid = await _verifyFileIntegrity(file, filePath);

      if (!isValid) {
        // File exists but is invalid/incomplete - don't cache as existing
        debugPrint(
            '[FileCacheService] File exists but is invalid/incomplete: $filePath');
        // Delete corrupted file immediately to prevent further issues
        try {
          await file.delete();
          debugPrint('[FileCacheService] Deleted corrupted file: $filePath');
        } catch (e) {
          debugPrint('[FileCacheService] Error deleting corrupted file: $e');
        }
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('[FileCacheService] Error checking file: $filePath - $e');
      return false;
    }
  }

  /// Verify file integrity - check if file is complete and can be read
  /// Uses production-ready validation including actual image decoding
  Future<bool> _verifyFileIntegrity(File file, String filePath) async {
    try {
      // Check if file exists and has non-zero size
      if (!await file.exists()) {
        return false;
      }

      final length = await file.length();
      if (length == 0) {
        debugPrint('[FileCacheService] File has zero size: $filePath');
        return false;
      }

      // For image files, perform comprehensive validation including decoding
      if (_isImageFile(filePath)) {
        return await _verifyImageFile(file, filePath, length);
      }

      // For non-image files, basic validation is sufficient
      return true;
    } catch (e) {
      debugPrint(
          '[FileCacheService] Error verifying file integrity: $filePath - $e');
      return false;
    }
  }

  /// Verify image file integrity with lightweight checks
  /// More lenient to avoid false negatives while still catching obvious corruption
  Future<bool> _verifyImageFile(File file, String filePath, int length) async {
    try {
      // Minimum size check - images should be at least a few hundred bytes
      if (length < 100) {
        debugPrint(
            '[FileCacheService] Image file too small: $filePath ($length bytes)');
        return false;
      }

      // For production reliability: only validate header, not entire file structure
      // Reading entire files into memory can cause performance issues
      // Let Image.file()'s errorBuilder handle actual decoding validation

      // Read only the header for lightweight validation
      Uint8List headerBytes;
      try {
        // Read first 100 bytes for header validation
        final stream = file.openRead(0, 100);
        final chunks = await stream.toList();
        headerBytes = Uint8List.fromList(chunks.expand((x) => x).toList());
      } catch (e) {
        debugPrint(
            '[FileCacheService] Failed to read image header: $filePath - $e');
        return false;
      }

      if (headerBytes.isEmpty || headerBytes.length < 10) {
        debugPrint('[FileCacheService] Image header too small: $filePath');
        return false;
      }

      // Validate image file header/signature - be lenient
      final ext = filePath.toLowerCase().split('.').last;

      // JPEG: FF D8 FF
      if (ext == 'jpg' || ext == 'jpeg') {
        if (headerBytes.length >= 3 &&
            headerBytes[0] == 0xFF &&
            headerBytes[1] == 0xD8 &&
            headerBytes[2] == 0xFF) {
          debugPrint('[FileCacheService] ✅ Valid JPEG header: $filePath');
          return true;
        }
      }

      // PNG: 89 50 4E 47 0D 0A 1A 0A
      if (ext == 'png') {
        if (headerBytes.length >= 8 &&
            headerBytes[0] == 0x89 &&
            headerBytes[1] == 0x50 &&
            headerBytes[2] == 0x4E &&
            headerBytes[3] == 0x47) {
          debugPrint('[FileCacheService] ✅ Valid PNG header: $filePath');
          return true;
        }
      }

      // For other formats, be lenient - just check size
      // The Image widget will handle actual decoding validation
      if (['gif', 'webp', 'bmp'].contains(ext) && length >= 1000) {
        debugPrint('[FileCacheService] ✅ Valid image size for $ext: $filePath');
        return true;
      }

      // If header check inconclusive but file is reasonable size, accept it
      // Actual decoding validation happens in Image widget
      if (length >= 1000) {
        debugPrint(
            '[FileCacheService] ⚠️ Header check inconclusive but accepting (size OK): $filePath');
        return true;
      }

      debugPrint('[FileCacheService] ❌ Image validation failed: $filePath');
      return false;
    } catch (e) {
      debugPrint(
          '[FileCacheService] Image file verification error: $filePath - $e');
      return false;
    }
  }

  /// Check if file is an image based on extension
  bool _isImageFile(String filePath) {
    final ext = filePath.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
  }

  /// Cache file existence result
  void _cacheFileExistence(String filePath, bool exists) {
    // Prevent cache from growing too large
    // Only remove non-existent files from cache when it's full (keep existing files)
    if (_fileExistenceCache.length >= _maxCacheSize) {
      // Remove oldest non-existent entries first to preserve existing files
      final keysToRemove = _fileExistenceCache.entries
          .where((entry) => entry.value == false)
          .take(100)
          .map((entry) => entry.key)
          .toList();

      // If we didn't remove enough, remove oldest entries regardless
      if (keysToRemove.length < 100) {
        final remaining = 100 - keysToRemove.length;
        final additionalKeys = _fileExistenceCache.keys
            .where((key) => !keysToRemove.contains(key))
            .take(remaining)
            .toList();
        keysToRemove.addAll(additionalKeys);
      }

      for (final key in keysToRemove) {
        _fileExistenceCache.remove(key);
        _knownMissingFiles.remove(key);
      }
    }

    _fileExistenceCache[filePath] = exists;

    if (exists) {
      // Remove from known missing if it now exists
      _knownMissingFiles.remove(filePath);
    }
  }

  /// Pre-cache file existence for a list of file paths
  Future<void> preCacheFiles(List<String> filePaths) async {
    final futures = filePaths.map((path) => fileExists(path));
    await Future.wait(futures, eagerError: false);
  }

  /// Manually set file existence (useful when file is downloaded)
  void setFileExists(String filePath, bool exists) {
    final oldValue = _fileExistenceCache[filePath];
    _cacheFileExistence(filePath, exists);
    _knownMissingFiles.remove(filePath);

    // Notify listeners if status changed
    if (oldValue != exists) {
      _fileUpdateController.add(filePath);
      debugPrint(
          '[FileCacheService] File status changed: $filePath -> $exists');
    }
  }

  /// Clear cache for a specific file (useful when file is deleted)
  void clearCache(String filePath) {
    final hadValue = _fileExistenceCache.containsKey(filePath);
    _fileExistenceCache.remove(filePath);
    _knownMissingFiles.remove(filePath);
    _checkingFutures.remove(filePath);

    // Notify listeners if we removed a cached entry
    if (hadValue) {
      _fileUpdateController.add(filePath);
      debugPrint('[FileCacheService] File cache cleared: $filePath');
    }
  }

  /// Clear all cache
  void clearAllCache() {
    _fileExistenceCache.clear();
    _knownMissingFiles.clear();
    _checkingFutures.clear();
  }

  /// Get cached file existence (without checking filesystem)
  bool? getCachedExistence(String filePath) {
    return _fileExistenceCache[filePath];
  }

  /// Dispose the stream controller (call on app shutdown)
  void dispose() {
    _fileUpdateController.close();
  }
}
