import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/theme/app_theme.dart';
import '../home/home_screen.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  bool _isChecking = true;
  bool _hasInternet = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkInternetConnection();
  }

  Future<void> _checkInternetConnection() async {
    setState(() {
      _isChecking = true;
      _errorMessage = '';
    });

    try {
      // First check if we have any network interface
      final connectivityResult = await Connectivity().checkConnectivity();
      debugPrint('[Startup] Connectivity result: $connectivityResult');

      // Handle both old API (single result) and new API (list of results)
      final bool hasNoConnection;
      if (connectivityResult is List) {
        hasNoConnection = (connectivityResult as List).contains(ConnectivityResult.none) ||
            (connectivityResult as List).isEmpty;
      } else {
        hasNoConnection = connectivityResult == ConnectivityResult.none;
      }

      if (hasNoConnection) {
        setState(() {
          _isChecking = false;
          _hasInternet = false;
          _errorMessage = 'No network connection.\nPlease connect to WiFi or mobile data.';
        });
        return;
      }

      // Now verify actual internet access by trying to reach a server
      final hasInternet = await _verifyInternetAccess();

      if (hasInternet) {
        setState(() {
          _isChecking = false;
          _hasInternet = true;
        });
        // Navigate to home screen
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      } else {
        setState(() {
          _isChecking = false;
          _hasInternet = false;
          _errorMessage = 'Unable to connect to the internet.\nPlease check your connection.';
        });
      }
    } catch (e) {
      debugPrint('[Startup] Error checking connectivity: $e');
      setState(() {
        _isChecking = false;
        _hasInternet = false;
        _errorMessage = 'Connection check failed.\nPlease try again.';
      });
    }
  }

  Future<bool> _verifyInternetAccess() async {
    try {
      // Try to resolve youtube.com since that's what we need
      final result = await InternetAddress.lookup('youtube.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      debugPrint('[Startup] DNS lookup failed: $e');
      // Try Google as fallback
      try {
        final result = await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 5));
        return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } catch (e) {
        debugPrint('[Startup] Fallback DNS lookup also failed: $e');
        return false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo/title
              const Icon(
                Icons.music_note,
                size: 80,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              const Text(
                'Aux',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 48),

              if (_isChecking) ...[
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 24),
                const Text(
                  'Checking internet connection...',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
              ] else if (!_hasInternet) ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.wifi_off,
                        size: 64,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No Internet Connection',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _checkInternetConnection,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
