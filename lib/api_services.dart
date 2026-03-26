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
    "AW cola",
    "Akabare Khursani",
    "Ampalaya",
    "Apple",
    "Artichoke",
    "Ash Gourd",
    "Asparagus",
    "Avocado",
    "Bacon",
    "Bamboo Shoots",
    "Banana",
    "Bay Leaf",
    "Beans",
    "Beaten Rice",
    "Beef",
    "Beetroot",
    "Beijing Beef",
    "Bell Pepper",
    "Bethu ko Saag",
    "Bitter Gourd",
    "Black Lentils",
    "Black Pepper",
    "Black beans",
    "Bottle Gourd",
    "Bread",
    "Brinjal",
    "Broad Beans",
    "Broccoli",
    "Buff Meat",
    "Burger",
    "Butter",
    "Cabbage",
    "Calamansi",
    "Capsicum",
    "Carrot",
    "Carrot Egg",
    "Cassava",
    "Cauliflower",
    "Chayote",
    "Cheese",
    "Cheese Burger",
    "Cheese Dip Sauce",
    "Chicken",
    "Chicken Gizzards",
    "Chicken Waffle",
    "Chickpeas",
    "Chili Pepper",
    "Chili Powder",
    "Chilli",
    "Chinese Cabbage",
    "Chinese Sausage",
    "Chow Mein",
    "Chowmein Noodles",
    "Cinnamon",
    "Coconut",
    "Coriander",
    "Corn",
    "Cornflakec",
    "Crab",
    "Crab Meat",
    "Cucumber",
    "Curry",
    "Dumplings",
    "Egg",
    "Eggplant",
    "Eggs",
    "Farsi ko Munta",
    "Fiddlehead Ferns",
    "Fish",
    "French Fries",
    "Fried Chicken",
    "Fried Rice",
    "Garden Peas",
    "Garden cress",
    "Garlic",
    "Ginger",
    "Grape",
    "Green Apple",
    "Green Brinjal",
    "Green Lentils",
    "Green Mint",
    "Green Peas",
    "Green Soyabean",
    "Gundruk",
    "Ham",
    "Hashbrown",
    "Honey Walnut Shrimp",
    "Ice",
    "Jack Fruit",
    "Juice",
    "Ketchup",
    "Kimchi",
    "Kiwi",
    "Kung Pao Chicken",
    "Lapsi",
    "Lemon",
    "Lime",
    "Long Beans",
    "Mac Cheese",
    "Mango Chicken Pocket",
    "Masyaura",
    "Mayonnaise",
    "Milk",
    "Minced Meat",
    "Monggo",
    "Moringa Drumsticks",
    "Moringa Leaves",
    "Mung Bean Sprouts",
    "Mushroom",
    "Mutton",
    "Noodles",
    "Nugget",
    "Okra",
    "Olive Oil",
    "Onion",
    "Onion Leaves",
    "Orange",
    "Paneer",
    "Papaya",
    "Pea",
    "Pear",
    "Pechay",
    "Pepper Corn",
    "Perkedel",
    "Pointed Gourd",
    "Pork",
    "Potato",
    "Product",
    "Pumpkin",
    "Pumpkin -Farsi-",
    "Radish",
    "Rahar ko Daal",
    "Rayo ko Saag",
    "Red Beans",
    "Red Lentils",
    "Red Pepper Corn",
    "Rice",
    "Salt",
    "Sandwich",
    "Sausage",
    "Seaweed",
    "Shrimp",
    "Sigarilyas",
    "Snake Gourd",
    "Soy Sauce",
    "Soya Chunks",
    "Soyabean",
    "Spinach",
    "Sponge Gourd",
    "Spring onion",
    "Sprite",
    "Squash",
    "Stinging Nettle",
    "Strawberry",
    "String Bean Chicken Breast",
    "String beans",
    "Sugar",
    "Super Greens",
    "Sweet Potato",
    "Taro Leaves",
    "Taro Root",
    "The Original Orange Chicken",
    "Thukpa Noodles",
    "Tofu",
    "Tomato",
    "Tomato Sauce",
    "Tori ko Saag",
    "Tree Tomato",
    "Turnip",
    "Wallnut",
    "Water Melon",
    "Wheat",
    "White Pepper Corn",
    "White Steamed Rice",
    "Yellow Lentils",
  ];

  String _cleanIngredient(String label) {
    String clean = label.toLowerCase();
    
    clean = clean.replaceAll("the original ", "");
    clean = clean.replaceAll("beijing ", "");
    clean = clean.replaceAll("aw ", "");
    clean = clean.replaceAll("kung pao ", "");
    
    clean = clean.replaceAll(RegExp(r'-.*?-'), ''); 
    
    if (clean.contains("orange chicken")) return "chicken,orange";
    if (clean.contains("chow mein") || clean.contains("noodles")) return "noodles";
    if (clean.contains("pechay")) return "bok choy"; // Spoonacular prefers "bok choy"
    if (clean.contains("monggo")) return "mung beans";
    
    return clean.trim();
  }

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
    if (ingredients.isEmpty || ingredients[0].contains("No ingredients")) {
      return [];
    }

    final cleanedIngredients = ingredients.map((e) => _cleanIngredient(e)).toSet().toList();
    final query = cleanedIngredients.join(",");

    final url =
        'https://api.spoonacular.com/recipes/findByIngredients?ingredients=$query&number=10&apiKey=$spoonacularKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 402) {
        print("Spoonacular Error: API Key limit reached or invalid.");
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
