import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';

void main(List<String> args) async {
  stdout.write('Enter city name: ');
  final input = stdin.readLineSync() ?? '';

  final fetch = FetchData();

  final location = await fetch.getCityName(input); // await here
  if (location == null) {
    print('City not found.');
    return;
  }

  final cityName = location['name'] as String;
  final country = location['country'] as String;
  final lat = (location['latitude'] as num).toDouble();
  final lon = (location['longitude'] as num).toDouble();

  final weather = await fetch.getWeather(lat, lon);
  if (weather == null) {
    print('Weather not found');
    return;
  }

  String getCondition(int code) {
    if (code == 0 || code == 1) return '☀️  Sunny';
    if (code == 2 || code == 3) return '⛅  Cloudy';
    if (code >= 51 && code <= 57) return '🌦  Light Rain';
    if (code >= 61 && code <= 67) {
      if (code == 61 || code == 66) return '🌦  Light Rain';
      return '🌧  Rain';
    }
    if (code >= 80 && code <= 82) {
      if (code == 80) return '🌦  Light Rain';
      return '🌧  Rain';
    }
    if (code >= 71 && code <= 77) return '❄️  Snow';
    if (code >= 95 && code <= 99) return '⛈️  Thunderstorm';
    if (code == 45 || code == 48) return '🌫  Foggy';
    return '🌡  Unknown';
  }

  final weatherCode = (weather['weathercode'] as int);
  final temperature = (weather['temperature_2m'] as num).toDouble();
  final windspeed = (weather['windspeed_10m'] as num).toDouble();

  print('\nCity Name: $cityName, $country');
  print('\nCondition: ${getCondition(weatherCode)}');
  print('\nWindspeed: $windspeed');
  print('\nTemp: $temperature');
  print('\nPosition: $lat, $lon');
}

class FetchData {
  Future<Map<String, dynamic>?> getCityName(String cityName) async {
    final uri = Uri.parse(
      'https://geocoding-api.open-meteo.com/v1/search'
      '?name=${Uri.encodeComponent(cityName)}&count=1&language=en&format=json',
    );

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>?;

      /* expectred data return

   {
  "results": [{
    "name": "Semarang",
    "latitude": -6.9932,
    "longitude": 110.4203,
    "country": "Indonesia"
  }]
   }. 

   */

      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) return null;

      if (decoded['results'] == null) return null;

      final results = decoded['results'] as List<dynamic>;
      return results[0] as Map<String, dynamic>;
    }
  }

  Future<Map<String, dynamic>?> getWeather(double lat, double lon) async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lat&longitude=$lon'
      '&current=temperature_2m,weathercode,windspeed_10m',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) return null;

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) return null;

    return decoded['current'] as Map<String, dynamic>;
  }
}
