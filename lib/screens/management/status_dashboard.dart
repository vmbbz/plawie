import 'package:flutter/material.dart';

class StatusDashboard extends StatelessWidget {
  const StatusDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('System Status')),
      body: const Center(child: Text('Detailed Health & Usage Metrics Coming Soon')),
    );
  }
}
