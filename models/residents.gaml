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
species resident parent: people
{

// Variables
	int nb_of_warning_msg <- 0;
	bool warned <- false;
	bool evacuating <- false;
	bool is_escorted <- false;
	float probability_to_react <- 0.0;
	init
	{
		speed <- rnd(13.0, 18.0) # km / # h;
		home <- one_of(building where (!each.bunker and !each.fire_station and !each.police_station));
		location <- any_location_in(home);
		at_home <- true;
		work <- one_of(building where (each != home and !each.bunker and !each.fire_station and !each.police_station));
	}

	// Relexe : Couleur
	reflex color
	{
		color <- on_alert ? rgb(energy, energy, 0) : rgb(0, energy, 0);
	}

	//======================  Début  action back_to_normal_state ================================================
	// Retour à l'état normal
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
	//====================== Fin action back_to_normal_state ================================================

}