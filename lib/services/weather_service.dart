import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../screens/settings/settings_screen.dart' show weatherCityProvider;

/// Код описания погоды от wttr.in. Перевод в текст — на стороне виджета
/// (см. weather_desc_text.dart), т.к. у WeatherService нет BuildContext.
enum WeatherDescCode {
  sunny,
  clear,
  partlyCloudy,
  cloudy,
  overcast,
  fog,
  lightRain,
  moderateRain,
  heavyRain,
  lightSnow,
  moderateSnow,
  heavySnow,
  blizzard,
  thunder,
  patchyRain,
  patchySnow,
  freezingDrizzle,
  lightDrizzle,
  unknown,
}

class WeatherData {
  final double temp;
  final WeatherDescCode descCode;
  final String rawDescription;
  final String icon;

  WeatherData({
    required this.temp,
    required this.descCode,
    required this.rawDescription,
    required this.icon,
  });
}

final weatherProvider = FutureProvider<WeatherData>((ref) async {
  final city = ref.watch(weatherCityProvider);
  return WeatherService().getWeather(city: city);
});

class WeatherService {
  // Используем открытый API wttr.in — не требует ключа
  Future<WeatherData> getWeather({String city = 'Minsk'}) async {
    final uri = Uri.parse('https://wttr.in/$city?format=j1');
    final response = await http.get(uri).timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) throw Exception('Ошибка погоды');

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final current =
        (json['current_condition'] as List)[0] as Map<String, dynamic>;
    // wttr.in отдаёт числа строками; битый/отсутствующий формат — не повод падать.
    final temp = double.tryParse(current['temp_C'] as String? ?? '') ?? 0.0;
    final weatherDesc =
        (current['weatherDesc'] as List)[0] as Map<String, dynamic>;
    final desc = (weatherDesc['value'] as String).toLowerCase();

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
      descCode: _matchDescCode(desc),
      rawDescription: desc,
      icon: icon,
    );
  }

  WeatherDescCode _matchDescCode(String desc) {
    const map = {
      'sunny': WeatherDescCode.sunny,
      'clear': WeatherDescCode.clear,
      'partly cloudy': WeatherDescCode.partlyCloudy,
      'cloudy': WeatherDescCode.cloudy,
      'overcast': WeatherDescCode.overcast,
      'mist': WeatherDescCode.fog,
      'fog': WeatherDescCode.fog,
      'light rain': WeatherDescCode.lightRain,
      'moderate rain': WeatherDescCode.moderateRain,
      'heavy rain': WeatherDescCode.heavyRain,
      'light snow': WeatherDescCode.lightSnow,
      'moderate snow': WeatherDescCode.moderateSnow,
      'heavy snow': WeatherDescCode.heavySnow,
      'blizzard': WeatherDescCode.blizzard,
      'thundery outbreaks': WeatherDescCode.thunder,
      'patchy rain': WeatherDescCode.patchyRain,
      'patchy snow': WeatherDescCode.patchySnow,
      'freezing drizzle': WeatherDescCode.freezingDrizzle,
      'light drizzle': WeatherDescCode.lightDrizzle,
    };
    for (final entry in map.entries) {
      if (desc.contains(entry.key)) return entry.value;
    }
    return WeatherDescCode.unknown;
  }
}