/**
* Name: fireman
* *=======================
* Author: Sofiane Sillali, Thomas Artigue, Pierre Blarre
* Description: Definition d'un pompier et ses reflex
* Fichier: fireman.gaml
*/
model Application_Fire_Model

import "Application_Fire_Model.gaml"
/*=============================================
*                                           Agent fireman  
*=============================================*/
species fireman parent: people
{
	// Variables
	float fighting_distance <- 10 # m;
	bool injured <- false;

	// Init
	init
	{
		speed <- rnd(20.0, 25.0) # km / # h;
		energy <- rnd(20000, 25500);
		color <- # red;
		at_home <- true;
		work <- one_of(building where (each.fire_station)); // Les pompiers travaillent à la caserne

		// Si la strategie de pompier est à true
		if (tactical_fireman)
		{
		// Création des pompier sur les sorties la carte, une fois sur deux la position est differente
			home <- building where (!each.bunker and !each.fire_station and !each.police_station) closest_to one_of(city_exit);
		} else
		{
			home <- one_of(building where (!each.bunker and !each.fire_station and !each.police_station));
		}

		location <- any_location_in(home);
		if (length(fireman where each.on_alert) > 0)
		{
			on_alert <- true;
		}

	}

	// Couleur
	reflex color
	{
		color <- rgb(energy / 100, 0, 0);
	}

	// Un pompier bléssé quand son energie est sous les xxx hp
	reflex health when: alive and !injured and energy < 1000
	{
		injured <- true;
	}

	// Réception de message
	reflex recieve_call when: !(empty(proposes))
	{
		message info <- proposes at 0;
		write (info.contents[0]);
		// Si c'est un alerte au feux
		if (info.contents[0] = "Il y a un feu!" and !on_alert)
		{
		// Accépter l'intervention
			do accept_proposal(message: info, contents: ['OK!']);
			on_alert <- true;

			// Demander au autres pompiers de passer en alerte
			ask fireman
			{
				on_alert <- true;
			}

		}

	}

	// Fin de l'alerte au feu si : taille du feu nulle
	reflex stop_fighting when: alive and (go_fighting or fighting_fire) and fire_size <= 0
	{
		if (first(fireman where each.alive) = self)
		{
			//write "stop_fighting";
			do save_result;
			do_pause <- true;
			//do start_conversation ( to : list(policeman where each.alive), protocol : 'fipa-propose', performative : 'propose', contents : ['Feu éteind'] );
			do send_msg(list(policeman where each.alive), every_resident_alive, "Fin de l'alerte au feu");
			write "Fin de l'alerte au feu";
		}

		go_fighting <- false;
		fighting_fire <- false;
		at_home <- false;
		at_work <- false;
		on_alert <- false;
		evacution_city_reported <- false;
	}

	// Se diriger vers le feu le plus proche 
	reflex go_fighting_fire when: alive and !fighting_fire and on_alert and !injured
	{
		if ((cycle + id) mod 10 = 0)
		{
			// Recherche d'un batiment en feu
			plot p_to_fight <- (plot where (each.is_building and each.burning)) closest_to self;

			// Si plot est toujours vide = pas de batiment en feux
			if (p_to_fight = nil)
			{
			// Récupération du feu le plus proche
				p_to_fight <- (plot where (each.burning)) closest_to self;
			}

			if (p_to_fight != nil)
			{
			// Pompier passe à l'action
				go_fighting <- true;
				// si un batiment est en feux on attaque directement celui-ci
				target <- point(p_to_fight);
				// Si est est à distance suffisante => combattre le feu
				if (location distance_to target < fighting_distance)
				{
					fighting_fire <- true;
				}

			}

		}

		do goto target: target on: road_network;
	}

	// Combattre le feu
	reflex fight_fire when: alive and fighting_fire and on_alert and !injured
	{
		if ((cycle + id) mod 20 = 0)
		{
			// Récupération du feu le plus proche
			plot p_in_fire <- nil;
			// Recherche d'un batiment en feu
			p_in_fire <- (plot where (each.is_building and each.burning)) closest_to self;

			// Si plot est toujours vide = pas de batiment en feux
			if (p_in_fire = nil)
			{
			// Récupération du feu le plus proche
				p_in_fire <- (plot where (each.burning)) closest_to self;
			}

			if p_in_fire != nil
			{
			// Récupération du plot n'ayant pas encore brûlé le plus priche du feu
				plot p_to_fight <- plot where (!each.burning and each.life > 0 and each.heat >= 0) closest_to p_in_fire;
				// Si le plot à arroser est nul ou trop loins du feu, on arrose le feu.
				p_to_fight <- ((p_to_fight != nil) and (self distance_to p_to_fight < 20)) ? p_to_fight : p_in_fire;
				if p_to_fight != nil
				{

				// Pouvoir  de base pour eteindre les flammes
					float figthing_power <- 20.00;
					// Si la vie d'un pompier est compris entre xxx et xxx valeurs
					if (energy < 20000 and energy >= 15000)
					{
					// on prend le pouvoir de base - l'energy du pompier ramené a 1.xxx et on ajoute un random
						figthing_power <- figthing_power - (energy / 10000 + rnd(1, 2));
					} else if (energy < 15000 and energy >= 10000)
					{
					// on prend le pouvoir de base - l'energy du pompier ramené a 1.xxx et on ajoute un random
						figthing_power <- figthing_power - (energy / 10000 + rnd(3, 4));
					} else if (energy < 9999 and energy >= 1000)
					{
					// on prend le pouvoir de base - l'energy du pompier ramené a 1.xxx et on ajoute un random
						figthing_power <- figthing_power - (energy / 1000 + rnd(4, 5));
					}
					// On arrose le feu => sa température baisse
					p_to_fight.heat <- p_to_fight.heat - figthing_power;
					if (p_to_fight.heat <= -10.0)
					{
						p_to_fight.burning <- false;
						p_to_fight.color <- # darkblue;
					}

					// On recherche le prochain plot à combattre
					target <- point(one_of(p_to_fight.neighbors where (!each.burning)));
					if (target != nil and location distance_to target >= fighting_distance)
					{
					// Le prochain point est trop loin => on arrête de combattre et le reflexe "go_fighting_fire" déplace le pompier vers le prochain point à combattre
						fighting_fire <- false;
					} else
					{
						location <- target;
					}

				}

			}

		}

		do goto target: target;
	}

	// Aller à la caserne se faire soigner
	reflex evacuate_to_rest when: alive and injured and !at_work
	{
		//write "evacuate";
		target <- any_location_in(work);
		do goto target: target on: road_network;
		if (location = target)
		{
			at_work <- true;
		}

	}

	// Se faire soigner à la caserne
	reflex resting when: alive and injured and at_work
	{
		//write "resting";
		// Un pompier récupère 700hp tous les 5 cycles.
		if ((cycle + 2) mod 5 = 0)
		{
			energy <- energy + 700;
			injured <- energy > 20000 ? false : true; // S'il a suffisamment récupéré => il n'est plus bléssé et retourne se battre par reflexe
		}
	}

	// Observation de l'évolution du feu (tous les 20 cycles)
	reflex watching_fire when: alive and on_alert and fire_size > 0 and (cycle mod 20 = 0)
	{
		// Demander à la police une évacution de la ville
		if (fire_size > fire_uncontrollable and !evacution_city_reported and first(fireman where each.alive) = self)
		{
		// do start_conversation ( to : list(policeman where each.alive), protocol : 'fipa-propose', performative : 'propose', contents : ['Evacuer les residents de la ville!'] );
			do send_msg(list(policeman where each.alive), every_resident_alive, 'Evacuer les residents de la ville!');
			evacution_city_reported <- true;
		}

	}

	// Observation de l'évolution du feu (tous les 20 cycles)
	reflex tactical_attitude when: alive and on_alert and fire_size > 0 and ((cycle + id) mod 150 = 0) and tactical_fireman
	{
		// Appelle des renforts si le feux est toujours incontrolable, tous les 100 cycles (appel de 10 pompier)
		if (fire_size > fire_uncontrollable and first(fireman where each.alive) = self)
		{
			write string(self) + " : Feux toujours incontrolable, on a besoin d'aide";
			create fireman number: 10;
		}

	}

}