/**
* Name: buildingRoadExit
* *=======================
* Author: Sofiane Sillali, Thomas Artigue, Pierre Blarre
* Description: Definition des Batiments, des routes et des sorties
* Fichier : buildingRoadExit.gaml
*/
model Application_Fire_Model

import "Application_Fire_Model.gaml"

/*=============================================
*                                            Agent building
*=============================================*/
//TODO bâtiment, sous-type: maison, shelter au lieu de passer par des variables
species building schedules: [] frequency: 0
{

	// Variables
	bool bunker <- false;
	bool fire_station <- false;
	bool police_station <- false;
	int resistance <- rnd(100, 200);
	float damage <- 0.0;
	float height <- 10 # m + rnd(30) # m;
	string texture <- "../images/bd_text.png";
	string roof_texture <- "../images/bd_roof.png";
	string bunker_texture <- "../images/bunker_txt.png";

	// Aspect
	aspect base
	{
	// graded gray, turning to black as the building burns
//		draw shape texture: bunker ? [bunker_texture, bunker_texture] : [roof_texture, texture] color: bunker ? # yellow : (fire_station ? # red : (police_station ? blend(# black, #
//		blue, damage / resistance) : ((resistance > 230 and damage = 0.0) ? blend(# black, # magenta, damage / resistance) : blend(# black, # white, damage / resistance)))) border: #
//		black depth: height;
		
		draw circle(5 # m) texture: bunker ? [bunker_texture, bunker_texture] : [roof_texture, texture] color: bunker ? # yellow : (fire_station ? # red : (police_station ? blend(# black, #
		blue, damage / resistance) : ((resistance > 230 and damage = 0.0) ? blend(# black, # magenta, damage / resistance) : blend(# black, # white, damage / resistance)))) border: #
		black depth: height;
	}

}

/*=============================================
*                                             Agent road
*=============================================*/
species road
{
	int id <- 1;
	rgb color <- # darkgrey;
	bool is_practicable <- true;
	geometry display_shape <- shape + 2.0;
	init
	{
		ids <- ids + 1;
		id <- ids;
	}

	aspect base
	{
		draw shape color: color width: 4.0;
	}

	reflex refresh_road when: ((cycle + id) mod 20 = 0)
	{
		// La route est praticable si aucun plot en feu ne brûle sur elle
		is_practicable <- empty(plot overlapping (self) where each.burning);
		color <- is_practicable ? # grey : # red;

		// Je rafraichi le réseau routier praticable
		road_network_practicable <- as_edge_graph(road where each.is_practicable);
	}

}

/*=============================================
*                                  Sortie de ville ou Bunker 
*=============================================*/
species city_exit
{
	int nb_escaped_through_me <- 0 update: length((every_resident_alive) at_distance 30 # m where (each.alive and each.in_safe_place));
	init
	{
		nb_exit <- nb_exit + 1;
	}

	// Aspect
	aspect base
	{
		draw circle(30 # m) color: # white depth: 1 # m border: # black;
		draw string(nb_escaped_through_me) color: # black size: 50 at: point(self.location.x - 1, self.location.y - 2, self.location.z + 5) depth: 2 # m;
	}

}
