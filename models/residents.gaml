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
	bool warned <- false;
	bool evacuating <- false;
	bool is_escorted <- false;
	
	//The rules are used to create a desire from a belief. We can specify the priority of the desire with a statement priority.
	rule belief: no_danger_belief new_desire: work_desire strength: 10.0 remove_desire: escape_desire;
	rule belief: potential_danger_belief new_desire: call_911_desire strength: 20.0 remove_desire: work_desire and escape_desire;
	rule belief: immediate_danger_belief new_desire: escape_desire strength: 30.0 remove_desire: work_desire and home_desire;
	rule belief: can_defend_belief new_desire: defend_desire strength: 40.0;

	init
	{
		//Locations
		home <- one_of(building where (!each.bunker and !each.fire_station and !each.police_station));
		work <- one_of(building where (each != home and !each.bunker and !each.fire_station and !each.police_station));
		escape_target <- get_closest_safe_place();
		
		// Default resident has the threat_avoiders attributes, which is average
		color <- rgb(0, energy, 0);
		speed <- rnd(13.0, 18.0) # km / # h; // If you want them faster so they die less use : rnd(30.0, 50.0) 
		motivation <- max([0, rnd(2, 3) + motivation]); //Average motivation
		risk_awareness <- max([0, rnd(3, 5) + risk_awareness]); // High awareness
		knowledge <- max([0, rnd(3, 5) + knowledge]); // Good knowledge
		
		//Default belief :  no danger I am safe
		do add_belief(no_danger_belief,0.5);
		
 		//By default, 80% are at work, the rest are at home, doesn't really matter actually
 		//we place them right away, it avoids waiting for them to drive to their work place
		if(flip(0.8))
		{
			location <- any_location_in(work);
			at_work <- true;
			at_home <- false;
		}
		else
		{
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
	
	//Cognitive Bias : Neglect of probability
	//Will influence the agent's probability_to_react (decisions on going home or escaping)
	action neglect_of_probability(float perceivedProbability)
	{
		cognitive_biases_influence_occurence <- cognitive_biases_influence_occurence + 1;
		
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
	
	//If the agent perceives a fire it should give the alert and stay alert, if his awareness is high enough
	perceive target: plot in: 50.0 # m when: alive and ! in_safe_place and ! has_belief(potential_danger_belief)  {
		if(burning)
		{
			ask myself {
				if (risk_awareness > 2)
				{
					do add_belief(potential_danger_belief); // will add call_911_desire desire by rule
					if(show_residents_BDI) { do status("potential_danger_belief added"); }
				}
			}
		}
	}
	
	//If the agent perceives is hurt by a fire it should escape
	perceive target: plot in: 10.0 # m when: alive and ! in_safe_place and ! has_belief(immediate_danger_belief) {
		if(burning)
		{
			ask myself{
				if(!has_desire(escape_desire))
				{
					do remove_belief(no_danger_belief);
					do remove_belief(potential_danger_belief);
					
					do add_belief(immediate_danger_belief);
					
					escape_target <- get_closest_safe_place();
					
					if(show_residents_messages) { do status("I'm hurt, need to escape"); }
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
			if(show_residents_messages) { do status("I'm at work"); }
		}
	}
	
	plan home_desire intention: home_desire priority: 2 when: alive and ! at_home and ! in_safe_place finished_when: at_home or has_desire(escape_desire)
	{
		if (bool(go_to(home)))
		{
			at_home <- true;
			at_work <- false;
			do remove_desire(home_desire);
			if(show_residents_messages) { do status("I'm at home"); }
		}
	}

	plan call_911_desire intention: call_911_desire priority: 3 when: alive and ! warning_sent finished_when: warning_sent instantaneous: true
	{
		do send_msg([one_of(firefighters where each.alive)], nil, "There's a fire");
		warning_sent <- true;
		if(show_residents_messages) { do status("I called 911"); }
	}

	plan escape_desire intention: escape_desire priority: 4 when: alive and ! in_safe_place finished_when: in_safe_place
	{
		if (bool(go_to(escape_target)))
		{
			at_home <- false;
			at_work <- false;
			in_safe_place <- true;
			if(show_residents_messages) { write (string(self) + " : I escaped safely"); }
		}
	}
	
	//TODO implement defense
//	plan defend intention: defend_intention when: alive and ! in_safe_place
//	{
//		write (string(self) + " : I want to defend");
//	}

	action back_to_normal_state
	{
		if (on_alert)
		{
			do remove_all_beliefs(potential_danger_belief);
			do remove_all_beliefs(immediate_danger_belief);
			do add_belief(no_danger_belief);
			
			speed <- speed - motivation;
			in_safe_place <- false;
			on_alert <- false;
			warning_sent <- false;
			warned <- false;
			evacuating <- false;
			
			if(show_residents_messages) { do status("back to normal"); }
		}
	}

}