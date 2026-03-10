import "dart:io";
import "dart:typed_data";
import "package:image/image.dart" as img;
import "package:tflite_flutter/tflite_flutter.dart";
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final spoonacularKey = String.fromEnvironment('SPOONACULAR_API_KEY');
  Interpreter? _interpreter;
  bool _modelLoaded = false;

  final int inputSize = 512;

  final List<String> labels = [
    "Ampalaya",
    "Apple",
    "Banana",
    "Bay Leaf",
    "Beef",
    "Bell Pepper",
    "Broccoli",
    "Cabbage",
    "Calamansi",
    "Carrot",
    "Carrots",
    "Chicken",
    "Chili Pepper",
    "Chilli",
    "Coconut",
    "Coke",
    "Corn",
    "Crab",
    "Cucumber",
    "Egg",
    "Eggplant",
    "Garlic",
    "Ginger",
    "Grape",
    "Green Apple",
    "Monggo",
    "Milk",
    "Okra",
    "Onion",
    "Papaya",
    "Pechay",
    "Pepper Corn",
    "Pork",
    "Potato",
    "Pumpkin",
    "Red Pepper Corn",
    "Rice",
    "Shrimp",
    "Sigarilyas",
    "Spinach",
    "Spring onion",
    "Squash",
    "String beans",
    "Tomato",
    "Tomato Sauce",
    "White Pepper Corn",
  ];

  Future<void> _loadModel() async {
    if (_modelLoaded) return;
    try {
      _interpreter = await Interpreter.fromAsset(
        "assets/models/best_float32.tflite",
        options: InterpreterOptions()..threads = 4,
      );
      _modelLoaded = true;
    } catch (e) {
      print("Error loading model: $e");
    }
  }

  Future<List<String>> identifyIngredients(String imagePath) async {
    await _loadModel();
    if (_interpreter == null) return ["Error: Model not loaded"];

    final imageFile = File(imagePath);
    final imageBytes = await imageFile.readAsBytes();
    img.Image? originalImage = img.decodeImage(imageBytes);

    if (originalImage == null) return ["Error: Unable to decode image"];

    img.Image resizedImage = img.copyResize(
      originalImage,
      width: inputSize,
      height: inputSize,
    );

    var input = Float32List(1 * inputSize * inputSize * 3);
    int pixelIndex = 0;
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        var pixel = resizedImage.getPixel(x, y);
        input[pixelIndex++] = pixel.r / 255.0;
        input[pixelIndex++] = pixel.g / 255.0;
        input[pixelIndex++] = pixel.b / 255.0;
      }
    }
    var finalInput = input.reshape([1, inputSize, inputSize, 3]);

    var outputShape = _interpreter!.getOutputTensor(0).shape;
    var output = List.generate(
      outputShape[0],
      (_) => List.generate(
        outputShape[1],
        (_) => List.filled(outputShape[2], 0.0),
      ),
    );

    _interpreter!.run(finalInput, output);

    List<String> detectedIngredients = [];

    for (int i = 0; i < outputShape[2]; i++) {
      double maxClassScore = 0;
      int classIndex = -1;

      for (int c = 4; c < outputShape[1]; c++) {
        double score = output[0][c][i];
        if (score > maxClassScore) {
          maxClassScore = score;
          classIndex = c - 4;
        }
      }

      if (maxClassScore > 0.45 &&
          classIndex >= 0 &&
          classIndex < labels.length) {
        detectedIngredients.add(labels[classIndex]);
      }
    }

    detectedIngredients = detectedIngredients.toSet().toList();
    return detectedIngredients.isEmpty
        ? ["No ingredients detected"]
        : detectedIngredients;
  }

  Future<List<dynamic>> fetchRecipes(List<String> ingredients) async {
    if (ingredients.isEmpty || ingredients[0].contains("No ingredients"))
      return [];

    final query = ingredients.join(",");
    final url =
        'https://api.spoonacular.com/recipes/findByIngredients?ingredients=$query&number=10&apiKey=$spoonacularKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      print("Spoonacular Error: $e");
    }
    return [];
  }

  Future<Map<String, dynamic>> fetchRecipeDetails(int id) async {
    final url =
        'https://api.spoonacular.com/recipes/$id/information?apiKey=$spoonacularKey';
    try {
      final response = await http.get(Uri.parse(url));
      return response.statusCode == 200 ? json.decode(response.body) : {};
    } catch (e) {
      print("Details Error: $e");
      return {};
    }
  }
}
