class ApiConstants {
  // For Chrome (web)
  //static const String baseUrl = "http://localhost:5000/api";

  // For Android emulator
  //static const String baseUrl = "http://10.0.2.2:5000/api";

   // For Android physical phone

   // Home WiFi
   static const String baseUrl = "http://192.168.1.6:5000/api";
   //static const String socketBaseUrl = "http://192.168.1.5:5000";

   /// Socket.IO endpoint (same scheme/host/port as [baseUrl], without `/api`).
   static String get socketBaseUrl {
     final uri = Uri.parse(baseUrl);
     return Uri(
       scheme: uri.scheme,
       host: uri.host,
       port: uri.port,
     ).toString();
   }

   //Hotspot
   //static const String baseUrl = "http://10.35.3.96:5000/api";

    // College WiFi
   //static const String baseUrl = "http://10.10.157.246:5000/api";
}
