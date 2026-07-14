## BUGS / ISSUES:

1. searches: 2. [api][algorithm] shows too much search results (duplicated and technically duplicates species) -> probable cause; fetches from multiple apis and adds them together INSTEAD of checking one, if none then next, etc.. 3. [api][algorithm][filtering] shows artificial plants 4. [decision][tags] uncertain what the tags [] are for and what they are used for -> keep/trash? 5. [tags] should add header and tooltip / descr to them tags. 6. [api][algorithm] sometimes shoes stuff that is NOT plants BAD 7. [api][algorithm] searching for their latin name or common-latin name does not work. all used names needs to be searchable. for example: "gullranke" needs to be searchable by "pothos" or "epipremnum aureum" as well.  
   8. [api][algorithm][TODO] double-check if the latin names are correct (ie, i suspect "epipremnum aureum" is not the right one for "pothos")

2. plant-form:
   1. [decision] should prob remove the switch-buttons; "near drag" and "near heat source" those should be automatically filled in floor plan builder?
      (or maybe we should keep them if the user does not want to use the builder??)
   2. [placement] for the room-placement field; the "corner" option needs a sub-selection for which corner it is.
   3. [decision] we might need to refactor how tyhe plantform works, to either have one simpler general one (the one we currently use) for when user is not using floor plan builder, and one more complex one for when the user is using  
       the floor plan builder. aka. the gerneral one count until the user starts using the floorplan builder and places a plant somewhere in the room, then the complex one will overwrite the general one.

3. plant over-view / plant-info:
   1. [water-schedule] says need more info to calculate watering times. (nice feature) but it should give a standard schedule if no additional info has been given (taken from the plants "stelletips" or general rules),
      then mark it with a yellow warning sign with the same tooltip, "this needs more info to accurately calculate schedule" or something like that.
   2.
   3.
4. storage
   1. [plants][rooms][objects][...] none of the objects added to the app stays presistant during app restart. they need to, this needs to be stores PROPERLY. via a dump file or a database.
5. object forms
   1. [window] when adding windows, the "himmelretning"-field; the options ["north|south|etc.."] should be inherited from the room chosen. i.e.: if living room is chosen, and living room only has a one outdoor-facing-wall (north) then only north should be an option. (the others are deactivated)
   2. [window] open-frequency should have more options: "often" and "rarely"

## TODO:

1.  maybe add a testmode that would automatically add this: {
    plants: {
    {
    name: monstera,
    room: office,
    room-placement: corner,
    window: None,
    vertical-loc: "on floor",
    near-drag: true,
    near-drag-extension: ,
    near-heat: true,
    near-heat-extension: ,
    light-measurement: default,
    size: default,
    maturity: default,
    age: default,
    acquired: today,
    health: default,
    price: 299,
    "everything else": default,  
     },
    {
    name: gullranke,
    room: office,
    room-placement: corner,
    window: "office - normal, openable",
    vertical-loc: "raised",
    near-drag: true,
    near-drag-extension: ,
    near-heat: true,
    near-heat-extension: ,
    light-measurement: default,
    size: default,
    maturity: default,
    age: default,
    acquired: today,
    health: default,
    price: 149,
    "everything else": default,
    },
    },
    heat-source: {
    "trille-ovn":{
    type: oil oven,
    room: office,
    settings: high,
    thermostat: default,
    effect: default,
    },
    },
    winodows: {
    "office - big, non-openable" : {
    size: big,
    open-frequency: never,
    room: office,
    wall: east,
    light-measurement: default,
    light-intensity: default,
    },
    "office - normal, openable" : {
    size: normal,
    open-frequency: normal,
    room: office,
    wall: east,
    light-measurement: default,
    light-intensity: default,
    },
    "office - normal, non-openable" : {
    size: normal,
    open-frequency: never,
    room: office,
    wall: east,
    light-measurement: default,
    light-intensity: default,
    },
    "office - small, openable" : {
    size: small,
    open-frequency: allways,
    room: office,
    wall: north,
    light-measurement: default,
    light-intensity: default,
    },

            "living room - small, openable" : {
                size: small,
                open-frequency: normal ,
                room: living room,
                wall: north,
                light-measurement: default,
                light-intensity: default,
            },

        },
        rooms: {
            "living room":{
                size: 11,
                outside-facing-walls: [north, ],
                temp: default
                light-measurement: default,
                light-intensity: default,
            },
            "office":{
                size: 10,
                outside-facing-walls: [north, east],
                temp: default
                light-measurement: default,
                light-intensity: default,
            },
        },

    }

1.  [decision] maybe add a tutorial for the user (HOW?)
1.  object forms:
    1. [window] when adding windows, the "himmelretning"-field; the options ["north|south|etc.."] should be inherited from the room chosen. i.e.: if living room is chosen, and living room only has a one outdoor-facing-wall (north) then only north should be an option. (the others are deactivated)
    2. [window] open-frequency should have more options: "often" and "rarely"
