import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'data/local_store.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Optional .env (e.g. PERENUAL_API_KEY). Absent file must not crash the app.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}
  await initializeDateFormatting('nb_NO', null);
  await LocalStore.instance.init();
  await NotificationService.instance.init();
  await NotificationService.instance.requestPermissions();
  runApp(const ProviderScope(child: ThirstTrApp()));
}

// STATUS KEY: [x] done · [*] half-done (see NOTE) · [ ] not started
//
// ! BUGS / MISSING
// [*]: add new plant -> search -> card tunmbnails in search results are emtpy. NOTE: this also applies to my-plants list
//      NOTE(status): Perenual FREE tier returns an "upgrade_access.jpg" placeholder for every image -> filtered, shows leaf fallback. Real photos need paid tier / Wikimedia (V2).
// [*]: add new plant -> form -> it wont provide with default values for plants (height, size, maturity)
//      NOTE(status): size=Middels, maturity=Voksen, date=today defaulted on new plant. Height left blank (no source).
// [x]: add new plant -> form -> relatize-size-select is freetext and not a list, it should be values selected form a list [tiny, small, medium, large, huge]
// [x]: add new plant -> form -> maturity-select is freetext and not a list, it should be values selected form a list [seedling, young, juvenile, mature, old] #this should also be automatically updated by year calculations (date-aquired value)
// [x]: add new plant -> form -> date-aquired should have todays date as default values
// [x]: add new plant -> form -> maturity-select -> this should also be automatically updated by year calculations (date-aquired value) - extending the current maturity value, not resetting it
// [x]: add new plant -> form -> condition-select should not be a free-text but a select
// [x]: add new plant -> form -> hazard for kids and pets should be filled by the API and not manual in form.
// [x]: add new plant -> form -> care-intervals notify the user it is recommended not to override; switch activates the fields (deactivated by default)
// [x]: general -> nordic characters are not activated, which they need to.
// [x]: general -> app version is set to 1.0.0 which is wrong, it is not finished yet and should be 0.1.0.
// [x]: palnt info -> not all plants need cleaning; wont force a cleaning routine for plants that do not specifically need it.
//
// * UPDATES
// [x]: location -> missing pick current location.
// [ ]: notification/location -> notify only when they are home (standby until current location within home location). DEFERRED: needs background location + geofencing.
// [*]: notification/location -> GDPR, ask the user to allways allow geolocation; INFORM clearly why.
//      NOTE(status): rationale dialog informs WHY. "Tillat alltid"/background permission not yet wired (tied to home-detection above).
// [ ]: notification/location -> the user should be able to postpone this notification. DEFERRED with geofencing.
// [x]: add new plant -> form -> NOTE recommending the user water the plant upon registration + checkmark (keeps scheduler in sync).
// [x]: palnt info -> the API provides a ton of useful info and care-tips; included ("Om arten" card).
// [*]: palnt info -> section about relevant diseases and pests common in users region.
//      NOTE(status): pests/diseases shown from Perenual; REGION filtering not available from the API.
// [x]: palnt info -> care-tips -> mini-version: four round circles [light-exposure, water-frequenzy-level, fertilization-frequenzy-level, notable-care-tag].
// [x]: palnt info -> plant info has the same four round circles.


/* //> TO DO's
! BUGS / MISSING
TODO [ ]: add new plant -> search -> card tunmbnails in search results are emtpy. NOTE: this also applies to my-plants list 
TODO [ ]: add new plant -> form -> it wont provide with default values for plants (height, size, maturity)
TODO [ ]: add new plant -> form -> relatize-size-select is freetext and not a list, it should be values selected form a list [tiny, small, medium, large, huge]
TODO [ ]: add new plant -> form -> maturity-select is freetext and not a list, it should be values selected form a list [seedling, young, juvenile, mature, old] #this should also be automatically updated by year calculations (date-aquired value)
TODO [ ]: add new plant -> form -> date-aquired should have todays date as default values  
TODO [ ]: add new plant -> form -> maturity-select -> this should also be automatically updated by year calculations (date-aquired value) - it is important that the update is 'extending' the current maturity value and does not reset it (if i aquire a juvenile plant,  and then have it for 2 years, then the maturity should be maturity=juvenile+2years, and not maturity=2years) 
TODO [ ]: add new plant -> form -> condition-select should not be a free-text but a select
TODO [ ]: add new plant -> form -> hazard for kids and pets should not be automaticalluy filled by the API and not manual in form.
TODO [ ]: add new plant -> form -> care-intervals should notify the user that; it is recommended that the user does not override because the app will calculate this based on multiple factors. then give add a checkbox or switch that activates the form fields (deactivated by default)
TODO [ ]: general -> nordic characters are not activated, which they need to.
TODO [ ]: general -> app version is set to 1.0.0 which is wrong, it is not finished yet and should be 0.1.0.
TODO [ ]: palnt info -> not all plants need cleaning, make sure it wont force a cleaning routine for plants that do not specifically need it.



* UPDATES
TODO [ ]: location -> missing pick current location.
TODO [ ]: notification/location -> make sure that the user is notified only when they are home. (if they are set to be notified at 11 but they wont be home from work before later in the day, have the notification on standby until theyre current location is within home location)
TODO [ ]: notification/location -> due to GDPR, we need ask the user to allways allow geolocation. it is important that we INFORM the user clearly why this is important.
TODO [ ]: notification/location -> the user should be able to postpone this notification. (notification gets through but the user is leaving soon and dont have time..)
TODO [ ]: add new plant -> form -> we should add a NOTE to the user that we recommend that the user water the plant upon registration (even though the soil is moist), this is so that the scheduler wont be out of sync with the plant. add a checkmark for that.
TODO [ ]: palnt info -> the API provides with a ton of useful information about the plant and care-tips. please include this in the app. 
TODO [ ]: palnt info -> the plant profile should also include a section about relevant diseases and also importantly; pests and diseases that are common in users region. 
TODO [ ]: palnt info -> care-tips ->  I want a mini-version of care-tips at the top of caretips, it will be four round circles with [light-exposure, water-frequenzy-level, frertilization-frequenzy-level, notable-care-tag: [needs-shower | easy-care | hard-care | loves soaking | blablabla ]]
TODO [ ]: palnt info -> i the same want plant info to have a tiny mini-version of care-tips, it will be four round circles with [light-exposure, water-frequenzy-level, frertilization-frequenzy-level, notable-care-tag: [needs-shower | easy-care | hard-care | loves soaking | blablabla ]]



*UPDATES (v2.0) ignore this untill all above are completed.
TODO [ ]: _topic_ -> add: add-multiple-homes / cabins etc.
TODO [ ]: _topic_ -> add: print overview function that can be actually printed or shared to other people (so that plant sitters can have a care-plan)
? can this be solved in some other means; add contributors for when there are more people in a household or temporarily adding a plant-sitter 

*UPDATES (v3.0) ignore this untill all above are completed.
TODO [ ]: general -> add garden as a room (require some adjustments)


TODO [ ]: _topic_ -> _content_

*/ 