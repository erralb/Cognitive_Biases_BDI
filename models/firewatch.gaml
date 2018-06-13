/**
* Name: firewatch
* *=======================
* Author: Sofiane Sillali, Thomas Artigue, Pierre Blarre
* Description: Surveillance et detection des Zone à risque, lance l'alerte dès qu'un feu est perçu
* Fichier : firewatch.gaml
*/
model Application_Fire_Model

import "Application_Fire_Model.gaml"

/*=============================================
*                                           Agent firewatch
*=============================================*/
species firewatch skills: [fipa]
{
	bool warningSent <- false;
	string roof_texture <- "../images/bd_roof.png";
	plot my_plot;
	point choosed_location <- nil;

	// Aspect
	aspect base
	{
		draw circle(100) texture: [roof_texture] depth: 1 # m border: # black;
		draw square(10) color: warningSent ? # orange : # white depth: 40 # m;
	}

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
	}

	// Verification tous les 20 cycles, des N plot s'ils sont en feux ou non
	reflex watch when: cycle mod 20 = 0
	{
	// Récupération des plots à distance de dangeureuse
		list<plot> plot_is_fire <- plot where each.burning at_distance 100;

		// Si la liste n'est pas vide, un feu est présent, le firewatch envoi un message d'alerte au pompier
		if (length(plot_is_fire) != 0 and !warningSent)
		{
			if (!empty(fireman))
			{
				do start_conversation(to: fireman where each.alive, protocol: 'fipa-propose', performative: 'propose', contents: ['Il y a un feu!']);
			}

			warningSent <- true;
		}

		if (length(fireman where each.on_alert) < 1)
		{
			warningSent <- false;
		}

	}

}
