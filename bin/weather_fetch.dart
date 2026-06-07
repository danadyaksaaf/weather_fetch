import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';

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

void printCurrentWeather(
  String cityName,
  String country,
  double lat,
  double lon,
  Map<String, dynamic> weather,
) {
  final weatherCode = weather['weathercode'] as int;
  final temperature = (weather['temperature_2m'] as num).toDouble();
  final windspeed = (weather['windspeed_10m'] as num).toDouble();

  print('\nCity    : $cityName, $country');
  print('Position: $lat, $lon');
  print('─' * 35);
  print('Condition : ${getCondition(weatherCode)}');
  print('Temp      : ${temperature}°C');
  print('Windspeed : $windspeed km/h');
}

void printForecastTable(
  String cityName,
  String country,
  List<HourlyForecast> forecasts,
) {
  // Column widths
  const int wTime = 6;
  const int wTemp = 7;
  const int wRain = 7;
  const int wWind = 10;
  const int wCond = 18;

  String pad(String s, int width) {
    if (s.length >= width) return s.substring(0, width);
    return s + ' ' * (width - s.length);
  }

  final divider =
      '├${'─' * (wTime + 2)}┼${'─' * (wTemp + 2)}┼${'─' * (wRain + 2)}┼${'─' * (wWind + 2)}┼${'─' * (wCond + 2)}┤';
  final topBorder =
      '┌${'─' * (wTime + 2)}┬${'─' * (wTemp + 2)}┬${'─' * (wRain + 2)}┬${'─' * (wWind + 2)}┬${'─' * (wCond + 2)}┐';
  final botBorder =
      '└${'─' * (wTime + 2)}┴${'─' * (wTemp + 2)}┴${'─' * (wRain + 2)}┴${'─' * (wWind + 2)}┴${'─' * (wCond + 2)}┘';

  String row(String time, String temp, String rain, String wind, String cond) {
    return '│ ${pad(time, wTime)} │ ${pad(temp, wTemp)} │ ${pad(rain, wRain)} │ ${pad(wind, wWind)} │ ${pad(cond, wCond)} │';
  }

  print('\n📅 24-Hour Forecast — $cityName, $country\n');
  print(topBorder);
  print(row('Time', 'Temp', 'Rain %', 'Wind km/h', 'Condition'));
  print(divider);

  for (final f in forecasts) {
    // time is "2025-01-01T14:00" → extract "14:00"
    final timePart = f.time.length >= 16 ? f.time.substring(11, 16) : f.time;
    final temp = '${f.temperature.toStringAsFixed(1)}°C';
    final rain = '${f.precitipiationProbability}%';
    final wind = '${f.windspeed.toStringAsFixed(1)}';
    final cond = getCondition(f.weatherCode);

    print(row(timePart, temp, rain, wind, cond));
  }

  print(botBorder);
}

void checkOperatorMsg() {
  stdout.write('''
zWeather CLI by Zdyaksa Labs, (idiotic project)\n
USAGE => zweather-cli (OPERATORS)\n
AVAILABLE OPERATORS:
forecast => Check for weather forecasts
current   => Check for current weather)
''');
}

void main(List<String> args) async {
  if (args.isEmpty) {
    checkOperatorMsg();
    return;
  }

  final mode = args[0].trim().toLowerCase();
  if (mode != 'forecast' && mode != 'current') {
    checkOperatorMsg();
    return;
  }

  stdout.write('Enter city name: ');
  final cityNameinput = stdin.readLineSync() ?? '';

  final fetch = FetchData();

  final location = await fetch.getCityName(cityNameinput); // await here
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

  if (mode == 'forecast') {
    final forecasts = await fetch.getHourlyForecast(lat, lon);
    if (forecasts == null || forecasts.isEmpty) {
      print('Forecast data not available.');
      return;
    }
    printForecastTable(cityName, country, forecasts);
  } else if (mode == 'current') {
    final weather = await fetch.getWeather(lat, lon);
    if (weather == null) {
      print('Weather not found.');
      return;
    }
    printCurrentWeather(cityName, country, lat, lon, weather);
  }
}

class HourlyForecast {
  final String time;
  final double temperature;
  final int weatherCode;
  final int precitipiationProbability;
  final double windspeed;

  HourlyForecast({
    required this.time,
    required this.temperature,
    required this.weatherCode,
    required this.precitipiationProbability,
    required this.windspeed,
  });
}

class FetchData {
  Future<Map<String, dynamic>?> getCityName(String cityName) async {
    final uri = Uri.parse(
      'https://geocoding-api.open-meteo.com/v1/search'
      '?name=${Uri.encodeComponent(cityName)}&count=1&language=en&format=json',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) return null;

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) return null;

    if (decoded['results'] == null) return null;

    final results = decoded['results'] as List<dynamic>;
    return results[0] as Map<String, dynamic>;
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

  Future<List<HourlyForecast>?> getHourlyForecast(
    double lat,
    double lon,
  ) async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lat&longitude=$lon'
      '&hourly=temperature_2m,precipitation_probability,weathercode,windspeed_10m'
      '&forecast_days=1',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) return null;

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) return null;

    final hourly = decoded['hourly'] as Map<String, dynamic>?;
    if (hourly == null) return null;

    final times = hourly['time'] as List<dynamic>;
    final temps = hourly['temperature_2m'] as List<dynamic>;
    final rains = hourly['precipitation_probability'] as List<dynamic>;
    final codes = hourly['weathercode'] as List<dynamic>;
    final winds = hourly['windspeed_10m'] as List<dynamic>;

    return List.generate(times.length, (i) {
      return HourlyForecast(
        time: times[i] as String,
        temperature: (temps[i] as num).toDouble(),
        precitipiationProbability: (rains[i] as num).toInt(),
        weatherCode: (codes[i] as num).toInt(),
        windspeed: (winds[i] as num).toDouble(),
      );
    });
  }
}
