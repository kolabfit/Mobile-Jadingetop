import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // Import yang benar untuk cek koneksi internet
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

    // Ambil data cache
    String? cachedToken = prefs.getString('cachedToken');
    String? cachedLoginData = prefs.getString('cachedLoginData');

    if (cachedToken != null && cachedLoginData != null) {
      print('Login dengan data dari cache.');

      // Simpan token ke dalam memori sementara
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('authToken', cachedToken);

      // Tampilkan pesan kepada pengguna
      _showAlertDialog('Offline Mode', 'Anda login menggunakan data dari cache.');

      // Navigasi ke HomeScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomeScreen()),
      );
    } else {
      _showErrorDialog('Cache kosong. Silakan periksa koneksi internet Anda.');
    }
  } catch (e) {
    print('Gagal memuat data cache: $e');
    _showErrorDialog('Gagal memuat data cache. Silakan coba lagi.');
  }
}


  Future<void> _cacheLoginData(String token, Map<String, dynamic> data) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Simpan data token dan response body ke cache
      await prefs.setString('cachedToken', token);
      await prefs.setString('cachedLoginData', jsonEncode(data));
      await prefs.setString('last_update', DateTime.now().toIso8601String());

      print('Data login berhasil disimpan ke cache.');
    } catch (e) {
      print('Gagal menyimpan data login ke cache: $e');
    }
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });

    final String url = 'https://jadingetop.ngolab.id/api/collection';
    final Map<String, String> body = {
      'username': _emailController.text,
      'password': _passwordController.text,
    };

    try {
      // Cek koneksi internet
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        // Jika tidak ada koneksi, load data dari cache
        await _loadCachedDataOnLogin();
        return;
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String token = data['data']['token'];

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('authToken', token);

        // Simpan hasil login dan data dari server ke cache
        await _cacheLoginData(token, data);

        // Validasi update status setelah login
        bool isUpdated = await _checkApiUpdateStatus(token);

        if (isUpdated) {
          _showAlertDialog('Update tersedia', 'Data akan diperbarui.');
          try {
            await _fetchLatestData(token);
          } catch (e) {
            print('Error saat memperbarui data setelah login: $e');
            _showErrorDialog(
                'Gagal memperbarui data terbaru. Silakan cek koneksi Anda.');
          }
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
      await _loadCachedDataOnLogin(); // Load data cache jika terjadi error
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

      Uri statusUri =
          Uri.https('jadingetop.ngolab.id', '/api/collection/update-status', {
        'last_update_unix': lastUpdateUnix.toString(),
      });

      final response = await http.get(
        statusUri,
        headers: {
          'Token': token,
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final statusData = jsonDecode(response.body);
        return statusData['data']['is_update'] ?? false;
      } else {
        print('Error response: ${response.body}');
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
      final response = await http.get(
        dataUri,
        headers: {'Token': token, 'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Validasi data response
        if (data == null || !data.containsKey('data')) {
          throw Exception('Data API tidak valid.');
        }

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('cachedData', response.body);
        await prefs.setString('last_update', DateTime.now().toIso8601String());

        print('Data berhasil diperbarui dan disimpan ke cache.');
      } else {
        print('Gagal mengambil data terbaru, response body: ${response.body}');
        throw Exception(
            'Gagal mengambil data terbaru. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception saat fetch data terbaru: $e');
      rethrow; // Lempar ulang exception agar bisa ditangani di fungsi pemanggil
    }
  }

  void _loadCachedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? cachedData = prefs.getString('cachedData');
    if (cachedData != null) {
      print('Data dari cache: $cachedData');
    } else {
      print('Cache kosong.');
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

  void _showAlertDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
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
