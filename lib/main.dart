import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'api_services.dart';

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    _cameras = await availableCameras();
  } catch (e) {
    _cameras = [];
  }

  runApp(
    const MaterialApp(home: HomeScreen(), debugShowCheckedModeBanner: false),
  );
}

// Home Screen
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF8BA882),
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/icon.png', width: 150, height: 150),
                const SizedBox(height: 20),
                const Text(
                  "PlateMate",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 60,
            left: 40,
            right: 40,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF8BA882),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CameraScreen()),
              ),
              child: const Text("Get Started", style: TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }
}

// Camera Screen
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ApiService _apiService = ApiService();
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  int _selectedCameraIndex = 0;
  bool _isFlashOn = false;

  @override
  void initState() {
    super.initState();
    _initCamera(_selectedCameraIndex);
  }

  Future<void> _initCamera(int index) async {
    try {
      if (_cameras.isEmpty) {
        _showErrorDialog("No cameras found on this device.");
        return;
      }
    } catch (e) {
      _showErrorDialog("Camera system not initialized yet.");
      return;
    }

    if (index >= _cameras.length) {
      index = 0;
    }

    if (_controller != null) {
      await _controller!.dispose();
    }

    final controller = CameraController(
      _cameras[index],
      ResolutionPreset.medium,
    );

    _controller = controller;
    _initializeControllerFuture = controller.initialize();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _takePictureAndProcess() async {
    try {
      if (_controller == null ||
          _initializeControllerFuture == null ||
          !_controller!.value.isInitialized) {
        _showErrorDialog("Camera not ready.");
        return;
      }

      await _initializeControllerFuture!;

      final image = await _controller!.takePicture();

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final ingredients =
          await _apiService.identifyIngredients(image.path) ?? [];

      if (!mounted) return;

      if (ingredients.isEmpty) {
        Navigator.pop(context);
        _showErrorDialog("No ingredients detected.");
        return;
      }

      if (ingredients.first.toString().contains("Error")) {
        Navigator.pop(context);
        _showErrorDialog(ingredients.first.toString());
        return;
      }

      final recipes = await _apiService.fetchRecipes(ingredients) ?? [];

      Navigator.pop(context);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ResultsScreen(recipes: recipes, detectedIngredients: ingredients),
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showErrorDialog("System Error: $e");
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Error"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              _controller != null &&
              _controller!.value.isInitialized) {
            return Stack(
              children: [
                Positioned.fill(child: CameraPreview(_controller!)),
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: Icon(
                          _isFlashOn ? Icons.flash_on : Icons.flash_off,
                          color: Colors.white,
                          size: 30,
                        ),
                        onPressed: () {
                          _isFlashOn = !_isFlashOn;
                          if (_controller != null) {
                            _controller!.setFlashMode(
                              _isFlashOn ? FlashMode.torch : FlashMode.off,
                            );
                          }
                          setState(() {});
                        },
                      ),
                      GestureDetector(
                        onTap: _takePictureAndProcess,
                        child: Container(
                          height: 80,
                          width: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.flip_camera_android,
                          color: Colors.white,
                          size: 30,
                        ),
                        onPressed: () {
                          _selectedCameraIndex =
                              (_selectedCameraIndex + 1) % _cameras.length;
                          _initCamera(_selectedCameraIndex);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        },
      ),
    );
  }
}

// Results Screen
class ResultsScreen extends StatelessWidget {
  final List<dynamic> recipes;
  final List<String> detectedIngredients;

  const ResultsScreen({
    super.key,
    required this.recipes,
    required this.detectedIngredients,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Recipe Results",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF6D8465),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: const Color(0xFF8BA882),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${recipes?.length ?? 0} Results Found",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: recipes.isEmpty
                  ? const Center(
                      child: Text(
                        "No recipes found.",
                        style: TextStyle(color: Colors.white),
                      ),
                    )
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.7,
                          ),
                      itemCount: recipes?.length ?? 0,
                      itemBuilder: (context, index) {
                        final recipe =
                            (recipes != null && index < recipes.length)
                            ? recipes[index]
                            : {};
                        return GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  RecipeDetailScreen(recipe: recipe),
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF6D8465),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(20),
                                    ),
                                    child: Image.network(
                                      recipe['image'],
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    recipe['title'],
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// Recipe Detail Screen
class RecipeDetailScreen extends StatefulWidget {
  final dynamic recipe;
  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  Map<String, dynamic>? fullDetails;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFullDetails();
  }

  Future<void> _loadFullDetails() async {
    final api = ApiService();

    final id = widget.recipe?['id'];

    if (id == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    final details = await api.fetchRecipeDetails(id);

    if (mounted) {
      setState(() {
        fullDetails = details ?? {};
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = fullDetails ?? widget.recipe ?? {};

    final String title = data['title']?.toString() ?? "Recipe";

    final String imageUrl = data['image']?.toString() ?? "";

    final List ingredientsList = (data['extendedIngredients'] is List)
        ? data['extendedIngredients']
        : [];

    final String ingredientsText = ingredientsList.isNotEmpty
        ? ingredientsList
              .map(
                (ing) =>
                    "• ${(ing is Map && ing['original'] != null) ? ing['original'].toString() : ''}",
              )
              .join("\n")
        : "Ingredients not found.";

    final String instructionsRaw = data['instructions']?.toString() ?? "";

    final String instructionsClean = instructionsRaw.isNotEmpty
        ? instructionsRaw.replaceAll(RegExp(r'<[^>]*>|&nbsp;'), '')
        : "No instructions provided.";

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF8BA882)),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          width: double.infinity,
                          height: 250,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          height: 250,
                          color: Colors.grey,
                          child: const Center(child: Text("No Image")),
                        ),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Ingredients Needed",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(ingredientsText),
                        const Divider(height: 40),
                        const Text(
                          "Instructions",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          instructionsClean,
                          style: const TextStyle(fontSize: 16, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
