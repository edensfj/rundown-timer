import 'package:screen_retriever/screen_retriever.dart';

/// Pantallas conectadas en escritorio.
Future<List<Display>> getAllDisplays() => screenRetriever.getAllDisplays();
