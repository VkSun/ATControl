import 'package:flutter/widgets.dart';
import '../l10n/gen/app_localizations.dart';
import '../services/weather_service.dart';

/// Переводит код описания погоды в локализованный текст.
/// WeatherService не знает про BuildContext — выбор текста происходит
/// здесь, на стороне виджета (см. auth_error_text.dart).
String weatherDescText(BuildContext context, WeatherData weather) {
  final l10n = AppLocalizations.of(context);
  return switch (weather.descCode) {
    WeatherDescCode.sunny => l10n.weatherDescSunny,
    WeatherDescCode.clear => l10n.weatherDescClear,
    WeatherDescCode.partlyCloudy => l10n.weatherDescPartlyCloudy,
    WeatherDescCode.cloudy => l10n.weatherDescCloudy,
    WeatherDescCode.overcast => l10n.weatherDescOvercast,
    WeatherDescCode.fog => l10n.weatherDescFog,
    WeatherDescCode.lightRain => l10n.weatherDescLightRain,
    WeatherDescCode.moderateRain => l10n.weatherDescModerateRain,
    WeatherDescCode.heavyRain => l10n.weatherDescHeavyRain,
    WeatherDescCode.lightSnow => l10n.weatherDescLightSnow,
    WeatherDescCode.moderateSnow => l10n.weatherDescModerateSnow,
    WeatherDescCode.heavySnow => l10n.weatherDescHeavySnow,
    WeatherDescCode.blizzard => l10n.weatherDescBlizzard,
    WeatherDescCode.thunder => l10n.weatherDescThunder,
    WeatherDescCode.patchyRain => l10n.weatherDescPatchyRain,
    WeatherDescCode.patchySnow => l10n.weatherDescPatchySnow,
    WeatherDescCode.freezingDrizzle => l10n.weatherDescFreezingDrizzle,
    WeatherDescCode.lightDrizzle => l10n.weatherDescLightDrizzle,
    WeatherDescCode.unknown => weather.rawDescription,
  };
}
