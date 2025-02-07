import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:marquee/marquee.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _token;
  bool _isLoading = false;
  List<String> _imageUrls = [];
  List<Map<String, dynamic>> _tinkersData = [];
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

      try {
        final response = await http.get(
          uri,
          headers: {
            'Token': _token!,
            'Accept': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final contentList = data['data']['content'] as List;
          final tinkersList = data['data']['tinkers'] as List;

          await prefs.setString('cachedAdsData', jsonEncode(contentList));
          await prefs.setString('cachedTinkersData', jsonEncode(tinkersList));

          setState(() {
            _imageUrls =
                contentList.map((item) => item['file'] as String).toList();
            _tinkersData = tinkersList
                .map((item) => item as Map<String, dynamic>)
                .toList();
            _isLoading = false;
            _startAutoScroll();
          });
        } else {
          throw Exception('Response Error Body: ${response.body}');
        }
      } catch (e) {
        print('Gagal mengambil data dari API: $e');
        _loadCachedData();
      }
    } catch (e) {
      print('Error: $e');
      _loadCachedData();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _loadCachedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? cachedData = prefs.getString('cachedAdsData');
    String? cachedTinkersData = prefs.getString('cachedTinkersData');

    if (cachedData != null) {
      final contentList = jsonDecode(cachedData) as List;
      setState(() {
        _imageUrls = contentList.map((item) => item['file'] as String).toList();
      });
    }

    if (cachedTinkersData != null) {
      final tinkersList = jsonDecode(cachedTinkersData) as List;
      setState(() {
        _tinkersData =
            tinkersList.map((item) => item as Map<String, dynamic>).toList();
      });
    }

    print('Cached tinkers data loaded: $_tinkersData');
    _startAutoScroll();
  }

  void _startAutoScroll() {
    if (_timer != null) {
      _timer!.cancel();
    }

    if (_imageUrls.isNotEmpty) {
      _timer = Timer.periodic(Duration(seconds: 5), (timer) {
        setState(() {
          _currentPage = (_currentPage + 1) % _imageUrls.length;
        });
      });
    }
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

  String _buildTinkerText() {
    if (_tinkersData.isEmpty) return 'Lorem ipsum - ';
    String text =
        _tinkersData.map((tinker) => tinker['title'] ?? 'Untitled').join(' - ');
    print('Tinker text: $text');
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTabletOrDesktop = screenSize.width > 600;

    return Scaffold(
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Menampilkan gambar
                _imageUrls.isEmpty
                    ? Center(child: Text('Tidak ada gambar yang tersedia'))
                    : AnimatedSwitcher(
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
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        (loadingProgress.expectedTotalBytes ??
                                            1)
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
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
                // Menampilkan teks bergerak di bagian paling bawah layar
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    width: double.infinity,
                    height: isTabletOrDesktop ? 80 : 60,
                    color: Colors.black87,
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Marquee(
                      text: _buildTinkerText(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isTabletOrDesktop ? 24 : 20,
                        fontWeight: FontWeight.bold,
                      ),
                      scrollAxis: Axis.horizontal,
                      blankSpace: 50.0,
                      velocity: 100.0,
                      pauseAfterRound: Duration(seconds: 0),
                      startPadding: 100.0,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
