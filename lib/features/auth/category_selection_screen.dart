import 'package:flutter/material.dart';

class CategorySelectionScreen extends StatelessWidget {
  const CategorySelectionScreen({super.key});

  final List<String> categories = const [
    'boutique',
    'pharmacy',
    'hardware',
    'beauty',
    'liquor',
    'bookshop',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select your business type')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.5,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: categories.length,
        itemBuilder: (ctx, index) {
          final cat = categories[index];
          return ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/select-country',
                arguments: cat,
              );
            },
            child: Text(cat.toUpperCase()),
          );
        },
      ),
    );
  }
}