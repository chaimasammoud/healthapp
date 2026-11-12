/// Clé Gemini : https://aistudio.google.com/apikey
/// Soit tu la colles ici, soit tu lances :
/// flutter run --dart-define=GEMINI_API_KEY=ta_cle
class AppConfig {
  static const geminiApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: 'AQ.Ab8RN6KP9MvZ7BMZvR8uuHT-ZLey8NQ9OVLev-dHMsP_Md00EQ');
  static const geminiModel = String.fromEnvironment('GEMINI_MODEL', defaultValue: 'gemini-flash-latest');
}
