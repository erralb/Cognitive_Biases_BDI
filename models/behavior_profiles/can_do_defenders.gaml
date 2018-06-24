/**
* Name: Can Do Defenders behavior profile

* Author: Pierre Blarre
* 
* Description:   
* 
* Can-do defenders : 
* - are determined to protect their house, 
* - have good knowledge of the area, 
* - previous experience and skills, 
* - are action-oriented, 
* - are self-sufficient,
* - are confident;
* 
*  They can :
*  - Increase terrain and buildings resitance
*  - Fight fire, although not as well as firefighters
* 
*/
model Bushfires_BDI_Cognitive_Biases

import "../main.gaml"

species can_do_defenders parent: resident control: simple_bdi
{
	init
	{
		probability_to_react <- 0.8; //High probability to react
		default_probability_to_react <- 0.9;
		escape_target <- home; //They want to defend their house
		speed <- rnd(18.0, 25.0) # km / # h; // If you want them faster so they die less use : rnd(30.0, 50.0) 
		//Highly motivated, low risk awareness, high knowledge
		motivation <- max([0, rnd(3, 5) + motivation]);
		risk_awareness <- max([0, rnd(1, 3) + risk_awareness]);
		knowledge <- max([0, rnd(4, 5) + knowledge]);
		
		//Default beliefs
		do add_belief(no_danger_belief,0.3);
		do add_belief(can_defend_belief,0.7);
	}
}