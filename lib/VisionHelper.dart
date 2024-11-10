import 'dart:convert'; // Import for base64Encode and jsonEncode
import 'dart:io'; // Import for File
import 'package:http/http.dart' as http; // Import for http

class VisionHelper {
  static const String apiKey = 'AIzaSyB22hFvSIxZQEG6kDeQo4zZkNGpqLzNqzE';
  static const double confidenceThreshold = 0.5;
  static const double challengeConfidenceThreshold = 0.5;

  // Method to verify image with Google Vision API
  static Future<Map<String, bool>> verifyImage(File imageFile) async {
    try {
      // Convert the image file to base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Define the endpoint and headers
      final url = Uri.parse('https://vision.googleapis.com/v1/images:annotate?key=$apiKey');
      final headers = {"Content-Type": "application/json"};

      // Define the request body
      final body = jsonEncode({
        "requests": [
          {
            "image": {"content": base64Image},
            "features": [
              {"type": "LABEL_DETECTION", "maxResults": 10},
              {"type": "OBJECT_LOCALIZATION"},
              {"type": "SAFE_SEARCH_DETECTION"}
            ]
          }
        ]
      });

      // Send the POST request
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Process the response to determine if it is home-cooked food
        bool isHomeCooked = _isHomeCookedFood(data['responses'][0]);
        bool matchesChallenge = _matchesChallengeTheme(data['responses'][0]);

        return {'isVerified': isHomeCooked, 'matchesChallenge': isHomeCooked && matchesChallenge};
      } else {
        print('Failed to connect to Vision API: ${response.statusCode}');
        return {'isVerified': false, 'matchesChallenge': false};
      }
    } catch (e) {
      print('Error verifying image: $e');
      return {'isVerified': false, 'matchesChallenge': false};
    }
  }

  // Determines if the image contains home-cooked food
  static bool _isHomeCookedFood(Map<String, dynamic> response) {
    bool hasFoodLabel = false;
    bool hasKitchenObject = false;

    // Define keywords and objects to identify home-cooked food
    const foodKeywords = [
      "food", "meal", "dish", "cuisine", "plate", "cooking", "homemade", "baked", "kitchen", "fresh", "prepared"
    ];
    const kitchenObjects = [
      "plate", "bowl", "pan", "spoon", "fork", "knife", "pot", "kitchen", "table"
    ];
    const nonHomeCookedKeywords = [
      "restaurant", "fast food", "takeout", "packaged", "brand", "logo"
    ];

    // Check for food-related labels with confidence threshold
    if (response.containsKey('labelAnnotations')) {
      for (var annotation in response['labelAnnotations']) {
        String description = annotation['description'].toLowerCase();
        double confidence = annotation['score'];

        if (foodKeywords.any((keyword) => description.contains(keyword)) && confidence >= confidenceThreshold) {
          hasFoodLabel = true;
        }

        if (nonHomeCookedKeywords.any((keyword) => description.contains(keyword))) {
          return false; // Immediately return false if non-home-cooked keywords are found
        }
      }
    }

    // Check for kitchen-related objects with confidence threshold
    if (response.containsKey('localizedObjectAnnotations')) {
      for (var object in response['localizedObjectAnnotations']) {
        String name = object['name'].toLowerCase();
        double confidence = object['score'];

        if (kitchenObjects.any((item) => name.contains(item)) && confidence >= confidenceThreshold) {
          hasKitchenObject = true;
          break; // Break if a relevant object is found
        }
      }
    }

    return hasFoodLabel && hasKitchenObject;
  }

  // Check if the image matches a specific challenge theme with an expanded keyword list and a lower confidence threshold
  static bool _matchesChallengeTheme(Map<String, dynamic> response) {
    // Expanded list of vegan-related keywords for better detection
    const challengeKeywords = [
      "vegan", "plant-based", "vegetable", "tofu", "salad", "fruit", "legume", "bean", "nuts", "grains", "plant protein"
    ];
    if (response.containsKey('labelAnnotations')) {
      for (var annotation in response['labelAnnotations']) {
        String description = annotation['description'].toLowerCase();
        double confidence = annotation['score'];

        if (challengeKeywords.any((keyword) => description.contains(keyword)) && confidence >= challengeConfidenceThreshold) {
          return true; // Only consider it a match if confidence is above the threshold
        }
      }
    }
    return false;
  }
}
