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
//		do status("Get Belief : "+get_belief(no_danger_belief).strength);
		
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
			cognitive_biases_influence <- true; 
			if(flip(cognitive_biases_distribution))
			{ 
				neglect_of_probability_cb_influence <- true; 
				nb_neglect_of_probability <- nb_neglect_of_probability + 1;
			}
			if(flip(cognitive_biases_distribution))
			{ 
				semmelweis_reflex_cb_influence <- true; 
				nb_semmelweis_reflex <- nb_semmelweis_reflex + 1;
			}
			if(flip(cognitive_biases_distribution))
			{
				illusory_truth_effect_cb_influence <- true; 
				nb_illusory_truth_effect <- nb_illusory_truth_effect + 1;
			}
		}
	}
	
	
	//Resident receives a message (for now only from the police)
	//TODO send receive messages between residents (family?)
	reflex receive_message when: !(empty(proposes))
	{
		message info <- proposes at 0;
		string msg <- info.contents[0];
		if(show_residents_messages) { do status("I received the message : "+msg); }
		
		// If personalized message is activated, the probability to react is increased by 30%
		if (personalized_msg) { probability_to_react <- (probability_to_react+30 > 100) ? 100.0 : probability_to_react + 30; }
		
		bool ignored_because_of_cb <- false;
		bool accepted <- false;
		
		if ("Alert for Residents : Go into shelter" in msg)
		{
			nb_of_warning_msg <- nb_of_warning_msg + 1;
			
			if(!cognitive_biases_influence) {
				do add_belief(potential_danger_belief, probability_to_react);
				accepted <- true;
			}
			else
			{
				nb_of_warning_msg_cb <- nb_of_warning_msg_cb + 1; //count messages sent to residents that are under cb influence
				
				do cognitive_biases(potential_danger_belief, probability_to_react, "potential_danger_belief receive_message reflex"); //Apply cognitive biases
				
				if(!has_belief(potential_danger_belief)) //the potential danger was ignored because of cognitive biases' impact
				{
					nb_ignored_msg_while_cb <- nb_ignored_msg_while_cb +1; 
					if(show_residents_messages) { do status("I ignore the warning"); }
					do reject_proposal(message: info, contents: ["I ignore the warning"]);
				}
				else { accepted <- true; } 
			}
			
			if(accepted)
			{
				if(show_residents_messages) { do status("I Believe there is a potential danger (Strengh : "+probability_to_react+")"); }
				do accept_proposal(message: info, contents: ['OK!']);
				on_alert <- true;
				warned <- true;
				do color; //change color
				speed <- speed + motivation; // Motivation increases speed
				if(nb_of_warning_msg = 1) { nb_residents_w_answered_1st_call <- nb_residents_w_answered_1st_call + 1; } //count people who reacted on first call
			}
		}

		// If the fires are extinguished, back to normal
		if ("Fires extinguished" in msg)
		{
			nb_of_stop_msg <- nb_of_stop_msg + 1;
			
			if(cognitive_biases_influence) {
				
				nb_of_warning_msg_cb <- nb_of_warning_msg_cb + 1; //count messages sent to residents that are under cb influence
				
				do cognitive_biases(potential_danger_belief, probability_to_react, "potential_danger_belief receive_message reflex"); //Apply cognitive biases
				do cognitive_biases(immediate_danger_belief, probability_to_react, "immediate_danger_belief receive_message reflex"); //Apply cognitive biases
				
				if(has_belief(potential_danger_belief) or has_belief(immediate_danger_belief)) //The agent still believes there's danger
				{
					nb_ignored_msg_while_cb <- nb_ignored_msg_while_cb +1;
					if(show_residents_messages) { do status("I ignore the extinguished fires message"); }
					do reject_proposal(message: info, contents: ["I ignore the end of the alert and keep defending"]);
					kept_defense_late <- kept_defense_late +1;
				}
				else { accepted <- true; }
				
			}
			else { accepted <- true; }
			
			if(accepted)
			{
				do accept_proposal(message: info, contents: ['OK!']);
				do back_to_normal_state;
				if(nb_of_warning_msg = 1) { nb_residents_w_stopped_1st_call <- nb_residents_w_stopped_1st_call + 1; } //count people who stopped on first call
			}
		}
	}
	
	//Smoke perception : he should give the alert and stay alert, if his awareness is high enough
	perceive target: plot in: smoke_view 
	when: ! has_perceived_smoke and alive and ! in_safe_place and ! has_belief(immediate_danger_belief)  {
		
		if(self != nil and self.burning and !myself.has_perceived_smoke)
		{
			smoke_perceive_total <- smoke_perceive_total +1;
			plot current_target <- self;
			
			ask myself {
				
				has_perceived_smoke <- true;
				
				bool react <- true;
				bool ignored_because_of_cb <- false;
				bool accepted <- false;
				
				//direct perception triggers beliefs if his awareness is above average
				if (risk_awareness > risk_awareness_average)
				{
					do add_belief(potential_danger_belief); // will add call_911_desire desire by rule
					if(show_residents_BDI) { do status("potential_danger_belief added"); }
				}
				
				//cognitive biases might influence beliefs
				if(cognitive_biases_influence) {
					do cognitive_biases(potential_danger_belief, probability_to_react, "smoke_view perceive on "+current_target); //Apply cognitive biases
				}
				
				//The agent still believes there's no potential danger
				if(!has_belief(potential_danger_belief)) 
				{
					nb_of_smoke_signals_ignored_cb <- nb_of_smoke_signals_ignored_cb + 1;
					if(show_residents_messages) { do status("I ignored smoke signals"); }
					has_perceived_smoke <- false;
				}
				
				if(has_desire(escape_desire)) { triggered_escape_early <- triggered_escape_early +1 ; } //record early escape plan
				if(has_desire(defend_desire)) { triggered_defense_early <- triggered_defense_early +1 ; } //record laste escape plan 
			}
		}
	}
	
	//Close fire perception : he should escape or trigger his fire plan
	perceive target: plot in: hurting_distance 
	when: ! has_perceived_fire and alive and ! in_safe_place  {
		
		if(self != nil and self.burning and !myself.has_perceived_fire)
		{
			fire_perceive_total <- fire_perceive_total +1;
			plot current_target <- self;
			
			ask myself{
				
				has_perceived_fire <- true;
				
				//since he perceives flames, we're going to assume the probabilty to react goes up
				probability_to_react <- probability_to_react + 20 > 100 ? 100.0 : probability_to_react + 20;
				
				//direct perception add beliefs if his risk_awareness is above 0
				//we consider that 0 awareness would represent a person not able to react to danger at all, like a baby or a handicapped person 
				if (risk_awareness > 0)
				{
					do remove_all_beliefs(no_danger_belief);
					do remove_all_beliefs(potential_danger_belief);
					do add_belief(immediate_danger_belief,probability_to_react);
				}

				//cognitive biases might influence beliefs
				if(cognitive_biases_influence) {
					do cognitive_biases(immediate_danger_belief, probability_to_react, "hurting_distance perceive on "+current_target); //Apply cignitive biases
				}
				
				//The agent still believes there's no immediate danger
				if(!has_belief(immediate_danger_belief))
				{
					nb_of_fire_signals_ignored_cb <- nb_of_fire_signals_ignored_cb + 1;
					if(show_residents_messages) { do status("I ignored flames signals"); }
					has_perceived_fire <- false;
				}
				else
				{
					if(show_residents_BDI) { do status("immediate_danger_belief added"); }
				}
				
				if(!has_desire(escape_desire)) { triggered_escape_late <- triggered_escape_late +1 ; } //record late escape plan
				if(!has_desire(defend_desire)) { triggered_defense_early <- triggered_defense_early +1 ; } //record late defense plan
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
			if(show_residents_messages) {do status("I escaped safely"); }
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
			
			has_perceived_smoke <- false;
			has_perceived_fire <- false;
			
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