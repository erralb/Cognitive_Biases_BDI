/**
* Name: Unaware Reactors behavior profile

* Author: Pierre Blarre
* 
* Description:   
* 
* Unaware Reactors : 
* - are unaware of the risk
* - feel they are not concerned by fires
* - have no knowledge of how to react (e.g. tourists)
* - therefore totally unprepared
* 
*/

model Bushfires_BDI_Cognitive_Biases

import "../main.gaml"

species unaware_reactors parent: resident
{
	init
	{
		probability_to_react <- 0.1; //lowest probability to react
		default_probability_to_react <- 0.1;
		
		color <- rgb(0, energy, energy);

		escape_target <- one_of(city_exit); //randomly know one of the city exit
		
		//Low motivation, low risk awareness, no knowledge. the ones you don't want during crisis situations...
		motivation <- max([0, rnd(1, 2) + motivation]);
		risk_awareness <- max([0, rnd(0, 1) + risk_awareness]);
		knowledge <- max([0, rnd(0, 1) + knowledge]);
		
		//Default beliefs
		do add_belief(no_danger_belief,1.0);
	}

	reflex color { color <- on_alert ? rgb(energy, energy, 0) : rgb(0, energy, energy); }
}
