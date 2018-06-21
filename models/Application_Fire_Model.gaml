/**
* Name: BDI Bushfire simulation base on the Australian Black Saturday
*
* Author: Pierre Blarre
* 
* Original Authors: Sofiane Sillali, Thomas Artigue, Pierre Blarre (No BDI)
* 
* Description: Modéliser cet évenement pour trouver des solutions afin de minimiser l'impact humain et matériel
* 
* Fichier : Application_Fire_Model.gaml
*/
model Application_Fire_Model

import "people.gaml"
import "residents.gaml"
import "fireman.gaml"
import "buildingRoadExit.gaml"
import "plot.gaml"
import "fire.gaml"
import "unused.gaml"
import "Personalities/can_do_defenders.gaml"
import "Personalities/considered_defenders.gaml"
import "Personalities/livelihood_defenders.gaml"
import "Personalities/threat_monitors.gaml"
import "Personalities/threat_avoiders.gaml"
import "Personalities/unaware_reactors.gaml"
import "Personalities/isolated_and_vulnerable.gaml"
import "policeman.gaml"
import "firewatch.gaml"

/*=============================================
*                                               Init 
*=============================================*/
global
{

	// Variables globales
	int starting_hour <- 8; //heure de départ de la simulation
	int current_hour <- 0 update: (starting_hour + (cycle / 60)) mod 24; //heure actuelle
	int current_min <- 0 update: (cycle) mod 60; // minutes actuelles
	bool is_night <- true update: current_hour < 7 or current_hour > 20; //jour / nuit
	string current_time update: string(current_hour) + "h" + string(current_min); //temps actuel
	
	float wind <- 0.2; //force du vent
	float drought <- 0.3; //niveau de secheresse
	float hurting_distance <- 5.0 # m;
	float field_of_view <- 15.0 # m;
	
	int nb_fireman <- 5;
	int nb_bunker <- 0;
	int nb_exit <- 0;
	int nb_fire_station <- 2;
	int nb_police_station <- 1;
	int nb_policeman <- 2;
	
	int nb_fire_starter <- 0;
	int nb_residents_w_answered_1st_call <- 0;
	int fire_size <- 1 update: length(plot where (each.burning = true));
//	int fire_uncontrollable <- 600;
	int fire_uncontrollable <- 300;
	int evacuation_reminder_cycle <- 300;
	bool result_saved <- false;
	bool do_pause <- false;
	string simulation_name <- "No_Cognitive_Biases";
	
	bool use_cognitive_biases <- false;
	int cognitive_biases_influence_occurence <- 0;

	// Intentions
	string run_away <- "Escape";
	string defend <- "Defend";
	string protect <- "Protect";
	string ask_for_help <- "I need help";

	// Beliefs
	string no_danger <- "No danger";
	string potential_danger <- "Potential danger";
	string immediate_danger <- "Immediate danger";

	// Init variables especes
//	int nb_residents <- 0;
//	int nb_isolated_and_vulnerable <- 5;
//	int nb_unaware_reactors <- 5;
//	int nb_threat_avoiders <- 30;
//	int nb_threat_monitors <- 30;
//	int nb_can_do_defenders <- 10;
//	int nb_considered_defenders <- 10;
//	int nb_livelihood_defenders <- 10;

	int nb_residents <- 100;
	int nb_isolated_and_vulnerable <- 0;
	int nb_unaware_reactors <- 0;
	int nb_threat_avoiders <- 0;
	int nb_threat_monitors <- 0;
	int nb_can_do_defenders <- 0;
	int nb_considered_defenders <- 0;
	int nb_livelihood_defenders <- 0;

	// Bouton Application
	bool personalized_msg <- false;
	bool trained_population <- false;
	bool tactical_fireman <- false;
	float burned_distance <- 10.0 # m;
	file bounds_shapefile <- file("../includes/bounds.shp");
	file buildings_shapefile <- file("../includes/building.shp");
	file roads_shapefile <- file("../includes/road.shp");
	//	file waterway_shapefile <- file("../includes/waterway.shp");
	geometry shape <- envelope(envelope(buildings_shapefile) + envelope(roads_shapefile) + envelope(bounds_shapefile));
	graph the_graph;
	int ids <- 1;
	bool evacution_city_reported <- false;
	list<resident> every_resident <- nil update: isolated_and_vulnerable union unaware_reactors union threat_avoiders union threat_monitors union can_do_defenders union
	considered_defenders union livelihood_defenders union resident;
	list<resident> every_resident_alive <- nil update: every_resident where each.alive;
	list<people> every_people_alive <- nil update: every_resident_alive + (fireman + policeman) where each.alive;
	graph road_network;
	graph road_network_practicable;
	int grid_size <- 150;
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
		create fire_starter number: 1 with: [choosed_location::{ 170, 210 }];
		create fire_starter number: 1 with: [choosed_location::{ 750, 300 }];
		
		// Fires (inside the city)
//		create fire_starter number: 1 with: [choosed_location::{ 460, 173 }];
//		create fire_starter number: 1 with: [choosed_location::{ 130, 823 }];
//		create fire_starter number: 1 with: [choosed_location::{ 704, 770 }];
		create fire_starter number: 1 with: [choosed_location::{ 420, 550 }];

		// Random fires
		create fire_starter number: nb_fire_starter;

		// People
		create resident number: nb_residents; //should be 0 if personnalities are used
		create isolated_and_vulnerable number: nb_isolated_and_vulnerable;
		create unaware_reactors number: nb_unaware_reactors;
		create threat_avoiders number: nb_threat_avoiders;
		create threat_monitors number: nb_threat_monitors;
		create can_do_defenders number: nb_can_do_defenders;
		create considered_defenders number: nb_considered_defenders;
		create livelihood_defenders number: nb_livelihood_defenders;
		
		// Police and firefighters
		create fireman number: nb_fireman;
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
	user_command "Create Fire starter here" { create fire_starter number: 1 with: [choosed_location::# user_location]; }

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
experiment No_Cognitive_Biases type: gui
{
	// Boutons d'interaction
	action createFire { create fire_starter; }
	user_command Create_Fire action: createFire;

	// Paramètres
	parameter "Start hour" var: starting_hour category: "Global" min: 0;
	parameter "Wind" var: wind category: "Global" min: 0.0 max: 0.5;
	parameter "Drought" var: drought category: "Global" min: 0.0 max: 0.5;
	parameter "Field of View" var: field_of_view category: "Global" min: 10.0 max: 20.0;
	parameter "Hurting distance" var: hurting_distance category: "Global" min: 1.0 max: 3.0;
	parameter "Nb fireman" var: nb_fireman category: "Agents" min: 0;
	parameter "Nb Policeman" var: nb_policeman category: "Agents" min: 0;

//	parameter "Isolated & Vulnerable" var: nb_isolated_and_vulnerable category: "Residents" min: 0;
//	parameter "Unaware reactors" var: nb_unaware_reactors category: "Residents" min: 0;
//	parameter "Threat avoiders" var: nb_threat_avoiders category: "Residents" min: 0;
//	parameter "Threat monitors" var: nb_threat_monitors category: "Residents" min: 0;
//	parameter "Can do defenders" var: nb_can_do_defenders category: "Residents" min: 0;
//	parameter "Considered defenders" var: nb_considered_defenders category: "Residents" min: 0;
//	parameter "Livelihood defenders" var: nb_livelihood_defenders category: "Residents" min: 0;
	
	init { simulation_name <- "No_Cognitive_Biases"; }

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
			species fireman aspect: sphere3D;
			species policeman aspect: sphere3D;
			species waterway aspect: base refresh: false;
			grid plot transparency: 0.4;
			species fire_starter aspect: base refresh: true;
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
	action createFire { create fire_starter; }
	user_command Create_Fire action: createFire;

	// Paramètres
	parameter "Cognitive Biases" var: use_cognitive_biases init: true category: "Modelisation";
	parameter "Start hour" var: starting_hour category: "Global" min: 0;
	parameter "Wind" var: wind category: "Global" min: 0.0 max: 0.5;
	parameter "Drought" var: drought category: "Global" min: 0.0 max: 0.5;
	parameter "Field of View" var: field_of_view category: "Global" min: 10.0 max: 20.0;
	parameter "Hurting distance" var: hurting_distance category: "Global" min: 1.0 max: 3.0;
	parameter "Nb fireman" var: nb_fireman category: "Agents" min: 0;
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
			species fireman aspect: sphere3D;
			species policeman aspect: sphere3D;
			species waterway aspect: base refresh: false;
			grid plot transparency: 0.4;
			species fire_starter aspect: base refresh: true;
			species city_exit aspect: base transparency: 0.1;
			species building aspect: base;
			species firewatch aspect: base;
			light 1 color: (is_night ? 50 : 230);
		}
	}
}














