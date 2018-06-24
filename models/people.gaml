/**
* Name:  People specie
*
* Author: Pierre Blarre
* 
* Based on a model without BDI architecture by : Sofiane Sillali, Thomas Artigue, Pierre Blarre
* 
* Description: 
* Mother specie for residents, firefighters and policemen. 
* Common moving skills (go to work, go home, go to shelter) following the road network
* Actions regarding dangerous situations (eaction to danger)
* Communication ( Send and receive messages )
* 
*/

model Bushfires_BDI_Cognitive_Biases
import "main.gaml"

species people skills: [moving, fipa] control: simple_bdi
{
	// Physical attributes
	int id <- 1;
	float energy <- float(rnd(200, 255));
	bool alive <- true;
	point target;
	rgb color <- # green;
	building home;
	building work;
	bool at_home;
	bool at_work <- false;
	bool in_safe_place <- false;
	bool warning_sent <- false;
	agent escape_target <- nil;
	bool on_alert <- false;
	bool fighting_fire <- false;
	bool go_fighting <- false;
	
	// Psychological attributes
	int motivation; //higher motivation increases speed and defense capacity
	int risk_awareness; //higher awareness will increase response to messages and escape_intention
	int knowledge; //level of knowledge crisis management and technical abilities -> should influend cognitive biases
	int training; //level of training will influence the three previous values
	int fear_of_fire <- rnd(0, 1); //will influence decision making	
	
	float default_probability_to_react <- 0.60; //by default we suppose at least 60% of people will react to an alert
	float probability_to_react <- 0.60; //by default we suppose at least 60% of people will react to an alert
	int nb_of_warning_msg <- 0;
	int nb_of_ignored_warning_msg <- 0;
	
	//Definition of the variables featured in the BDI architecture. 
	//How is this used, I am not sure. TODO: research how this should be used
	float plan_persistence <- 1.0; 
	float intention_persistence <- 1.0;
	bool probabilistic_choice <- false;
	
	//Cognitive Biases
	//Whether the agent's choices will be influenced or not by the cognitive biases algorithms
	bool cognitive_biases_influence <- false;
	bool neglect_of_probability_cb_influence <- false;
	bool semmelweis_reflex_cb_influence <- false;
	bool illusory_truth_effect_cb_influence <- false;
	
	
    //Beliefs
	float default_belief_strengh <- 0.5;
	predicate no_danger_belief <- new_predicate("no_danger_belief",true);
	predicate potential_danger_belief <- new_predicate("potential_danger_belief",true);
	predicate immediate_danger_belief <- new_predicate("immediate_danger_belief",true);
	predicate risk_of_fires_today <- new_predicate("risk_of_fire",true);
	predicate can_defend_belief <- new_predicate("can_defend_belief",true);
	predicate i_can_escape <- new_predicate("i_can_escape",true); 
	
	//Desires
	predicate work_desire <- new_predicate("work_desire",10);
	predicate home_desire <- new_predicate("home_desire",20);
	predicate call_911_desire <- new_predicate("call_911_desire",30);
	predicate defend_desire <- new_predicate("defend_desire",40);
	predicate escape_desire <- new_predicate("escape_desire",50); //desire to escape is the equal to the desire to shelter
	
	// OLD BDI - Left for now for firefighters and policemen compatibility TODO convert them to simple_bdi architecture
	list<string> desires <- nil;
	string intention <- nil;
	string belief <- "no_danger_belief";
	// OLD BDI Intentions
	string run_away <- "Escape";
	string defend <- "Defend";
	string protect <- "Protect";
	string ask_for_help <- "I need help";
	// OLD BDI Beliefs
	string no_danger <- "No danger";
	string potential_danger <- "Potential danger";
	string immediate_danger <- "Immediate danger";

	init
	{
		ids <- ids + 1;
		id <- ids;

		// these attributes will vary for different behavior profiles
		training <- trained_population ? 2 : 0; // if training set to true it will influence psychological attributes
		risk_awareness <- training + fear_of_fire;
		motivation <- training - fear_of_fire;
		knowledge <- training - fear_of_fire;
		do add_belief(no_danger_belief, default_belief_strengh);
	}

	aspect sphere3D { draw sphere(3) at: { location.x, location.y, location.z + 3 } color: color; }
//	aspect sphere3D { draw circle(3) at: { location.x, location.y } color: color; } //2d version
	
	action status (string msg)
	{
		write string(self) + " ("+energy+") : " + msg;
		 
		if(show_residents_BDI)
		{
			write "B:" + length(belief_base) + ":" + belief_base; 
			write "D:" + length(desire_base) + ":" + desire_base; 
			write "I:" + length(intention_base) + ":" + intention_base; 
		}
	}
	
	// Go somewhere with the road network
	// @params : destination (agent)
	// @returns : boolean (reached destination or not)
	action go_to (agent a)
	{
		if (!(target overlaps a)) { target <- any_location_in(a); } // set target destination to agent location
		do goto target: target on: road_network; // move along roads TODO check if roads are usable if not, should try to walk
		if (location = target) { return true; } 
		else { return false; }
	}
	
	//for now unused, but should be used if all roads become unusable
	action walk (agent a)
	{
		speed <- rnd(5.0, 10.0) # km / # h; //We assume they are at least going at average walking speed
		if (!(target overlaps a)) { target <- any_location_in(a); } // set target destination to agent location
		do goto target: target; // move anywhere
		if (location = target) { return true; } //reached 
		return false;
	}

	//Send message to other agents
	action send_msg (list<agent> main_recipients, list<agent> main_secondary, string msg)
	{
		if (empty(main_recipients)) // if main list empty, we use the second list
		{
			main_recipients <- main_secondary;
		}
		if (!empty(main_recipients))
		{
			do start_conversation(to: main_recipients, protocol: 'fipa-propose', performative: 'propose', contents: [msg]);
		}
	}

	//@returns agent
	action get_closest_safe_place
	{
		float dist_to_closest_bunker;
		float dist_to_closest_exit;
		building closest_bunker;
		city_exit closest_exit;
		
		if (nb_bunker > 0)
		{
			closest_bunker <- (building where (each.bunker) closest_to location);
			dist_to_closest_bunker <- closest_bunker distance_to location;
		}

		if (nb_exit > 0)
		{
			closest_exit <- city_exit closest_to location;
			dist_to_closest_exit <- closest_exit distance_to location;
		}

		if (dist_to_closest_bunker < dist_to_closest_exit and closest_bunker != nil)
		{
			return closest_bunker;
		} 
		else if (closest_exit != nil)
		{
			return closest_exit;
		}

		return agent(nil);
	}

	//Get info on close fire(s) - is there one and if yes from where?
	// returns : bool fire is close, bool fire_is_north, bool fire_is_west
	action get_closest_fire_at_hurting_distance
	{
		bool danger <- false;
		bool fire_is_north <- false;
		bool fire_is_west <- false;
		list<plot> plotS_in_fire <- plot at_distance field_of_view where each.burning; //get burning plots in view distance

		// S'il existe des feux à distance dangeureuse
		if (length(plotS_in_fire) > 0)
		{
			danger <- true;
			plot plot_in_fire <- plotS_in_fire closest_to location; //get the closest one from location
			if (plot_in_fire.location.x < location.x) { fire_is_west <- true; }
			if (plot_in_fire.location.y < location.y) { fire_is_north <- true; }
		}

		return [danger, fire_is_north, fire_is_west];
	}


	// Get the city exit to try avoid the fire
	// @params : information du feu, bool:trouver le plus proche, inclure les bunker
	// @returns : target point
	action get_city_exit_opposed_to_fire (list<bool> fire_direction, bool m_closest, bool include_bunker)
	{
		bool fire_is_north <- fire_direction[1];
		bool fire_is_west <- fire_direction[2];
		list<agent> exit_at_Y <- nil;
		list<agent> exit_at_X <- nil;
		list<agent> exits_found <- nil;
		point target_point <- nil;

		// Get exit coordinates
		// North exits at south from fire. West exits as East from fire. Etc.
		exit_at_Y <- fire_is_north ? city_exit where (each.location.y > location.y) : city_exit where (each.location.y < location.y);
		exit_at_X <- fire_is_west ? city_exit where (each.location.x > location.x) : city_exit where (each.location.x < location.x);
		if (include_bunker) //Only when bunker buildings are activated
		{
			exit_at_Y <- exit_at_Y + (fire_is_north ? building where (each.bunker and each.location.y > location.y) : building where (each.bunker and each.location.y < location.y));
			exit_at_X <- exit_at_X + (fire_is_west ? building where (each.bunker and each.location.x > location.x) : building where (each.bunker and each.location.x < location.x));
		}

		if (length(exit_at_Y) > 0)
		{
			if (length(exit_at_X) > 0)
			{
				exits_found <- exit_at_Y inter exit_at_X;
				if (length(exits_found) = 0) { exits_found <- exit_at_Y; }
			}
		} 
		else
		{
			if (length(exit_at_X) > 0) { exits_found <- exit_at_X; }
		}

		if (length(exits_found) > 0)
		{
			agent exit_f <- m_closest ? exits_found closest_to location : one_of(exits_found);
			target_point <- exit_f != nil ? any_point_in(exit_f) : nil;
		}

		return target_point;
	}



	// TODO replaced with simple_bdi "perceives"
	// Left for emergency services compatibility
	// @returns  : boolean
	action check_if_danger_is_near
	{
		list<bool> directions <- get_closest_fire_at_hurting_distance();
		// Si un danger existe ( bool danger <- directions[0] ) et que ma conscience des risques n'est pas nulle => je change de direction
		return directions;
	}


	// TODO replaced with simple_bdi "plan" -> escape
	// @params : fire info (from get_closest_fire_at_hurting_distance)
	action react_to_danger (list<bool> directions)
	{
		//  if directions[0] is true then there is a danger
		// if my risk_awareness isn't null => I change direction
		if (directions[0] and risk_awareness > 0)
		{
			if(show_people_messages) { 
				do status("I perceived a danger at North ? => " + directions[1] + " : West ? =>" + directions[2]);
			}

			// Default, I go opposite from the fire
			bool include_bunker <- false;
			bool find_the_nearest <- false;

			// But if my knowledge is high, then I know where are the nearest city exits and the bunker locations
			if (knowledge >= 3)
			{
				include_bunker <- true;
				find_the_nearest <- true;
			}

			// Search for my target
			city_exit plan_b <- get_city_exit_opposed_to_fire(directions, find_the_nearest, include_bunker);
			escape_target <- plan_b != nil ? plan_b : escape_target;
			if(show_people_messages) { do status("I'm trying to escape through " + escape_target); }
		}

	}

	//Simulate watering terrain and cutting vegetation to avoid fire spreading
	action increase_terrain_resistance (int increase_value)
	{
		building bd_location <- at_home ? home : (at_work ? work : nil);
		if (bd_location != nil)
		{
			// neighboring nature plots
			list<plot> nature_plots <- plot where (!each.is_road and each.heat > -5.0) overlapping bd_location;

			//increase resistance
			if (length(nature_plots) > 0)
			{
				// Treat burning plots first
				plot a_plot <- one_of(nature_plots where each.burning);
				if (a_plot = nil) { a_plot <- one_of(nature_plots); }

				// Dimish plot heat
				a_plot.heat <- a_plot.heat - increase_value / 2;
				if (a_plot.heat <= -5.0) { a_plot.color <- # magenta; }
			}
		}
	}

	//Simulate  watering building and cutting vegetation around it to avoid fire spreading
	action increase_building_resistance (int increase_value)
	{
		if (at_home) { home.resistance <- home.resistance + int(increase_value / 2); }
		if (at_work) { work.resistance <- work.resistance + int(increase_value / 2); }
	}
	
	
	// Save data into CSV files
	action save_result
	{
		if (!result_saved)
		{
			// Percentages
			int nb_res <- length(every_resident);
			int nb_res_alerted <- length(every_resident where each.on_alert);
			int nb_dead_res <- length(every_resident where !each.alive);
			float percentage_dead_res <- nb_dead_res * 100 / nb_res;
			float percentage_res_alive <- 100 - percentage_dead_res;
			float percentage_res_answered_1st_call <- 100 - percentage_dead_res;
			float percentage_residents_w_answered_1st_call <- nb_residents_w_answered_1st_call * 100 / nb_res;
			//float percentage_alerted <- nb_res_alerted * 100 / nb_res ;
			float percentage_in_safe_place <- length(every_resident where each.in_safe_place) * 100 / nb_res;

			// If file does not exist yet, we write the column names
			if (!file_exists("../results/exported_results.csv"))
			{
				save ["Simulation", "Msg Personnalises", "Population entraînee", "Tactiques Pompiers/Fire Watch", "Rescapes (%)", "Victims (%)", "Reaction a l'ordre d'evacution (%)",
				//					"Alerté",
				"En lieux surs(%)", "Degat sur les batiments (%)"] to: "../results/exported_results.csv" type: "csv" rewrite: false;
			}

			// Ajouts des résultats de la simulation dans le fichier csv
			save [simulation_name, personalized_msg, trained_population, tactical_firefighters, percentage_res_alive, percentage_dead_res, percentage_residents_w_answered_1st_call,
			//				percentage_alerted,
			percentage_in_safe_place,buildings_damage] header: true to: "../results/exported_results.csv" type: "csv" rewrite: false;

			// Si le fichier n'existe pas, on écrit son header
			if (!file_exists("../results/exported_results_personnalities_victims.csv"))
			{
				save
				["Simulation", "can_do_defenders (" + nb_can_do_defenders * 100 / nb_res + "%)", "considered_defenders (" + nb_considered_defenders * 100 / nb_res + "%)", "isolated_and_vulnerable (" + nb_isolated_and_vulnerable * 100 / nb_res + "%)", "livelihood_defenders (" + nb_livelihood_defenders * 100 / nb_res + "%)", "threat_avoiders (" + nb_threat_avoiders * 100 / nb_res + "%)", "threat_monitors (" + nb_threat_monitors * 100 / nb_res + "%)", "unaware_reactors (" + nb_unaware_reactors * 100 / nb_res + "%)"]
				header: true to: "../results/exported_results_personnalities_victims.csv" type: "csv" rewrite: false;
			}

			// Calcul des pourcentages
			float percentage_dead_can_do_defenders <- length(can_do_defenders where !each.alive) * 100 / nb_can_do_defenders;
			float percentage_dead_considered_defenders <- length(considered_defenders where !each.alive) * 100 / nb_considered_defenders;
			float percentage_dead_isolated_and_vulnerable <- length(isolated_and_vulnerable where !each.alive) * 100 / nb_isolated_and_vulnerable;
			float percentage_dead_livelihood_defenders <- length(livelihood_defenders where !each.alive) * 100 / nb_livelihood_defenders;
			float percentage_dead_threat_avoiders <- length(threat_avoiders where !each.alive) * 100 / nb_threat_avoiders;
			float percentage_dead_threat_monitors <- length(threat_monitors where !each.alive) * 100 / nb_threat_monitors;
			float percentage_dead_unaware_reactors <- length(unaware_reactors where !each.alive) * 100 / nb_unaware_reactors;
			// Ajouts des résultats de la simulation dans le fichier csv
			save
			[simulation_name, percentage_dead_can_do_defenders, percentage_dead_considered_defenders, percentage_dead_isolated_and_vulnerable, percentage_dead_livelihood_defenders, percentage_dead_threat_avoiders, percentage_dead_threat_monitors, percentage_dead_unaware_reactors]
			header: true to: "../results/exported_results_personnalities_victims.csv" type: "csv" rewrite: false;
		}

		result_saved <- true;
	}
	

}


