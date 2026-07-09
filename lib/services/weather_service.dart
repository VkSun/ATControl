import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/logger.dart';

final _log = Logger('WeatherService');

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
    try {
      final uri = Uri.parse('https://wttr.in/$city?format=j1');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        _log.warning('Weather API returned status ${response.statusCode}');
        throw Exception('Ошибка получения погоды');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final currentCondition = json['current_condition'];
      
      if (currentCondition is! List || currentCondition.isEmpty) {
        _log.warning('Unexpected weather API response format');
        throw Exception('Ошибка получения погоды');
      }

      final current = currentCondition[0] as Map<String, dynamic>;

      // Безопасное получение данных с fallback'ом
      final tempStr = current['temp_C']?.toString() ?? '0';
      final temp = double.tryParse(tempStr) ?? 0.0;

      final descList = current['weatherDesc'];
      final desc = (descList is List && descList.isNotEmpty)
          ? (descList[0] as Map<String, dynamic>?)?.containsKey('value') == true
              ? ((descList[0] as Map)['value'] as String?)?.toLowerCase() ?? 'неизвестно'
              : 'неизвестно'
          : 'неизвестно';

      final codeStr = current['weatherCode']?.toString() ?? '0';
      final code = int.tryParse(codeStr) ?? 0;

      final icon = _iconForWeatherCode(code);

      return WeatherData(
        temp: temp,
        description: _translateDesc(desc),
        icon: icon,
      );
    } catch (e, s) {
      _log.error('getWeather failed for city: $city', e, s);
      // Возвращаем заглушку вместо выброса исключения
      return WeatherData(
        temp: 0.0,
        description: 'Данные недоступны',
        icon: '❓',
      );
    }
  }

  String _iconForWeatherCode(int code) {
    if (code == 113) {
      return '☀';
    } else if (code == 116) {
      return '⛅';
    } else if (code <= 122) {
      return '☁';
    } else if (code <= 185) {
      return '🌦';
    } else if (code <= 246) {
      return '❄';
    } else if (code <= 299) {
      return '🌧';
    } else if (code <= 399) {
      return '🌨';
    } else {
      return '⛈';
    }
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
