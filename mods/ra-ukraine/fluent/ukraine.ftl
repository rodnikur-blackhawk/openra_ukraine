## Red Alert: Ukraine
mod-title-ukraine = Red Alert: Ukraine
mod-windowtitle-ukraine = OpenRA - Red Alert: Ukraine

faction-ukraine-zsu =
    .description = Ukraine: Drone Warfare
     Kamikaze drones on land, at sea and in the air
     Special Ability: Storm Shadow
     Special Ability: Mi-8 Air Assault
     Special Unit: Lyutyi Kamikaze Drone
     Special Unit: UAV Operator (FPV drones)
     Special Unit: Ratel S, Sea Baby
     Special Unit: Bayraktar TB2
     Superweapons: Flamingo, Pokrova EW

## Ukraine (Allied sub-faction): Armed Forces of Ukraine equipment
## Descriptions follow the stock Red Alert style: a short role line,
## then what the unit is strong and weak against.

actor-btr4 =
    .name = BTR-4 Bucephalus
    .description =
    Fast infantry transport with an autocannon.
      Strong vs Infantry and Light armor
      Weak vs Tanks and Aircraft

actor-gepard =
    .name = Gepard
    .description =
    Mobile unit with twin anti-aircraft cannons.
      Strong vs Aircraft, Infantry and Light armor
      Weak vs Tanks

actor-bulat =
    .name = T-64BM Bulat
    .generic-name = Tank
    .description =
    Ukrainian Main Battle Tank with reactive armor.
      Strong vs Vehicles
      Weak vs Infantry and Aircraft

actor-oplot =
    .name = T-84 Oplot
    .generic-name = Tank
    .description =
    Heavy tank with an anti-aircraft machine gun.
      Strong vs Vehicles, Infantry and Aircraft
      Weak vs Artillery

actor-vilkha =
    .name = Vilkha MLRS
    .description =
    Long-range guided rocket artillery.
      Strong vs Infantry, Buildings and Light armor
      Weak vs Tanks and Aircraft

actor-bohdana =
    .name = 2S22 Bohdana
    .description =
    Long-range wheeled artillery.
      Strong vs Infantry, Buildings and Light armor
      Weak vs Tanks and Aircraft

actor-ratel =
    .name = Ratel S
    .description =
    Remote-controlled unmanned ground kamikaze drone.
    Detonates on contact.
    Destroys buildings in one to three hits, depending on their health.
      Strong vs Vehicles and Buildings
      Weak vs Infantry and Aircraft
      Special Ability: Kamikaze

actor-tb2 =
    .name = Bayraktar TB2
    .description =
    Slow combat drone with guided missiles.
    Jams enemy radar.
    Can detect cloaked units and submarines.
      Strong vs Tanks and Vehicles
      Weak vs Infantry and Aircraft

actor-f16 =
    .name = F-16 Fighting Falcon
    .description =
    Fast air superiority fighter
    with long-range air-to-air missiles.
      Strong vs Aircraft
      Weak vs Ground units

actor-lyutyi =
    .name = Lyutyi
    .description =
    Slow long-range kamikaze drone.
    Can only be used once.
    Direct hits destroy ground vehicles. A full-health Mammoth Tank survives with 25% health.
      Strong vs Buildings, Infantry and Vehicles
      Weak vs Anti-Air
      Special Ability: Kamikaze

actor-mi8 =
    .name = Mi-8 Transport Helicopter

actor-seababy =
    .name = Sea Baby
    .description =
    Fast naval drone packed with explosives.
      Strong vs Naval units and Naval yards
      Weak vs Ground units and Aircraft
      Special Ability: Kamikaze

actor-bulat-husk-name = Husk (T-64BM Bulat)
actor-oplot-husk-name = Husk (T-84 Oplot)
actor-tb2-husk-name = Bayraktar TB2
actor-f16-husk-name = F-16 Fighting Falcon
actor-lyutyi-husk-name = Lyutyi
actor-mi8-husk-name = Mi-8 Transport Helicopter

actor-uavop =
    .name = UAV Operator
    .description =
    Anti-infantry unit with FPV drones.
      Strong vs Infantry and Light armor
      Weak vs Tanks and Aircraft

actor-gur =
    .name = HUR Agent
    .description =
    Elite agent with an assault rifle.
    Steals enemy credits.
    Hijacks enemy vehicles.
      Strong vs Infantry
      Weak vs Vehicles and Aircraft
      Special Ability: Stealth

## Structures
actor-barr-ukraine =
    .name = Ukrainian Barracks

actor-spen-ukraine =
    .name = Naval Base
    .description =
    Produces and repairs ships
    and transports.

actor-stek-ukraine =
    .name = Ukrainian Tech Center
    .description =
    Provides Ukrainian advanced technologies.

actor-dbnk =
    .name = Drone Bunker
    .description =
    Anti-Infantry base defense.
    Can detect cloaked units.
      Strong vs Infantry and Light armor
      Weak vs Tanks and Aircraft

actor-stugna =
    .name = Stugna-P ATGM Position
    .description =
    Anti-Tank base defense.
    Requires power to operate.
    Can detect cloaked units.
      Strong vs Vehicles
      Weak vs Infantry and Aircraft

actor-mazepa =
    .name = Corvette "Hetman Ivan Mazepa"
    .description =
    Multi-role warship with cruise missiles.
    Can detect submarines.
      Strong vs Buildings, Naval units and Aircraft
      Weak vs Tanks

## Superweapons
actor-flamingo =
    .name = Flamingo Launch Position
    .description =
    Provides a cruise missile strike.
    Requires power to operate.
    Maximum of three can be build.
      Special Ability: Flamingo Strike
    .power-name = Flamingo Strike
    .power-description = Launches a cruise missile that devastates
     a small area at the target location.

actor-pokrova =
    .name = Pokrova EW Station
    .description =
    Strategic electronic warfare complex.
    Maximum of one can be built.
      Special Ability: EW Field (jams enemy radar and cloaks friendly units for 15 sec)
    .power-name = Pokrova EW Field
    .power-description = Jams enemy units in an area and hides
     your units from enemy sensors.

actor-pokrova-field-name = EW Field

actor-afld-ukraine-zsu =
    .name = Ukrainian Airfield
    .description =
    Produces and reloads aircraft.
    Launches Lyutyi drones from its catapult.
      Special Ability: Mi-8 Air Assault
      Special Ability: Storm Shadow
    .power-name = Storm Shadow
    .power-description = Launches a precision cruise missile
     that destroys a single target.
    .heliassault-name = Mi-8 Air Assault
    .heliassault-description = Two Mi-8 helicopters land a squad
     of infantry at the target location.

actor-heliassault-marker-name = Air Assault Landing Zone

notification-flamingo-prepping = Flamingo missile preparing.
notification-flamingo-ready = Flamingo missile ready.
notification-flamingo-launch-detected = Cruise missile launch detected.
notification-pokrova-charging = Pokrova EW station charging.
notification-pokrova-ready = Pokrova EW field ready.
notification-heliassault-launched = Air assault helicopters on the way.
