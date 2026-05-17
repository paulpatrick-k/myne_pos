import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import '../../core/data/country_data.dart';

class CountrySelectionScreen extends StatefulWidget {
  const CountrySelectionScreen({super.key});

  @override
  State<CountrySelectionScreen> createState() => _CountrySelectionScreenState();
}

class _CountrySelectionScreenState extends State<CountrySelectionScreen> {
  String? _selectedCountry;

  @override
  Widget build(BuildContext context) {
    final selectedCategory = ModalRoute.of(context)!.settings.arguments as String;
    final countryNames = CountryData.countries.map((c) => c['name']!).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Select Your Country')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Search or select your business country',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            DropdownSearch<String>(
              items: countryNames,
              selectedItem: _selectedCountry,
              popupProps: const PopupProps.menu(
                showSearchBox: true,
                searchFieldProps: TextFieldProps(
                  decoration: InputDecoration(
                    labelText: 'Search country',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _selectedCountry = value;
                });
              },
              dropdownDecoratorProps: const DropDownDecoratorProps(
                dropdownSearchDecoration: InputDecoration(
                  labelText: 'Country',
                  border: OutlineInputBorder(),
                ),
              ),
              validator: (value) => value == null || value.isEmpty ? 'Please select a country' : null,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _selectedCountry == null
                  ? null
                  : () {
                      final country = CountryData.countries.firstWhere(
                        (c) => c['name'] == _selectedCountry,
                        orElse: () => CountryData.countries.first,
                      );
                      Navigator.pushNamed(
                        context,
                        '/register',
                        arguments: {
                          'category': selectedCategory,
                          'country': country['name']!,
                          'currencyCode': country['currency']!,
                        },
                      );
                    },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
