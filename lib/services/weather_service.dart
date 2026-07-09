import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class WeatherData {
  final double temp;
  final String description;
  final String icon;

  WeatherData({required this.temp, required this.description, required this.icon});
}

final weatherProvider = FutureProvider<WeatherData>((ref) async {
  return WeatherService().getWeather();
});

class WeatherService {
  // Используем открытый API wttr.in — не требует ключа
  Future<WeatherData> getWeather({String city = 'Minsk'}) async {
    final uri = Uri.parse('https://wttr.in/$city?format=j1');
    final response = await http.get(uri).timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) throw Exception('Ошибка погоды');

    final json = jsonDecode(response.body);
    final current = json['current_condition'][0];
    // wttr.in отдаёт числа строками; битый/отсутствующий формат — не повод падать.
    final temp = double.tryParse(current['temp_C'] as String? ?? '') ?? 0.0;
    final desc = (current['weatherDesc'][0]['value'] as String).toLowerCase();

    final code = int.tryParse(current['weatherCode'] as String? ?? '');
    String icon;
    if (code == null) {
      icon = '☁';
    } else if (code == 113) {
      icon = '☀';
    } else if (code == 116) {
      icon = '⛅';
    } else if (code <= 122) {
      icon = '☁';
    } else if (code <= 185) {
      icon = '🌦';
    } else if (code <= 246) {
      icon = '❄';
    } else if (code <= 299) {
      icon = '🌧';
    } else if (code <= 399) {
      icon = '🌨';
    } else {
      icon = '⛈';
    }

    return WeatherData(
      temp: temp,
      description: _translateDesc(desc),
      icon: icon,
    );
  }

  String _translateDesc(String desc) {
    const map = {
      'sunny': 'солнечно',
      'clear': 'ясно',
      'partly cloudy': 'переменная облачность',
      'cloudy': 'облачно',
      'overcast': 'пасмурно',
      'mist': 'туман',
      'fog': 'туман',
      'light rain': 'небольшой дождь',
      'moderate rain': 'дождь',
      'heavy rain': 'сильный дождь',
      'light snow': 'небольшой снег',
      'moderate snow': 'снег',
      'heavy snow': 'сильный снег',
      'blizzard': 'метель',
      'thundery outbreaks': 'гроза',
      'patchy rain': 'местами дождь',
      'patchy snow': 'местами снег',
      'freezing drizzle': 'ледяная морось',
      'light drizzle': 'морось',
    };
    for (final entry in map.entries) {
      if (desc.contains(entry.key)) return entry.value;
    }
    return desc;
  }
}