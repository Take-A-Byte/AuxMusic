import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../host/host_setup_screen.dart';
import '../guest/guest_connect_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Logo and Title
              _buildHeader(),
              const Spacer(flex: 2),
              // Mode Selection Cards
              _buildModeCard(
                context,
                icon: Icons.speaker_group,
                title: 'Host a Party',
                subtitle: 'Connect to speaker and let friends control the music',
                onTap: () => _navigateToHost(context),
                isPrimary: true,
              ),
              const SizedBox(height: 16),
              _buildModeCard(
                context,
                icon: Icons.phone_android,
                title: 'Join a Party',
                subtitle: 'Scan QR code to add songs and control playback',
                onTap: () => _navigateToGuest(context),
                isPrimary: false,
              ),
              const Spacer(flex: 3),
              // Footer
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(
            Icons.music_note,
            size: 56,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Aux',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Share the aux with friends',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildModeCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return Material(
      color: isPrimary ? AppColors.primary : AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isPrimary ? Colors.white.withOpacity(0.2) : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 18,
                color: Colors.white.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Text(
      'No accounts • No ads • Just music',
      style: TextStyle(
        fontSize: 12,
        color: Colors.white.withOpacity(0.4),
      ),
    );
  }

  void _navigateToHost(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HostSetupScreen()),
    );
  }

  void _navigateToGuest(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GuestConnectScreen()),
    );
  }
}
