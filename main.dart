import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ColorWithHsl {

  ColorWithHsl({
    required this.originalHex,
    required this.hue,
    required this.saturation,
    required this.lightness,
  });
  final String originalHex;
  final double hue;
  final double saturation;
  final double lightness;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {

  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'M3 Primary Color Sweeper',
      debugShowCheckedModeBanner: false,
      home: PrimaryColorSweeper(),
    );
  }
}

class PrimaryColorSweeper extends StatefulWidget {

  const PrimaryColorSweeper({super.key});

  @override
  State<PrimaryColorSweeper> createState() => PrimaryColorSweeperState();
}

class PrimaryColorSweeperState extends State<PrimaryColorSweeper> {

  // Iterate over RGB 0x000000 to 0xFFFFFF... 16,777,216 seeds total
  static const int maxSeeds = 0x1000000;

  // How many seeds to process per tick
  static const int batchSize = 1000;

  int currentSeedIndex = 0;

  List<int> uniquePrimaryColors = [];
  List<String> sortedHexColorCodesList = [];
  List<String> shareList = [];

  Timer? processingTimer;
  Timer? displayTimer;

  bool isRunning = false;

  Future<File> saveStringsToFile(List<String> uniquePrimaryColorsList) async {

    final Directory tempDir = await getTemporaryDirectory();
    final String filePath = '${tempDir.path}/primary_colors.txt';
    final String fileContents = uniquePrimaryColorsList.join('\n');
    final File file = File(filePath);
    return file.writeAsString(fileContents);
  }

  Color? hexToColor(String colorCodeInHex) {

    String hexColorCode = colorCodeInHex.trim();

    if (hexColorCode.startsWith('#')) {
      hexColorCode = hexColorCode.substring(1);
    }

    if (hexColorCode.startsWith('0x') || hexColorCode.startsWith('0X')) {
      hexColorCode = hexColorCode.substring(2);
    }

    if (hexColorCode.length == 6) {
      hexColorCode = 'FF$hexColorCode';
    } else if (hexColorCode.length != 8) {
      return null; // Unsupported format
    }

    final colorCode = int.tryParse(hexColorCode, radix: 16);
    if (colorCode == null) return null;

    return Color(colorCode);
  }

  List<String> sortHexColorsByHue(List<String> hexColorCodesList) {

    final List<ColorWithHsl> sortedColorsList = [];

    for (final hexColorCode in hexColorCodesList) {
      final colorCode = hexToColor(hexColorCode);
      if (colorCode == null) continue;

      final hslColor = HSLColor.fromColor(colorCode);
      sortedColorsList.add(
        ColorWithHsl(
          originalHex: hexColorCode,
          hue: hslColor.hue,
          saturation: hslColor.saturation,
          lightness: hslColor.lightness,
        ),
      );
    }

    sortedColorsList.sort((a, b) {

      final hueComp = a.hue.compareTo(b.hue);
      if (hueComp != 0) return hueComp;

      final satComp = a.saturation.compareTo(b.saturation);
      if (satComp != 0) return satComp;

      return a.lightness.compareTo(b.lightness);
    });

    return sortedColorsList.map((color) => color.originalHex).toList();
  }

  Future<void> writeArraytoFile(List<String> hexColorCodesList) async {

    try {
      final File file = await saveStringsToFile(hexColorCodesList);

      final shareParams = ShareParams(
        subject: 'List of Unique Generated Primary Colors',
        text: ' ',
        files: [XFile(file.path)],
      );

      await SharePlus.instance.share(shareParams);
    }
    catch (error) {
      print('Error sharing file: $error');
    }
  }

  void start() {

    if (isRunning) return;

    isRunning = true;

    // Time alloted to process batch
    processingTimer = Timer.periodic(const Duration(milliseconds: 200), (
      timer,
    ) {
      processBatch();
    });

    // Update UI timer
    displayTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      setState(() {});
    });

    setState(() {});
  }

  void stop() {

    displayTimer?.cancel();
    displayTimer = null;
    processingTimer?.cancel();
    processingTimer = null;
    isRunning = false;

    shareList = uniquePrimaryColors.map(
      (setElement) => setElement.toRadixString(16).toString().toUpperCase(),
    ).toList();

    writeArraytoFile(shareList);

    setState(() {});
  }

  void reset() {

    stop();
    currentSeedIndex = 0;
    uniquePrimaryColors.clear();
    setState(() {});
  }

  void processBatch() {

    int processed = 0;

    while (processed < batchSize && currentSeedIndex < maxSeeds) {
      final int rgb = currentSeedIndex;
      final Color seedColor = Color(0xFF000000 | rgb);

      final generatedColorScheme = ColorScheme.fromSeed(seedColor: seedColor);

      final int primaryColor = generatedColorScheme.primary.toARGB32().toInt();

      if (uniquePrimaryColors.contains(primaryColor)) {
      }
      else {
        uniquePrimaryColors.add(primaryColor);
      }

      currentSeedIndex++;
      processed++;

      sortedHexColorCodesList = sortHexColorsByHue(
        uniquePrimaryColors.map((e) => e.toRadixString(16)).toList(),
      );

      uniquePrimaryColors.clear();
      uniquePrimaryColors = sortedHexColorCodesList.map(
        (e) => int.parse(e, radix: 16)
      ).toList();
    }

    if (currentSeedIndex >= maxSeeds) {
      stop();
    }
  }

  @override
  void dispose() {

    displayTimer?.cancel();
    displayTimer = null;
    processingTimer?.cancel();
    processingTimer = null;
    super.dispose();
  }

  double get progress =>
      currentSeedIndex == 0 ? 0 : currentSeedIndex / maxSeeds;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('M3 Primary Color Sweeper'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Seeds processed: $currentSeedIndex / $maxSeeds',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 16),
            Text(
              'Unique primary colors found: ${uniquePrimaryColors.length}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                itemCount: uniquePrimaryColors.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemBuilder: (context, index) {
                  final colorValue = uniquePrimaryColors.elementAt(index);
                  return Container(
                    alignment: Alignment.topCenter,
                    color: Color(colorValue),
                    child: Text(
                      colorValue.toRadixString(16).toUpperCase(),
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: Colors.white,
                        backgroundColor: Colors.black,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: isRunning ? null : start,
                  style: ButtonStyle(
                    backgroundColor: isRunning
                        ? WidgetStateProperty.all(Colors.grey)
                        : WidgetStateProperty.all(Colors.green),
                  ),
                  child: const Text(
                    'Start',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: isRunning ? stop : null,
                  style: ButtonStyle(
                    backgroundColor: isRunning
                        ? WidgetStateProperty.all(Colors.red)
                        : WidgetStateProperty.all(Colors.grey),
                  ),
                  child: const Text(
                    'Stop',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(onPressed: reset, child: const Text('Reset')),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Sweeping 16,777,216 seed colors take a few minutes.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
