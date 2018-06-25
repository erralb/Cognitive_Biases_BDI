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
	rule belief: can_defend_belief new_desire: defend_desire strength: 30.0 remove_desire: work_desire and home_desire;
	rule belief: immediate_danger_belief new_desire: escape_desire strength: 40.0 remove_desire: work_desire and home_desire;

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
			//Randomly distribute Cognitive Biases at a cognitive_biases_distribution% chance
			// But give only one bias
			
			bool cb_flip <- flip(cognitive_biases_distribution);
			int cb <- rnd(1,3);
			
			if(cb = 1)
			{ 
				neglect_of_probability_cb_influence <- true; 
				cognitive_biases_influence <- true; 
				nb_neglect_of_probability <- nb_neglect_of_probability + 1;
			}
			if(cb = 2)
			{ 
				semmelweis_reflex_cb_influence <- true; 
				cognitive_biases_influence <- true;
				nb_semmelweis_reflex <- nb_semmelweis_reflex + 1;
			}
			if(cb = 3)
			{
				illusory_truth_effect_cb_influence <- true; 
				cognitive_biases_influence <- true;
				nb_illusory_truth_effect <- nb_illusory_truth_effect + 1;
			}
		}
		
	}

	//Relexe : Couleur
	reflex color { color <- on_alert ? rgb(int(energy), int(energy), 0) : rgb(0, int(energy), 0); }
	
	
	//Resident receives a message
	reflex receive_message when: !(empty(proposes))
	{
		nb_of_warning_msg <- nb_of_warning_msg + 1;
		message info <- proposes at 0;
		string msg <- info.contents[0];
		
		// If personalized message is activated, the probability to react is increased by 30%
		if (personalized_msg)
		{
			probability_to_react <- probability_to_react + 0.3;
			if(probability_to_react > 1) { probability_to_react <- 1.0; }
		}
		
		bool react <- flip(probability_to_react);
		
		bool ignored_because_of_cb <-false;
		
		if(cognitive_biases_influence) {
			nb_of_warning_msg_cb <- nb_of_warning_msg_cb + 1; //count messages sent to residents that are under cb influence
			list<bool> cb_results <- cognitive_biases("receive_message reflex"); //Apply cignitive biases
 			do status("("+probability_to_react+") - "+cb_results);
			bool react <- cb_results[0];
			bool ignored_because_of_cb <- cb_results[1];
		}
		
		if (react and "Alert for Residents : Go into shelter" in msg)
		{
			if(show_residents_messages) { do status("I'm going to defend my house"); }
			on_alert <- true;
			warned <- true;
			
			do accept_proposal(message: info, contents: ['OK!']);
			
			speed <- speed + motivation; // Motivation increases speed
			
//			do add_belief(potential_danger_belief);
			do add_belief(immediate_danger_belief);
			
			if(nb_of_warning_msg = 1) { nb_residents_w_answered_1st_call <- nb_residents_w_answered_1st_call + 1; } //count people who reacted on first call
		}
		else
		{
			nb_ignored_msg_while_cb <- nb_ignored_msg_while_cb +1;
//			if(ignored_because_of_cb) { nb_ignored_msg_while_cb <- nb_ignored_msg_while_cb +1; }
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
	
	//If the agent perceives a smoke it should give the alert and stay alert, if his awareness is high enough
	perceive target: plot in: smoke_view 
	when: alive and ! in_safe_place and ! has_belief(potential_danger_belief)  {
		if(burning)
		{
			smoke_perceive_total <- smoke_perceive_total +1;
			ask myself {

//				bool react <- flip(probability_to_react);
				bool react <- true;
				bool ignored_because_of_cb <- false;
				
				if(cognitive_biases_influence) {
					list<bool> cb_results <- cognitive_biases("smoke_view perceive"); //Apply cognitive biases
					react <- cb_results[0];
					ignored_because_of_cb <- cb_results[1];
				}

				if (risk_awareness > 2 and react)
				{
					do add_belief(potential_danger_belief); // will add call_911_desire desire by rule
//					if(show_residents_messages) { do status("I perceived smoke signals"); }
					if(show_residents_BDI) { do status("potential_danger_belief added"); }
				}
				else
				{
					if(ignored_because_of_cb) { nb_of_smoke_signals_ignored_cb <- nb_of_smoke_signals_ignored_cb + 1; }
//					if(show_residents_messages) { do status("I ignored smoke signals"); }
				}
			}
		}
	}
	
	//If the agent perceives is hurt by a fire it should escape
	perceive target: plot in: hurting_distance 
//	perceive target: plot in: field_of_view 
//	when: alive and ! in_safe_place and ! has_belief(immediate_danger_belief) {
	when: alive and ! in_safe_place {
		if(burning)
		{
			fire_perceive_total <- fire_perceive_total +1;
			ask myself{
				
//				//since he perceives flames, we're going to assume the probabilty to react goes up
//				probability_to_react <- probability_to_react + 0.3;
//				if(probability_to_react > 1) { probability_to_react <- 1.0; }

//				bool react <- flip(probability_to_react);
				bool react <- true;
				bool ignored_because_of_cb <- false;
				
				if(cognitive_biases_influence) {
					list<bool> cb_results <- cognitive_biases("hurting_distance perceive"); //Apply cignitive biases
					react <- cb_results[0];
					ignored_because_of_cb <- cb_results[1];
				}
				
				if(!has_desire(escape_desire) and (risk_awareness >= 3 or react)) 
//				if((risk_awareness >= 3 and react)) 
				{
					do remove_belief(no_danger_belief);
					do remove_belief(potential_danger_belief);
					
					do add_belief(immediate_danger_belief);
					
					escape_target <- get_closest_safe_place();
					
//					if(show_residents_messages) { do status("I'm hurt, need to escape"); }
					if(show_residents_BDI) { do status("immediate_danger_belief added"); }
				}
				else
				{
					if(ignored_because_of_cb) { nb_of_fire_signals_ignored_cb <- nb_of_fire_signals_ignored_cb + 1; }
//					if(show_residents_messages) { do status("I ignored flames signals"); }
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
			if ((cycle + id) mod 10 = 0)
			{
				do increase_terrain_resistance(knowledge + motivation);
				do increase_building_resistance(knowledge + motivation);
			}
			if ((cycle + id) mod 100 = 0 and show_residents_messages) { do status("I'm protecting my surroundings"); }
		}
	}
	
	plan escape intention: escape_desire priority: 5 when: alive and ! in_safe_place finished_when: in_safe_place
	{
		if(escape_target = nil) { escape_target <- get_closest_safe_place(); }
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