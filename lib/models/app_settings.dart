import '../core/enums.dart';
import '../core/json.dart';

/// Global app/user preferences. Defaults are Norwegian + metric per spec.
class AppSettings {
  AppSettings({
    this.languageCode = 'nb',
    this.units = UnitSystem.metric,
    this.locationName,
    this.latitude,
    this.longitude,
    this.perenualApiKey = '',
    this.portfolioView = PortfolioView.groupByRoom,
    this.notificationsEnabled = true,
    this.notifyHour = 9,
    this.useWeatherAdjustment = true,
  });

  String languageCode;
  UnitSystem units;

  /// Home location for climate-based adjustments.
  String? locationName;
  double? latitude;
  double? longitude;

  /// Perenual key; entered in Settings, empty until the user adds one.
  String perenualApiKey;

  PortfolioView portfolioView;
  bool notificationsEnabled;

  /// Hour of day (0-23) reminders fire.
  int notifyHour;
  bool useWeatherAdjustment;

  bool get hasLocation => latitude != null && longitude != null;
  bool get hasApiKey => perenualApiKey.trim().isNotEmpty;

  AppSettings copyWith({
    String? languageCode,
    UnitSystem? units,
    String? locationName,
    double? latitude,
    double? longitude,
    String? perenualApiKey,
    PortfolioView? portfolioView,
    bool? notificationsEnabled,
    int? notifyHour,
    bool? useWeatherAdjustment,
  }) =>
      AppSettings(
        languageCode: languageCode ?? this.languageCode,
        units: units ?? this.units,
        locationName: locationName ?? this.locationName,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        perenualApiKey: perenualApiKey ?? this.perenualApiKey,
        portfolioView: portfolioView ?? this.portfolioView,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        notifyHour: notifyHour ?? this.notifyHour,
        useWeatherAdjustment: useWeatherAdjustment ?? this.useWeatherAdjustment,
      );

  Map<String, dynamic> toJson() => {
        'languageCode': languageCode,
        'units': units.id,
        'locationName': locationName,
        'latitude': latitude,
        'longitude': longitude,
        'perenualApiKey': perenualApiKey,
        'portfolioView': portfolioView.id,
        'notificationsEnabled': notificationsEnabled,
        'notifyHour': notifyHour,
        'useWeatherAdjustment': useWeatherAdjustment,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        languageCode: asString(j['languageCode']) ?? 'nb',
        units: UnitSystem.fromId(asString(j['units'])),
        locationName: asString(j['locationName']),
        latitude: asDouble(j['latitude']),
        longitude: asDouble(j['longitude']),
        perenualApiKey: asString(j['perenualApiKey']) ?? '',
        portfolioView: j['portfolioView'] != null
            ? PortfolioView.fromId(asString(j['portfolioView']))
            // Migrate legacy bool: groupByRoom true → grouped, false → flat list.
            : (asBool(j['groupByRoom'], fallback: true)
                ? PortfolioView.groupByRoom
                : PortfolioView.groupByView),
        notificationsEnabled: asBool(j['notificationsEnabled'], fallback: true),
        notifyHour: asInt(j['notifyHour']) ?? 9,
        useWeatherAdjustment: asBool(j['useWeatherAdjustment'], fallback: true),
      );
}
