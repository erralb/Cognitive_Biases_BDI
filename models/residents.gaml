/**
* Name: resident
* *=======================
* Author: Sofiane Sillali, Thomas Artigue, Pierre Blarre
* Description:  Definition des types de residants
* Fichier: resident.gaml
*/
model Application_Fire_Model

import "Application_Fire_Model.gaml"

/*=============================================
*                                             Agent résidents  
*=============================================*/
species resident parent: people skills: [moving, fipa] control: simple_bdi
{

	// Variables
	int nb_of_warning_msg <- 0;
	bool warned <- false;
	bool evacuating <- false;
	bool is_escorted <- false;
	float probability_to_react <- 0.20;
	
//	//The rules are used to create a desire from a belief. We can specify the priority of the desire with a statement priority.
	rule belief: no_danger_belief new_desire: work_desire strength: 10.0 remove_desire: escape_desire;
	rule belief: potential_danger_belief new_desire: call_911_desire strength: 20.0 remove_desire: work_desire and escape_desire;
	rule belief: immediate_danger_belief new_desire: escape_desire strength: 30.0 remove_desire: work_desire and home_desire;
	rule belief: can_defend_belief new_desire: defend_desire strength: 40.0;

	init
	{
		speed <- rnd(13.0, 18.0) # km / # h;
//		speed <- rnd(30.0, 50.0) # km / # h;
		home <- one_of(building where (!each.bunker and !each.fire_station and !each.police_station));
		location <- any_location_in(home);
		at_home <- true;
		work <- one_of(building where (each != home and !each.bunker and !each.fire_station and !each.police_station));
		
		escape_target <- (city_exit closest_to location);
		
		color <- rgb(0, energy, 0);
		
		motivation <- max([0, rnd(3, 5) + motivation]); // Très motivé
		risk_awareness <- max([0, rnd(1, 3) + risk_awareness]); // Pas forcément conscient des risques
		knowledge <- max([0, rnd(4, 5) + knowledge]); // Expérimentés et compétents,
		
		//Default :  no danger and go to work
		do add_belief(no_danger_belief);
		
//		do status("init");
		
//		//Most of them are going to work, the rest stays at home
		if(flip(0.8))
		{
			do add_desire(work_desire);
		}
		else
		{
			do add_desire(home_desire);
		}
		
	}

	// Relexe : Couleur
	reflex color
	{
		color <- on_alert ? rgb(energy, energy, 0) : rgb(0, energy, 0);
	}
	
	// Resident received message
	reflex receive_call_resident when: !(empty(proposes))
	{
		nb_of_warning_msg <- nb_of_warning_msg + 1;
		message info <- proposes at 0;
		string msg <- info.contents[0];
		
		// Si le message est personnalisé, cette probabilité augmente fortement
		if (personalized_msg)
		{
			probability_to_react <- 1.0;
		}

		// Si ce n'est pas le premiers message, la probabilité de réaction baisse en fonction du nombre de messages déjà reçus
		if (nb_of_warning_msg > 1)
		{
			probability_to_react <- (probability_to_react > 0.0) ? (probability_to_react - (nb_of_warning_msg / 10)) : 0.0;
		}

		// Si une alerte d'évacution est donnée
		if ("Go to shelter" in msg)
		{
			// Je réagis ou non
			if (flip(probability_to_react))
			{
				// Ok I react
				
				write (string(self) + " : I'm going to defend my house");
				on_alert <- true;
				warned <- true;
				
				do accept_proposal(message: info, contents: ['OK!']);
				// Motivation increases speed
				speed <- speed + motivation;
				// Je crois qu'il y a un danger potentiel
//				belief <- potential_danger;
				do add_belief(potential_danger_belief);
				if(nb_of_warning_msg = 1)
				{
					nb_residents_w_answered_1st_call <- nb_residents_w_answered_1st_call + 1;
				}
			}
		}

		// Si c'est la Fires extinguished
		if (info.contents[0] = "Fires extinguished")
		{
			do accept_proposal(message: info, contents: ['OK!']);
			do back_to_normal_state;
		}

	}
	
//	perceive target:self when: alive {
//	}

	//If the agent perceives a fire it should give the alert and stay alert
	perceive target: plot in: 100.0 # m when: alive and ! in_safe_place and ! has_belief(potential_danger_belief)  {
		if(burning)
		{
			ask myself{
				do add_belief(potential_danger_belief);
				do add_desire(call_911_desire);
//				do status("Adding potential_danger_belief and home_intention");
			}
		}
	}
	
	//If the agent perceives is hurt by a fire it should escape
	perceive target: plot in: 50.0 # m when: alive and ! in_safe_place and ! has_belief(immediate_danger_belief) {
		if(burning)
		{
			ask myself{
				energy <- energy - 0.01;
				if(energy <= 0)  {
					alive <-false;
				}
				else if(!has_desire(escape_desire))
				{
//					do remove_desire(work_desire);
//					do remove_belief(no_danger_belief);
//					do remove_belief(potential_danger_belief);
					
					do add_belief(immediate_danger_belief);
					do add_desire(escape_desire);
					
					escape_target <- get_closest_safe_place();
					
//					do status("I'm hurt, need to escape");
				}
			}
		}
	}
	
	plan work_desire intention: work_desire priority: 1 when: alive and ! at_work and ! in_safe_place finished_when: at_work or has_desire(escape_desire)
	{
		if (bool(go_to(work)))
		{
			at_home <- false;
			at_work <- true;
			do remove_desire(work_desire);
//			do status("I'm at work");
		}
	}
	
	plan home_desire intention: home_desire priority: 2 when: alive and ! at_home and ! in_safe_place finished_when: at_home or has_desire(escape_desire)
	{
		if (bool(go_to(home)))
		{
			at_home <- true;
			at_work <- false;
			do remove_desire(home_desire);
//			do status("I'm at home");
		}
	}

	plan call_911_desire intention: call_911_desire priority: 3 when: alive and ! warning_sent finished_when: warning_sent
	{
		do send_msg([one_of(fireman where each.alive)], nil, "There's a fire");
		warning_sent <- true;
//		do status("I called 911");
	}

	plan escape_desire intention: escape_desire priority: 4 when: alive and ! in_safe_place finished_when: in_safe_place
	{
//		write (string(self) + " : I'm escaping");
		if (bool(go_to(escape_target)))
		{
			at_home <- false;
			at_work <- false;
			in_safe_place <- true;
			write (string(self) + " : I escaped safely");
		}
	}
	
//	plan defend intention: defend_intention when: alive and ! in_safe_place
//	{
//		write (string(self) + " : I want to defend");
//	}
	
	
//	// Donner l'alerte au feu si : en vie, n'est pas trop égoîste, est en alerte
//	reflex saw_the_fire when: alive and on_alert and !warning_sent
//	{
//
//	// Si la conscience des risques d'une personne est supérieure à la moyenne ...
//		if (risk_awareness > 2)
//		{
//		// ...elle alerte les pompiers
//			do send_msg([one_of(fireman where each.alive)], nil, 'Il y a un feu!');
//			// do start_conversation ( to : [one_of(fireman where each.alive)], protocol : 'fipa-propose', performative : 'propose', contents : ['Il y a un feu!'] );
//			warning_sent <- true;
//			belief <- potential_danger;
//		}
//
//	}
	
	
//	//Perceives fire, give the alert -> === CB should influence decision =======
//	//If the he thinks the danger isn't real (or not)
////	perceive target:self when: alive and on_alert and !warning_sent {
//	perceive target:self when: alive and !warning_sent and (has_belief(potential_danger_belief) or has_belief(immediate_danger_belief))  {
//		
//		write string(self) + " : Danger perceived ";
//		if(risk_awareness > 2)
//		{
//			do send_msg([one_of(fireman where each.alive)], nil, 'Il y a un feu!');
//			warning_sent <- true;
////			belief <- potential_danger_belief;
//		}
//	}


	action back_to_normal_state
	{
		if (on_alert)
		{
			do remove_all_beliefs(potential_danger_belief);
			do remove_all_beliefs(immediate_danger_belief);
			do add_belief(no_danger_belief);
			
			do remove_desire(home_desire);
			
//			belief <- no_danger_belief;
//			intention <- desires[0];

			speed <- speed - motivation;
			in_safe_place <- false;
			on_alert <- false;
			warning_sent <- false;
			warned <- false;
			evacuating <- false;
			
			do status("back to normal");
			
		}
	}

}