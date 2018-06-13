/**
* Name: PeopleBDI
* Author: Pierre Blarre
* Description: 
* Tags: Tag1, Tag2, TagN
*/

model CognitiveBiasesBDI

import "Cognitive_Biases_BDI.gaml"



species people skills: [moving, fipa] control: simple_bdi
{
	//Variables
	int id <- 1;
	rgb color <- # green;
	int energy <- rnd(200, 255);
	bool alive <- true;
//	building home;
//	building work;
	
	//Locations / Places
	bool at_home;
	bool at_work <- false;
	bool in_a_safe_place <- false;
	point target; //where the person wants to go
	agent escape_target <- nil; //the escape target in case of an emergency
	float speed <- 45 #km/#h; //default city road speed
	
	//Behaviors
	bool warning_sent <- false;
	
	// Psychological attributes
	int motivation; //higher motivation increases speed and defense capacity
	int risk_awareness; //higher awareness will increase response to messages and escaping
	int knowledge; //level of knowledge crisis management and technical abilities -> should influend cognitive biases
	int training; //level of training will influence the three previous values
	int fear_of_fire <- rnd(0, 1); //will influence decision making	
	
	
	//Definition of the variables featured in the BDI architecture.
	float plan_persistence <- 1.0; 
	float intention_persistence <- 1.0;
	bool probabilistic_choice <- true;
	
	//At the beginning, a person has no idea if there's a fire or if he's in danger
	int belief_operator <- 50;
	int subjective_probability <- 50;
	int warnings_received <- 0;
	
	//Available Desires
	predicate relax <- new_predicate("relax");
	predicate work <- new_predicate("work");
	
	predicate stay_alive <- new_predicate("stay_alive");
	predicate patrol <- new_predicate("patrol");
	predicate call_for_help <- new_predicate("call_for_help");
	predicate defend <- new_predicate("defend");
	predicate escape <- new_predicate("escape");
	
	predicate on_alert <- new_predicate("on_alert"); //CB : Neglect of Probability
	
	predicate at_target <- new_predicate("at_target");
	predicate in_shelter <- new_predicate("shelter");
	predicate has_target <- new_predicate("has target");
	predicate has_shelter <- new_predicate("has shelter");
	
    //Beliefs
	predicate possibility_of_a_fire <- new_predicate("possibility_of_a_fire",false);
	predicate there_s_a_fire <- new_predicate("there_s_a_fire",false);
	predicate im_in_danger <- new_predicate("im_in_danger",false);
	
//	//HOW TO ACHIEVE SOMETHING LIKE THIS?
//	//contains the desires and beliefs
//	list<list<predicate>> desires <- [[relax,0],[work,0],[stay_alive,100],[patrol,0],[call_for_help,0],[defend,0],[escape,0],[on_alert,0]];
//	list<list<predicate>> beliefs <- [[there_s_a_fire,0],[im_in_danger,0]];
	
	
	//The rules are used to create a desire from a belief. 
	//We can specify the priority of the desire with a statement priority.
	
	//if possibility_of_a_fire, the person is on alert
	rule belief: possibility_of_a_fire new_desire: on_alert strength: 50;
	
	//for most people, a fire means the want to escape. 
	//These rule will change for different personnalities
	rule belief: there_s_a_fire new_desire: escape strength: 100;
	rule belief: there_s_a_fire new_desire: on_alert strength: 100;
	rule belief: there_s_a_fire new_desire: im_in_danger strength: 100;
	
	init
	{
		//Give the agent an ID number
		ids <- ids + 1;
		id <- ids;

		//If people were trained, they are better prepared and also believe more in their capacities and their plans
		//training <- trained_population ? 2 : 0;
		training <- 0;

		//The agent fear of fire will influence his psychological attributes
		risk_awareness <- training + fear_of_fire; //increases awareness
		motivation <- training + fear_of_fire; //increases motivation 
		knowledge <- training - fear_of_fire; //decreases knowledge because of panic

		//These features will be different for each category of person (firefighter, police, residents and their subspecies
		
		do add_desire(stay_alive);

	}
	
	////////////////////////////////
	// Perception
	//	At each iteration, the agent has perceptions to do. 
	
	//Is there a fire or possibilities of fires ?
	//Am I in danger?
	//Am I able to defend? (do i have means to) if not -> escape
	//Should I call for help?
	//Should I defend my house / work place?
	//Should I try to escape?

	
	//Am I in danger?
	perceive target:self {
		
		if(has_belief(there_s_a_fire) and fear_of_fire)
		{
			do add_desire(escape);
		}
//		if(risk_awareness > 0){
//			do add_belief(there_s_a_fire);
//		}
	}
	
	
	//Perceives a fire
	perceive target:fireArea in: 50 {
		
//		do myself.add_belief(there_s_a_fire);
//do myself.add_belief(myself.there_s_a_fire);
		
	}
	
	plan escape intention: escape {
	}
	
	action get_closest_safe_place
	{

	// On recherche l'issue la plus proche (quitter la ville ou aller dans un bunker)
		float dist_to_closest_bunker;
		float dist_to_closest_exit;
//		building closest_bunker;
//		city_exit closest_exit;
//		if (nb_bunker > 0)
//		{
////			closest_bunker <- (building where (each.bunker) closest_to location);
////			dist_to_closest_bunker <- closest_bunker distance_to location;
//		}
//
//		if (nb_exit > 0)
//		{
////			closest_exit <- city_exit closest_to location;
////			dist_to_closest_exit <- closest_exit distance_to location;
//		}

//		if (dist_to_closest_bunker < dist_to_closest_exit and closest_bunker != nil)
//		{
//			return closest_bunker;
//		} else
//		{
//			if (closest_exit != nil)
//			{
//				return closest_exit;
//			}
//
//		}

		// Si aucun sortie trouvée, on renvois 
		return agent(nil);
	}
	


	action getBeliefProbability (predicate belief) {}
	
	action saveBeliefProbability (predicate belief, int probabilityValue) {}
	
	action incrementNumberOfOccurrences (predicate information) {}
	
	action getAcquiredInfoOccurrences(predicate information) {}
	
	action acquireBelief(predicate belief, int probabilityValue) {}
	
	action dramaticallyIncreaseBeliefProbability (predicate belief, int probabilityValue) {}
	
	action decreaseBeliefProbability (predicate belief, int probabilityValue) {}
	
	

	//Algorithm 1 Pseudo-code for the Neglect of Probability bias
	action neglectOfProbability (predicate belief, int perceivedProbability)
	{
//		ancientBeliefProbability ← getBeliefProbability (info)
//		newBeliefProbability ← ancientBeliefProbability + perceivedProbability
//		if newBeliefProbability > 100 then
//		newBeliefProbability ← 100
//		end if
//		if newBeliefProbability is small and consequences are not perceived to be dire and consequences are not
//		perceived to be extremely favourable then
//		newBeliefProbability ← 0
//		else if beliefProbability is small and (consequences are perceived to be dire or consequences are perceived
//		to be extremely favourable) then
//		newBeliefProbability ← dramaticallyIncraseBeliefProbability (info, newBeliefProbability)
//		else # newBeliefProbability is medium or high
//		newBeliefProbability ← decreaseBeliefProbability (info, newBeliefProbability)
//		end if
//		saveBeliefProbability (info, newBeliefProbability)
//		end procedure
	}
	
	
}