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
import "Bushfires_BDI_Cognitive_Biases.gaml"

species people skills: [moving, fipa] control: simple_bdi
{

	// Physical attributes
	int id <- 1;
//	int energy <- rnd(200, 255);
	float energy <- 200.0;
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
	

	// OLD BDI
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
	
	// Psychological attributes
	int motivation; //higher motivation increases speed and defense capacity
	int risk_awareness; //higher awareness will increase response to messages and escape_intention
	int knowledge; //level of knowledge crisis management and technical abilities -> should influend cognitive biases
	int training; //level of training will influence the three previous values
	int fear_of_fire <- rnd(0, 1); //will influence decision making	

	// Init
	init
	{
		ids <- ids + 1;
		id <- ids;

		// training and will influence psychological attributes
		training <- trained_population ? 2 : 0;
		
		risk_awareness <- training + fear_of_fire;
		motivation <- training - fear_of_fire;
		knowledge <- training - fear_of_fire;
		
		// these attributes will be different for each personnalities
	}

	// Graphic aspect
	aspect sphere3D { draw sphere(3) at: { location.x, location.y, location.z + 3 } color: color; }
	
	action status (string msg)
	{
		write string(self) + " ("+energy+") : " + msg; 
//		write "Plans : " + plans_base;
		write "B:" + length(belief_base) + ":" + belief_base; 
		write "D:" + length(desire_base) + ":" + desire_base; 
		write "I:" + length(intention_base) + ":" + intention_base; 
	}
	
	// Go somewhere
	// @params : destination (agent)
	// @returns : boolean (reached destination or not)
	action go_to (agent a)
	{
		if (!(target overlaps a)) { target <- any_location_in(a); } // set target destination to agent location

		do goto target: target on: road_network; // move along roads

		// reached destination
		if (location = target) { return true; } 
		else { return false; }
	}
	
	
//	// Donner l'alerte au feu si : en vie, n'est pas trop égoîste, est en alerte
//	reflex saw_the_fire when: alive and on_alert and !warning_sent
//	{
//
//	// Si la conscience des risques d'une personne est supérieure à la moyenne ...
//		if (risk_awareness > 2)
//		{
//		// ...elle alerte les pompiers
//			do send_msg([one_of(firefighters where each.alive)], nil, 'Il y a un feu!');
//			// do start_conversation ( to : [one_of(firefighters where each.alive)], protocol : 'fipa-propose', performative : 'propose', contents : ['Il y a un feu!'] );
//			warning_sent <- true;
//			belief <- potential_danger_belief;
//		}
//
//	}


	//Send message to other agents
	action send_msg (list<agent> main_recipients, list<agent> main_secondary, string msg)
	{
		if (empty(main_recipients)) // if main list empty, we use the second list
		{
			main_recipients <- main_secondary;
		}
		if (!empty(main_recipients))
		{
//			write "911 conversation started";
			do start_conversation(to: main_recipients, protocol: 'fipa-propose', performative: 'propose', contents: [msg]);
		}

	}

	// Save data into a CSV file
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
	//====================== Fin action save_result ================================================

	//======================  Début  action get_closest_safe_place ================================================
	// Récupérer l'issue la plus proches
	// return : agent : issue
	action get_closest_safe_place
	{

	// On recherche l'issue la plus proche (quitter la ville ou aller dans un bunker)
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
		} else
		{
			if (closest_exit != nil)
			{
				return closest_exit;
			}

		}

		// Si aucun sortie trouvée, on renvois 
		return agent(nil);
	}
	//====================== Fin action get_closest_safe_place ================================================


	//======================  Début  action get_closest_fire_at_hurting_distance ================================================
	// Récupérer la direction du feu à distance dangeureuse
	// return : bool fire is close, bool fire_is_north, bool fire_is_west
	action get_closest_fire_at_hurting_distance
	{

	// Var
		bool danger <- false;
		bool fire_is_north;
		bool fire_is_west;
		list<plot> plotS_in_fire <- plot at_distance field_of_view where each.burning;

		// S'il existe des feux à distance dangeureuse
		if (length(plotS_in_fire) > 0)
		{
			danger <- true;

			// Récupération du feux le plus proche
			plot plot_in_fire <- plotS_in_fire closest_to location;
			if (plot_in_fire.location.x < location.x)
			{
			// Le feu est à l'ouest
				fire_is_west <- true;
			} else
			{
			// Le feu est à l'est
				fire_is_west <- false;
			}

			if (plot_in_fire.location.y < location.y)
			{
			// Le feu est au nord
				fire_is_north <- true;
			} else
			{
			// Le feu est au sud
				fire_is_north <- false;
			}

		}

		return [danger, fire_is_north, fire_is_west];
	}
	//====================== Fin action get_closest_fire_at_hurting_distance ================================================


	//======================  Début  action get_city_exit_opposed_to_fire ================================================
	// Récupérer la sorties (la plus proche ou non) opposée au feux
	// paramètre : information du feu, bool:trouver le plus proche, inclure les bunker
	// return : issue trouvée
	action get_city_exit_opposed_to_fire (list<bool> fire_direction, bool m_closest, bool include_bunker)
	{

	// Je me dirige vers une sortie opposée au feu
		bool fire_is_north <- fire_direction[1];
		bool fire_is_west <- fire_direction[2];
		list<agent> exit_at_Y <- nil;
		list<agent> exit_at_X <- nil;
		list<agent> exits_found <- nil;
		point target_point <- nil;

		// Récupération des sortie opposées en Y et en X
		// (= toutes les sorties nords sur le feu est au sud et toutes les sorties ouest sir le feu est à l'est)
		exit_at_Y <- fire_is_north ? city_exit where (each.location.y > location.y) : city_exit where (each.location.y < location.y);
		exit_at_X <- fire_is_west ? city_exit where (each.location.x > location.x) : city_exit where (each.location.x < location.x);
		if (include_bunker)
		{
			exit_at_Y <- exit_at_Y + (fire_is_north ? building where (each.bunker and each.location.y > location.y) : building where (each.bunker and each.location.y < location.y));
			exit_at_X <- exit_at_X + (fire_is_west ? building where (each.bunker and each.location.x > location.x) : building where (each.bunker and each.location.x < location.x));
		}

		// S'il existe au moins une sortie opposée en Y
		if (length(exit_at_Y) > 0)
		{
		// On essaye de combiner les sorties opposées en X et en Y
			if (length(exit_at_X) > 0)
			{
				exits_found <- exit_at_Y inter exit_at_X;
				// Si aucune sortie ne correspond sur X et Y
				if (length(exits_found) = 0)
				{
				// on ne s'interresse qu'aux sorties opposées en Y
					exits_found <- exit_at_Y;
				}

			}

		} else
		{
		// Aucune sorties n'est opposées  en Y
		// On regarde s'il en existe au moins une en X
			if (length(exit_at_X) > 0)
			{
				exits_found <- exit_at_X;
			}

		}

		// S'il une sortie opposée a été trouvée
		if (length(exits_found) > 0)
		{

		// On récupère la plus proche ou non en fonction du paramètre m_closest
			agent exit_f <- m_closest ? exits_found closest_to location : one_of(exits_found);
			target_point <- exit_f != nil ? any_point_in(exit_f) : nil;
		}

		return target_point;
	}
	//====================== Fin action get_city_exit_opposed_to_fire ================================================



	//======================  Début  action check_if_danger_is_near ================================================
	// Regarder s'il existe un danger prche
	// return : bool: danger proche
	action check_if_danger_is_near
	{

		// Je regarde si un feu est à distance de danger
		list<bool> directions <- get_closest_fire_at_hurting_distance();

		// Si un danger existe ( bool danger <- directions[0] ) et que ma conscience des risques n'est pas nulle => je change de direction
		return directions;
	}
	//====================== Fin action check_if_danger_is_near ================================================

	//======================  Début  action react_to_danger ================================================
	// Se déplacer vers une destination
	// paramètre : infos sur le feu
	action react_to_danger (list<bool> directions)
	{
	// Si un danger existe ( bool danger <- directions[0] ) et que ma conscience des risques n'est pas nulle => je change de direction
		if (directions[0] and risk_awareness > 0)
		{
			write string(self) + " : il y a un danger ";
			write string(self) + " : Le feu est proche = feux au nord ? => " + directions[1] + " : feux à l'ouest ? =>" + directions[2];

			// Par défaut, je vais vers une des sorties opposées car je ne connais ni la plus proche, ni les bunkers
			bool include_bunker <- false;
			bool find_the_nearest <- false;

			// Mais si ma connaissance est supérieur à la moyenne
			if (knowledge >= 3)
			{
				// Je connais les bunkers et  les soties les plus proches
				include_bunker <- true;
				find_the_nearest <- true;
			}

			// Je recherche un plan B en fonction de mes connaissances 
			city_exit plan_b <- get_city_exit_opposed_to_fire(directions, find_the_nearest, include_bunker);

			// Si j'en ai trouvé un, il devient ma nouvelle destination
			escape_target <- plan_b != nil ? plan_b : escape_target;
			write string(self) + " : je vais vers " + escape_target;
		}

	}
	//====================== Fin action react_to_danger ================================================


	//mouiller terrain / couper herbe -> augmenter la resitance au feu
	action increase_terrain_resistance (int increase_value)
	{
		building bd_location <- at_home ? home : (at_work ? work : nil);
		if (bd_location != nil)
		{

		//si de la nature est présente autour de location
			list<plot> nature_plots <- plot where (!each.is_road and each.heat > -5.0) overlapping bd_location;

			//augmente la resistance au feu du point nature
			if (length(nature_plots) > 0)
			{
			// Si l'un des plots autour de chez moi est en feu, je le priorise
				plot a_plot <- one_of(nature_plots where each.burning);

				// Si aucun plot n'est en feu, j'en prend un aléatoirement
				if (a_plot = nil)
				{
					a_plot <- one_of(nature_plots);
				}

				// J'humidifie en fonction 
				a_plot.heat <- a_plot.heat - increase_value / 2;
				if (a_plot.heat <= -5.0)
				{
					a_plot.color <- # magenta;
				}

			}

		}

	}

	//renforce batiment où il se trouve
	action increase_building_resistance (int increase_value)
	{
		if (at_home)
		{
			home.resistance <- home.resistance + int(increase_value / 2);
		}

		if (at_work)
		{
			work.resistance <- work.resistance + int(increase_value / 2);
		}

	}

}








