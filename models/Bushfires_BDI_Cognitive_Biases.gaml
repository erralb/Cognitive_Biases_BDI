/**
* Name: BDI Bushfires simulation
*
* Author: Pierre Blarre
* 
* Based on a model without BDI architecture by : Sofiane Sillali, Thomas Artigue, Pierre Blarre
* 
* Description: BDI Bushfires simulation based on the Australian Black Saturday, with an attempt to include cognitive biases
* 
* Tags : Bushfires, BDI, Cognitive Biases, Behavior Profiles
*/

model Bushfires_BDI_Cognitive_Biases

import "environment.gaml"

import "people.gaml"

import "emergency_services.gaml"

import "residents.gaml"
import "behavior_profiles/can_do_defenders.gaml"
import "behavior_profiles/considered_defenders.gaml"
import "behavior_profiles/livelihood_defenders.gaml"
import "behavior_profiles/threat_monitors.gaml"
import "behavior_profiles/threat_avoiders.gaml"
import "behavior_profiles/unaware_reactors.gaml"
import "behavior_profiles/isolated_and_vulnerable.gaml"


global
{
	//Time
	int starting_hour <- 8;
	int current_hour <- 0 update: (starting_hour + (cycle / 60)) mod 24;
	int current_min <- 0 update: (cycle) mod 60;
	string current_time update: string(current_hour) + "h" + string(current_min);
	bool is_night <- true update: current_hour < 7 or current_hour > 20;
	
	//Nature
	float burning_probability <- 0.6; //probabilty that a plot will spread fire to one of its neighboring plot
	float wind <- 0.2;
	float drought <- 0.3;
	float hurting_distance <- 5.0 # m;
	float field_of_view <- 15.0 # m;
	int nb_fire <- 0;
	int fire_size <- 1 update: length(plot where (each.burning = true));
	int fire_uncontrollable <- 600; //when is the fire size found incontrable and evacuation alert must be triggered
	int burning_speed <- 10; //value in cycle. 1 is the fastest, 10 default value, above 10 will be very slow
	
	//Buildings
	int nb_bunker <- 0;
	int nb_exit <- 0;
	int nb_fire_station <- 2;
	int nb_police_station <- 1;
	
	//People and emergency services
	int nb_firefighters <- 5;
	int nb_policeman <- 2;
	
	int nb_residents_w_answered_1st_call <- 0;
	int evacuation_reminder_cycle <- 300;
	
	//Residents distribution (we use a total of 100 people, for the simulation is slow above this number)
	int nb_residents <- 0;
	int nb_isolated_and_vulnerable <- 5;
	int nb_unaware_reactors <- 5;
	int nb_threat_avoiders <- 30;
	int nb_threat_monitors <- 30;
	int nb_can_do_defenders <- 10;
	int nb_considered_defenders <- 10;
	int nb_livelihood_defenders <- 10;
	
	list<resident> every_resident <- nil update: resident union isolated_and_vulnerable union unaware_reactors union threat_avoiders union threat_monitors union can_do_defenders union considered_defenders union livelihood_defenders;
	list<resident> every_resident_alive <- nil update: every_resident where each.alive;
	list<people> every_people_alive <- nil update: every_resident_alive + (firefighters + policeman) where each.alive;
	
	//Cognitive Biases
	bool use_cognitive_biases <- false;
	int cognitive_biases_influence_occurence <- 0;

	//Application
	int ids <- 1; //used for agents identifications
	bool result_saved <- false;
	bool do_pause <- false;
	string simulation_name <- "No_Cognitive_Biases";

	bool personalized_msg <- false; //If true, it will increase residents' probability to react to alert messages
	bool trained_population <- false; //if true, it will increase residents' knowledge
	bool tactical_firefighters <- false; //if true, firefighter can call for reinforcements and are placed in strategical places on the map
	bool evacution_city_reported <- false; //true when the evacuation alert has been issued
	
	//Map
	file bounds_shapefile <- file("../includes/bounds.shp");
	file buildings_shapefile <- file("../includes/building.shp");
	file roads_shapefile <- file("../includes/road.shp");
	//file waterway_shapefile <- file("../includes/waterway.shp");
	geometry shape <- envelope(envelope(buildings_shapefile) + envelope(roads_shapefile) + envelope(bounds_shapefile));
	graph the_graph;
	graph road_network;
	graph road_network_practicable;
	
	init
	{
		//Buildings
		create building from: buildings_shapefile;
		
		// Roads
		create road from: roads_shapefile;
		road_network <- as_edge_graph(road);
		
		// City exits
		create city_exit { location <- { 450, 2.0 }; }
		create city_exit { location <- { 0, 920 }; }
		create city_exit { location <- { 850, 920 }; }

		// Bunkers (= Shelters. Color: blue)
		list<building> bunkers <- nb_bunker among building;
		loop i over: bunkers { i.bunker <- true; }

		// Fire stations
		list<building> fire_stations <- nb_fire_station among building where (!each.bunker);
		loop i over: fire_stations { i.fire_station <- true; }

		// Police stations
		list<building> police_stations <- nb_police_station among building where (!each.bunker and !each.fire_station);
		loop i over: police_stations { i.police_station <- true; }

		// Fires (outside the city)
		create fire number: 1 with: [choosed_location::{ 170, 210 }];
		create fire number: 1 with: [choosed_location::{ 750, 300 }];
		
		// Fires (inside the city)
//		create fire number: 1 with: [choosed_location::{ 460, 173 }];
//		create fire number: 1 with: [choosed_location::{ 130, 823 }];
//		create fire number: 1 with: [choosed_location::{ 704, 770 }];
		create fire number: 1 with: [choosed_location::{ 420, 550 }];

		// Random fires
		create fire number: nb_fire;

		// Police and firefighters
		create firefighters number: nb_firefighters;
		create policeman number: nb_policeman;
		
		if(simulation_name = "With_Cognitive_Biases"){
			use_cognitive_biases <- true;
		}
	}

	reflex fin_simulation when: do_pause
	{
		do_pause <- false;
		do pause;
	}

	//Mouse commands
	// Warning : do not use after 3d rotation or the coordinates will be messed up

	// Create fire  (Right click on map then  "Apply Create Fire starter here")
	user_command "Create Fire starter here" { create fire number: 1 with: [choosed_location::# user_location]; }

	// Create firewatch tower  (Right click on map then ->  "Apply Create Fire watch here")
	user_command "Create Fire Watch here" { create firewatch number: 1 with: [location::# user_location]; }

	// Create city exit
	user_command "Create Exit here" { create city_exit number: 1 with: [location::# user_location]; }

	// Monitoring
	int residents_alive <- 0 update: length(every_resident_alive);
	int residents_dead <- 0 update: length(every_resident) - length(every_resident_alive);
	int residents_alert <- 0 update: length(every_resident_alive where each.on_alert);
	int residents_bunker <- 0 update: length(every_resident_alive where each.in_safe_place);
	int residents_influenced_by_cognitive_biases <- 0 update: length(every_resident where each.cognitive_biases_influence);
	float buildings_damage <-0.0 update:  (building sum_of (each.damage )  / length( building ) ) /255;
}


/*=============================================
*         Experiment 1 : No cognitive Biases - No personnalities
*=============================================*/
experiment No_Cognitive_Biases_No_Personnalities type: gui
{
	// Boutons d'interaction
	action createFire { create fire; }
	user_command Create_Fire action: createFire;

	// Paramètres
	parameter "Start hour" var: starting_hour category: "Global" min: 0;
	parameter "Burning speed (in cycles)" var: burning_speed category: "Global" min: 10;
	parameter "Wind" var: wind category: "Global" min: 0.0 max: 0.5;
	parameter "Drought" var: drought category: "Global" min: 0.0 max: 0.5;
	parameter "Field of View" var: field_of_view category: "Global" min: 10.0 max: 20.0;
	parameter "Hurting distance" var: hurting_distance category: "Global" min: 1.0 max: 3.0;
	parameter "Nb firefighters" var: nb_firefighters category: "Agents" min: 0;
	parameter "Nb Policeman" var: nb_policeman category: "Agents" min: 0;
	parameter "Residents" var: nb_residents category: "Residents" min: 0;

	init { 
		simulation_name <- "No_Cognitive_Biases";
		nb_residents <- 100;
		create resident number: 100;
	}

	output
	{
		// Valeurs monitorées
		monitor "Current_time" value: current_time;
		monitor "Fire Size" value: fire_size;
		monitor "Resident with Cognitive Biases" value: residents_influenced_by_cognitive_biases;
		monitor "Resident alive" value: residents_alive;
		monitor "Dead resident" value: residents_dead;
		monitor "Alerted resident" value: residents_alert;
		monitor "Resident in safe place" value: residents_bunker;
		monitor "Buildings damage" value: buildings_damage color: #grey;

		// Visualisation graphique
		display Global
		{
			chart "Global" type: series size: { 0.5, 1 } position: { 0, 0 }
			{
				data "Fire Size" value: fire_size / 50 color: # orange;
				data "Dead people" value: length(every_resident where !each.alive) color: # red;
				data "People in alerte" value: length(every_resident where each.on_alert) color: # yellow;
				data "People in safe place" value: length(every_resident where each.in_safe_place) color: # green;
				data "Buildings damage" value: (building sum_of (each.damage)) / length(building) color: # darkgrey;
			}
		}

		// Visualisation 3D
		display map type: opengl
		{
			species people aspect: sphere3D;
			species road aspect: base;
			species resident aspect: sphere3D;
			species isolated_and_vulnerable aspect: sphere3D;
			species unaware_reactors aspect: sphere3D;
			species threat_avoiders aspect: sphere3D;
			species threat_monitors aspect: sphere3D;
			species can_do_defenders aspect: sphere3D;
			species considered_defenders aspect: sphere3D;
			species livelihood_defenders aspect: sphere3D;
			species firefighters aspect: sphere3D;
			species policeman aspect: sphere3D;
			species waterway aspect: base refresh: false;
			grid plot transparency: 0.4;
			species fire aspect: base refresh: true;
			species city_exit aspect: base transparency: 0.1;
			species building aspect: base;
			species firewatch aspect: base;
			light 1 color: (is_night ? 50 : 230);
		}
	}
}

experiment No_Cognitive_Biases_With_Personnalities type: gui
{
	// Boutons d'interaction
	action createFire { create fire; }
	user_command Create_Fire action: createFire;

	// Paramètres
	parameter "Start hour" var: starting_hour category: "Global" min: 0;
	parameter "Wind" var: wind category: "Global" min: 0.0 max: 0.5;
	parameter "Drought" var: drought category: "Global" min: 0.0 max: 0.5;
	parameter "Field of View" var: field_of_view category: "Global" min: 10.0 max: 20.0;
	parameter "Hurting distance" var: hurting_distance category: "Global" min: 1.0 max: 3.0;
	parameter "Nb firefighters" var: nb_firefighters category: "Agents" min: 0;
	parameter "Nb Policeman" var: nb_policeman category: "Agents" min: 0;
	parameter "Residents" var: nb_residents category: "Residents" min: 0;
	parameter "Isolated & Vulnerable" var: nb_isolated_and_vulnerable category: "Residents" min: 0;
	parameter "Unaware reactors" var: nb_unaware_reactors category: "Residents" min: 0;
	parameter "Threat avoiders" var: nb_threat_avoiders category: "Residents" min: 0;
	parameter "Threat monitors" var: nb_threat_monitors category: "Residents" min: 0;
	parameter "Can do defenders" var: nb_can_do_defenders category: "Residents" min: 0;
	parameter "Considered defenders" var: nb_considered_defenders category: "Residents" min: 0;
	parameter "Livelihood defenders" var: nb_livelihood_defenders category: "Residents" min: 0;

	init { 
		simulation_name <- "No_Cognitive_Biases";
		
		nb_residents <- 0;
		nb_isolated_and_vulnerable <- 5;
		nb_unaware_reactors <- 5;
		nb_threat_avoiders <- 30;
		nb_threat_monitors <- 30;
		nb_can_do_defenders <- 10;
		nb_considered_defenders <- 10;
		nb_livelihood_defenders <- 10;
		
		// People
		create resident number: nb_residents; //should be 0 if personnalities are used
		create isolated_and_vulnerable number: nb_isolated_and_vulnerable;
		create unaware_reactors number: nb_unaware_reactors;
		create threat_avoiders number: nb_threat_avoiders;
		create threat_monitors number: nb_threat_monitors;
		create can_do_defenders number: nb_can_do_defenders;
		create considered_defenders number: nb_considered_defenders;
		create livelihood_defenders number: nb_livelihood_defenders;
	}
	
	output
	{
		// Valeurs monitorées
		monitor "Current_time" value: current_time;
		monitor "Fire Size" value: fire_size;
		monitor "Resident with Cognitive Biases" value: residents_influenced_by_cognitive_biases;
		monitor "Resident alive" value: residents_alive;
		monitor "Dead resident" value: residents_dead;
		monitor "Alerted resident" value: residents_alert;
		monitor "Resident in safe place" value: residents_bunker;
		monitor "Buildings damage" value: buildings_damage color: #grey;

		// Visualisation graphique
		display Global
		{
			chart "Global" type: series size: { 0.5, 1 } position: { 0, 0 }
			{
				data "Fire Size" value: fire_size / 50 color: # orange;
				data "Dead people" value: length(every_resident where !each.alive) color: # red;
				data "People in alerte" value: length(every_resident where each.on_alert) color: # yellow;
				data "People in safe place" value: length(every_resident where each.in_safe_place) color: # green;
				data "Buildings damage" value: (building sum_of (each.damage)) / length(building) color: # darkgrey;
			}
		}

		// Visualisation 3D
		display map type: opengl
		{
			species people aspect: sphere3D;
			species road aspect: base;
			species resident aspect: sphere3D;
			species isolated_and_vulnerable aspect: sphere3D;
			species unaware_reactors aspect: sphere3D;
			species threat_avoiders aspect: sphere3D;
			species threat_monitors aspect: sphere3D;
			species can_do_defenders aspect: sphere3D;
			species considered_defenders aspect: sphere3D;
			species livelihood_defenders aspect: sphere3D;
			species firefighters aspect: sphere3D;
			species policeman aspect: sphere3D;
			species waterway aspect: base refresh: false;
			grid plot transparency: 0.4;
			species fire aspect: base refresh: true;
			species city_exit aspect: base transparency: 0.1;
			species building aspect: base;
			species firewatch aspect: base;
			light 1 color: (is_night ? 50 : 230);
		}
	}
}



/*=============================================
*         Experiment 2 : With cognitive Biases - No personnalities
*=============================================*/
experiment With_Cognitive_Biases type: gui
{
	// Boutons d'interaction
	action createFire { create fire; }
	user_command Create_Fire action: createFire;

	// Paramètres
	parameter "Cognitive Biases" var: use_cognitive_biases init: true category: "Modelisation";
	parameter "Start hour" var: starting_hour category: "Global" min: 0;
	parameter "Wind" var: wind category: "Global" min: 0.0 max: 0.5;
	parameter "Drought" var: drought category: "Global" min: 0.0 max: 0.5;
	parameter "Field of View" var: field_of_view category: "Global" min: 10.0 max: 20.0;
	parameter "Hurting distance" var: hurting_distance category: "Global" min: 1.0 max: 3.0;
	parameter "Nb firefighters" var: nb_firefighters category: "Agents" min: 0;
	parameter "Nb Policeman" var: nb_policeman category: "Agents" min: 0;

//	parameter "Isolated & Vulnerable" var: nb_isolated_and_vulnerable category: "Residents" min: 0;
//	parameter "Unaware reactors" var: nb_unaware_reactors category: "Residents" min: 0;
//	parameter "Threat avoiders" var: nb_threat_avoiders category: "Residents" min: 0;
//	parameter "Threat monitors" var: nb_threat_monitors category: "Residents" min: 0;
//	parameter "Can do defenders" var: nb_can_do_defenders category: "Residents" min: 0;
//	parameter "Considered defenders" var: nb_considered_defenders category: "Residents" min: 0;
//	parameter "Livelihood defenders" var: nb_livelihood_defenders category: "Residents" min: 0;
	
	init { simulation_name <- "With_Cognitive_Biases"; }

	output
	{
		// Valeurs monitorées
		monitor "Current_time" value: current_time;
		monitor "Fire Size" value: fire_size;
		monitor "Resident with Cognitive Biases" value: residents_influenced_by_cognitive_biases;
		monitor "Resident alive" value: residents_alive;
		monitor "Dead resident" value: residents_dead;
		monitor "Alerted resident" value: residents_alert;
		monitor "Resident in safe place" value: residents_bunker;
		monitor "Buildings damage" value: buildings_damage color: #grey;

		// Visualisation graphique
		display Global
		{
			chart "Global" type: series size: { 0.5, 1 } position: { 0, 0 }
			{
				data "Fire Size" value: fire_size / 50 color: # orange;
				data "Cognitive Biases influence" value: cognitive_biases_influence_occurence color: # blue;
				data "Dead people" value: length(every_resident where !each.alive) color: # red;
				data "People in alerte" value: length(every_resident where each.on_alert) color: # yellow;
				data "People in safe place" value: length(every_resident where each.in_safe_place) color: # green;
				data "Buildings damage" value: (building sum_of (each.damage)) / length(building) color: # darkgrey;
			}
		}

		// Visualisation 3D
		display map type: opengl
		{
			species people aspect: sphere3D;
			species road aspect: base;
			species resident aspect: sphere3D;
			species isolated_and_vulnerable aspect: sphere3D;
			species unaware_reactors aspect: sphere3D;
			species threat_avoiders aspect: sphere3D;
			species threat_monitors aspect: sphere3D;
			species can_do_defenders aspect: sphere3D;
			species considered_defenders aspect: sphere3D;
			species livelihood_defenders aspect: sphere3D;
			species firefighters aspect: sphere3D;
			species policeman aspect: sphere3D;
			species waterway aspect: base refresh: false;
			grid plot transparency: 0.4;
			species fire aspect: base refresh: true;
			species city_exit aspect: base transparency: 0.1;
			species building aspect: base;
			species firewatch aspect: base;
			light 1 color: (is_night ? 50 : 230);
		}
	}
}














