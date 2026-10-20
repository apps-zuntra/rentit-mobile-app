import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rentit/ViewDetailsPages/ApartmentViewDetails/ApartmentPropertyDetails.dart';
import 'package:rentit/ViewDetailsPages/Commercial/CommercialPropertyDetails.dart';
import 'package:rentit/ViewDetailsPages/FlatmateViewDetails/FlatmatePropertyDetails.dart';
import 'package:rentit/main/PropertyDetails.dart';

class DeepLinkHandlerScreen extends StatefulWidget {
  final int propertyId;

  const DeepLinkHandlerScreen({super.key, required this.propertyId});

  @override
  State<DeepLinkHandlerScreen> createState() => _DeepLinkHandlerScreenState();
}

class _DeepLinkHandlerScreenState extends State<DeepLinkHandlerScreen> {
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchPropertyAndNavigate();
  }

  Future<void> _fetchPropertyAndNavigate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token");
      final headers = {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      };

      final response = await http.get(
        Uri.parse(
          "https://rentit-backend-omega.vercel.app/property/${widget.propertyId}",
        ),
        headers: headers,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> p = jsonDecode(response.body);
        final String category = (p['propertyType'] ?? '')
            .toString()
            .toLowerCase();

        if (category.contains('commercial')) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  CommercialPropertyDetailScreen(propertyId: widget.propertyId),
            ),
          );
        } else if (category.contains('flatmate')) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  FlatmateDetailScreen(propertyId: widget.propertyId),
            ),
          );
        } else if (category.contains('apartment') ||
            category.contains('villa') ||
            category.contains('independent')) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ApartmentPropertyDetailScreen(propertyId: widget.propertyId),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  PropertyDetailScreen(propertyId: widget.propertyId),
            ),
          );
        }
      } else {
        setState(() {
          _error = 'Property not found';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load property';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Loading Property...'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(_error, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
      ),
    );
  }
}
