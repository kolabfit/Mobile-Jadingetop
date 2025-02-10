import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart'; // Tambahkan ini
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'HomeScreen.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  HttpOverrides.global = MyHttpOverrides();
  runApp(JadiNgetopApp());
}

class JadiNgetopApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jadi Ngetop CMS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  Future<void> _loadCachedDataOnLogin() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? cachedToken = prefs.getString('cachedToken');
      String? cachedLoginData = prefs.getString('cachedLoginData');
      List<String>? cachedImagePaths = prefs.getStringList('localImagePaths');

      print('Cached token: $cachedToken');
      print('Cached login data: $cachedLoginData');
      print('Cached image paths: $cachedImagePaths');

      if (cachedToken != null && cachedLoginData != null) {
        // Pastikan data gambar cache tersedia dan valid
        if (cachedImagePaths != null && cachedImagePaths.isNotEmpty) {
          print('Menggunakan gambar cache saat offline.');
        }

        await prefs.setString('authToken', cachedToken);
        _showAlertDialog(
            'Offline Mode', 'Anda login menggunakan data dari cache.');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
      } else {
        _showErrorDialog(
            'Cache kosong. Silakan periksa koneksi internet Anda.');
      }
    } catch (e) {
      print('Gagal memuat data cache: $e');
      _showErrorDialog('Gagal memuat data cache. Silakan coba lagi.');
    }
  }

  Future<void> _cacheLoginData(String token, Map<String, dynamic> data) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('cachedToken', token);
      await prefs.setString('cachedLoginData', jsonEncode(data));
      await prefs.setString('last_update', DateTime.now().toIso8601String());
      print('Data login berhasil disimpan ke cache.');
    } catch (e) {
      print('Gagal menyimpan data login ke cache: $e');
    }
  }

  Future<void> _downloadAndCacheImage(String url, String filename) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$filename';
      final file = File(filePath);

      if (await file.exists()) {
        print('Gambar sudah ada di cache: $filePath');
        return;
      }

      final dio = Dio();
      final response = await dio.get(url,
          options: Options(responseType: ResponseType.bytes));
      await file.writeAsBytes(response.data);
      print('Gambar berhasil disimpan ke cache: $filePath');
    } catch (e) {
      print('Gagal mendownload atau menyimpan gambar: $e');
    }
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });

    final String url = 'https://jadingetop.ngolab.id/api/collection';
    final Map<String, String> bodyinput = {
      'username': _emailController.text,
      'password': _passwordController.text,
    };

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        await _loadCachedDataOnLogin();
        return;
      }

      // Send the POST request
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(bodyinput),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String token = data['data']['token'];

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('authToken', token);
        await _cacheLoginData(token, data);

        bool isUpdated = await _checkApiUpdateStatus(token);
        if (isUpdated) {
          _showAlertDialog('Update tersedia', 'Data akan diperbarui.');
          await _fetchLatestData(token);
        } else {
          _showAlertDialog('Tidak ada update', 'Data di cache masih relevan.');
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
      } else {
        _showErrorDialog('Login gagal. Silakan periksa kembali data Anda.');
      }
    } catch (e) {
      print('Terjadi kesalahan: $e');
      await _loadCachedDataOnLogin();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _checkApiUpdateStatus(String token) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? lastUpdate = prefs.getString('last_update');
      int lastUpdateUnix = lastUpdate != null
          ? DateTime.parse(lastUpdate).millisecondsSinceEpoch ~/ 1000
          : 0;

      Uri statusUri = Uri.https(
          'jadingetop.ngolab.id',
          '/api/collection/update-status',
          {'last_update_unix': lastUpdateUnix.toString()});
      final response = await http.get(statusUri,
          headers: {'Token': token, 'Accept': 'application/json'});

      if (response.statusCode == 200) {
        final statusData = jsonDecode(response.body);
        return statusData['data']['is_update'] ?? false;
      } else {
        throw Exception('Gagal memeriksa status update.');
      }
    } catch (e) {
      print('Error saat memeriksa status update: $e');
      return false;
    }
  }

  Future<void> _fetchLatestData(String token) async {
    try {
      final Uri dataUri = Uri.https('jadingetop.ngolab.id', '/api/collection');
      final response = await http.get(dataUri,
          headers: {'Token': token, 'Accept': 'application/json'});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final contentList = data['data']['content'] as List;

        for (var item in contentList) {
          String? imageUrl = item['file'];
          if (imageUrl != null && imageUrl.isNotEmpty) {
            String filename = imageUrl.split('/').last;
            await _downloadAndCacheImage(imageUrl, filename);
          }
        }

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('cachedData', response.body);
        await prefs.setString('last_update', DateTime.now().toIso8601String());
      } else {
        throw Exception('Gagal mengambil data terbaru.');
      }
    } catch (e) {
      print('Exception saat fetch data terbaru: $e');
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
              onPressed: () => Navigator.of(context).pop(), child: Text('OK')),
        ],
      ),
    );
  }

  void _showAlertDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(), child: Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isWideScreen = screenSize.width > 800;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFEEF4FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Container(
              padding: EdgeInsets.all(20.0),
              constraints: BoxConstraints(maxWidth: 1000),
              child: isWideScreen
                  ? Row(
                      children: [
                        Flexible(
                          flex: 1,
                          child: _buildLoginForm(),
                        ),
                        SizedBox(width: 20),
                        Flexible(
                          flex: 1,
                          child: _buildImageContainer(),
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildImageContainer(),
                          SizedBox(height: 20),
                          _buildLoginForm(),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 20.0),
          Text(
            'Login',
            style: TextStyle(
              fontSize: 32.0,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8.0),
          Text(
            'Kelola konten Anda dengan mudah dan efisien!',
            style: TextStyle(
              fontSize: 16.0,
              color: Colors.black54,
            ),
          ),
          SizedBox(height: 30.0),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Enter your Email',
              prefixIcon: Icon(Icons.email_outlined),
              border: UnderlineInputBorder(),
            ),
          ),
          SizedBox(height: 20.0),
          TextField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Enter your Password',
              prefixIcon: Icon(Icons.lock_outline),
              border: UnderlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              ),
            ),
          ),
          SizedBox(height: 30.0),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _login,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 14.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50.0),
                ),
                backgroundColor: Color(0xFF0C21C1),
              ),
              child: _isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageContainer() {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFF000842),
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Center(
        child: Image.asset(
          'assets/jadingetop.png',
          width: 300,
          height: 300,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
