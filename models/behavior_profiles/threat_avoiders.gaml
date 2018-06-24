/**
* Name: Threat Avoider behavior profile

* Author: Pierre Blarre
* 
* Description:   
* 
* Threat Avoider : 
* - are conscious of the risk
* - feel vulnerable
* - plan to leave early before any real threat
* - but therefore have no plan if caught by surprise
* 
*/

model Bushfires_BDI_Cognitive_Biases

import "../main.gaml"

species threat_avoiders parent: resident
{

	init
	{
		probability_to_react <- 0.8; //High probability to react
		default_probability_to_react <- 0.9;
		
		color <- # purple;

		escape_target <- get_closest_safe_place(); //knows the city exits
		
		//Average motivation, high awareness, good knowledge
		motivation <- max([0, rnd(2, 3) + motivation]);
		risk_awareness <- max([0, rnd(4, 5) + risk_awareness]);
		knowledge <- max([0, rnd(3, 5) + knowledge]);
		
		//Default beliefs
		do add_belief(no_danger_belief,0.5);
	}

	// Relexe : Couleur
	reflex color { color <- on_alert ? rgb(energy, energy, 0) : # purple; }
}