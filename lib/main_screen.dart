import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'VisionHelper.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _databaseRef =
  FirebaseDatabase.instance.ref().child("users");
  User? currentUser;
  File? _imageFile;
  int streakCount = 0;
  DateTime? lastUploadDate;
  bool isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      currentUser = _auth.currentUser;
      if (currentUser != null) {
        final event =
        await _databaseRef.child(currentUser!.uid).child("streaks").once();
        final snapshot = event.snapshot;
        if (snapshot.value != null) {
          Map<String, dynamic> streakData =
          Map<String, dynamic>.from(snapshot.value as Map);
          setState(() {
            streakCount = streakData["streakCount"] ?? 0;
            lastUploadDate =
                DateTime.tryParse(streakData["lastUploadDate"] ?? '');
          });
        }
      }
    } catch (e) {
      print("Error loading user data: $e");
    }
  }

  Future<void> _updateStreak() async {
    try {
      DateTime today = DateTime.now();
      if (lastUploadDate != null) {
        int difference = today.difference(lastUploadDate!).inDays;
        if (difference == 1) {
          streakCount++;
        } else if (difference > 1) {
          streakCount = 1;
        }
      } else {
        streakCount = 1;
      }

      lastUploadDate = today;
      await _databaseRef.child(currentUser!.uid).child("streaks").set({
        "streakCount": streakCount,
        "lastUploadDate": DateFormat('yyyy-MM-dd').format(today),
      });

      setState(() {});
    } catch (e) {
      print("Error updating streak: $e");
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await ImagePicker().pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _verifyAndUploadImage() async {
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No image selected!")),
      );
      return;
    }

    setState(() {
      isUploading = true;
    });

    try {
      bool isVerified = await VisionHelper.verifyImage(_imageFile!);
      if (isVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Verified as home-cooked food. Streak updated!")),
        );

        // Update the streak count
        await _updateStreak();
        setState(() {
          _imageFile = null; // Remove the image after verification
          isUploading = false; // Reset the uploading state
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Image not verified as home-cooked food.")),
        );
        setState(() {
          _imageFile = null; // Remove image if verification fails
          isUploading = false; // Reset the uploading state
        });
      }
    } catch (e) {
      print("Error during verification: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to verify image. Please try again.")),
      );
      setState(() {
        isUploading = false; // Reset the uploading state in case of error
      });
    }
  }

  void _navigateTo(String route) {
    Navigator.pushNamed(context, route);
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    // Navigate back to the login screen and remove all previous routes
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/',
          (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF222831),
      appBar: AppBar(
        title: Text('Main Screen'),
        backgroundColor: Color(0xFF222831),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Welcome, ${currentUser?.email ?? 'User'}",
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            SizedBox(height: 10),
            Text(
              "Current Streak: $streakCount days",
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            SizedBox(height: 20),
            _imageFile != null
                ? Flexible(
              child: Image.file(
                _imageFile!,
                fit: BoxFit.contain,
                width: MediaQuery.of(context).size.width * 0.8,
                height: MediaQuery.of(context).size.height * 0.4,
              ),
            )
                : Text(
              "No image selected.",
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 20),
            if (isUploading)
              CircularProgressIndicator()
            else ...[
              ElevatedButton(
                onPressed: () => _pickImage(ImageSource.camera),
                child: Text("Take Photo"),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                ),
              ),
              ElevatedButton(
                onPressed: () => _pickImage(ImageSource.gallery),
                child: Text("Upload from Gallery"),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                ),
              ),
              ElevatedButton(
                onPressed: _verifyAndUploadImage,
                child: Text("Verify"),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Color(0xFF393E46),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.photo_camera), // Use the correct icon for Camera
            label: "Camera",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard), // Use the correct icon for Leaderboard
            label: "Leaderboard",
          ),
        ],
        onTap: (index) {
          if (index == 0) {
            // Camera functionality remains as is
          } else if (index == 1) {
            _navigateTo('/leaderboard');
          }
        },
      ),
    );
  }
}