/**
* Name: Main Experiment for the BDI Bushfires with Cognitive Biases simulation
*
* Author: Pierre Blarre
* 
* Description:  Bushfires simulation based on the Australian Black Saturday
* 
* This is the main file containing all global variable and the main experiment
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
	int starting_hour <- 7;
	int current_hour <- 0 update: (starting_hour + (cycle / 60)) mod 24;
	int current_min <- 0 update: (cycle) mod 60;
	string current_time update: string(current_hour) + "h" + string(current_min);
	bool is_night <- true update: current_hour < 7 or current_hour > 20;
	
	//Nature
	float burning_probability <- 0.6; //probabilty that a plot will spread fire to one of its neighboring plot
	float wind <- 0.2;
	float drought <- 0.3;
	float hurting_distance <- 10.0 # m;
	float field_of_view <- 15.0 # m;
	float smoke_view <- 50.0 # m;
	int nb_fire <- 0;
	int fire_size <- 1 update: length(plot where (each.burning = true));
	int fire_uncontrollable <- 100; //when is the fire size found incontrable and evacuation alert must be triggered
	int burning_speed <- 10; //value in cycle. 1 is the fastest, 10 default value, above 10 will be very slow
	
	int grid_size <- 150; //Plots' size
	
	//Buildings
	int nb_bunker <- 0;
	int nb_exit <- 0;
	int nb_fire_station <- 2;
	int nb_police_station <- 1;
	bool simple_buildings <- false;
	
	//People and emergency services
	int nb_firefighters <- 5;
	int nb_policemen <- 2;
	
	int alert_msg_sent <- 0 update: alert_msg_sent;
	int nb_residents_w_answered_1st_call <- 0 update: nb_residents_w_answered_1st_call;
	int evacuation_reminder_cycle <- 60; //one reminder per hour
	
	bool tactical_fireman <- false;
	
	//Residents distribution (we use a total of 100 people, for the simulation is slow above this number)
	int nb_residents <- 0;
	int nb_isolated_and_vulnerable <- 5;
	int nb_unaware_reactors <- 5;
	int nb_threat_avoiders <- 30;
	int nb_threat_monitors <- 30;
	int nb_can_do_defenders <- 10;
	int nb_considered_defenders <- 10;
	int nb_livelihood_defenders <- 10;
	
	list<resident> every_resident <- nil update: resident union can_do_defenders union considered_defenders union isolated_and_vulnerable union livelihood_defenders union threat_avoiders union threat_monitors union unaware_reactors ;
	list<resident> every_resident_alive <- nil update: every_resident where each.alive;
	list<people> every_people_alive <- nil update: every_resident_alive + (firefighters + policemen) where each.alive;
	
	list<can_do_defenders> can_do_defenders_alive <- nil update: can_do_defenders where each.alive;
	list<considered_defenders> considered_defenders_alive <- nil update: considered_defenders where each.alive;
	list<isolated_and_vulnerable> isolated_and_vulnerable_alive <- nil update: isolated_and_vulnerable where each.alive;
	list<livelihood_defenders> livelihood_defenders_alive <- nil update: livelihood_defenders where each.alive;
	list<threat_avoiders> threat_avoiders_alive <- nil update: threat_avoiders where each.alive;
	list<threat_monitors> threat_monitors_alive <- nil update: threat_monitors where each.alive;
	list<unaware_reactors> unaware_reactors_alive <- nil update: unaware_reactors where each.alive;
	
	//Cognitive Biases
	bool use_cognitive_biases <- true;
	int cognitive_biases_influence_occurence <- 0;
	int nb_cb_influences <- 0;
	int nb_of_warning_msg_cb <- 0; //total warning message for people with cb
	int nb_ignored_msg_while_cb <- 0;
	float cognitive_biases_distribution <- 0.5;
	
	//keep count of perceives and when they were ingored
	int smoke_perceive_total <- 0;
	int fire_perceive_total <- 0;
	int nb_of_smoke_signals_ignored_cb <- 0;
	int nb_of_fire_signals_ignored_cb <- 0;
	
	//Indicators for when Cognitive Biases
	int triggered_escape_early <- 0;
	int triggered_escape_late <- 0;
	int triggered_defense_early <- 0;
	int triggered_defense_late <- 0;
	int kept_defense_late <- 0;
	int did_not_want_to_evacuate <- 0;
	
	int nb_neglect_of_probability <- 0;
	int nb_semmelweis_reflex <- 0;
	int nb_illusory_truth_effect <- 0;

	//Application
	int ids <- 1; //used for agents identifications
	bool result_saved <- false;
	bool do_pause <- false;
	string simulation_name <- "No_Cognitive_Biases";
	
	//Show 
	bool show_firefighters_messages <- false;
	bool show_police_messages <- false;
	bool show_people_messages <- false;
	bool show_residents_messages <- false;
	bool show_residents_BDI <- false;
	bool show_cognitive_biases_messages <- false;

	bool personalized_msg <- false; //If true, it will increase residents' probability to react to alert messages
	bool trained_population <- false; //if true, it will increase residents' knowledge
	bool tactical_firefighters <- false; //if true, firefighter can call for reinforcements and are placed in strategical places on the map
	bool evacution_city_reported <- false; //true when the evacuation alert has been issued
	
	//Map
	file bounds_shapefile <- file("../assets/shapefiles/bounds.shp");
	file buildings_shapefile <- file("../assets/shapefiles/building.shp");
	file roads_shapefile <- file("../assets/shapefiles/road.shp");
	//file waterway_shapefile <- file("../includes/waterway.shp");
	geometry shape <- envelope(envelope(buildings_shapefile) + envelope(roads_shapefile) + envelope(bounds_shapefile));
	graph the_graph;
	graph road_network;
	graph road_network_practicable;
	
	//Mouse commands (right click on the map)
	// Warning : do not use after 3d rotation or the coordinates will be messed up
	user_command "Create a Fire here" { create fire number: 1 with: [choosed_location::# user_location]; }
	user_command "Create Fire Watch Tower here" { create firewatch number: 1 with: [location::# user_location]; }
	user_command "Create a City Exit here" { create city_exit number: 1 with: [location::# user_location]; }
	
	// Monitoring
	string monitor_ignored_msg_cb <- "0/0"  update: ""+nb_ignored_msg_while_cb + " / " + nb_of_warning_msg_cb;
	string monitor_ignored_smoke_perceive_cb <- "0/0"  update: ""+nb_of_smoke_signals_ignored_cb + " / " + smoke_perceive_total;
	string monitor_ignored_fire_perceive_cb <- "0/0"  update: ""+nb_of_fire_signals_ignored_cb + " / " + fire_perceive_total;
	
	int residents_total <- 0 update: length(every_resident);
	int residents_alive <- 0 update: length(every_resident_alive);
	int residents_dead <- 0 update: length(every_resident) - length(every_resident_alive);
	int residents_alert <- 0 update: length(every_resident_alive where each.on_alert);
	int residents_bunker <- 0 update: length(every_resident_alive where each.in_safe_place);
	int residents_influenced_by_cognitive_biases <- 0 update: length(every_resident where each.cognitive_biases_influence);
	float buildings_damage <-0.0 update:  (building sum_of (each.damage )  / length( building ) ) /255;
	
	int residents_dead_with_cb <- 0 update: length(every_resident where (each.cognitive_biases_influence and !each.alive) );
	
	string cdd_alive <- "0 / "+nb_can_do_defenders update: ""+length(can_do_defenders_alive)+ " / "+nb_can_do_defenders;
	string cd_alive <- "0 / "+nb_considered_defenders update: ""+length(considered_defenders_alive)+ " / "+nb_considered_defenders;
	string iv_alive <- "0 / "+nb_isolated_and_vulnerable update: ""+length(isolated_and_vulnerable_alive)+ " / "+nb_isolated_and_vulnerable;
	string ld_alive <- "0 / "+nb_livelihood_defenders update: ""+length(livelihood_defenders_alive)+ " / "+nb_livelihood_defenders;
	string ta_alive <- "0 / "+nb_threat_avoiders update: ""+length(threat_avoiders_alive)+ " / "+nb_threat_avoiders;
	string tm_alive <- "0 / "+nb_threat_monitors update: ""+length(threat_monitors_alive)+ " / "+nb_threat_monitors;
	string ur_alive <- "0 / "+nb_unaware_reactors update: ""+length(unaware_reactors_alive)+ " / "+nb_unaware_reactors;
	
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

		//Fires - close to Black Saturday
//		create fire number: 1 with: [choosed_location::{ 170, 210 }];
//		create fire number: 1 with: [choosed_location::{ 750, 300 }];
		
		//Faster experiment
		create fire number: 1 with: [choosed_location::{ 420, 550 }]; // in the middle of the city
		create fire number: 1 with: [choosed_location::{ 180, 810 }]; // in the middle of the city
		create fire number: 1 with: [choosed_location::{ 595, 750 }]; // in the middle of the city

		// Random fires
		create fire number: nb_fire;

		// Police and firefighters
		create firefighters number: nb_firefighters;
		create policemen number: nb_policemen;
		
	}

	//stop experiment if : pause is triggered or when no more residents are active or the simulation never ends...
	reflex pause_and_save when: do_pause or (residents_dead + residents_bunker = residents_total) or cycle > 1200
	{
		do_pause <- false;
		do pause;
		do save;
	}
	
	// Save data into CSV files
	action save
	{
		if (!result_saved)
		{
			int nb_res <- length(every_resident);
			
			if (!file_exists("../results/exported_results.csv")) //create file if does not exist
			{
				save
				["Simulation", "Cycles", "Alive (%)", "Dead (%)", "Dead under CB (%)", "Safe (%)", "Alerted", "Reacted 1st call (%)", "Influenced by CB", "Neglect of probability", "Semmelweis reflex", "Illusory of truth", "CB influences", "Warnings sent", "Warnings ignored", "Smoke ignored", "Flames ignored", "Early Escape", "Late Escape", "Early Defense", "Late defense", "Kept defending", "Refused evacuation"]
				header: false to: "../results/exported_results.csv" type: "csv" rewrite: false;
			}
			
			save 
			[ simulation_name, cycle, residents_alive*100/nb_res , residents_dead*100/nb_res, residents_dead_with_cb*100/nb_res, residents_bunker*100/nb_res, residents_alert*100/nb_res, nb_residents_w_answered_1st_call*100/nb_res, residents_influenced_by_cognitive_biases*100/nb_res, nb_neglect_of_probability*100/nb_res, nb_semmelweis_reflex*100/nb_res, nb_illusory_truth_effect*100/nb_res, nb_cb_influences, alert_msg_sent, monitor_ignored_msg_cb, monitor_ignored_smoke_perceive_cb, monitor_ignored_fire_perceive_cb, triggered_escape_early, triggered_escape_late, triggered_defense_early, triggered_defense_late, kept_defense_late, did_not_want_to_evacuate]
			header: false to: "../results/exported_results.csv" type: "csv" rewrite: false;
	
	
			if (!file_exists("../results/exported_results_personnalities_victims.csv"))
			{
				save
				["Simulation", "can_do_defenders (" + nb_can_do_defenders * 100 / nb_res + "%)", "considered_defenders (" + nb_considered_defenders * 100 / nb_res + "%)", "isolated_and_vulnerable (" + nb_isolated_and_vulnerable * 100 / nb_res + "%)", "livelihood_defenders (" + nb_livelihood_defenders * 100 / nb_res + "%)", "threat_avoiders (" + nb_threat_avoiders * 100 / nb_res + "%)", "threat_monitors (" + nb_threat_monitors * 100 / nb_res + "%)", "unaware_reactors (" + nb_unaware_reactors * 100 / nb_res + "%)"]
				header: false to: "../results/exported_results_personnalities_victims.csv" type: "csv" rewrite: false;
			}
	
			//Percentages
			float percentage_dead_can_do_defenders <- length(can_do_defenders where !each.alive) * 100 / nb_can_do_defenders;
			float percentage_dead_considered_defenders <- length(considered_defenders where !each.alive) * 100 / nb_considered_defenders;
			float percentage_dead_isolated_and_vulnerable <- length(isolated_and_vulnerable where !each.alive) * 100 / nb_isolated_and_vulnerable;
			float percentage_dead_livelihood_defenders <- length(livelihood_defenders where !each.alive) * 100 / nb_livelihood_defenders;
			float percentage_dead_threat_avoiders <- length(threat_avoiders where !each.alive) * 100 / nb_threat_avoiders;
			float percentage_dead_threat_monitors <- length(threat_monitors where !each.alive) * 100 / nb_threat_monitors;
			float percentage_dead_unaware_reactors <- length(unaware_reactors where !each.alive) * 100 / nb_unaware_reactors;
			save
			[simulation_name, percentage_dead_can_do_defenders, percentage_dead_considered_defenders, percentage_dead_isolated_and_vulnerable, percentage_dead_livelihood_defenders, percentage_dead_threat_avoiders, percentage_dead_threat_monitors, percentage_dead_unaware_reactors]
			header: false to: "../results/exported_results_personnalities_victims.csv" type: "csv" rewrite: false;
		}
	
		result_saved <- true;
		write "Saved data to CSV files";
	}
}

experiment Main type:gui 
{
	// User interface
	action createFire { create fire; }
	user_command Create_Fire action: createFire;
	
	parameter "Cognitive Biases" var: use_cognitive_biases init: use_cognitive_biases category: "Cognitive Biases (hit reload after changing these values)";
	parameter "Cognitive Biases Distribution" var: cognitive_biases_distribution init: cognitive_biases_distribution category: "Cognitive Biases (hit reload after changing these values)" max: 1.0;
	
	parameter "Firefighters Messages" var: show_firefighters_messages init: true category: "Messages";
	parameter "Police Messages" var: show_police_messages init: true category: "Messages";
	parameter "Residents Messages" var: show_residents_messages init: true category: "Messages";
	parameter "BDI Information" var: show_residents_BDI init: false category: "Messages";
	parameter "Cognitive Biases Messages" var: show_cognitive_biases_messages init: true category: "Messages";
	
	parameter "Pause and Save" var: do_pause init: do_pause category: "Global";
	parameter "Simple buildings" var: simple_buildings category: "Global" init: true;
	parameter "Tactical fireman" var: tactical_fireman category: "Global";
	parameter "Start hour" var: starting_hour category: "Global" min: 0;
	parameter "Wind" var: wind category: "Global" min: 0.0;
	parameter "Drought" var: drought category: "Global" min: 0.0;
	parameter "Field of View" var: field_of_view category: "Global" min: 10.0;
	parameter "Hurting distance" var: hurting_distance category: "Global" min: 1.0;
	parameter "Uncontrollable fire size" var: fire_uncontrollable category: "Global";
	parameter "Evacuation Reminder (in cycles)" var: evacuation_reminder_cycle category: "Global";
	parameter "Burning speed (in cycles)" var: burning_speed category: "Global" min: 2;
	
	parameter "Nb firefighters" var: nb_firefighters category: "Emergency Services" min: 0;
	parameter "Nb Policeman" var: nb_policemen category: "Emergency Services" min: 0;

	parameter "Residents" var: nb_residents category: "Residents" min: 0;
    parameter "Can do defenders" var: nb_can_do_defenders category: "Residents" min: 0;
    parameter "Considered defenders" var: nb_considered_defenders category: "Residents" min: 0;
    parameter "Isolated & Vulnerable" var: nb_isolated_and_vulnerable category: "Residents" min: 0;
    parameter "Livelihood defenders" var: nb_livelihood_defenders category: "Residents" min: 0;
    parameter "Threat avoiders" var: nb_threat_avoiders category: "Residents" min: 0;
    parameter "Threat monitors" var: nb_threat_monitors category: "Residents" min: 0;
    parameter "Unaware reactors" var: nb_unaware_reactors category: "Residents" min: 0;
	
	init { 
		
		simulation_name <- "Main";
		
		// People
		create resident number: nb_residents; //should be 0 if personnalities are used
		create can_do_defenders number: nb_can_do_defenders;
		create considered_defenders number: nb_considered_defenders;
		create isolated_and_vulnerable number: nb_isolated_and_vulnerable;
		create livelihood_defenders number: nb_livelihood_defenders;
		create threat_avoiders number: nb_threat_avoiders;
		create threat_monitors number: nb_threat_monitors;
		create unaware_reactors number: nb_unaware_reactors;
	}

	output
	{
		// Monitoring
		monitor "Current_time" value: current_time;
		monitor "Fire Size" value: fire_size;
		
		monitor "Alive" value: residents_alive;
		monitor "Dead" value: residents_dead;
		monitor "Dead with CB" value: residents_dead_with_cb;
		monitor "Alerted" value: residents_alert;
		monitor "Reacted on first warning" value: nb_residents_w_answered_1st_call;
		monitor "Safe" value: residents_bunker;
		
		monitor "Can Do defenders" value: cdd_alive;
        monitor "Considered Defenders" value: cd_alive;
        monitor "Isolated and vulnerable" value: iv_alive;
        monitor "Livelihood Defenders" value: ld_alive;
        monitor "Threat Avoiders" value: ta_alive;
        monitor "Threat Monitors" value: tm_alive;
        monitor "Unaware Reactors" value: ur_alive;
		
		monitor "With Cognitive Biases" value: residents_influenced_by_cognitive_biases;
		monitor "With Neglect of probablity" value: nb_neglect_of_probability;
		monitor "With Semmelweis reflex" value: nb_semmelweis_reflex;
		monitor "With Illusory of truth" value: nb_illusory_truth_effect;
		
		monitor "Cognitive Biases influence" value: nb_cb_influences;
		monitor "Global warning messages" value: alert_msg_sent;
		monitor "Warning ignored because Cognitive Biases" value: monitor_ignored_msg_cb;
		
		monitor "Smoke perceived ignored" value: monitor_ignored_smoke_perceive_cb;
		monitor "Fire perceived ignored" value: monitor_ignored_fire_perceive_cb;
		
		monitor "Escaped early" value: triggered_escape_early;
        monitor "Escaped late" value: triggered_escape_late;
        monitor "Defended early" value: triggered_defense_early;
        monitor "Defended late" value: triggered_defense_late;
        monitor "Kept defending" value: kept_defense_late;
        monitor "Did not want to evacuate" value: did_not_want_to_evacuate;
	
//		monitor "Buildings damage" value: buildings_damage color: #grey;

		// Graphs
		display Global
		{
			chart "Global" type: series size: { 0.5, 1 } position: { 0, 0 }
			{
				data "Fire Size" value: fire_size / 50 color: # orange;
				data "Cognitive Biases influence" value: cognitive_biases_influence_occurence color: # blue;
				data "Dead" value: length(every_resident where !each.alive) color: # red;
				data "Alerted" value: length(every_resident where each.on_alert) color: # yellow;
				data "Safe" value: length(every_resident where each.in_safe_place) color: # green;
//				data "Damage" value: (building sum_of (each.damage)) / length(building) color: # darkgrey;
			}
			
			// Survivors by profiles
			chart "Survivors" type: pie size: { 0.5, 0.5 } position: { 0.5, 0.5 }
			{
				data "can_do_defenders" value: length(can_do_defenders where each.alive) color: # green;
				data "considered_defenders" value: length(considered_defenders where each.alive) color: # darkgreen;
				data "livelihood_defenders" value: length(livelihood_defenders where each.alive) color: # lightgreen;
				data "threat_monitors" value: length(threat_monitors where each.alive) color: # purple;
				data "threat_avoiders" value: length(threat_avoiders where each.alive) color: # violet;
				data "unaware_reactors" value: length(unaware_reactors where each.alive) color: # cyan;
				data "isolated_and_vulnerable" value: length(isolated_and_vulnerable where each.alive) color: # blue;
			}
			
			// Dead  by profiles
			chart "Deaths" type: pie size: { 0.5, 0.5 } position: { 0.5, 0 }
			{
				data "can_do_defenders" value: length(can_do_defenders where !each.alive) color: # green;
				data "considered_defenders" value: length(considered_defenders where !each.alive) color: # darkgreen;
				data "livelihood_defenders" value: length(livelihood_defenders where !each.alive) color: # lightgreen;
				data "threat_monitors" value: length(threat_monitors where !each.alive) color: # purple;
				data "threat_avoiders" value: length(threat_avoiders where !each.alive) color: # violet;
				data "unaware_reactors" value: length(unaware_reactors where !each.alive) color: # cyan;
				data "isolated_and_vulnerable" value: length(isolated_and_vulnerable where !each.alive) color: # blue;
			}
		}

		// 3D Map
		display map type: opengl
		{
			light id:1 type:direction direction:{1,1,1} color: (is_night ? 50 : 230); // day / night - does not seem to be working
			
			species building aspect: base;
			species road aspect: base;
			species firewatch aspect: base;
			species city_exit aspect: base transparency: 0.1;
			species waterway aspect: base refresh: false;
			
			species fire aspect: base refresh: true;
			grid plot transparency: 0.4;
			
			species people aspect: sphere3D;
			
			species firefighters aspect: sphere3D;
			species policemen aspect: sphere3D;

			species resident aspect: sphere3D;
			species can_do_defenders aspect: sphere3D;
            species considered_defenders aspect: sphere3D;
            species isolated_and_vulnerable aspect: sphere3D;
            species livelihood_defenders aspect: sphere3D;
            species threat_avoiders aspect: sphere3D;
            species threat_monitors aspect: sphere3D;
            species unaware_reactors aspect: sphere3D;
		}
	}
}


////Creates a null pointer exception : https://github.com/gama-platform/gama/issues/2432
//experiment Main_Batch parent: Main type: batch repeat: 2 keep_seed: false until: fire_size <= 0 or cycle > 1200
//{
//	init { 
//		simulation_name <- "Batch Main";
//		result_saved <- false;
//	}
//
//	reflex end_of_runs
//	{
//		ask simulations { do save; }
//		write "fin batch";
//	}
//
//	permanent
//	{
//		display Survivor_pie
//		{
//			chart "Global" type: series size: { 0.5, 1 } position: { 0, 0 }
//			{
//				data "Fire Size" value: fire_size / 50 color: # orange;
//				data "Dead people" value: simulations collect length(every_resident where !each.alive) color: # red;
//				data "People in alerte" value: simulations collect length(every_resident where each.on_alert) color: # yellow;
//				data "People in safe place" value: simulations collect length(every_resident where each.in_safe_place) color: # green;
//				data "Buildings damage" value: simulations collect ((building sum_of (each.damage)) / length(building)) color: # darkgrey;
//			}
//
//			chart "Survivors" type: pie size: { 0.5, 0.5 } position: { 0.5, 0.5 }
//			{
//				data "can_do_defenders" value: simulations collect length(can_do_defenders where each.alive) color: # green;
//				data "considered_defenders" value: simulations collect length(considered_defenders where each.alive) color: # darkgreen;
//				data "livelihood_defenders" value: simulations collect length(livelihood_defenders where each.alive) color: # lightgreen;
//				data "threat_monitors" value: simulations collect length(threat_monitors where each.alive) color: # purple;
//				data "threat_avoiders" value: simulations collect length(threat_avoiders where each.alive) color: # violet;
//				data "unaware_reactors" value: simulations collect length(unaware_reactors where each.alive) color: # cyan;
//				data "isolated_and_vulnerable" value: simulations collect length(isolated_and_vulnerable where each.alive) color: # blue;
//			}
//
//			chart "Dead" type: pie size: { 0.5, 0.5 } position: { 0.5, 0 }
//			{
//				data "can_do_defenders" value: simulations collect length(can_do_defenders where !each.alive) color: # green;
//				data "considered_defenders" value: simulations collect length(considered_defenders where !each.alive) color: # darkgreen;
//				data "livelihood_defenders" value: simulations collect length(livelihood_defenders where !each.alive) color: # lightgreen;
//				data "threat_monitors" value: simulations collect length(threat_monitors where !each.alive) color: # purple;
//				data "threat_avoiders" value: simulations collect length(threat_avoiders where !each.alive) color: # violet;
//				data "unaware_reactors" value: simulations collect length(unaware_reactors where !each.alive) color: # cyan;
//				data "isolated_and_vulnerable" value: simulations collect length(isolated_and_vulnerable where !each.alive) color: # blue;
//			}
//		}
//	}
//}
