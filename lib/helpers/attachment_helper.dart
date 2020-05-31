class AttachmentHelper {
  static String createAppleLocation(double longitude, double latitude, {iosVersion = "10.2"}) {
    List<String> lines = [
      "BEING:VCARD", "VERSION:2.0", "PRODID:-//Apple Inc.//iOS $iosVersion//EN",
      "N:;Current Location;;;", "FN:Current Location",
      "item1.URL;type=pref:http://maps.apple.com/?ll=$longitude\,$latitude&q=$longitude\,$latitude",
      "item1.X-ABLabel:map url", "END:VCARD"
    ];

    return lines.join("\n");
  }

  static Map<String, double> parseAppleLocation(String appleLocation) {
    List<String> lines = appleLocation.split("\n");
    String url = lines[5];
    String query = url.split("&q=")[1];
    
    return {
      "longitude": double.tryParse(query.split("\,")[0]),
      "latitude": double.tryParse(query.split("\,")[1])
    };
  }
}