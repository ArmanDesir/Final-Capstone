import 'package:flutter/material.dart';

class BasicOperationsDashboard extends StatelessWidget {
  const BasicOperationsDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Basic Operations'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildOperationButton(
              context,
              'Addition',
              Icons.add,
              Colors.lightBlue,
              '/addition',
            ),
            const SizedBox(height: 16),
            _buildOperationButton(
              context,
              'Subtraction',
              Icons.remove,
              Colors.redAccent,
              '/subtraction',
            ),
            const SizedBox(height: 16),
            _buildOperationButton(
              context,
              'Multiplication',
              Icons.close,
              Colors.green,
              '/multiplication',
            ),
            const SizedBox(height: 16),
            _buildOperationButton(
              context,
              'Division',
              Icons.percent,
              Colors.purple,
              '/division',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOperationButton(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    String routeName,
  ) {
    return ElevatedButton.icon(
      icon: Icon(icon),
      label: Text(title),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: () => Navigator.pushNamed(context, routeName),
    );
  }
}
