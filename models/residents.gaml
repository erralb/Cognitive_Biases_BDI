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
//		speed <- rnd(13.0, 18.0) # km / # h;
		speed <- rnd(30.0, 50.0) # km / # h;
		home <- one_of(building where (!each.bunker and !each.fire_station and !each.police_station));
		location <- any_location_in(home);
		at_home <- true;
		work <- one_of(building where (each != home and !each.bunker and !each.fire_station and !each.police_station));
		
		escape_target <- home;
		color <- rgb(0, energy, 0);
		
		//everybody goes to work by default and thinks there's no danger
		do add_belief(no_danger);
		do add_desire(go_to_work);
		do add_intention(working);
		do status("Init status");
	}

	// Relexe : Couleur
	reflex color
	{
		color <- on_alert ? rgb(energy, energy, 0) : rgb(0, energy, 0);
	}

	
	// Go to work if alive, daytime, not already at work, not on alert, not fighting fire
	plan go_to_work intention: working when: alive and ! at_work and ! in_safe_place
	{
		if (bool(go_to(work)))
		{
			at_home <- false;
			at_work <- true;
			do remove_desire(go_to_work);
			do remove_intention(relaxing);
			do status("I'm at work");
		}
	}
	
	// Go home if alive, it's nighttime, not already at home, is not on alert, not fighting fire
	plan go_home intention: relaxing when: alive and ! at_home and ! in_safe_place
	{
		if (bool(go_to(home)))
		{
			at_home <- true;
			at_work <- false;
			do remove_desire(go_home);
			do remove_intention(working);
			do status("I'm at home");
		}
	}
	
	plan escape intention: escaping when: alive and ! in_safe_place
	{
//		write (string(self) + " : I need to escape");
		if (bool(go_to(escape_target)))
		{
			at_home <- false;
			at_work <- false;
			in_safe_place <- true;
			
			do remove_belief(immediate_danger);
			do remove_desire(run_away);
			do remove_intention(escaping);
			do add_intention(relaxing);
					
			write (string(self) + " : I'm safe and relaxing");
		}
	}
	
	plan defend intention: defending when: alive and ! in_safe_place
	{
		write (string(self) + " : I want to defend");
	}
	
	plan call intention: calling_for_help when: alive and ! in_safe_place
	{
		write (string(self) + " : I want to call 911");
		do send_msg([one_of(fireman where each.alive)], nil, "There's a fire");
		warning_sent <- true;
	}

	//If the agent perceives a fire for sure, then it escapes and gives the alert
	perceive target: plot in: 50 when: not has_belief(immediate_danger) and flip(probability_to_react) and ! in_safe_place  {
		if(burning)
		{
			ask myself{
				if(!has_belief(immediate_danger))
				{
					do add_belief(immediate_danger, 100.0);
					do add_desire(run_away);
					do add_intention(escaping); 
					escape_target <- get_closest_safe_place();
					do status("Perceived fire");
					
					if(!warning_sent)
					{
						do add_desire(call_911);
						do add_intention(calling_for_help);
					}
				}
			}
		}
	}
	
//	//Perceives fire, give the alert -> === CB should influence decision =======
//	//If the he thinks the danger isn't real (or not)
////	perceive target:self when: alive and on_alert and !warning_sent {
//	perceive target:self when: alive and !warning_sent and (has_belief(potential_danger) or has_belief(immediate_danger))  {
//		
//		write string(self) + " : Danger perceived ";
//		if(risk_awareness > 2)
//		{
//			do send_msg([one_of(fireman where each.alive)], nil, 'Il y a un feu!');
//			warning_sent <- true;
////			belief <- potential_danger;
//		}
//	}


	action back_to_normal_state
	{
		if (on_alert)
		{
			belief <- no_danger;
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