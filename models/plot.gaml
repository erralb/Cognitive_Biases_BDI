/**
* Name: plot
* *=======================
* Author: Sofiane Sillali, Thomas Artigue, Pierre Blarre
* Description: Definition d'un plot et de ses actions
* Fichier: plot.gaml
*/
model Application_Fire_Model

import "Application_Fire_Model.gaml"

/*=============================================
*                                                   Plot 
*=============================================*/
grid plot height: grid_size width: grid_size neighbors: 8 use_regular_agents: false use_individual_shapes: false  control: simple_bdi
{

// Variables
	rgb color <- # white;
	bool flammable <- false;
	bool burning <- false;
	float flame_tilt <- wind + rnd(0.2);
	float heat <- 0.0;
	int life <- rnd(90, 100);
	int id <- 1;
	bool is_road <- false;
	bool is_building <- false;

	// init
	init
	{
		ids <- ids + 1;
		id <- ids;
		flammable <- true;
		color <- blend(# green, # maroon, 100 / life);

		// Si plot est sur la route
		if (!empty(roads_shapefile overlapping (self)))
		{
			flammable <- true;
			is_road <- true;
			color <- # grey;
		}

		//		if (!empty( waterway_shapefile overlapping(self))  ){
		//			flammable <- false;
		//			color <- #blue;
		//		}

		// Si plot est sur un bâtiment
		if (!empty(buildings_shapefile overlapping (self)))
		{
			flammable <- true;
			color <- # lightgrey;
			is_building <- true;
		}

	}
	
//	//way too slow, which I do not understand
//	perceive target: resident in: 50 when: burning  {
//		if(not has_belief(immediate_danger) and flip(probability_to_react) and not in_safe_place)
//		{
//			do add_belief(immediate_danger, 100.0);
//			do add_desire(run_away);
//			do add_intention(escaping); 
//			escape_target <- get_closest_safe_place();
//			do status("Perceived fire");
//		}
//	}

	// Si le plot brûle
	reflex burn when: burning
	{

	// Animation du feu :
		color <- rgb(1 among [# orange, # red]);

		// Répèrcution du plot en feu (tous 10 cycles)
//		if ((cycle + id) mod 10 = 0)
		if ((cycle + id) mod 1 = 0)
		{

		// Dommages sur les personnes trop proches :
		//===========================

		// Récupération des plots à distance de dangeureuse
			list<plot> plot_at_hurting_distance <- self neighbors_at hurting_distance;

			// Récupération de la listes des résidents et des pompiers vivant se trouvant sur ces plots
			list<people> victims;
			loop pl over: plot_at_hurting_distance
			{
				victims <- victims + every_resident_alive inside pl where (!each.in_safe_place);
				victims <- victims + fireman inside pl where (each.alive);
				victims <- victims + policeman inside pl where (each.alive) where (!each.in_safe_place);
			}

			//			 // Récupération de la listes des résidents et des pompiers vivant se trouvant sur ces plots
			//			list<people> victims <-   every_people_alive where !each.in_safe_place at_distance hurting_distance;


			// Dommages
			loop victim over: victims
			{
			// Dégats : -30 à 1m du feu, -15 à 2 m, -10 à 3m
				victim.energy <- victim.energy - int(30 / max([1, victim distance_to self]));
				victim.on_alert <- true;
				// Les résidents touchés par le feu sont ralentis
				if (string(victim) contains "resident")
				{
					victim.speed <- victim.speed - rnd(0, 0.3);
				}
				// La personne n'ayant plus d'energie meurt
				if (victim.energy <= 0)
				{
					victim.alive <- false;
				}

			}

			// Domages sur les buildings :
			//==================
			list<building> bldins <- building overlapping (self) where (each.damage < 255 and each.bunker = false);
			loop bld over: bldins
			{
				float damage <-  min([1, bld.resistance / 300]);
				bld.damage <- bld.damage + rnd(1.0, 1.5) - damage;
				
			}

			// Propagation du feu :
			//==============
			// TODO les routes ne brûlent pas encore...
			// Récupération des plots voisins qui sont : non en feu, non brûlés.
			
			list<plot> neighbors_plot <- neighbors where (!each.burning and each.life > 0);
			loop neighbor over: neighbors_plot
			{
				if (neighbor.flammable)
				{
					
				// Récupération de la chaleur du plot voisin
				// Si sa chaleur est faible => elle augment en fonction de l'inclinaisont de feu
					float combust_limmit <- is_road ? 5.0 : (is_building ? 2.5 : 1.0);
					if (neighbor.heat < combust_limmit)
					{
						flame_tilt <- wind + rnd(0.2);
						neighbor.heat <- neighbor.heat + ((drought * 0.2) + 0.1 * flame_tilt);
					}

					// Le plot s'enflamme si sa chaleur > 1
					if (neighbor.heat >= combust_limmit)
					{
						neighbor.burning <- true;
					}
//
				}

			}

			// Combustion du feu :	
			life <- life - rnd(3, 7);
			if (life < 0)
			{
				burning <- false;
				color <- is_road ? rgb(5, 1, 1) : # maroon;
			}

		}

	}

}
