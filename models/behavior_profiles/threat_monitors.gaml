/**
* Name: Threat Monitors behavior profile

* Author: Pierre Blarre
* 
* Description:   
* 
* Threat Monitors : 
* - do not intend to stay in front of a serious threat
* - but do not intend to leave until it feels necessary, will wait and see
* 
*/
model Bushfires_BDI_Cognitive_Biases

import "../main.gaml"

/*============================================================
*                                             Agent  threat_avoider
*============================================================*/
species threat_monitors parent: resident
{
	init
	{
		probability_to_react <- 0.7;

		color <- # purple;

		escape_target <- get_closest_safe_place(); //knows the city exits
		
		//Average motivation, average risk awareness, average knowledge
		motivation <- max([0, rnd(2, 3) + motivation]);
		risk_awareness <- max([0, rnd(2, 4) + risk_awareness]);
		knowledge <- max([0, rnd(2, 4) + knowledge]);

	}

	reflex color { color <- on_alert ? rgb(energy, energy, 0) : # purple; }
}