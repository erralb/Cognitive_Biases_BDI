/**
* Name: CognitiveBiasesNew
* Author: Pierre Blarre
*/

model CognitiveBiasesNew

species person control: simple_bdi
{
	float risk_awareness <- 3.0;
	
	bool has_perceived_smoke <- false;
	bool has_perceived_fire <- false;

	//Whether the agent's choices will be influenced or not by the cognitive biases algorithms
	bool neglect_of_probability_cb_influence <- false;
	bool semmelweis_reflex_cb_influence <- false;
	bool illusory_truth_effect_cb_influence <- false;

	float probability_to_react <- 0.70;
	int nb_of_warning_msg <- 0;
	int cognitive_biases_influence_occurence <- 0;
	int cb_nob_occurences <- 0;
	int cb_iot_occurences <- 0;
	int cb_sr_occurences <- 0;
	
	predicate no_danger_belief <- new_predicate("no_danger_belief",true);
	predicate potential_danger_belief <- new_predicate("potential_danger_belief",true);
	predicate immediate_danger_belief <- new_predicate("immediate_danger_belief",true);
	predicate risk_of_fires_today <- new_predicate("risk_of_fire",true);
	predicate can_defend_belief <- new_predicate("can_defend_belief",true);
	predicate i_can_escape <- new_predicate("i_can_escape",true); 

	//For neglect of probability
	float small_probability <- 0.2;
	float medium_high_probability <- 0.6;
	float risk_awareness_average <- 3.0;
	
	//Cognitive Bias : Neglect of probability
	//Will influence the agent's belief's strength
	action neglect_of_probability(predicate beliefName, float perceivedProbability)
	{
		//TODO Should i do that or not?? If yes should I add it to the end of the algorithm?
		//if(!has_belief(beliefName)) { do add_belief(beliefName, probability_to_react);}
		
		bool probabilityHasChanged <- false;
		
		if(has_belief(beliefName)) //check if 
		{
			cb_nob_occurences <- cb_nob_occurences + 1; //count occurences
			
			float ancientBeliefProbability <- get_belief(beliefName).strength ; //get ancient belief strength
			float newBeliefProbability <- (ancientBeliefProbability + perceivedProbability > 100) ? 100.0 : ancientBeliefProbability + perceivedProbability; //get new beliefStrengh (cannot go over 100)
			
			float increasedProbability <- newBeliefProbability; //just for readability
			float decreasedProbability <- ancientBeliefProbability - perceivedProbability;
			
			//1 - ignore what is unlikely to happen, even if it's happening
            //1 - if newBeliefProbability is small and consequences are not perceived to be dire and consequences are not perceived to be extremely favourable
			if( newBeliefProbability < small_probability and risk_awareness < risk_awareness_average and !has_belief(immediate_danger_belief) )
			{
				do remove_all_beliefs(beliefName); //stop believing
				probabilityHasChanged <- true;
			}
			//2 - not likely to happen, but I desire/dread it so I will react
			//2 - if beliefProbability is small and (consequences are perceived to be dire or consequences are perceived to be extremely favourable)
			else if( newBeliefProbability  < small_probability and (risk_awareness >= 3 or has_belief(immediate_danger_belief)) )
			{
				do remove_all_beliefs(beliefName);
				do add_belief(beliefName, increasedProbability); // increase the Belief Probability
				probabilityHasChanged <- true;
			}
			//3 - under-estimate a high and medium probability of something happening
			else if( newBeliefProbability  > medium_high_probability ) 
			{
				do remove_all_beliefs(beliefName);
				do add_belief(beliefName, decreasedProbability); // decrease Belief Probability
				probabilityHasChanged <- true;
			}
		}
		
		return probabilityHasChanged;
	}
	
	
	//Cognitive Bias : Semmelweis Reflex : Clinging to a belief
	//Will influence the agent's belief on no / potential / immediate danger : Should I keep my belief/certainty?
	action semmelweis_reflex(predicate beliefName)
	{
		cb_sr_occurences <- cb_sr_occurences +1;
		if( (!has_belief(beliefName) or get_belief(beliefName).strength = 0) and (nb_of_warning_msg <= 3 or (!has_perceived_smoke and !has_perceived_fire)) )
		{
			do remove_all_beliefs(beliefName);
			do add_belief(beliefName, 0.0); // is this correct ... ?
			return true;
		}
		else if ( get_belief(beliefName).strength > 0 or (nb_of_warning_msg > 3 or has_perceived_smoke or has_perceived_fire) ) //I started to believe, I should change my certainty
		{
			do remove_all_beliefs(beliefName);
//			do add_belief(beliefName, probability_to_react); // is this correct ... ?
			return false;
		}
	}
	
	//Cognitive Illusory Truth effect
	//Will re-inforce agent's belief
	// "Info" = no / potential / immediate danger
	// "nb of occurences" = received_warnings
	action illusory_truth_effect(predicate beliefName, float perceivedProbability)
	{
		cognitive_biases_influence_occurence <- cognitive_biases_influence_occurence + 1;
		cb_iot_occurences <- cb_iot_occurences + 1;
		
		if( ! has_belief(beliefName) )
		{
			do add_belief(beliefName, perceivedProbability);
			return false;
		}
		else //reinforce belief strength
		{
			float illusoryProbability <- perceivedProbability +  perceivedProbability * nb_of_warning_msg / 100;
			if(illusoryProbability > 100) { illusoryProbability <- 100.0; }
			do remove_all_beliefs(beliefName);
			do add_belief(beliefName, illusoryProbability);
			return true;
		}
		
	}
}