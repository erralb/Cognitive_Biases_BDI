/**
* Name: Livelihood Defenders behavior profile

* Author: Pierre Blarre
* 
* Description:   
* 
* Can-do defenders : 
* - are committed to stay and defend what they consider as their livelihood (farm, hotel, etc.)
* - are therefore well-prepared year-round
* 
*  They can :
*  - Increase terrain and buildings resitance
*  - Fight fire, although not as well as firefighters
* 
*/

model Bushfires_BDI_Cognitive_Biases

import "../main.gaml"

species livelihood_defenders parent: resident
{
	init
	{
		probability_to_react <- 90.0; //Highest probability to react
		default_probability_to_react <- 90.0;
		
		do add_belief(no_danger_belief,20.0);
		do add_belief(can_defend_belief,100.0);

		home <- work;
		escape_target <- home;
		
		//Highly motivated, lower risk awareness because they care too much about their livelihood, high knowledge
		motivation <- max([0, rnd(4, 5) + motivation]);
		risk_awareness <- max([0, rnd(1, 2) + risk_awareness]);
		knowledge <- max([0, rnd(3, 4) + knowledge]);
		
	}
	
	//They'd rather die than escape...
	rule belief: immediate_danger_belief new_desire: escape_desire strength: 10.0 remove_desire: work_desire and home_desire;
	rule belief: can_defend_belief new_desire: defend_desire strength: 100.0;

	reflex color { color <- on_alert ? rgb(energy, energy, 0) : rgb(0, energy, 0); }

}