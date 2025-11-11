import 'package:flutter/material.dart';

class BalesukApp extends StatelessWidget {
  const BalesukApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Balesuk POS',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Balesuk POS'),
        ),
        body: const Center(
          child: Text('Welcome to Balesuk POS!'),
        ),
      ),
    );
  }
}
