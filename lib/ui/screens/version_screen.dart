import 'package:flutter/material.dart';
import 'package:ten_of_a_kind_poker/ui/theme/colors.dart';

class VersionScreen extends StatelessWidget {
  const VersionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        title: const Text('Choose Version', style: TextStyle(color: AppColors.white)),
        iconTheme: const IconThemeData(color: AppColors.white),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _VersionButton(
                label: 'India',
                color: AppColors.red,
                onTap: () {
                  // TODO: save selection if needed
                  Navigator.pushReplacementNamed(context, '/home');
                },
              ),
              const SizedBox(height: 20),
              _VersionButton(
                label: 'International',
                color: AppColors.blue,
                onTap: () {
                  // TODO: save selection if needed
                  Navigator.pushReplacementNamed(context, '/home');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VersionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _VersionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
