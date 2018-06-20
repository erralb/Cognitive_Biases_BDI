/**
* Name: fire
* Author: Sofiane Sillali, Thomas Artigue, Pierre Blarre
* Description: Definition d'un plot et de ses actions
* Fichier: fire.gaml
*/

model Application_Fire_Model

import "Application_Fire_Model.gaml"


/*=============================================
*                                          Agent Création Feu 
*=============================================*/
species fire_starter control: simple_bdi
{

// Variables
	rgb color <- # yellow;
	float size <- 10.00;
	plot my_plot;
	point choosed_location <- nil;

	// Init
	init
	{
	// Se placer dans une brousse ou à l'endroit choisi par l'utilisateur
		if (choosed_location = nil)
		{
			my_plot <- one_of(plot where (each.color = # green));
		} else
		{
			my_plot <- plot closest_to choosed_location;
		}

		location <- my_plot.location;

		// Il commence sa propagation sur ses voisins inflammables avec une probabilité de 0.6
		list<plot> neighbors_plot <- my_plot.neighbors where (each.flammable = true);
		loop neighbors over: neighbors_plot
		{
			neighbors.burning <- flip(0.6);
		}

	}

	// Aspect
	aspect base
	{
		draw triangle(size) color: color depth: 5 # m;
	}
	
}