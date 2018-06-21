/**
* Name: CognitiveBiases
* Author: Pierre Blarre - based on : The role of cognitive biases in reactions to bushfires - by Maël Arnaud, Carole Adam, Julie dugdale - May 2017
* 
* Description: GAML Implementation of 3 cognitive biases, cannot be used as such, must be implemented in other species
*/

model CognitiveBiases

species person control: simple_bdi
{
	
	// Psychological attributes
	int motivation; //higher motivation increases speed and defense capacity
	int risk_awareness; //higher awareness will increase response to messages and escape_intention
	int knowledge; //level of knowledge crisis management and technical abilities -> should influend cognitive biases
	int training; //level of training will influence the three previous values
	int fear_of_fire <- rnd(0, 1); //will influence decision making	

	//Cognitive Biases
	//Will be about the belief the person thinks it's in danger or not
	
	//Around the time of the Black Saturday, the risk of bushfire is high
	//We assume the agent is totally unsure if there's a fire or not
	
	//Whether the agent's choices will be influenced or not by the cognitive biases algorithms
	bool neglect_of_probability_cb_influence <- false;
	bool semmelweis_reflex_cb_influence <- false;
	bool illusory_truth_effect_cb_influence <- false;

	float probability_to_react <- 0.70;
	int nb_of_warning_msg <- 0;
	
	//Cognitive Bias : Neglect of probability
	//Will influence the agent's decisions on going home or escaping
	action neglect_of_probability(float perceivedProbability)
	{
		float newBeliefProbability <- probability_to_react + perceivedProbability;
		
		if (newBeliefProbability > 1) { newBeliefProbability <- 1.0; } //Cannot be over 1
		
		
		if( newBeliefProbability < 0.34 and risk_awareness <= 3 and knowledge < 3) //1 ignore what is unlikely to happen, even if it's happening
		{
			newBeliefProbability <- 0.0;
		}
		else if( newBeliefProbability  < 0.34 and (risk_awareness > 3 or knowledge < 3) )//2 not likely to happen, but I desire/dread it so I will react
		{
			newBeliefProbability <- 0.9;
		}
		else if( newBeliefProbability  > 0.34 ) //3 under-estimate a high and medium probability of something happening
		{
			newBeliefProbability <- 0.2;
		}
		
		probability_to_react <- newBeliefProbability;
	}
	
	
	//Cognitive Bias : Semmelweis Reflex : Clinging to a belief
	//Will influence the agent's belief on no / potential / immediate danger : Should I keep my belief/certainty?
	action semmelweis_reflex(float beliefProbability)
	{
		if (beliefProbability = 0 and nb_of_warning_msg < 2) //he does not believe the danger will occur, I keep my belief 
		{
			return true;
		}
		else if (beliefProbability > 0 and nb_of_warning_msg > 2) //I started to believe, I should change my certainty
		{
			return false;
		}
	}
	
	
	//Cognitive Illusory Truth effect
	//Will re-inforce agent's belief
	// "beliefName" = no / potential / immediate danger
	// "nb of occurences" = received_warnings
	action illusory_truth_effect(predicate beliefName, float perceivedProbability)
	{
		if( ! has_belief(beliefName) )
		{
			do add_belief(beliefName, perceivedProbability);
		}
		else //reinforce belief strength
		{
			float illusoryProbability <- perceivedProbability * nb_of_warning_msg;
			do remove_belief(beliefName);
			do add_belief(beliefName, illusoryProbability);
		}
	}
}
