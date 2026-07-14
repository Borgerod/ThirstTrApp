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
 STATUS KEY: [x] done · [*] half-done (see NOTE) · [ ] not started

 ! BUGS / MISSING
 TODO [*]: add new plant -> search -> card tunmbnails in search results are emtpy. NOTE: this also applies to my-plants list
      NOTE(status): Perenual FREE tier returns an "upgrade_access.jpg" placeholder for every image -> filtered, shows leaf fallback. Real photos need paid tier / Wikimedia (V2).
 TODO [*]: add new plant -> form -> it wont provide with default values for plants (height, size, maturity)
      NOTE(status): size=Middels, maturity=Voksen, date=today defaulted on new plant. Height left blank (no source).
 TODO [x]: add new plant -> form -> relatize-size-select is freetext and not a list, it should be values selected form a list [tiny, small, medium, large, huge]
 TODO [x]: add new plant -> form -> maturity-select is freetext and not a list, it should be values selected form a list [seedling, young, juvenile, mature, old] #this should also be automatically updated by year calculations (date-aquired value)
 TODO [x]: add new plant -> form -> date-aquired should have todays date as default values
 TODO [x]: add new plant -> form -> maturity-select -> this should also be automatically updated by year calculations (date-aquired value) - extending the current maturity value, not resetting it
 TODO [x]: add new plant -> form -> condition-select should not be a free-text but a select
 TODO [x]: add new plant -> form -> hazard for kids and pets should be filled by the API and not manual in form.
 TODO [x]: add new plant -> form -> care-intervals notify the user it is recommended not to override; switch activates the fields (deactivated by default)
 TODO [x]: general -> nordic characters are not activated, which they need to.
 TODO [x]: general -> app version is set to 1.0.0 which is wrong, it is not finished yet and should be 0.1.0.
 TODO [x]: palnt info -> not all plants need cleaning; wont force a cleaning routine for plants that do not specifically need it.

 * UPDATES
 TODO [x]: location -> missing pick current location.
 TODO [ ]: notification/location -> notify only when they are home (standby until current location within home location). DEFERRED: needs background location + geofencing.
 TODO [*]: notification/location -> GDPR, ask the user to allways allow geolocation; INFORM clearly why.
      NOTE(status): rationale dialog informs WHY. "Tillat alltid"/background permission not yet wired (tied to home-detection above).
 TODO [ ]: notification/location -> the user should be able to postpone this notification. DEFERRED with geofencing.
 TODO [x]: add new plant -> form -> NOTE recommending the user water the plant upon registration + checkmark (keeps scheduler in sync).
 TODO [x]: palnt info -> the API provides a ton of useful info and care-tips; included ("Om arten" card).
 TODO [*]: palnt info -> section about relevant diseases and pests common in users region.
      NOTE(status): pests/diseases shown from Perenual; REGION filtering not available from the API.
 TODO [x]: palnt info -> care-tips -> mini-version: four round circles [light-exposure, water-frequenzy-level, fertilization-frequenzy-level, notable-care-tag].
 TODO [x]: palnt info -> plant info has the same four round circles.

 ~ WATERING ESTIMATION — Penman-Monteith / evapotranspiration recipe
   (engine: services/evapotranspiration.dart · wired: services/scheduler.dart watering())
 TODO [x]: model soil-moisture loss as evapotranspiration (ET) as the primary driver.
 TODO [x]: FAO-56 Penman-Monteith reference ET (ET0) — verified vs reference (es=2.338, Δ=0.145 @20°C).
 TODO [x]: four ET drivers resolved — net radiation (Rn), air temp (T), wind (u2), VPD (es−ea).
 TODO [x]: VPD from es(T) & ea = es·RH/100; soil heat flux G ≈ 0 for daily indoor.
 TODO [x]: crop coefficient Kc per plant = species thirst × relative-size × maturity.
 TODO [x]: ET_plant = Kc × ET0; interval = pot readily-available water / ET_plant.
 TODO [x]: per-plant individual assessment (own room/window/heat/species via CareContext).
 TODO [x]: data-source policy sensor(light-meter, thermometer) > manual > weather-API > statistics.
 TODO [x]: statistics flagged as a failure — warning icon on care row + red warning in "why" sheet.
 TODO [x]: light-meter (lux) & thermometer (room °C) both OPTIONAL; model degrades gracefully.
 TODO [x]: indoor humidity by psychrometrics — outdoor absolute moisture re-evaluated at indoor T.
 TODO [x]: window orientation → sunlight (Facing) and window draft → wind (openFrequency + outdoor wind).
 TODO [x]: daylight hours from latitude + day-of-year (astronomical), not assumed.
 TODO [x]: room temperature estimate (weather-derived indoor / thermostat setpoint / fallback).
 TODO [x]: user thermostat reading + heating-cable strength feed local temp (room °C, heat-source setting/target).
 TODO [x]: "why" breakdown sheet shows every driver with its data source.
 TODO [x]: localized heat source → local temp rise. Physics-based: rated W (label or type default) ×
      setting duty → radiant/convective split per type → local ΔT = α·P_rad/(4πd²)/h with d=1 m assumed;
      room temp from heat balance T_out + ΣQ/UA capped at thermostat/dial target (UA from area + ext walls).
      User no longer guesses "spredning/intensitet" — those fields are removed from the form.
 TODO [*]: soil-surface evaporation. NOTE: folded into Kc; not split from transpiration as its own term.
 TODO [*]: light → Rn. NOTE: lux via luminous efficacy + light-band estimate; no PAR conversion / grow-light input.
 TODO [ ]: cold sources (AC, fridge) + window cold-gradient effect on local temp — no cold-source model yet.
 TODO [ ]: distance-to-source inputs (heat/cold/window) for proximity fall-off (∝1/d²) — only a near/not-near flag today.
 TODO [ ]: pot material (terracotta vs plastic) → evaporation from pot sides.
 TODO [ ]: soil type (peat/coco/mix) → water-retention (available-water fraction fixed at 0.30 now).
 TODO [ ]: artificial grow lights as a radiation source.
 TODO [ ]: obstructions (furniture/walls) blocking light or airflow.
 TODO [ ]: single/double-pane window in the thermal calc.
*/

/* > TO DO's
! BUGS / MISSING
TODO [x]: add new plant -> search -> card tunmbnails in search results are emtpy. NOTE: this also applies to my-plants list  # fixed: Perenual dropped; Mestergrønn/Plantasjen images render via web CORS proxy (displayImage)
TODO [*]: add new plant -> form -> it wont provide with default values for plants (height, size, maturity)  # size/maturity/date/condition defaulted; height now from catalogue standardHeightCm when available
TODO [x]: add new plant -> form -> relatize-size-select is freetext and not a list, it should be values selected form a list [tiny, small, medium, large, huge]
TODO [x]: add new plant -> form -> maturity-select is freetext and not a list, it should be values selected form a list [seedling, young, juvenile, mature, old] #this should also be automatically updated by year calculations (date-aquired value)
TODO [x]: add new plant -> form -> date-aquired should have todays date as default values
TODO [x]: add new plant -> form -> maturity-select -> this should also be automatically updated by year calculations (date-aquired value) - it is important that the update is 'extending' the current maturity value and does not reset it (if i aquire a juvenile plant,  and then have it for 2 years, then the maturity should be maturity=juvenile+2years, and not maturity=2years)  # MaturityStage.advancedBy()
TODO [x]: add new plant -> form -> condition-select should not be a free-text but a select  # + defaults to Frisk on new plants
TODO [x]: add new plant -> form -> hazard for kids and pets should not be automaticalluy filled by the API and not manual in form.  # from species poisonousToPets/Humans (Plantasjen 'Giftig')
TODO [x]: add new plant -> form -> care-intervals should notify the user that; it is recommended that the user does not override because the app will calculate this based on multiple factors. then give add a checkbox or switch that activates the form fields (deactivated by default)
TODO [x]: general -> nordic characters are not activated, which they need to.
TODO [x]: general -> app version is set to 1.0.0 which is wrong, it is not finished yet and should be 0.1.0.
TODO [x]: plant info -> not all plants need cleaning, make sure it wont force a cleaning routine for plants that do not specifically need it.  # cleaning opt-in (only when intervals.cleanDays set)
TODO [x]: palnt info -> need to estimate the room temperature  # weather-derived indoor estimate + thermostat setpoint + 21°C fallback (evapotranspiration.dart _resolveTemp)
TODO [x]: palnt info -> user input thermostat reading (or heating cable strength)  # room °C (thermometer) + heat-source tempSetting/heatSetting feed local temp



* UPDATES
TODO [x]: location -> missing pick current location.
TODO [ ]: notification/location -> make sure that the user is notified only when they are home. (if they are set to be notified at 11 but they wont be home from work before later in the day, have the notification on standby until theyre current location is within home location)  # DEFERRED: needs background location + geofencing
TODO [*]: notification/location -> due to GDPR, we need ask the user to allways allow geolocation. it is important that we INFORM the user clearly why this is important.  # rationale dialog informs WHY; "always allow"/background perm not wired (tied to home-detection)
TODO [ ]: notification/location -> the user should be able to postpone this notification. (notification gets through but the user is leaving soon and dont have time..)  # DEFERRED with geofencing (postpone action exists on the notification itself)
TODO [x]: add new plant -> form -> we should add a NOTE to the user that we recommend that the user water the plant upon registration (even though the soil is moist), this is so that the scheduler wont be out of sync with the plant. add a checkmark for that.
TODO [x]: palnt info -> the API provides with a ton of useful information about the plant and care-tips. please include this in the app.  # "Om arten" + care-tips cards
TODO [*]: palnt info -> the plant profile should also include a section about relevant diseases and also importantly; pests and diseases that are common in users region.  # NOTE: Perenual dropped; Mestergrønn/Plantasjen have no pest/disease data -> section currently empty. Needs a new data source.
TODO [x]: palnt info -> care-tips ->  I want a mini-version of care-tips at the top of caretips, it will be four round circles with [light-exposure, water-frequenzy-level, frertilization-frequenzy-level, notable-care-tag: [needs-shower | easy-care | hard-care | loves soaking | blablabla ]]
TODO [x]: palnt info -> i the same want plant info to have a tiny mini-version of care-tips, it will be four round circles with [light-exposure, water-frequenzy-level, frertilization-frequenzy-level, notable-care-tag: [needs-shower | easy-care | hard-care | loves soaking | blablabla ]]



*UPDATES (v2.0) ignore this untill all above are completed.
TODO [ ]: _topic_ -> add: add-multiple-homes / cabins etc.
TODO [ ]: _topic_ -> add: print overview function that can be actually printed or shared to other people (so that plant sitters can have a care-plan)
? can this be solved in some other means; add contributors for when there are more people in a household or temporarily adding a plant-sitter 

*UPDATES (v3.0) ignore this untill all above are completed.
TODO [ ]: general -> add garden as a room (require some adjustments)


TODO [ ]: _topic_ -> _content_

*/
