/**
* Name: resident
* *=======================
* Author: Sofiane Sillali, Thomas Artigue, Pierre Blarre
* Description:  Definition des types de residants
* Fichier: resident.gaml
*/
model Bushfires_BDI_Cognitive_Biases

import "environment.gaml"

/*=============================================
*                                             Agent résidents  
*=============================================*/
species resident parent: people skills: [moving, fipa] control: simple_bdi
{
	// Variables
	bool warned <- false;
	bool evacuating <- false;
	bool is_escorted <- false;
	
	//Definition of the variables featured in the BDI architecture. ??USEFUL??
	float plan_persistence <- 1.0; 
	float intention_persistence <- 1.0;
	bool probabilistic_choice <- false;
	
	float probability_to_react <- 0.70;
	int nb_of_warning_msg <- 0;
	
	//Cognitive Biases
	//Whether the agent's choices will be influenced or not by the cognitive biases algorithms
	bool cognitive_biases_influence <- false;
	bool neglect_of_probability_cb_influence <- false;
	bool semmelweis_reflex_cb_influence <- false;
	bool illusory_truth_effect_cb_influence <- false;

	
    //Beliefs
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
	
//	//The rules are used to create a desire from a belief. We can specify the priority of the desire with a statement priority.
	rule belief: no_danger_belief new_desire: work_desire strength: 10.0 remove_desire: escape_desire;
	rule belief: potential_danger_belief new_desire: call_911_desire strength: 20.0 remove_desire: work_desire and escape_desire;
	rule belief: immediate_danger_belief new_desire: escape_desire strength: 30.0 remove_desire: work_desire and home_desire;
	rule belief: can_defend_belief new_desire: defend_desire strength: 40.0;

	init
	{
		speed <- rnd(13.0, 18.0) # km / # h;
//		speed <- rnd(30.0, 50.0) # km / # h; //to fast they never die
		home <- one_of(building where (!each.bunker and !each.fire_station and !each.police_station));
//		location <- any_location_in(home);
		work <- one_of(building where (each != home and !each.bunker and !each.fire_station and !each.police_station));
		
		color <- rgb(0, energy, 0);
		
		// Default resident has the threat_avoiders attributes
		escape_target <- get_closest_safe_place();
		motivation <- max([0, rnd(2, 3) + motivation]); // Motivation moyenne
		risk_awareness <- max([0, rnd(3, 5) + risk_awareness]); //  Conscients du risque
		knowledge <- max([0, rnd(3, 5) + knowledge]); // Bonne connaissances
		
		//Default :  no danger
		do add_belief(no_danger_belief,0.5);
		
		//do status("init");
		
 		//80% are at work, the rest stays at home, doesn't really matter
 		//we place them right away, it avoids waiting for them to drive to their work place
		if(flip(0.8))
		{
//			do add_desire(work_desire);
			location <- any_location_in(work);
			at_work <- true;
			at_home <- false;
		}
		else
		{
//			do add_desire(home_desire);
			location <- any_location_in(home);
			at_home <- true;
			at_work <- false;
		}
		
		if(use_cognitive_biases)
		{
			//Randomly distribute Cognitive Biases at a 20% chance
			if(flip(0.2)) { neglect_of_probability_cb_influence <- true; cognitive_biases_influence <- true; }
			if(flip(0.2)) { semmelweis_reflex_cb_influence <- true; cognitive_biases_influence <- true; }
			if(flip(0.2)) { illusory_truth_effect_cb_influence <- true; cognitive_biases_influence <- true; }
		}
		
	}

	// Relexe : Couleur
	reflex color { color <- on_alert ? rgb(energy, energy, 0) : rgb(0, energy, 0); }
		
	action status (string msg)
	{
		write string(self) + " ("+energy+") : " + msg; 
		write "B:" + length(belief_base) + ":" + belief_base; 
		write "D:" + length(desire_base) + ":" + desire_base; 
		write "I:" + length(intention_base) + ":" + intention_base; 
	}
	
	
	//Cognitive Biases
	//Will be about the belief the person thinks it's in danger or not
	
	//Around the time of the Black Saturday, the risk of bushfire is high
	//We assume the agent is totally unsure if there's a fire or not
	
	
	//Cognitive Bias : Neglect of probability
	//Will influence the agent's decisions on going home or escaping
	action neglect_of_probability(float perceivedProbability)
	{
		cognitive_biases_influence_occurence <- cognitive_biases_influence_occurence + 1;
		
//		float ancientBeliefProbability <- probability_to_react;
		float newBeliefProbability <- probability_to_react + perceivedProbability;
		
		if (newBeliefProbability > 1) { newBeliefProbability <- 1.0; } //Cannot be over 1
		
		if( newBeliefProbability < 0.34 and risk_awareness <= 3 and knowledge < 3) //1 ignore what is unlikely to happen, even if it's happening
		{
			newBeliefProbability <- 0.0;
		}
		else if( newBeliefProbability  < 0.34 and (risk_awareness > 3 or knowledge < 3) )//2 not likely to happen, but I desire/dread it so I will react
		{
			newBeliefProbability <- 0.9;
		}
		else if( newBeliefProbability  > 0.34 ) //3 under-estimate a high and medium probability of something happening
		{
			newBeliefProbability <- 0.2;
		}
		
		probability_to_react <- newBeliefProbability;
	}
	
	
	//Cognitive Bias : Semmelweis Reflex : Clinging to a belief
	//Will influence the agent's belief on no / potential / immediate danger : Should I keep my belief/certainty?
	action semmelweis_reflex(float beliefProbability)
	{
		cognitive_biases_influence_occurence <- cognitive_biases_influence_occurence + 1;
		
		if (beliefProbability = 0 and nb_of_warning_msg < 2) //he does not believe the danger will occur, I keep my belief 
		{
			return true;
		}
		else if (beliefProbability > 0 and nb_of_warning_msg > 2) //I started to believe, I should change my certainty
		{
			return false;
		}
		
		return true;
	}
	
	
	//Cognitive Illusory Truth effect
	//Will re-inforce agent's belief
	// "Info" = no / potential / immediate danger
	// "nb of occurences" = received_warnings
	action illusory_truth_effect(predicate beliefName, float perceivedProbability)
	{
		cognitive_biases_influence_occurence <- cognitive_biases_influence_occurence + 1;
		
		if( ! has_belief(beliefName) )
		{
			do add_belief(beliefName, perceivedProbability);
		}
		else //reinforce belief strength
		{
			float illusoryProbability <- perceivedProbability * nb_of_warning_msg;
			do remove_belief(beliefName);
			do add_belief(beliefName, illusoryProbability);
		}
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
		
		
		if(neglect_of_probability_cb_influence)
		{
			write string(self)+" My probability to reacte is influenced by neglect_of_probability";
			do neglect_of_probability(probability_to_react);
		}
		
		bool react <- flip(probability_to_react);
		
		//Should be in perceive
		if(illusory_truth_effect_cb_influence)
		{
			write string(self)+" My probability to react is influenced by illusory_truth_effect";
			do illusory_truth_effect(potential_danger_belief, probability_to_react);
		}
		
		if(semmelweis_reflex_cb_influence)
		{
			react <- semmelweis_reflex(probability_to_react);
			if(!react) { write string(self)+" My probability to react is influenced by the semmelweis_reflex"; }
		}

		if ("Alert for Residents : Go to shelter" in msg and react)
		{
			write (string(self) + " : I'm going to defend my house");
			on_alert <- true;
			warned <- true;
			
			do accept_proposal(message: info, contents: ['OK!']);
			
			speed <- speed + motivation; // Motivation increases speed
			
			do add_belief(potential_danger_belief);
			
			if(nb_of_warning_msg = 1) { nb_residents_w_answered_1st_call <- nb_residents_w_answered_1st_call + 1; } //count people who reacted on first call
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
	perceive target: plot in: 50.0 # m when: alive and ! in_safe_place and ! has_belief(potential_danger_belief)  {
		if(burning)
		{
			ask myself{
				do add_belief(potential_danger_belief);
//				do add_desire(call_911_desire);
//				do status("Adding potential_danger_belief and home_intention");
			}
		}
	}
	
	//If the agent perceives is hurt by a fire it should escape
	perceive target: plot in: 10.0 # m when: alive and ! in_safe_place and ! has_belief(immediate_danger_belief) {
		if(burning)
		{
			ask myself{
////				energy <- energy - 0.01;
//				if(energy <= 0)  {
//					alive <-false;
//				}
//				else 
				if(!has_desire(escape_desire))
				{
//					do remove_desire(work_desire);
					do remove_belief(no_danger_belief);
					do remove_belief(potential_danger_belief);
					
					do add_belief(immediate_danger_belief);
//					do add_desire(escape_desire);
					
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

	plan call_911_desire intention: call_911_desire priority: 3 when: alive and ! warning_sent finished_when: warning_sent instantaneous: true
	{
		do send_msg([one_of(firefighters where each.alive)], nil, "There's a fire");
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
//			do send_msg([one_of(firefighters where each.alive)], nil, 'Il y a un feu!');
//			// do start_conversation ( to : [one_of(firefighters where each.alive)], protocol : 'fipa-propose', performative : 'propose', contents : ['Il y a un feu!'] );
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
//			do send_msg([one_of(firefighters where each.alive)], nil, 'Il y a un feu!');
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