import 'package:CryptoChat/global/environment.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CDNService {
  static const String _cdnUrlCacheKey = 'cdn_base_url';
  static String? _cachedCdnUrl;

  /// Get CDN URL for a file path
  /// Falls back to local URL if CDN is not configured
  static Future<String> getCdnUrl(String filePath) async {
    // Remove leading slash if present
    if (filePath.startsWith('/')) {
      filePath = filePath.substring(1);
    }

    // Try to get CDN base URL from cache or environment
    String? cdnBaseUrl = _cachedCdnUrl;
    if (cdnBaseUrl == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        cdnBaseUrl = prefs.getString(_cdnUrlCacheKey);
        _cachedCdnUrl = cdnBaseUrl;
      } catch (e) {
        print('CDNService: Error reading CDN URL from cache: $e');
      }
    }

    // If CDN is configured, use it
    if (cdnBaseUrl != null && cdnBaseUrl.isNotEmpty) {
      // Ensure CDN URL doesn't have trailing slash
      if (cdnBaseUrl.endsWith('/')) {
        cdnBaseUrl = cdnBaseUrl.substring(0, cdnBaseUrl.length - 1);
      }
      return '$cdnBaseUrl/$filePath';
    }

    // Fallback to local server URL
    return '${Environment.urlArchivos}$filePath';
  }

  /// Cache CDN base URL
  static Future<void> cacheCdnUrl(String cdnBaseUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cdnUrlCacheKey, cdnBaseUrl);
      _cachedCdnUrl = cdnBaseUrl;
    } catch (e) {
      print('CDNService: Error caching CDN URL: $e');
    }
  }

  /// Get CDN URL from server (if available)
  static Future<String?> fetchCdnUrlFromServer(String filePath) async {
    try {
      // This would call an API endpoint to get CDN URL
      // For now, return null to use fallback
      return null;
    } catch (e) {
      print('CDNService: Error fetching CDN URL from server: $e');
      return null;
    }
  }

  /// Clear cached CDN URL
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cdnUrlCacheKey);
      _cachedCdnUrl = null;
    } catch (e) {
      print('CDNService: Error clearing CDN cache: $e');
    }
  }
}





