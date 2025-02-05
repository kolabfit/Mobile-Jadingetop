import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _token;
  bool _isLoading = false;
  List<String> _imageUrls = [];
  int _currentPage = 0;
  Timer? _timer;

  Future<void> _fetchData(double latitude, double longitude) async {
    setState(() {
      _isLoading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('authToken');

      if (_token == null || _token!.isEmpty) {
        print('Token tidak tersedia atau kosong.');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      Uri uri = Uri.https('jadingetop.ngolab.id', '/api/collection', {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
      });

      print('Request URL: ${uri.toString()}');
      print('Request Token: $_token');

      final response = await http.get(
        uri,
        headers: {
          'Token': _token!,
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('API Response: ${response.body}');

        final contentList = data['data']['content'] as List;

        setState(() {
          _imageUrls =
              contentList.map((item) => item['file'] as String).toList();
          _isLoading = false;
          _startAutoScroll(); // Mulai auto-scroll setelah gambar dimuat
        });

        print('Parsed image URLs: $_imageUrls');
      } else {
        print('Response Error Body: ${response.body}');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startAutoScroll() {
    if (_timer != null) {
      _timer!.cancel();
    }

    _timer = Timer.periodic(Duration(seconds: 5), (timer) {
      setState(() {
        _currentPage = (_currentPage + 1) % _imageUrls.length;
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchData(-6.9737, 107.6531); // Koordinat Bojongsoang, Bandung
  }

  @override
  void dispose() {
    if (_timer != null) {
      _timer!.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _imageUrls.isEmpty
              ? Center(child: Text('Tidak ada gambar yang tersedia'))
              : Stack(
                  children: [
                    AnimatedSwitcher(
                      duration: Duration(seconds: 1),
                      switchInCurve: Curves.easeIn,
                      switchOutCurve: Curves.easeOut,
                      child: Image.network(
                        _imageUrls[_currentPage],
                        key: ValueKey<String>(_imageUrls[_currentPage]),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      (loadingProgress.expectedTotalBytes ?? 1)
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          print('Error loading image: $error');
                          return Center(
                            child: Icon(
                              Icons.broken_image,
                              size: 100,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
