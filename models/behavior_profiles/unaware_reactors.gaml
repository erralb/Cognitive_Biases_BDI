/**
* Name: unaware_reactors
* *=======================
* Author: Sofiane Sillali, Thomas Artigue, Pierre Blarre
* Description:  
* 
*   Réactifs inconscients (unaware reactors) : inconscients du risque, ne se sentent pas
*   concernés, aucune connaissance des réactions appropriées ni préparation (touristes...) ;
* 
* Fichier: unaware_reactors.gaml
*/
model Bushfires_BDI_Cognitive_Biases

import "../environment.gaml"

/*============================================================
*                                             Agent unaware_reactors
*============================================================*/
species unaware_reactors parent: resident
{

// Variables
	bool reacting <- false;
	init
	{
	// Les personnes Réactifs inconscients  n'ont pas conscience du risque et ne réagissent pas beaucoup
		probability_to_react <- 0.1;
		// Affectation de la couleur de base
		color <- rgb(0, energy, energy);

		// En cas d'alerte je fuis
		desires <- [run_away];
		intention <- desires[0];

		// je ne connais pas bien la ville, je ne connais qu'une sortie sans savoir si c'est la plus proche
		escape_target <- one_of(city_exit);
		motivation <- max([0, rnd(2, 3) + motivation]); // Motivation moyenne
		risk_awareness <- max([0, rnd(0, 1) + risk_awareness]); //  Inconscients du risque
		knowledge <- max([0, rnd(0, 1) + knowledge]); // Aucune connaissances
	}

	// Relexe : Couleur
	reflex color
	{
		color <- on_alert ? rgb(energy, energy, 0) : rgb(0, energy, energy);
	}

	// Réception de messages
	reflex receive_call_resident when: !(empty(proposes))
	{
		nb_of_warning_msg <- nb_of_warning_msg + 1;
		message info <- proposes at 0;
		string msg <- info.contents[0];

		// Si une alerte d'évacution est donnée
		if ("Allez dans un bunker!" in msg)
		{

		// Si le message est personnalisé, cette probabilité augmente fortement
			if (personalized_msg)
			{
				probability_to_react <- 0.7;
			}

			// Si ce n'est pas le premiers message, la probabilité de réaction baisse en fonction du nombre de messages déjà reçus
			if (nb_of_warning_msg > 1)
			{
				probability_to_react <- (probability_to_react > 0.0) ? (probability_to_react - (nb_of_warning_msg / 10)) : 0.0;
			}

			// Je réagis ou non
			if (flip(probability_to_react))
			{
			// Ok je réagis, je suis en alerte
				write (string(self) + " : Je vais essayé de fuire mais je connais mal la ville.");
				on_alert <- true;
				// Ma motivation augement ma vitesse
				speed <- speed + motivation;
				// Je crois qu'il y a un danger potentiel
				belief <- potential_danger;
				nb_residents_w_answered_1st_call <- nb_residents_w_answered_1st_call + 1;
			} else
			{
			// Je ne suis pas concerné, je ne réagit pas.
				write (string(self) + " : J'ignore l'avertissement");
				do reject_proposal(message: info, contents: ["J'ignore l'avertissement"]);
			}

		}

		// Si c'est la fin de l'alerte au feux
		if (info.contents[0] = "Fin de l'alerte au feu")
		{
		// Accépter le message et retour à l'état normal
			do accept_proposal(message: info, contents: ['OK!']);
			do back_to_normal_state;
		}

	}

	// Je suis en alerte et pas en lieux sûr et que je désire fuire
	reflex react when: alive and on_alert and !in_safe_place and intention = run_away
	{

	// Ils n'ont pas de plan et recherche l'un des sortie de la ville sans savoir si c'est la plus proche
		if (bool(go_to(agent(escape_target))))
		{
			at_home <- false;
			at_work <- false;
			in_safe_place <- true;
		}

		if (cycle mod 2 = 0)
		{
		// S'il existe un danger, je réagis en fonction de ma conscience du risque et de trouve la meilleurs issue en fonction de ma connaissance
			list<bool> danger <- check_if_danger_is_near();
			if (danger[0])
			{
			// Je crois qu'il y a un danger immédiat
				belief <- immediate_danger;
				do react_to_danger(danger);
			}

		}

	}

}
