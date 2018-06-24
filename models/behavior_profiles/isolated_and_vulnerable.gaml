/**
* Name: isolated_and_vulnerable
* *=======================
* Author: Sofiane Sillali, Thomas Artigue, Pierre Blarre
* Description:  
* 
*    Isolés vulnérables (isolated and vulnerable) : physiquement ou socialement isolés (p. ex.
*    personnes âgées ou handicapées) ce qui limite leur capacité à répondre adéquatement.
* 
* Fichier: resident.gaml
*/
model Bushfires_BDI_Cognitive_Biases

import "../environment.gaml"

/*============================================================
*                                             Agent isolated_and_vulnerable
*============================================================*/
species isolated_and_vulnerable parent: resident
{

// Variables
	init
	{
	// On part du principe qu'une personne isolé socialement ou physiquement ne travaille pas
		work <- home;
		// Affectation de la couleur de base
		color <- rgb(0, energy, energy);

		// En cas d'alerte je fuis
		desires <- [ask_for_help];
		intention <- desires[0];

		// Les personnes isolés ou vulnérable ont de base une faible capacité de réaction
		probability_to_react <- 0.1;

		// Faiblesse au niveau de la motivation , de la conscience des risques et des conaissances
		motivation <- max([0, rnd(1, 2) + motivation]);
		risk_awareness <- max([0, rnd(0, 1) + risk_awareness]);
		knowledge <- max([0, rnd(0, 1) + knowledge]);
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

		// TODO en fonction du message (personnalisé ou non) et de la personnalité => déduire une probabilité de réagir

		// Si le message est personnalisé, cette probabilité augmente fortement
			if (personalized_msg)
			{
				probability_to_react <- 0.3;
			}

			// Si ce n'est pas le premiers message, la probabilité de réaction baisse en fonction du nombre de messages déjà reçus
			if (nb_of_warning_msg > 1)
			{
				probability_to_react <- (probability_to_react > 0.0) ? (probability_to_react - (nb_of_warning_msg / 10)) : 0.0;
			}

			// Je réagis ou non
			if (flip(probability_to_react) and intention = ask_for_help)
			{
			// Ok je réagis
				on_alert <- true;
				warned <- true;
				do accept_proposal(message: info, contents: ['OK!']);
				// Ma motivation augement ma vitesse
				speed <- speed + motivation;
				// Je crois qu'il y a un danger potentiel
				belief <- potential_danger;
				nb_residents_w_answered_1st_call <- nb_residents_w_answered_1st_call + 1;

				// Je demande à un policier de venir me chercher;
				if (!(residents_who_have_asked_help contains self))
				{
					write (string(self) + " : je demandee de l'aide à la police" + string(self));
					residents_who_have_asked_help <- residents_who_have_asked_help + self;
				}

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

}