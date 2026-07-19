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
/* _______________________________ TODO SYSTEM ___________________________________

  * FORMAT
  TODO [status]: id. (TAG)[location][sub-location-if-needed][subject] action -> description _comment only if needed_

    * STATUS  — status comes RIGHT after TODO, otherwise the colors break
        [ ] = open (bright orange) · [x] = done (dark orange) · [*] = half-done, must carry a NOTE (status): line

    * ID
        ids are global and permanent: take the next free number, never reuse, never renumber.
        sub-items restart at 1. inside their parent. (next free id: 14)

    * TAGS  — optional, before [location]
        (BUG) broken behaviour · (UX) polish · (PERF) performance _only (BUG) in use so far_

    * LOCATIONS  — first bracket, keep to this list, extend the list here when a new one is needed
        [general] [objects] [rooms] [add_new] [plant_list] [plant_info] [notification] [location] [engine]
        sub-locations are free-form: [form] [profile] [heat-source] [windows] [search] [gdpr] ...

    * ACTIONS
        add feat / add / fix / update / refactor / delete / test

    * VERSIONS
        todos live in version blocks (> VERSION 1.0 / 2.0 / 3.0) below.
        later versions are marked _ignore untill all above are completed_

________________________________ RULES ________________________________________

  * 1. one task = one line
    TODO [ ]: 90. [objects][heat-source][form] add feat(field) -> select for heat source type _air-conditioner is special: both drag-source and heat-source_

  * 2. multiple tasks on one subject = parent header + indented sub-items (one tab)
    TODO [ ]: 90. [objects] update forms
            [x]: 1. [heat-source][form] add feat(field) -> select for heat source type [oil-heater, electric-heater, fan-heater, wall-heater, heating-cables, heat-pump, air-conditioner, fireplace]
            [ ]: 2. [room][form] update field(light-intensity) -> add "Estimate" option _triggers estimation model for light exposure_

  * 3. long line? wrap it — indent the wrapped part DEEPER than the line it belongs to
    TODO [ ]: 90. [objects][heat-source][form] add feat(field) -> select for heat source type
                  [oil-heater, electric-heater, fan-heater, wall-heater, heating-cables, heat-pump,
                  air-conditioner, fireplace] _air-conditioner is special: drag-source and heat-source_

  * 4. half-done = [*] + indented NOTE (status): saying exactly what is left. the same amount of indentations as wrapped lines, so that the wrapped line comes after the ID, on the same line as TAGS (if any) or LOCATION (ref: 3.) 
    TODO [*]: 90. [notification][location] GDPR always-allow geolocation -> INFORM user clearly why
                  NOTE (status): rationale dialog done; "Tillat alltid" background permission not wired yet.

  * 5. bugs/missing get a (BUG) tag, inline in their version block (no separate bug section)
    TODO [ ]: 90. (BUG)[objects][rooms] fix climate coupling -> _blablabla_

  * 6. Questions / to-be-discussed = ? line directly under the todo they block, indent the the question-line DEEPER than the line it belongs to, the same way as wrapped linnes (ref: 3.)
    TODO [ ]: 90. [plant_list][add_new] plant-sitter sharing -> print/share care-plan
                  ? could contributors-per-household solve this instead of print?

  (all examples above use fake id 90. so they never collide with real ids)

*/

/* > VERSION 1.0
TODO [x]: 1. (BUG)[general] fix nordic characters -> they were not activated
TODO [x]: 2. (BUG)[general] fix app version -> was set to 1.0.0, not finished yet, set to 0.1.0
TODO [x]: 3. [add_new][form] update fields
        [x]: 1. [form][relative-size] update field(select) -> freetext replaced with select from list [tiny, small, medium, large, huge]
        [x]: 2. [form][maturity] update field(select) -> freetext replaced with select from list [seedling, young, juvenile, mature, old]
        [x]: 3. [form][maturity] add feat(auto-update) -> maturity advances by year calculations (date-aquired), extending current value
                not resetting it _MaturityStage.advancedBy()_
        [x]: 4. [form][date-aquired] update field(default) -> defaults to todays date
        [x]: 5. [form][condition] update field(select) -> freetext replaced with select _defaults to Frisk on new plants_
        [x]: 6. [form][hazard] update field(auto-fill) -> kids/pets hazard filled from species data, not manual _poisonousToPets/Humans, Plantasjen 'Giftig'_
        [x]: 7. [form][care-intervals] add feat(override-switch) -> notify user it is recommended not to override; switch activates the fields (deactivated by default)
        [x]: 8. [form][note] add feat(checkmark) -> recommend watering the plant upon registration so the scheduler stays in sync _even though the soil is moist_
        [x]: 9. [form][defaults] add feat(default-values) -> provide defaults for height, size, maturity
                _size/maturity/date/condition/height done earlier; default age unblocked by 10.-12._
        [x]: 10. (BUG)[form][age] fix default age -> age defaults to 0 (= freshly planted seed) which is very wrong;
                current age = estimated retail age at acquisition (unless user-provided) + (today − date-aquired)
                _example: medium monstera bought 1 yr ago -> 1.5 + 1 = 2.5 yrs · Plant.age / Plant.owned;
                maturity auto-advance uses owned only_
        [x]: 11. [form][age] add feat(retail-age-estimate) -> estimate by size class: small pot (6-9 cm) 3-9 mo ·
                medium (12-17 cm) 1-3 yr · large floor 3-8 yr · specimen 8-20+ yr; species overrides where known
                (monstera medium 1-2 yr · ficus elastica 1-3 yr · pothos 4-12 mo · sansevieria 1-3 yr · peace lily 1-2 yr)
                _core/retail_age.dart: size-class midpoints + species overrides (incl. norwegian trade names),
                overrides scale by size ratio; tested in test/retail_age_test.dart_
        [x]: 12. [form][age] update field(default) -> prefill estimated age; user-provided age always wins
                _form field "Alder ved anskaffelse (år)": empty = estimate (shown as hint + "Alder nå" preview),
                typed value stored as ageYearsAtAcquisition; profile shows "(estimert)" when estimate-based_
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
        [x]: 6. [profile][tabs] refactor profile -> keep profile a simple quick view; move detailed sections into
                tabs: ["stelletips"], ["om arten", "farer"]
        [x]: 7. [profile][stelletips] update tab -> detailed, descriptive explanation / instructions for the plant
                _mini-version (four circles) stays the quick and easy version, as today_
        [x]: 8. [profile][notes] update section -> notes are user-only; the app must never write data here
                _species prefill of tips/generalInfo removed from edit screen; section renamed "Mine notater"_
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
TODO [ ]: 9. (BUG)[add_new][search] fix data merge -> BOTH Mestergrønn AND Plantasjen must be checked; species data
              missing from Mestergrønn must be covered by Plantasjen _example: "monstera" shows giftig for
              kjæledyr/barn: ukjent, but Plantasjen clearly marks it poisonous_

TODO [x]: 10. [objects]:
        [x]: 1. [objects][windows]: refactor form(opening-frequency) -> add more options; [never, rarely, normal, often, always].
              NOTE migration: map old stored frequency values to the new 5-option scale so existing windows keep sane values.
        [x]: 2. [objects][windows] add object -> we need to add "glass doors" and "partial glass door" (need diffused / not-diffused options)
                these also need to act as windows regarding drag and sunlight.

TODO [ ]: 11. [home][plant-list]:
        [ ]: 1. [floorplan][plant-list][floorplan] implement floorplan -> floorplan is still not made, make it and remove "coming-soon".
        [ ]: 2. [floorplan][plant-list][floorplan] add feat(view) -> when viewing a floor. it should display a little more info about rooms;
                 [ovens should have heat-radiation circle around them, "cooling-circle for windows (depending on their frequency)" the temperature of the room should be displayed, and light values, as well as some icons for "needs-watering/fertilizing"]
                 NOTE heat-radiation circle radius: computed from existing HeatSource values (outputW/radiantW/localRiseC) -> radius = distance where localRiseC >= ~0.5 C. window cooling-circle likewise from opening-frequency + outdoor temp.
        [ ]: 3. [floorplan][plant-list][floorplan] replace icon -> to use the icon currently being used by "by-room"
        [ ]: 4. [floorplan][plant-list][by-rooms] replace icon -> replace the icon to be a 4x4 box grid.

TODO [ ]: 12. [floorplan]:
        [ ]: 1. [floorplan] add feat(zoom) -> add zoom function [+]/[-] button, + mouse wheel scroll compatibility for computers, and pinch-compatibility for touch screens.
        [ ]: 2. (BUG)[floorplan] disappearing rooms -> when adding a plant (click and drag) the whole floor's content disappeared.
        [ ]: 3. [floorplan] add feat(pan) -> drag empty canvas (mouse) / two-finger drag (touch) to pan; required companion to zoom.
        [ ]: 4. [floorplan] add feat(undo-redo) -> undo/redo stack for all floorplan edits (place, move, resize, draw, delete); mandatory once draw tools exist.

TODO [ ]: 13. [floorplan][rooms] redesign room objects ->
        [ ]: 1. [floorplan][rooms] replace name -> place room name in middle, big text, translucent color.
                NOTE they are currently styled as a "computer window" with name in top left corner and "x" in the other, and "expand" in the bottom-left, i dont like that.
        [ ]: 2. [floorplan][rooms] add editing marker rule -> after a room is placed or drawn, the editing markers and icons should disappear, they appear once clicked on.
        [ ]: 3. [floorplan][rooms] move "x"-icon -> move the icon outside of the box, only visible when a room is clicked on.
        [ ]: 4. [floorplan][rooms] add editing markers -> resizing and rotating should be small circles at each corner and side of the room-object.
                NOTE like in other drawing apps
        [ ]: 5. [floorplan][rooms] add complex rooms -> user should be able to add different shapes to a room, and draw more complex shapes. [add shapes, merge shapes, draw tools]
                NOTE some rooms look like a square with a circle in the corner, or some have perpendicular walls, or some rooms have more than four corners. We need to account for that.
                NOTE area for non-rectangles: draw shape first, compute polygon area (shoelace formula), then uniformly scale the drawn shape so its area matches the room's size-value.
        [ ]: 6. [floorplan][rooms] add apply-draw-on-existing-rooms -> user should be able to place a room and then edit the shape (standard room is square)
        [ ]: 7. [floorplan][rooms] add field(draw-room) -> when drawing a room, the user should be able to set the size of the room.
                NOTE currently the user is only prompted to enter the name of the room.
                NOTE The rest of the editing should be done in room-tab as normal.
        [ ]: 8. [floorplan][rooms] refactor shape -> rooms should not have rounded edges.
        [ ]: 9. [floorplan][rooms] restrict resizing -> placed rooms w/size value should be "restricted" from resizing (give warning when resizing). It should also update the size value for the object in room tab.
        [ ]: 10. [floorplan][rooms] add feat(add-divider-wall) -> allow user to add / draw a divider wall.
                NOTE divider blocks only DIRECT effects: draft, direct heat radiation, direct sunlight. ambient room temperature and ambient light stay uniform (no climate-zone split, unlike a full wall).
        [ ]: 11. [floorplan][rooms] add feat(size-tolerance) -> user's room measurements can be inaccurate; allow some "elbow-room" on room sizes in the floorplan so adjacent rooms actually fit each other instead of leaving slivers/overlaps.
        [ ]: 12. [floorplan][rooms] add rule(overlap) -> define whether rooms may overlap when drawing/merging; block or warn on overlap.
        [ ]: 13. [floorplan][rooms] add rule(orphans) -> deleting or reshaping a room must define what happens to objects/plants inside it (reassign, unplace, or block delete).

TODO [ ]: 14. [floorplan][objects][window] redesign window-object ->
        [ ]: 1. [floorplan][objects][window] redesign windows -> make the window object look like a window box
        [ ]: 2. [floorplan][objects][window] add relative size -> the size of the window should be accurate to the room size (use a default size based on its size-value; [tiny:50cm, small:100cm, regular:100cm, large:120cm huge:150cm]) (width can be resized by user)
        [ ]: 3. [floorplan][objects][window] replace names -> dont use the assigned name for windows, just use window icon. desktop: show name on hover.
                touch: market standard -> first tap selects the object and shows its name label (like map-pin apps); actions stay behind the (...) icon (TODO 18.1).
        [ ]: 4. [floorplan][objects][window] placement logic -> windows can only be placed on walls.
        [ ]: 5. [floorplan][objects][window] window group -> windows also act as a group, which contains plants.

TODO [ ]: 15. [floorplan][objects][plants] redesign plant-object -> 
        [ ]: 1. [floorplan][objects][plants] refactor design -> use icons, hide name, add (...) icon.
        [ ]: 2. [floorplan][objects][plants] add grouping -> plants should be able to be grouped in clusters.
                click to view list, list items need individual (...) icons.
                NOTE clarify relation to window group (TODO 14.5): same UI/mechanic or separate? can a plant be in both?

TODO [ ]: 16. [floorplan][objects][openings] redesign opening-object -> 
        [ ]: 1. [floorplan][objects][openings][opening] add location -> can only be placed on walls, in-between two rooms (interior only; exterior handled by doors).
        [ ]: 2. [floorplan][objects][openings][door] add location -> can only be placed on walls, any wall (interior and exterior).
        [ ]: 3. [floorplan][objects][openings][door] add swing-direction -> the door's swing direction should be editable (just use the rotation, limit to 180 degrees (so that it only flips to inside wall or outside wall.))
        [ ]: 4. [floorplan][objects][openings][door] add field(door-type) -> [single, double].
        [ ]: 5. [floorplan][objects][openings][opening] add shape -> should be a box, and should remove the wall lining, so that it looks open
        [ ]: 6. [floorplan][objects][openings][door] add shape -> should look like how doors are shaped in blueprints.

TODO [ ]: 17. [floorplan][objects][heat-source] redesign heat-source-object -> 
        [ ]: 1. [floorplan][objects][heat-source] refactor design -> use icons, hide name, add (...) icon.
        [ ]: 2. [floorplan][objects][heat-source] add location-limitation -> these can only be placed on walls [heat-pumps, air-conditioner, wall-ovens]
                NOTE I'm a bit uncertain about fireplaces, there are wall connected 99.99% of the time, but i have seen plenty of centered fireplaces. so lets keep it location-freedom for now. 
        // [ ]: 2. [floorplan][objects][heat-source]  -> XXXX
        // [ ]: 3. [floorplan][objects][heat-source] XXXX -> XXXX

TODO [ ]: 18. [floorplan][objects] redesign object ->
        [ ]: 1. [floorplan][objects]  editing object -> clicking an object should reveal a (...) icon, which opens a select, one of the fields is "edit" / "delete" / "duplicate".
        [ ]: 2. [floorplan][objects]  editing object -> clicking an object should also reveal their name.
                NOTE this includes room objects
        // [ ]: 3. [floorplan][objects][room exception]  add room exception -> the (...)-select for a room object, should also
        //         NOTE this includes room objects

TODO [ ]: 19. [floorplan][objects] add feat(wall-snap-engine) -> one shared wall-snapping engine for windows, openings, doors and wall-mounted heat sources;
              snap to nearest wall, rotate object to match wall orientation, slide along wall. build once, reuse for all wall-bound objects (TODO 14.4, 16.1, 16.2, 17.2).

TODO [ ]: 20. [floorplan][data] add migration -> complex room shapes (TODO 13.5) change the stored room schema; existing saved floorplans must load
              without data loss (versioned fromJson / sane defaults for old data).

*/
     
/* > VERSION 2.0
TODO [ ]: 1. [general][v2.0] add feat(multiple-homes) -> support more homes, cabins etc. _ignore untill all above are completed_
TODO [ ]: 2. [general][v2.0] add feat(print/share) -> printable overview so plant-sitters can have a care-plan _ignore untill all above are completed_
              ? can this be solved some other way -> contributors for households with more people or temporarily adding a plant-sitter?      
*/

/* > VERSION 3.0
TODO [ ]: 1. [rooms][v3.0] add feat(garden) -> garden as a room type, requires some adjustments _ignore untill all above are completed_
*/