/**
* Name:  policeman
* *=======================
* Author: Sofiane Sillali, Thomas Artigue, Pierre Blarre
* Description: Definition des policiers et de leurs actions
* Fichier: policeman.gaml
*/
model Application_Fire_Model

import "Application_Fire_Model.gaml"

/*=============================================
*                                            Agent policeman  
*=============================================*/
global
{
	list<resident> residant_who_have_asked_help <- nil;
	list<resident> people_to_warn <- nil update: every_resident_alive where (!each.evacuating and !each.on_alert and !each.warned and !each.is_escorted and !each.in_safe_place);
}

species policeman parent: people
{

// Variables
	bool escorting <- false;
	resident escorted_res <- nil;
	resident resident_to_help <- nil;

	// Init
	init
	{
		speed <- rnd(20.0, 25.0) # km / # h;
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

		// Si le feu a été éteind
		if (msg contains "Fin de l'alerte au feu")
		{
		// Accépter le message et prévenire les résidents
			do accept_proposal(message: info, contents: ['OK!']);
			if (first(policeman where each.alive) = self)
			{
			// do start_conversation ( to : list(every_resident_alive), protocol : 'fipa-propose', performative : 'propose', contents : ['Fin de l\'alerte au feu'] );
				do send_msg(list(every_resident_alive), nil, "Fin de l'alerte au feu");
			}

			on_alert <- false;
			warning_sent <- false;
		}

		// S'il faut évacuer la ville
		if (msg contains "Evacuer les residents de la ville!")
		{
		// Accépter le message et prévenire les résidents d'évacuer
			do accept_proposal(message: info, contents: ['OK!']);
			string msg <- 'Allez dans un bunker!';
			at_work <- false;
			at_home <- false;
			on_alert <- true;
			warning_sent <- true;
			target <- nil;
			resident_to_help <- nil;

			// Un seul policier envoie le message d'évacuation
			if (first(policeman where each.alive) = self)
			{
				write "La police demande une évacuation générale";
				// do start_conversation ( to : list(every_resident_alive),  protocol : 'fipa-propose', performative : 'propose', contents : [msg] );
				do send_msg(every_resident_alive, nil, msg);
			}

		}

	}

	// Tout les 1000 cycles, les policier relance l'ordre d'évacution.
	reflex inform_people when: alive and on_alert and fire_size > fire_uncontrollable and (cycle mod 1000 = 0)
	{
		if (first(policeman where each.alive) = self)
		{
			write string(self) + " : Rappel d'évacutaion!";
			do send_msg(every_resident_alive where ( !each.in_safe_place and !each.warned), nil, 'Allez dans un bunker!');
		}

	}

	// Si je suis en alerte (= avertir les résident en porte à porte) et que je n'escorte personne
	reflex evacuate_resident when: alive and on_alert and !escorting and intention = protect
	{

	// Evacuer les résidents selon la priorisation suivante :
		if ((cycle + 1) mod 30 = 0)
		{
		// 1 : les personnes ayant demandé de l'aide (isolés vulnérables)
			if (length(residant_who_have_asked_help) > 0)
			{
				resident_to_help <- residant_who_have_asked_help closest_to self;
				write (string(self) + " : Je vais aider " + resident_to_help);
				remove resident_to_help from: residant_who_have_asked_help;
			} else
			{
			// 2 : les personnes qui ne sont pas avertis
				if (length(people_to_warn) > 0)
				{
					resident_to_help <- people_to_warn closest_to self;
					remove resident_to_help from: people_to_warn;
					write (string(self) + " : Je vais aider " + resident_to_help);
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
					remove resident_to_help from: residant_who_have_asked_help;
					write "J'escorte " + escorted_res + " vers " + escape_target;
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
						write "le résident évacue";
					} else
					{
						resident_to_help.warned <- true;
						write "le résident ne veux PAS évacuer";
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
		// Je dis à la personne que j'escorte de me suivre
			escorted_res.location <- { location.x + 3, location.y };

			// Si le résident que j'escorte est mort, je change de cicle
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