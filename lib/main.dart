import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'data/local_store.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  //  Optional .env (e.g. PERENUAL_API_KEY). Absent file must not crash the app.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}
  await initializeDateFormatting('nb_NO', null);
  await LocalStore.instance.init();
  await NotificationService.instance.init();
  await NotificationService.instance.requestPermissions();
  runApp(const ProviderScope(child: ThirstTrApp()));
}
/*
                  insert tab
                     v
TODO [status]: number [location][sub-location-if-needed][subject] overall action -> description _explaination or comment if only needed_

TODO [ ]: 12. [objects][heat-source][form] add feat(field) -> add a select for heat source type [oil-heater, eletric-heater, fan-heater, wall-heater, heating-kabels, heat-pump, air-conditioner, fireplace,] _air-condition is a special case since its a drag-source and heat-source_
  
  
* If multiple things are to be done on a subject/place
TODO [ ]: 12. [objects] update forms 
        [X]: 1. [heat-source][form] add feat(field) -> add a select for heat source type [oil-heater, eletric-heater, fan-heater, wall-heater, heating-kabels, heat-pump, air-conditioner, fireplace,]
        [ ]: 2. [room][form] update field(light-intensity) -> add option to lightintensity - "Estimate" _this will trigger estimation model for light exposure_

* multiline is turned on, so you are permitted to wrap the line (remember to tab)
TODO [ ]: 12.  [objects][heat-source][form] add feat(field) -> add a select for heat source type 
               [oil-heater, eletric-heater, fan-heater, wall-heater, heating-kabels, heat-pump, air-conditioner, fireplace,] _air-condition is a special case since its a drag-source and heat-source_


TODO [ ]: 2. [objects][rooms] add this -> _blablabla_
TODO [ ]: 3. [objects][windows] delete that -> _blablabla_
TODO [ ]: 4. [plant_list][layout] refactor this -> _blablabla_
TODO [ ]: 5. [plant_list][add_new]
        [ ]: 1. [plant_list][bar-code] fix this -> _blablabla_
        [ ]: 1. [plant_list][search] add that -> _blablabla_


* bugs or missing stuff needs to have marked with a tag: 
TODO [ ]: 2. (BUG)[objects][rooms] fix this -> _blablabla_ 

*/

/* > VERSION 1.0
TODO [x]: 1. (BUG)[general] fix nordic characters -> they were not activated
TODO [x]: 2. (BUG)[general] fix app version -> was set to 1.0.0, not finished yet, set to 0.1.0
TODO [ ]: 3. [add_new][form] update fields
        [x]: 1. [form][relative-size] update field(select) -> freetext replaced with select from list [tiny, small, medium, large, huge]
        [x]: 2. [form][maturity] update field(select) -> freetext replaced with select from list [seedling, young, juvenile, mature, old]
        [x]: 3. [form][maturity] add feat(auto-update) -> maturity advances by year calculations (date-aquired), extending current value
                not resetting it _MaturityStage.advancedBy()_
        [x]: 4. [form][date-aquired] update field(default) -> defaults to todays date
        [x]: 5. [form][condition] update field(select) -> freetext replaced with select _defaults to Frisk on new plants_
        [x]: 6. [form][hazard] update field(auto-fill) -> kids/pets hazard filled from species data, not manual _poisonousToPets/Humans, Plantasjen 'Giftig'_
        [x]: 7. [form][care-intervals] add feat(override-switch) -> notify user it is recommended not to override; switch activates the fields (deactivated by default)
        [x]: 8. [form][note] add feat(checkmark) -> recommend watering the plant upon registration so the scheduler stays in sync _even though the soil is moist_
        [*]: 9. [form][defaults] add feat(default-values) -> provide defaults for height, size, maturity
                NOTE (status): size/maturity/date/condition defaulted; height from catalogue standardHeightCm when available.
TODO [x]: 4. (BUG)[add_new][search] fix thumbnails -> card thumbnails were empty; Perenual dropped, Mestergrønn/Plantasjen
              images render via web CORS proxy (displayImage) _also applied to my-plants list_
TODO [ ]: 5. [plant_info] update profile
        [x]: 1. (BUG)[profile][cleaning] fix routine -> no forced cleaning for plants that do not specifically need it _only when intervals.cleanDays is set_
        [x]: 2. [profile][om-arten] add feat(card) -> species info + care-tips from API included
        [x]: 3. [profile][care-tips] add feat(mini-version) -> four round circles at top [light-exposure, water-frequenzy-level,
                fertilization-frequenzy-level, notable-care-tag: [needs-shower | easy-care | hard-care | loves-soaking]]
        [x]: 4. [profile][info] add feat(mini-version) -> same four round circles on plant info
        [*]: 5. [profile][pests] add feat(section) -> relevant diseases + pests common in users region
                NOTE (status): Perenual dropped; Mestergrønn/Plantasjen have no pest/disease data -> section currently empty. Needs a new data source.
TODO [x]: 6. [location] add feat(pick-current-location) -> it was missing
TODO [ ]: 7. [notification][location] update notification flow
        [ ]: 1. [notification][home] add feat(standby) -> notify only when user is home; hold notification until current location
                is within home location _DEFERRED: needs background location + geofencing_
        [*]: 2. [notification][gdpr] add feat(permission) -> ask user to allways allow geolocation; INFORM clearly why
                NOTE (status): rationale dialog informs WHY. "Tillat alltid"/background permission not wired (tied to 1.)
        [ ]: 3. [notification][postpone] add feat(postpone) -> let user postpone when notification gets through but they are
                leaving soon _DEFERRED with 1.; postpone action already exists on the notification itself_
TODO [ ]: 8. [engine] watering estimation -> Penman-Monteith / evapotranspiration recipe
              _engine: services/evapotranspiration.dart · wired: services/scheduler.dart watering()_
        [x]: 1. [engine][model] add feat(ET) -> soil-moisture loss modeled as evapotranspiration, the primary driver
        [x]: 2. [engine][model] add feat(ET0) -> FAO-56 Penman-Monteith reference ET, verified vs reference (es=2.338, Δ=0.145 @20°C)
        [x]: 3. [engine][model] add feat(drivers) -> four ET drivers resolved: net radiation (Rn), air temp (T), wind (u2), VPD (es−ea)
        [x]: 4. [engine][model] add feat(VPD) -> VPD from es(T) & ea = es·RH/100; soil heat flux G ≈ 0 for daily indoor
        [x]: 5. [engine][model] add feat(Kc) -> crop coefficient per plant = species thirst × relative-size × maturity
        [x]: 6. [engine][model] add feat(interval) -> ET_plant = Kc × ET0; interval = pot readily-available water / ET_plant
        [x]: 7. [engine][model] add feat(per-plant) -> individual assessment, own room/window/heat/species via CareContext
        [x]: 8. [engine][data] add feat(policy) -> data-source priority: sensor(light-meter, thermometer) > manual > weather-API > statistics
        [x]: 9. [engine][data] add feat(warning) -> statistics flagged as failure: warning icon on care row + red warning in "why" sheet
        [x]: 10. [engine][data] add feat(sensors) -> light-meter (lux) & thermometer (room °C) both OPTIONAL, model degrades gracefully
        [x]: 11. [engine][climate] add feat(humidity) -> indoor humidity by psychrometrics, outdoor absolute moisture re-evaluated at indoor T
        [x]: 12. [engine][climate] add feat(window) -> orientation gives sunlight (Facing); draft gives wind (openFrequency + outdoor wind)
        [x]: 13. [engine][climate] add feat(daylight) -> hours from latitude + day-of-year (astronomical), not assumed
        [x]: 14. [engine][climate] add feat(room-temp) -> estimate from weather-derived indoor / thermostat setpoint / 21°C fallback (_resolveTemp)
        [x]: 15. [engine][climate] add feat(thermostat) -> user reading + heating-cable strength feed local temp (room °C, heat-source tempSetting/heatSetting)
        [x]: 16. [engine][ui] add feat(why-sheet) -> breakdown sheet shows every driver with its data source
        [x]: 17. [engine][climate] add feat(heat-source) -> localized heat source gives local temp rise, physics-based: rated W
                 (label or type default) × setting duty -> radiant/convective split per type -> local ΔT = α·P_rad/(4πd²)/h with
                 d=1 m assumed; room temp from heat balance T_out + ΣQ/UA capped at thermostat/dial target (UA from area + ext walls)
                 _"spredning/intensitet" form fields removed — user no longer guesses_
        [*]: 18. [engine][model] add feat(soil-evaporation) -> evaporation from the soil surface as its own term
                 NOTE (status): folded into Kc; not split from transpiration.
        [*]: 19. [engine][model] add feat(light-Rn) -> light converted to net radiation (Rn)
                 NOTE (status): lux via luminous efficacy + light-band estimate; no PAR conversion / grow-light input.
        [ ]: 20. [engine][climate] add feat(cold-sources) -> AC/fridge + window cold-gradient effect on local temp _no cold-source model yet_
        [ ]: 21. [engine][form] add feat(distance-fields) -> distance-to-source (heat/cold/window) for proximity fall-off (∝1/d²) _only a near/not-near flag today_
        [ ]: 22. [engine][model] add feat(pot-material) -> terracotta vs plastic, evaporation from pot sides
        [ ]: 23. [engine][model] add feat(soil-type) -> peat/coco/mix water-retention _available-water fraction fixed at 0.30 now_
        [ ]: 24. [engine][model] add feat(grow-lights) -> artificial grow lights as a radiation source
        [ ]: 25. [engine][model] add feat(obstructions) -> furniture/walls blocking light or airflow
        [ ]: 26. [engine][model] add feat(window-panes) -> single/double-pane window in the thermal calc
*/
     
/* > VERSION 2.0
TODO [ ]: 9. [general][v2.0] add feat(multiple-homes) -> support more homes, cabins etc. _ignore untill all above are completed_
TODO [ ]: 10. [general][v2.0] add feat(print/share) -> printable overview so plant-sitters can have a care-plan _ignore untill all above are completed_
              ? can this be solved some other way -> contributors for households with more people or temporarily adding a plant-sitter?      
*/

/* > VERSION 3.0
TODO [ ]: 11. [rooms][v3.0] add feat(garden) -> garden as a room type, requires some adjustments _ignore untill all above are completed_
*/