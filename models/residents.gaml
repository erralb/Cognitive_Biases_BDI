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
species resident parent: people control: simple_bdi
{

	// Variables
	int nb_of_warning_msg <- 0;
	bool warned <- false;
	bool evacuating <- false;
	bool is_escorted <- false;
	float probability_to_react <- 0.20;
	
	init
	{
		speed <- rnd(13.0, 18.0) # km / # h;
//		speed <- rnd(30.0, 50.0) # km / # h;
		home <- one_of(building where (!each.bunker and !each.fire_station and !each.police_station));
		location <- any_location_in(home);
		at_home <- true;
		work <- one_of(building where (each != home and !each.bunker and !each.fire_station and !each.police_station));
		
		escape_target <- (city_exit closest_to work);
		
		color <- rgb(0, energy, 0);
		
		motivation <- max([0, rnd(3, 5) + motivation]); // Très motivé
		risk_awareness <- max([0, rnd(1, 3) + risk_awareness]); // Pas forcément conscient des risques
		knowledge <- max([0, rnd(4, 5) + knowledge]); // Expérimentés et compétents,
		
		//Default :  no danger
		do add_belief(no_danger_belief);
		do add_desire(work_desire);
		do add_intention(work_intention);
		
//		//Some are staying at home and relax_intention, some are going to work
//		if(bool(rnd(0, 1)))
//		{
//			do add_desire(work_desire);
//			do add_intention(work_intention);
//		}
//		else
//		{
//			do add_desire(home_desire);
//			do add_intention(relax_intention);
//		}
		
	}

	// Relexe : Couleur
	reflex color
	{
		color <- on_alert ? rgb(energy, energy, 0) : rgb(0, energy, 0);
	}
	
	// Réception de messages
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
		if ("Allez dans un bunker!" in msg)
		{

			// Je réagis ou non
			if (flip(probability_to_react))
			{

				// Ok je réagis
				write (string(self) + " : Je vais défendre ma maison.");
				on_alert <- true;
				warned <- true;
				do accept_proposal(message: info, contents: ['OK!']);
				// Ma motivation augement ma vitesse
				speed <- speed + motivation;
				// Je crois qu'il y a un danger potentiel
				belief <- potential_danger;
				nb_residents_w_answered_1st_call <- nb_residents_w_answered_1st_call + 1;
			}

		}

		// Si c'est la fin de l'alerte au feu
		if (info.contents[0] = "Fin de l'alerte au feu")
		{
		// Accépter le message et retour à l'état normal
			do accept_proposal(message: info, contents: ['OK!']);
			do back_to_normal_state;
		}

	}

//	plan call intention: call_911_intention when: alive and ! in_safe_place and ! warning_sent
//	plan call intention: call_911_intention priority: 90 when: ! warning_sent
	plan call intention: call_911_intention  priority: 5
	{
		write (string(self) + " : I want to call 911");
		do send_msg([one_of(fireman where each.alive)], nil, "There's a fire");
		warning_sent <- true;
	}
	
	// Go to work if alive, daytime, not already at work, not on alert, not fighting fire
	plan work_desire intention: work_intention priority: 1 when: alive and ! at_work and ! in_safe_place
	{
		if (bool(go_to(work)))
		{
			at_home <- false;
			at_work <- true;
			do remove_desire(work_desire);
			do remove_intention(work_intention,true);
			do status("I'm at work");
		}
	}
	
	// Go home if alive, it's nighttime, not already at home, is not on alert, not fighting fire
	plan home_desire intention: relax_intention priority: 1 when: alive and ! at_home and ! in_safe_place
	{
		if (bool(go_to(home)))
		{
			at_home <- true;
			at_work <- false;
			do remove_desire(home_desire);
			do remove_intention(home_intention,true);
			do status("I'm at home");
		}
	}
	
	
//	plan escape intention: escape_intention when: alive and ! in_safe_place and warning_sent
//	{
//		write (string(self) + " : I need to escape");
//		if (bool(go_to(escape_target)))
//		{
//			at_home <- false;
//			at_work <- false;
//			in_safe_place <- true;
//			
//			do remove_belief(immediate_danger_belief);
//			do remove_desire(escape_desire);
//			do remove_intention(escape_intention,true);
//			do add_intention(relax_intention);
//					
//			write (string(self) + " : I escaped safely");
//		}
//	}
	
//	plan defend intention: defend_intention when: alive and ! in_safe_place
//	{
//		write (string(self) + " : I want to defend");
//	}
	

	//If the agent perceives a fire it should give the alert and then defend or escape
//	perceive target: plot in: 10.0 # m when: not has_belief(immediate_danger_belief) and flip(probability_to_react) and ! in_safe_place  {
	perceive target: plot in: 10.0 # m when: not has_belief(immediate_danger_belief)  {
		if(burning)
		{
			ask myself{
				
				do status("Adding call_911_intention");
//				do add_desire(call_911_desire);
				do add_intention(call_911_intention);
				do add_belief(immediate_danger_belief, 100.0);
//				on_alert <- true;
				
//				do remove_intention(relax_intention,true);
//				do remove_intention(work_intention,true);
//				
//				do add_desire(call_911_desire);
//				do add_intention(call_911_intention,100.0);
				
//				if(!has_belief(immediate_danger_belief))
//				{
//////					do status("Adding calling for help and escape intentions");
//					do add_belief(immediate_danger_belief, 100.0);
//					
////					if(!warning_sent)
////					{
//////						do status("Adding calling for help and escape intentions");
//////						do add_desire(call_911_desire);
//////						do add_intention(call_911_intention);
//////						on_alert <- true;
////					}
//					
//					do add_desire(escape_desire);
//					do add_intention(escape_intention); 
//					
//					escape_target <- get_closest_safe_place();
//					do status("Perceived fire");
//					
//				}
			}
		}
	}
	
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
//			belief <- no_danger_belief;
			intention <- desires[0];
			speed <- speed - motivation;
			in_safe_place <- false;
			on_alert <- false;
			warning_sent <- false;
			warned <- false;
			evacuating <- false;
			
		}
	}

}