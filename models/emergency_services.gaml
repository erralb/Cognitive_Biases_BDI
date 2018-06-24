/**
* Name: firefighters
* *=======================
* Author: Sofiane Sillali, Thomas Artigue, Pierre Blarre
* Description: Definition d'un pompier et ses reflex
* Fichier: firefighters.gaml
*/
model Bushfires_BDI_Cognitive_Biases

import "Bushfires_BDI_Cognitive_Biases.gaml"



global
{
	list<resident> residents_who_have_asked_help <- nil;
	list<resident> people_to_warn <- nil update: every_resident_alive where (!each.evacuating and !each.on_alert and !each.warned and !each.is_escorted and !each.in_safe_place);
}

//Firefighters
species firefighters parent: people
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
		if (tactical_firefighters)
		{
		// Création des pompier sur les sorties la carte, une fois sur deux la position est differente
			home <- building where (!each.bunker and !each.fire_station and !each.police_station) closest_to one_of(city_exit);
		} else
		{
			home <- one_of(building where (!each.bunker and !each.fire_station and !each.police_station));
		}

		location <- any_location_in(home);
		if (length(firefighters where each.on_alert) > 0)
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
		// Si c'est un alerte au feux
		if (info.contents[0] = "There's a fire" and !on_alert)
		{
			write ("Fireman called received : "+info.contents[0]);
			// Accépter l'intervention
			do accept_proposal(message: info, contents: ['OK!']);
			on_alert <- true;

			// Demander au autres pompiers de passer en alerte
			ask firefighters
			{
				on_alert <- true;
			}

		}

	}

	// Fires extinguished si : taille du feu nulle
	reflex stop_fighting when: alive and (go_fighting or fighting_fire) and fire_size <= 0
	{
		if (first(firefighters where each.alive) = self)
		{
			//write "stop_fighting";
			do save_result;
			do_pause <- true;
			//do start_conversation ( to : list(policeman where each.alive), protocol : 'fipa-propose', performative : 'propose', contents : ['Fires extinguished'] );
			do send_msg(list(policeman where each.alive), every_resident_alive, "Fires extinguished");
			write "Fires extinguished";
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
		if (fire_size > fire_uncontrollable and !evacution_city_reported and first(firefighters where each.alive) = self)
		{
			// do start_conversation ( to : list(policeman where each.alive), protocol : 'fipa-propose', performative : 'propose', contents : ['General evacuation required'] );
			do send_msg(list(policeman where each.alive), every_resident_alive, 'General evacuation required');
			evacution_city_reported <- true;
		}

	}

	// Observation de l'évolution du feu (tous les 20 cycles)
	reflex tactical_attitude when: alive and on_alert and fire_size > 0 and ((cycle + id) mod 150 = 0) and tactical_firefighters
	{
		// Appelle des renforts si le feux est toujours incontrolable, tous les 100 cycles (appel de 10 pompier)
		if (fire_size > fire_uncontrollable and first(firefighters where each.alive) = self)
		{
			write string(self) + " : Incontrollable fires, we need reinforcements";
			create firefighters number: 10;
		}

	}

}

/*=============================================
*                                            Agent policeman  
*=============================================*/

species policeman parent: people
{

// Variables
	bool escorting <- false;
	resident escorted_res <- nil;
	resident resident_to_help <- nil;

	// Init
	init
	{
//		speed <- rnd(20.0, 25.0) # km / # h;
		speed <- 50 # km / # h;
		energy <- rnd(2000, 2550);
		color <- # blue;
		home <- one_of(building where (!each.bunker and !each.fire_station and !each.police_station));
		location <- any_location_in(home);
		at_home <- true;
		work <- one_of(building where (each.police_station)); // Les policiers travaillent au commisariat           

		// En cas d'alerte je protège les résidents
		desires <- [protect];
		intention <- desires[0];
		motivation <- max([0, rnd(4, 5) + motivation]); // Très motivé
		risk_awareness <- max([0, rnd(4, 5) + risk_awareness]); //  Conscients du risque
		knowledge <- max([0, rnd(4, 5) + knowledge]); // Très instruit 

	}

	// Couleur
	reflex color
	{
		color <- rgb(0, 0, energy);
	}

	// Réception de message
	reflex recieve_call_policeman when: !(empty(proposes))
	{
		message info <- proposes at 0;
		string msg <- info.contents[0];

		if (msg contains "Fires extinguished")
		{
			do accept_proposal(message: info, contents: ['OK!']);
			if (first(policeman where each.alive) = self)
			{
				// do start_conversation ( to : list(every_resident_alive), protocol : 'fipa-propose', performative : 'propose', contents : ['Fin de l\'alerte au feu'] );
				do send_msg(list(every_resident_alive), nil, "Fires extinguished");
			}

			on_alert <- false;
			warning_sent <- false;
		}

		if (msg contains "General evacuation required")
		{
			// Accépter le message et prévenire les résidents d'évacuer
			do accept_proposal(message: info, contents: ['OK!']);
			string msg <- 'Go to shelter';
			at_work <- false;
			at_home <- false;
			on_alert <- true;
			warning_sent <- true;
			target <- nil;
			resident_to_help <- nil;

			// Un seul policier envoie le message d'évacuation
			if (first(policeman where each.alive) = self)
			{
				write "Police is asking for general evacuation";
				// do start_conversation ( to : list(every_resident_alive),  protocol : 'fipa-propose', performative : 'propose', contents : [msg] );
				do send_msg(every_resident_alive, nil, msg);
			}

		}

	}

	// Every evacuation_reminder_cycle cycles, send evacuation reminder
	reflex inform_people when: alive and on_alert and fire_size > fire_uncontrollable and (cycle mod evacuation_reminder_cycle = 0)
	{
		if (first(policeman where each.alive) = self)
		{
			write string(self) + " : Evacuation reminder";
			do send_msg(every_resident_alive where ( !each.in_safe_place and !each.warned), nil, 'Go to shelter');
		}

	}

	// Si je suis en alerte (= avertir les résident en porte à porte) et que je n'escorte personne
	reflex evacuate_resident when: alive and on_alert and !escorting and intention = protect
	{

	// Evacuer les résidents selon la priorisation suivante :
		if ((cycle + 1) mod 30 = 0)
		{
		// 1 : les personnes ayant demandé de l'aide (isolés vulnérables)
			if (length(residents_who_have_asked_help) > 0)
			{
				resident_to_help <- residents_who_have_asked_help closest_to self;
				write (string(self) + " : I'm going to help " + resident_to_help);
				remove resident_to_help from: residents_who_have_asked_help;
			} else
			{
			// 2 : les personnes qui ne sont pas avertis
				if (length(people_to_warn) > 0)
				{
					resident_to_help <- people_to_warn closest_to self;
					remove resident_to_help from: people_to_warn;
					write (string(self) + " : I'm going to help " + resident_to_help);
				}

			}

		}

		// S'il existe des personnes à aider
		if (resident_to_help != nil)
		{
			if (bool(go_to(resident_to_help)))
			{

			// Si c'est une personne isolé à escorter
				if (string(resident_to_help) contains "isolated_and_vulnerable")
				{
					speed <- speed - 3; // L'escorte réduit ma vitesse
					escape_target <- get_closest_safe_place();
					escorting <- true;
					resident_to_help.is_escorted <- true;
					resident_to_help.on_alert <- true;
					escorted_res <- resident_to_help;
					remove resident_to_help from: residents_who_have_asked_help;
					write "I'm escorting " + escorted_res + " to " + escape_target;
				} else
				{
				// Si c'est pas une personne à escorter
				// 70% de chance de convaincre le résident d'évacuer
					if (flip(0.7))
					{
						resident_to_help.warned <- true;
						resident_to_help.on_alert <- true;
						resident_to_help.evacuating <- true;
						resident_to_help.speed <- resident_to_help.speed + motivation;
						write "the resident evacuates";
					} else
					{
						resident_to_help.warned <- true;
						write "the resident doesn't want to evacuate";
					}

					resident_to_help <- nil;
				}

			}

		} else
		{
		// S'il n'y a personne à aider, je vais m'abriter
			escape_target <- escape_target = nil ? get_closest_safe_place() : escape_target;
			if (bool(go_to(agent(escape_target))))
			{
				at_home <- false;
				at_work <- false;
				in_safe_place <- true;
			}

		}

	}

	// Si je suis en train d'escorter une personne isolé
	reflex escorting_resident when: alive and on_alert and escorting and intention = protect
	{

	// Si Je suis arrivé
		if (bool(go_to(escape_target)))
		{
			escorting <- false;
			escorted_res.in_safe_place <- true;
			escorted_res.is_escorted <- false;
			escorted_res.location <- target;
			escorted_res <- nil;
			speed <- speed + 3;
			target <- nil;
			resident_to_help <- nil;
		} else
		{

		// Si je ne suis toujours pas arrivé
		// Je dis à la personne que I'm escorting de me suivre
			escorted_res.location <- { location.x + 3, location.y };

			// Si le résident que I'm escorting est mort, je change de cicle
			if (!escorted_res.alive)
			{
				escorting <- false;
				escorted_res <- nil;
				speed <- speed + 3;
				target <- nil;
				resident_to_help <- nil;
			}

		}

		if (cycle mod 2 = 0)
		{
		// S'il existe un danger, je réagis en fonction de ma conscience du risque et de trouve la meilleurs issue en fonction de ma connaissance
			do react_to_danger(check_if_danger_is_near());
		}

	}

}


