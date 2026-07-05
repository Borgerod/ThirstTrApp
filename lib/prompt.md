ok. make me a mobile App with Flutter in this folder. I shall give you a description of the app:
The app is a portfolio of all of your plants in your house, where each plant contains some info about it regarding [ general info, maturaty, age, size, relative-size, plant care, tips, condition, price, reciepts (if any), pet/child hazards, light-measurement, light-intensity, room placement, near drag, near heat source, link it to window object you have in your home (window object demo further down)],
the list of plants can be split up into rooms, or you can keep them as one complete list.
But the main function of it is that it keeps track of the watering and fertilization schedule (based on plant care info), and will notifty you when some plants needs to be watered, fertilized, cleaned (some plants require that) etc.. the notifications will ask me to confirm weather ive completed the task or not, and it how the option to postpone it when the apps estimations are wrong and the soil is not dry enough for example.  
It needs to base those schedules on a bit external information as well, things like; location of home, the plants location in the home (northside, southside, window, drag / airflow, volatile temperatures), recent weather, air moisture, season.
here are some usefull objects that can be linked to the plants: {
oven/heat_source:{
type: [oil heaters, heating cables, fan heaters, wall heaters, eletric heaters, heat pumps, fireplace, etc]
heat_spread:, [low, med, high] #heat pump have big spread, oilheaters have low, heating cables have big spead,
heat_intensity: [low, med, high], #ovens and heating cables usually have mild heat, while a fireplace has high intensity.
heat_settings: [low, med, high, static] , #some ovens just have a dial, and static heat with no controllers like a fireplace.
temp_settings: number,
#a oven will have atleast one of these values; heat_settings, temp_settings -> which will moderate the value of heat_intensity.

},
window:{
open-frequenzy: [often, normal, never]
size: [tiny, small, regular, big, huge]
light-measurement: number #(if the user has a light-meter)
light-intensity: [shaded, indirect, direct] #word based alternative for light-measurements, if not then the app will estimate it through
}
the rooms can be marked with properties such as: {
size: number,
room temperature: number #from manual thermostat readings by user -> fallback is 21 celcius
light-measurement: number #(if the user has a light-meter)
light-intensity /light-exposure: [shaded, indirect, direct] #word based alternative for light-measurements, if not then the app will estimate it through
}
the plants can also have the same properties as previously meantioned: {
light-measurement: number #(if the user has a light-meter)
light-intensity /light-exposure: [shaded, indirect, direct] #word based alternative for light-measurements, if not then the app will estimate it through
room placement (if not manually placed in map (later version)); [corner, in-room, window]
}
}
the app manu needs settngs such as what units they prefer (default: norwegian), home location -> will fill location based data regarding [weather, air moisture, wind, temperatures and other stuff that might alter the plant care estimations]
And now for thirdparty API's and such:
{

plant_api: Mestergrønn product catalogue (Salesforce Commerce Cloud, no API key). Search: SearchServices-GetSuggestions?q=<name> (HTML, gives pid+name+thumb). Details: Product-Variation?pid=<id>&quantity=1 (JSON: productName, shortDescription, images, careTips1-4 SVGs, productDimensions height). See services/mestergronn_api.dart.
climate_api: uses the user location through this api: (whichever is more suitable one out of these: [https://open-meteo.com, https://openweathermap.org/api, https://www.weatherapi.com/ ]) to fill in climate related home-information.
}
Thats all that i can think of but maybe there are more API's that would be useful?

how the user will add plants to their home:
-> by search, filter, and picks from the list made from -> /v2/species-list
-> by scanning reciept
-> by scanning barcode
-> by adding name

V2
Optional (we can add this in a later version) allow the user to "make/draw" their home, as a basic blueprint/map of the home where the plants can be added, along with usefull objects such as the ones mentioned above[ovens, windows,]

## reponse

Save project memory.

Recalled 1 memory, wrote 2 memories

Done. Full runnable V1 built. flutter analyze = 0 issues, tests pass, whole app compiles.

Built

29 Dart files + platform config. Structure:
lib/
core/ enums, json, format
models/ Plant, Room, WindowObject, HeatSource, Species, CareTask, AppSettings
data/ Hive store, repositories, Riverpod providers
services/ perenual_api, weather_api, scheduler, notification_service
features/ home, tasks, plant_detail(+edit), add_plant(search/barcode/receipt/name), rooms, settings

Covers your spec:

- Plant info block — species, size/maturity/age, condition, price, receipt, pet/child hazards, light, placement, near-draft/heat flags, links to window + hea
