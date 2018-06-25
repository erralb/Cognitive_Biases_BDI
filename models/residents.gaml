/**
* Name: resident
* *=======================
* Author: Sofiane Sillali, Thomas Artigue, Pierre Blarre
* Description:  Definition des types de residants
* Fichier: resident.gaml
*/
model Bushfires_BDI_Cognitive_Biases

import "main.gaml"

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
		
		// Default resident has the threat_avoiders attributes, which is average
		color <- rgb(0, int(energy), 0);
		
		speed <- rnd(13.0, 18.0) # km / # h; // If you want them faster so they die less use : rnd(30.0, 50.0) 
		
		motivation <- max([0, rnd(2, 3) + motivation]); //Average motivation
		risk_awareness <- max([0, rnd(3, 5) + risk_awareness]); // High awareness
		knowledge <- max([0, rnd(3, 5) + knowledge]); // Good knowledge
		
		//Default belief :  no danger I am safe
		do add_belief(no_danger_belief, default_belief_strengh);
		
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
		
		escape_target <- get_closest_safe_place();
		
		if(use_cognitive_biases)
		{
			//Randomly distribute Cognitive Biases at a 20% chance
			if(flip(0.2))
			{ 
				neglect_of_probability_cb_influence <- true; 
				cognitive_biases_influence <- true; 
				nb_neglect_of_probability <- nb_neglect_of_probability + 1;
			}
			if(flip(0.2))
			{ 
				semmelweis_reflex_cb_influence <- true; 
				cognitive_biases_influence <- true;
				nb_semmelweis_reflex <- nb_semmelweis_reflex + 1;
			}
			if(flip(0.2))
			{
				illusory_truth_effect_cb_influence <- true; 
				cognitive_biases_influence <- true;
				nb_illusory_truth_effect <- nb_illusory_truth_effect + 1;
			}
		}
		
	}

	// Relexe : Couleur
	reflex color { color <- on_alert ? rgb(int(energy), int(energy), 0) : rgb(0, int(energy), 0); }
	

	
	// Resident received message
	reflex receive_call_resident when: !(empty(proposes))
	{
		nb_of_warning_msg <- nb_of_warning_msg + 1;
		message info <- proposes at 0;
		string msg <- info.contents[0];
		bool ignored_because_of_cb <- false;
		
		// If personalized message is activated, the probability to react is increased by 30%
		if (personalized_msg)
		{
			probability_to_react <- probability_to_react + 0.3;
			if(probability_to_react > 1) { probability_to_react <- 1.0; }
		}
		
//		// Si ce n'est pas le premiers message, la probabilité de réaction baisse en fonction du nombre de messages déjà reçus
//		if (nb_of_warning_msg > 1)
//		{
//			probability_to_react <- (probability_to_react > 0.0) ? (probability_to_react - (nb_of_warning_msg / 10)) : 0.0;
//		}
//		
		if(neglect_of_probability_cb_influence)
		{
			if(show_cognitive_biases_messages) { do status("My probability to react was influenced by neglect_of_probability"); }
			do neglect_of_probability(probability_to_react);
			nb_cb_influences <- nb_cb_influences + 1;
			ignored_because_of_cb <- true;
		}
		
		bool react <- flip(probability_to_react);
		
		//Should be in perceive
		if(illusory_truth_effect_cb_influence)
		{
			if(show_cognitive_biases_messages) { do status("My probability to react is influenced by illusory_truth_effect"); }
			do illusory_truth_effect(potential_danger_belief, probability_to_react);
			nb_cb_influences <- nb_cb_influences + 1;
			ignored_because_of_cb <- true;
		}
		
		if(semmelweis_reflex_cb_influence)
		{
			react <- bool(semmelweis_reflex(probability_to_react));
			if(!react) { 
				if(show_cognitive_biases_messages) { do status("My probability to react is influenced by the semmelweis_reflex"); }
				nb_cb_influences <- nb_cb_influences + 1;
				ignored_because_of_cb <- true;
			}
		}

		if (react and "Alert for Residents : Go to shelter" in msg)
		{
			write (string(self) + " : I'm going to defend my house");
			on_alert <- true;
			warned <- true;
			
			do accept_proposal(message: info, contents: ['OK!']);
			
			speed <- speed + motivation; // Motivation increases speed
			
			do add_belief(potential_danger_belief);
			
			if(nb_of_warning_msg = 1) { nb_residents_w_answered_1st_call <- nb_residents_w_answered_1st_call + 1; } //count people who reacted on first call
		}
		else
		{
			if(ignored_because_of_cb) { nb_ignored_msg_while_cb <- nb_ignored_msg_while_cb +1; }
			if(show_residents_messages) { do status("I ignore the warning"); }
			do reject_proposal(message: info, contents: ["I ignore the warning"]);
		}

		// If the fires are extinguished, back to normal
		if (info.contents[0] = "Fires extinguished")
		{
			//TODO this should also be influenced by Cognitive Biases
			//Like reject the fact that the dange is over and keep escaping or defending when it's not useful anymore
			do accept_proposal(message: info, contents: ['OK!']);
			do back_to_normal_state;
		}
	}
	
	//If the agent perceives a fire/smoke it should give the alert and stay alert, if his awareness is high enough
	perceive target: plot in: smoke_view 
	when: alive and ! in_safe_place and ! has_belief(potential_danger_belief)  {
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
	perceive target: plot in: hurting_distance 
	when: alive and ! in_safe_place and ! has_belief(immediate_danger_belief) {
		if(burning)
		{
			ask myself{
				//TODO should be influence by cognitive biases
				if(!has_desire(escape_desire) and risk_awareness >= 3) 
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
	
	plan go_to_work intention: work_desire priority: 1 when: alive and ! at_work and ! in_safe_place finished_when: at_work or has_desire(escape_desire)
	{
		if (bool(go_to(work)))
		{
			at_home <- false;
			at_work <- true;
			do remove_desire(work_desire);
			if(show_residents_messages) { do status("I'm at work"); }
		}
	}
	
	plan go_home intention: home_desire priority: 2 when: alive and ! at_home and ! in_safe_place finished_when: at_home or has_desire(escape_desire)
	{
		if (bool(go_to(home)))
		{
			at_home <- true;
			at_work <- false;
			do remove_desire(home_desire);
			if(show_residents_messages) { do status("I'm at home"); }
		}
	}

	plan call_911 intention: call_911_desire priority: 3 
	when: alive and ! warning_sent 
	finished_when: warning_sent 
	instantaneous: true
	{
		do send_msg([one_of(firefighters where each.alive)], nil, "There's a fire");
		warning_sent <- true;
		if(show_residents_messages) { do status("I called 911"); }
	}
	
	plan defend  intention: defend_desire  priority: 4 
	when: alive and !in_safe_place and ( has_belief(potential_danger_belief) or has_belief(immediate_danger_belief) )
	finished_when: has_desire(escape_desire) //this will be triggered if the agent perceives a fire at hurting distance
	{
		if (bool(go_to(home)))
		{
			if(show_residents_messages) { do status("I'm trying to defend"); }
			if ((cycle + id) mod 10 = 0)
			{
				do increase_terrain_resistance(knowledge + motivation);
				do increase_building_resistance(knowledge + motivation);
			}
		}
	}
	
	plan escape intention: escape_desire priority: 5 when: alive and ! in_safe_place finished_when: in_safe_place
	{
		if (bool(go_to(escape_target)))
		{
			at_home <- false;
			at_work <- false;
			in_safe_place <- true;
			if(show_residents_messages) { write (string(self) + " : I escaped safely"); }
		}
	}

	//Reset beliefs  and attributes to initial state
	action back_to_normal_state
	{
		if (on_alert)
		{
			do remove_all_beliefs(potential_danger_belief);
			do remove_all_beliefs(immediate_danger_belief);
			do add_belief(no_danger_belief);
			
			probability_to_react <- default_probability_to_react;
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