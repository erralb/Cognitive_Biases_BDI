/**
* Name: livelihood_defenders
* *=======================
* Author: Sofiane Sillali, Thomas Artigue, Pierre Blarre
* Description:  
* 
* 	Défenseurs économiques (livelihood defenders) : engagés à rester et défendre ce qu’ils considèrent 
* 	comme leur moyen de subsistance (ferme, hôtel...) et donc bien préparés
* 
*  Les defenders peuvent:
*  - Renforcer leur maison
*  - combattre le feu
* 
* 
* Fichier: livelihood_defenders.gaml
*/
model Application_Fire_Model

import "../Application_Fire_Model.gaml"

/*============================================================
*                                             Agent  livelihood_defenders
*============================================================*/
species livelihood_defenders parent: resident
{

// Variables
	init
	{
	// Ces  personnes ont de base une bonne capacité de réaction
		probability_to_react <- 0.8;
		// Affectation de la couleur de base
		color <- rgb(0, energy, 0);

		// En cas d'alerte je rentre chez moi car je suis déterminés à protéger ma maison
		// A la base, mon intention et mon désir sont identiques
		desires <- [defend, run_away];
		intention <- desires[0];
		escape_target <- home;
		motivation <- max([0, rnd(4, 5) + motivation]); // Très motivé
		risk_awareness <- max([0, rnd(1, 2) + risk_awareness]); // Attachement économique qui diminue la conscience des risques
		knowledge <- max([0, rnd(3, 4) + knowledge]); // Expérimentés et compétents,
	}

	// Relexe : Couleur
	reflex color
	{
		color <- on_alert ? rgb(energy, energy, 0) : rgb(0, energy, 0);
	}

	// Réception de messages
	reflex receive_call_resident when: !(empty(proposes))
	{
		nb_of_warning_msg <- nb_of_warning_msg + 1;
		message info <- proposes at 0;
		string msg <- info.contents[0];

		// Si le message est personnalisé, cette probabilité augmente fortement
		if (personalized_msg)
		{
			probability_to_react <- 1.0;
		}

		// Si ce n'est pas le premiers message, la probabilité de réaction baisse en fonction du nombre de messages déjà reçus
		if (nb_of_warning_msg > 1)
		{
			probability_to_react <- (probability_to_react > 0.0) ? (probability_to_react - (nb_of_warning_msg / 10)) : 0.0;
		}

		// Si une alerte d'évacution est donnée
		if ("Allez dans un bunker!" in msg)
		{

		// Je réagis ou non
			if (flip(probability_to_react))
			{

			// Ok je réagis
				write (string(self) + " : Je vais défendre ma source de revenu");
				on_alert <- true;
				warned <- true;
				do accept_proposal(message: info, contents: ['OK!']);
				// Ma motivation augement ma vitesse
				speed <- speed + motivation;
				// Je crois qu'il y a un danger potentiel
				belief <- potential_danger;
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

	// Je suis en alerte et pas en lieu sûr et pas au travail
	reflex react_go_work when: alive and on_alert and !in_safe_place and !at_work
	{
	// je vais au travail car je suis déterminé à protéger mon lieu de travail
		if (bool(go_to(work)))
		{
			at_home <- false;
			at_work <- true;
		}

	}

	// Je suis en alerte et au travail => je défend
	reflex defending when: alive and on_alert and !in_safe_place and at_work and intention = defend
	{

	// Si mon intention de base et de déffendre mon travail
		if ((cycle + id) mod 10 = 0)
		{
		//write string(self) + " : Je défends mon travail." ;
			location <- any_point_in(work);
			// Plus ma connaissance et ma motivation sont grandes, plus mon efficacité défendre mon travail est grande
			do increase_terrain_resistance(knowledge + motivation);
			do increase_building_resistance(knowledge + motivation);

			// Si je vois le feu et que ma conscience des risques est >= 3, mon désire change et je fuis 
			list<bool> danger <- check_if_danger_is_near();
			if (danger[0] and risk_awareness >= 3)
			{
				write string(self) + " : Le feu est là et je suis conscient des risques : je fuis";
				// Je crois qu'il y a un danger immédiat
				belief <- immediate_danger;
				intention <- desires[1];
				escape_target <- get_closest_safe_place();
			}

		}

	}

	// Je fuis car je suis conscient des risques
	reflex run_away when: alive and on_alert and !in_safe_place and intention = run_away
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