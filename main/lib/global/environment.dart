class Environment {
  // static String apiUrl = "http://cliniapp.net:5000/api";
  // static String socketUrl = "http://cliniapp.net:5000";

  // Environment configuration: Use local server by default
  // To use production VPS server, set USE_PRODUCTION=true
  static bool get useProduction =>
      const bool.fromEnvironment('USE_PRODUCTION', defaultValue: false);

  // Local development server (default)
  // Using your local IP address for physical devices on same network
  static String get localServerUrl => "http://192.168.100.97:3000";
  // Alternative options (uncomment if needed):
  // For Android emulator: "http://10.0.2.2:3000"
  // For localhost (same machine): "http://localhost:3000"

  // VPS Backend Server (Hosted at http://93.95.231.249:3000)
  // Use this for production or when local server is not available
  static String get vpsServerUrl => "http://93.95.231.249:3000";

  // Active server URL based on environment
  // Default: VPS server (http://93.95.231.249:3000)
  // Change to localServerUrl if you want to use local development server
  static String get serverUrl => vpsServerUrl;

  static String get apiUrl => "$serverUrl/api";
  static String get urlArchivos => "$serverUrl/CryptoChatfiles/";
  static String get socketUrl => serverUrl;
  //":5000"
  static String urlWebPage = "https://www.CryptoChat.com";
  static String urlTerminos = "$urlWebPage/es/terminos/";
  static String urlFAQ = "$urlWebPage/es/preguntas/";
  static List<String> locales = ['es', 'en'];
  static List<String> idiomas = ['Español', 'English'];

  static String urlSvrNet = "https://www.CryptoChat.net";
  static String urlService = "$urlSvrNet/C_service/";

  static List<String> userAvatar = [
    'abogado.png',
    'astronauta.png',
    'barbero.png',
    'blanco.png',
    'bombero.png',
    'boxeo.png',
    'buzo.png',
    'chaplin.png',
    'chef.png',
    'cientifico.png',
    'danyels.png',
    'doctor.png',
    'enfermera.png',
    'enfermero.png',
    'inspector.png',
    'jamaica.png',
    'juez.png',
    'negro.png',
    'ninja.png',
    'police.png',
    'quimico.png',
    'toxico.png',
    'veneco.png',
  ];
  static List<String> groupAvatar = ['CryptoChat.png', 'gris.png'];
}
