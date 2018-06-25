/**
* Name: Isolated and vulnerable behavior profile

* Author: Pierre Blarre
* 
* Description:   
* 
* CIsolated and vulnerable : 
* - are isolated physically or socially (old, geographically isolated or handicaped people for example)
* - are not aware of the risk
* - are slow
* - need assitance
* 
*  They can :
*  - call for escort (with low probability)
* 
* The model has an option to create a list of isolated and vulnerable people
* so the police know in advance where to go first in case of an alert
* 
*/

model Bushfires_BDI_Cognitive_Biases

import "../main.gaml"

species isolated_and_vulnerable parent: resident
{
	init
	{
		work <- home; //we assume this profile is not working
		color <- rgb(0, int(energy), int(energy)); //different color

		probability_to_react <- 0.1; //lowest probability to react
		default_probability_to_react <- 0.1;

		// Everything is low... poor little ones!
		speed <- rnd(5.0, 8.0) # km / # h;
		motivation <- max([0, rnd(1, 2) + motivation]);
		risk_awareness <- max([0, rnd(0, 1) + risk_awareness]);
		knowledge <- max([0, rnd(0, 1) + knowledge]);
		
		//Default beliefs
		do add_belief(no_danger_belief,0.7);
	}
	
	//then can only escape
	rule belief: immediate_danger_belief new_desire: escape_desire strength: 40.0 remove_desire: work_desire and home_desire and can_defend_belief;

	reflex color { color <- on_alert ? rgb(energy, energy, 0) : rgb(0, energy, energy); }
	
	plan escape intention: escape_desire priority: 5 
	when: alive and ! in_safe_place 
	finished_when: (residents_who_have_asked_help contains self)
//	instantaneous: true
	{
		// Call for a policeman to escort me
		if (!(residents_who_have_asked_help contains self))
		{
			if(show_residents_messages) { do status("I need help to evacuate"); }
			residents_who_have_asked_help <- residents_who_have_asked_help + self;
		}
	}
}

