import 'package:flutter/material.dart';

void main() {
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

class LoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFDBEAFE), // Biru muda
              Color(0xFFEAF4FE), // Biru lebih terang
              Color(0xFFFFFFFF), // Putih
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            // Bagian Kiri: Form Login
            Expanded(
              flex: 1,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 40.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Spacer(flex: 2),
                    Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 36.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 8.0),
                    Text.rich(
                      TextSpan(
                        text: 'Kelola konten Anda dengan\n',
                        style: TextStyle(
                          fontSize: 16.0,
                          color: Colors.black54,
                        ),
                        children: [
                          TextSpan(
                            text: 'mudah dan efisien!',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0C21C1),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 50.0),
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                        hintText: 'Enter your Email',
                        border: UnderlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 20.0),
                    TextField(
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline),
                        hintText: 'Enter your Password',
                        border: UnderlineInputBorder(),
                        suffixIcon: Icon(Icons.visibility_off),
                      ),
                    ),
                    SizedBox(height: 40.0),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50.0),
                          ),
                          backgroundColor: Color(0xFF0C21C1),
                          elevation: 5,
                        ),
                        child: Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Spacer(flex: 3),
                  ],
                ),
              ),
            ),
            // Bagian Kanan: Kotak dengan Logo
            Expanded(
              flex: 1,
              child: Padding(
                padding: EdgeInsets.all(10.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF000842), // Background biru gelap
                    borderRadius:
                        BorderRadius.circular(20.0), // Sudut melengkung
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/jadingetop.png', // Path logo
                      width: 700, // Lebar logo (diperbesar)
                      height: 700, // Tinggi logo (diperbesar)
                      fit: BoxFit.contain, // Menjaga proporsi logo
                    ),
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
