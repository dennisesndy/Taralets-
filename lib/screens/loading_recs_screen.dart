import 'package:flutter/material.dart';
import 'group_recs_screen.dart';

class LoadingRecsScreen extends StatefulWidget {
  final String tripId;

  const LoadingRecsScreen({super.key, required this.tripId});

  @override
  State<LoadingRecsScreen> createState() => _LoadingRecsScreenState();
}

class _LoadingRecsScreenState extends State<LoadingRecsScreen> {
  @override
  void initState() {
    super.initState();
    _fetchRecommendations();
  }

  Future<void> _fetchRecommendations() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => GroupRecsScreen(tripId: widget.tripId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(strokeWidth: 3.5),
              ),
              SizedBox(height: 28),
              Text(
                'Analyzing Group Harmony...',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text(
                'Balancing preferences, operating hours, and travel distance across all trip members.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}