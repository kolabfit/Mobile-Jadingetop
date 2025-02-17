import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:marquee/marquee.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'dart:math';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _token;
  bool _isLoading = false;
  List<String> _imageUrls = [];
  List<String> _localImagePaths = [];
  List<Map<String, dynamic>> _tinkersData = [];
  int _currentPage = 0;
  Timer? _timer;
  bool _isPortrait = true;
  int _rotationIndex = 0; // 0 = 0°, 1 = 90°, 2 = 180°, 3 = 270°

  @override
  void initState() {
    super.initState();
    _loadCachedAdsData();
    _fetchData(-6.9737, 107.6531);
  }

  @override
  void dispose() {
    if (_timer != null) {
      _timer!.cancel();
    }
    SystemChrome.setPreferredOrientations([]);
    super.dispose();
  }

  void _applyOrientation(String setting) {
    print('Setting orientasi dari API: $setting');
    setState(() {
      _isPortrait = setting.toLowerCase() == 'potrait';
    });
  }

  void _rotateImage() {
    setState(() {
      _rotationIndex = (_rotationIndex + 1) % 4;
    });
  }

  double get _rotationAngle {
    return _rotationIndex * (pi / 2);
  }

  Alignment getTinkerAlignment() {
    switch (_rotationIndex) {
      case 1: // 90° Rotasi
        return Alignment.centerRight;
      case 2: // 180° Rotasi
        return Alignment.topCenter;
      case 3: // 270° Rotasi
        return Alignment.centerLeft;
      default: // 0° (Normal)
        return Alignment.bottomCenter;
    }
  }

  EdgeInsets getTinkerPosition(Size screenSize, bool isTabletOrDesktop) {
    switch (_rotationIndex) {
      case 1: // 90 degrees
        return EdgeInsets.only(
          top: 0,
          right: 0,
          bottom: 0,
          left: screenSize.height - (isTabletOrDesktop ? 40 : 30),
        );
      case 2: // 180 degrees
        return EdgeInsets.only(
          top: 0,
          right: 0,
          left: 0,
          bottom: screenSize.height - (isTabletOrDesktop ? 40 : 30),
        );
      case 3: // 270 degrees
        return EdgeInsets.only(
          top: 0,
          right: screenSize.height - (isTabletOrDesktop ? 40 : 30),
          bottom: 0,
          left: 0,
        );
      default: // 0 degrees
        return EdgeInsets.only(
          top: screenSize.height - (isTabletOrDesktop ? 40 : 30),
          right: 0,
          bottom: 0,
          left: 0,
        );
    }
  }

  Future<void> _fetchData(double latitude, double longitude) async {
    setState(() {
      _isLoading = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('authToken');

      if (_token == null || _token!.isEmpty) {
        _showErrorDialog('Token tidak tersedia. Silakan login ulang.');
        return;
      }

      Uri uri = Uri.https('jadingetop.ngolab.id', '/api/collection', {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
      });

      final response = await http.get(uri, headers: {
        'Token': _token!,
        'Accept': 'application/json',
      }).timeout(Duration(seconds: 10), onTimeout: () {
        throw Exception('Request timeout. Coba lagi nanti.');
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['data'] != null && data['data']['collection'] != null) {
          String setting = data['data']['collection']['setting'] ?? 'potrait';
          _isPortrait = setting.toLowerCase() == 'potrait';
          _applyOrientation(setting);
        }

        if (data['data'] == null ||
            data['data']['content'] == null ||
            data['data']['tinkers'] == null) {
          throw Exception('Data API tidak valid.');
        }

        final dynamic contentData = data['data']['content'];

        List<dynamic> contentList;
        if (contentData is Map) {
          contentList = contentData.values.toList();
        } else if (contentData is List) {
          contentList = contentData;
        } else {
          throw Exception('Format data content tidak valid.');
        }

        contentList = contentList.where((item) {
          DateTime now = DateTime.now();
          DateTime startDate = DateTime.parse(item['start_date']);
          DateTime endDate = DateTime.parse(item['end_date']);
          return now.isAfter(startDate) && now.isBefore(endDate);
        }).toList();

        final tinkersList = data['data']['tinkers'] as List;

        await prefs.setString('cachedAdsData', jsonEncode(contentList));
        await prefs.setString('cachedTinkersData', jsonEncode(tinkersList));

        _localImagePaths.clear();
        for (var item in contentList) {
          String imageUrl = item['file'];
          String localPath =
              await _downloadAndSaveImage(imageUrl, imageUrl.split('/').last);
          if (localPath.isNotEmpty) {
            _localImagePaths.add(localPath);
          }
        }
        await prefs.setStringList('localImagePaths', _localImagePaths);

        setState(() {
          _imageUrls =
              contentList.map((item) => item['file'] as String).toList();
          _tinkersData =
              tinkersList.map((item) => item as Map<String, dynamic>).toList();
          _startAutoScroll();
        });
      } else {
        throw Exception('Response Error Body: ${response.body}');
      }
    } catch (e) {
      print('Gagal mengambil data dari API: $e');
      bool cacheLoaded = await _loadCachedAdsData();
      if (!cacheLoaded) {
        _showErrorDialog('Gagal mengambil data. Menggunakan data cache.');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _loadCachedAdsData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? cachedAdsData = prefs.getString('cachedAdsData');
      String? cachedTinkersData = prefs.getString('cachedTinkersData');
      _localImagePaths = prefs.getStringList('localImagePaths') ?? [];

      bool cacheAvailable = false;

      if (cachedAdsData != null) {
        final contentList = jsonDecode(cachedAdsData) as List;

        if (contentList.isNotEmpty) {
          setState(() {
            _imageUrls =
                contentList.map((item) => item['file'] as String).toList();
          });
          cacheAvailable = true;
        }
      }

      if (cachedTinkersData != null) {
        final tinkersList = jsonDecode(cachedTinkersData) as List;
        if (tinkersList.isNotEmpty) {
          setState(() {
            _tinkersData = tinkersList
                .map((item) => item as Map<String, dynamic>)
                .toList();
          });
          cacheAvailable = true;
        }
      }

      if (cacheAvailable) {
        _startAutoScroll();
      }

      return cacheAvailable;
    } catch (e) {
      print('Error saat memuat data cache: $e');
      return false;
    }
  }

  Future<String> _downloadAndSaveImage(String url, String filename) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$filename';
      await Dio().download(url, filePath);
      print('Gambar berhasil diunduh dan disimpan di $filePath');
      return filePath;
    } catch (e) {
      print('Gagal mengunduh gambar: $e');
      return '';
    }
  }

  void _startAutoScroll() {
    if (_timer != null) {
      _timer!.cancel();
    }

    if (_imageUrls.isNotEmpty || _localImagePaths.isNotEmpty) {
      _timer = Timer.periodic(Duration(seconds: 5), (timer) {
        setState(() {
          _currentPage = (_currentPage + 1) %
              (_localImagePaths.isNotEmpty
                  ? _localImagePaths.length
                  : _imageUrls.length);
        });
      });
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  String _buildTinkerText() {
    if (_tinkersData.isEmpty) return '';
    String text =
        _tinkersData.map((tinker) => tinker['title'] ?? 'Untitled').join(' - ');
    print('Tinker text: $text');
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTabletOrDesktop = screenSize.width > 600;
    final tinkerHeight = isTabletOrDesktop ? 40.0 : 30.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : GestureDetector(
              onTapDown: (_) => _rotateImage(),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: AnimatedSwitcher(
                      duration: Duration(seconds: 1),
                      switchInCurve: Curves.easeIn,
                      switchOutCurve: Curves.easeOut,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      child: Transform.rotate(
                        key: ValueKey<int>(_rotationIndex),
                        angle: _rotationAngle,
                        child: Container(
                          width: _rotationIndex.isOdd
                              ? screenSize.height
                              : screenSize.width,
                          height: _rotationIndex.isOdd
                              ? screenSize.width
                              : screenSize.height,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: _localImagePaths.isNotEmpty
                                ? Image.file(
                                    File(_localImagePaths[_currentPage]),
                                    key: ValueKey<String>(
                                        _localImagePaths[_currentPage]),
                                  )
                                : _imageUrls.isNotEmpty
                                    ? Image.network(
                                        _imageUrls[_currentPage],
                                        key: ValueKey<String>(
                                            _imageUrls[_currentPage]),
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Center(
                                            child: Icon(Icons.broken_image,
                                                size: 100, color: Colors.grey),
                                          );
                                        },
                                      )
                                    : Center(
                                        child: Text(
                                          'Tidak ada gambar yang tersedia',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: _rotationIndex == 3 ? 0 : null,
                    right: _rotationIndex == 1 ? 0 : null,
                    top: _rotationIndex == 2 ? 0 : null,
                    bottom: _rotationIndex == 0 ? 0 : null,
                    child: Transform(
                      alignment: _rotationIndex.isOdd
                          ? (_rotationIndex == 1
                              ? Alignment.topRight
                              : Alignment.topLeft)
                          : Alignment.center,
                      transform: Matrix4.rotationZ(_rotationAngle),
                      child: Container(
                        width: _rotationIndex.isOdd
                            ? screenSize.height
                            : screenSize.width,
                        height: tinkerHeight,
                        color: Colors.black54,
                        alignment: Alignment.center,
                        child: Marquee(
                          text: _buildTinkerText(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          scrollAxis: Axis.horizontal,
                          blankSpace: 50.0,
                          velocity: 75.0,
                          showFadingOnlyWhenScrolling: true,
                          fadingEdgeStartFraction: 0.1,
                          fadingEdgeEndFraction: 0.1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
