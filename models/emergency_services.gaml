/**
* Name: Emergency Services
* 
* Author: Sofiane Sillali, Thomas Artigue, Pierre Blarre
* 
* Description: Firefighters and Policemen species
* 
* We could probably add ambulances. Right now the police is helping evacuating people
* 
*/
model Bushfires_BDI_Cognitive_Biases

import "main.gaml"

global
{
	list<resident> residents_who_have_asked_help <- nil;
	list<resident> people_to_warn <- nil update: every_resident_alive where (!each.evacuating and !each.on_alert and !each.warned and !each.is_escorted and !each.in_safe_place);
}

species firefighters parent: people
{
	float fighting_distance <- 10 # m;
	bool injured <- false;
	
	//Beliefs
	predicate no_fire <- new_predicate("no_fire",true);
	predicate possible_fire <- new_predicate("possible_fire",true);
	predicate sure_fire <- new_predicate("sure_fire",true);
	
	//Desires
	predicate recover_desire <- new_predicate("rest_desire",true);
	predicate fighting_desire <- new_predicate("go_fighting_desire",true);
	predicate stop_fighting_desire <- new_predicate("stopfighting_desire",true);
	predicate watch_desire <- new_predicate("watch_desire",true);
	predicate reinforcements_desire <- new_predicate("watch_desire",true);

	init
	{
		speed <- rnd(20.0, 25.0) # km / # h;
		energy <- rnd(20000, 25500); // supermen :-)
		color <- # red;
		at_home <- true;
		work <- one_of(building where (each.fire_station)); //They're at a firestation by default

		if (tactical_firefighters) //option to improve firefighters efficency - Their home will be close to stations or city exists, thus improving reaction time
		{
			home <- building where (!each.bunker and !each.fire_station and !each.police_station) closest_to one_of(city_exit);
		} 
		else
		{
			home <- one_of(building where (!each.bunker and !each.fire_station and !each.police_station));
		}

		location <- any_location_in(home);
		
		if (length(firefighters where each.on_alert) > 0) { on_alert <- true; }
	}

	reflex color { color <- rgb(energy / 100, 0, 0); } //color is changing when injured

//	plan recover intention: recover_desire priority 5
//	when:
//	finished_when:
//	{
//		
//	}

	// If hurt (energy below 1000) then it will go back to the station to get healed
	reflex health when: alive and !injured and energy < 1000
	{
		injured <- true;
	}

	// Receive fire alert
	reflex recieve_call when: !(empty(proposes))
	{
		message info <- proposes at 0;
		if (info.contents[0] = "There's a fire" and !on_alert)
		{
			write ("Fireman called received : "+info.contents[0]);
			do accept_proposal(message: info, contents: ['OK!']);
			on_alert <- true;

			ask firefighters { on_alert <- true; }
		}
	}

	// Stop fighting when fire is out
	reflex stop_fighting when: fire_size <= 0 and alive and (go_fighting or fighting_fire) 
	{
		if (first(firefighters where each.alive) = self)
		{
			do save_result; //save results
			do_pause <- true; //stop experiment
			
			do send_msg(list(policemen where each.alive), every_resident_alive, "Fires extinguished"); //End fire alert
			
			if(show_firefighters_messages) { status("Fires extinguished"); }
		}

		go_fighting <- false;
		fighting_fire <- false;
		at_home <- false;
		at_work <- false;
		on_alert <- false;
		evacution_city_reported <- false;
	}

	// Go to closest fire
	reflex go_fighting_fire when: on_alert and alive and !fighting_fire and !injured
	{
		if ((cycle + id) mod 10 = 0)
		{
			// Search for building on fire
			plot p_to_fight <- (plot where (each.is_building and each.burning)) closest_to self;

			// If no building is burning, get closest burning plot
			if (p_to_fight = nil)
			{
				p_to_fight <- (plot where (each.burning)) closest_to self;
			}

			if (p_to_fight != nil)
			{
				go_fighting <- true;
				target <- point(p_to_fight);
				if (location distance_to target < fighting_distance) //if close enough to fight (throw water)
				{
					fighting_fire <- true;
				}
			}
		}

		if (target != nil) { do goto target: target on: road_network; }
	}

	// Fight the fire
	reflex fight_fire when: on_alert and alive and fighting_fire and !injured
	{
		if ((cycle + id) mod 20 = 0)
		{
			//find closest burning plot
			plot p_in_fire <- (plot where (each.is_building and each.burning)) closest_to self;
			if (p_in_fire = nil) { p_in_fire <- (plot where (each.burning)) closest_to self; }

			if (p_in_fire != nil)
			{
				// Get closest plot to fire that isn't burning
				plot p_to_fight <- plot where (!each.burning and each.burning_capacity > 0 and each.heat >= 0) closest_to p_in_fire;
				
				// If plot is nil or to far away we water the fire directly
				p_to_fight <- ((p_to_fight != nil) and (self distance_to p_to_fight < 20)) ? p_to_fight : p_in_fire;
				if p_to_fight != nil
				{
					//The fighting capacity is calculated regarding the firefighter energy mixed with random values
					//The less energy he has, the less fighting power he has. I
					//This way it simulates the firefighter getting tired but also how a firefighter can be more effecient depending moments
					
					float figthing_power <- 20.00;
					if ( energy >= 15000 and energy < 20000 ) { figthing_power <- figthing_power - (energy / 10000 + rnd(1, 2)); } 
					else if (energy >= 10000 and energy < 15000) { figthing_power <- figthing_power - (energy / 10000 + rnd(3, 4)); } 
					else if (energy >= 1000 and energy < 9999) { figthing_power <- figthing_power - (energy / 1000 + rnd(4, 5)); }
					
					
					// Water the fire so its heat goes down
					p_to_fight.heat <- p_to_fight.heat - figthing_power;
					if (p_to_fight.heat <= -10.0)
					{
						p_to_fight.burning <- false;
						p_to_fight.color <- # darkblue;
					}

					// Search the next burning plot to water
					target <- point(one_of(p_to_fight.neighbors where (!each.burning)));
					
					//if the next burning plot is to far, he stops fighting and must first move to the next one
					if (target != nil and location distance_to target >= fighting_distance) { fighting_fire <- false; } 
					else { location <- target; }
				}
			}
		}

		do goto target: target;
	}

	//When injured, go back to the station to recover
	reflex evacuate_to_rest when: alive and injured and !at_work
	{
		if(show_firefighters_messages) { do status("I'm injured and going back to the station to get healed"); }

		target <- any_location_in(work);
		do goto target: target on: road_network;
		if (location = target) { at_work <- true; }
	}

	// Recover
	reflex recover when: alive and injured and at_work
	{
		// recover 700hp every 5 cycles
		if ((cycle + 2) mod 5 = 0)
		{
			energy <- energy + 700;
			injured <- energy > 20000 ? false : true; // enough recovery? -> go back on the field
		}
	}

	// Fire observation in order to trigger city evacuation if the fires are incontrollables
	reflex watching_fire when: on_alert and alive and fire_size > 0 and (cycle mod 20 = 0)
	{
		if (fire_size > fire_uncontrollable and !evacution_city_reported and first(firefighters where each.alive) = self)
		{
			do send_msg(policemen where each.alive, every_resident_alive, 'General evacuation required');
			evacution_city_reported <- true;
		}
	}

	// IF tactical_firefighters option is true, call for reinforcments (create 10 new firefighters) every 150 cycles
	reflex tactical_attitude when: tactical_firefighters and alive and on_alert and fire_size > 0 and ((cycle + id) mod 150 = 0) 
	{
		if (fire_size > fire_uncontrollable and first(firefighters where each.alive) = self)
		{
			write string(self) + " : Incontrollable fires, we need reinforcements";
			create firefighters number: 10;
		}
	}
}


species policemen parent: people
{
	bool escorting <- false;
	resident escorted_res <- nil;
	resident resident_to_help <- nil;

	init
	{
//		speed <- rnd(20.0, 25.0) # km / # h;
		speed <- 50 # km / # h;
		energy <- rnd(2000, 2550);
		
		color <- # blue;
		home <- one_of(building where (!each.bunker and !each.fire_station and !each.police_station));
		location <- any_location_in(home);
		at_home <- true;
		work <- one_of(building where (each.police_station));    

		//TODO: change to real BDI
		desires <- [protect];
		intention <- desires[0];
		
		//We consider police to be highly motivated, aware of the risks and having knowledge of crisis situation management
		motivation <- max([0, rnd(4, 5) + motivation]);
		risk_awareness <- max([0, rnd(4, 5) + risk_awareness]);
		knowledge <- max([0, rnd(4, 5) + knowledge]);
	}

	reflex color { color <- rgb(0, 0, energy); } //color is changing when injured

	reflex receive_message when: !(empty(proposes))
	{
		message info <- proposes at 0;
		string msg <- info.contents[0];

		if (msg contains "Fires extinguished") //Terminate fire alert
		{
			do accept_proposal(message: info, contents: ['OK!']);
			if (first(policemen where each.alive) = self) { do send_msg(list(every_resident_alive), nil, "Fires extinguished"); }
			on_alert <- false;
			warning_sent <- false;
		}

		if (msg contains "General evacuation required") //Firefighter ask for a city evacuation
		{
			do accept_proposal(message: info, contents: ['OK!']);
			at_work <- false;
			at_home <- false;
			on_alert <- true;
			warning_sent <- true;
			target <- nil;
			resident_to_help <- nil;

			if (first(policemen where each.alive) = self) //pick a policeman and make him send the alert
			{
				if(show_police_messages) { do status("Police is asking for general evacuation"); }
				do send_msg(every_resident_alive, nil, 'Alert for Residents : Go to shelter');
			}
		}
	}

	// Every evacuation_reminder_cycle value,  send the alert to the residents once more
	reflex inform_people when: on_alert and alive and fire_size > fire_uncontrollable and (cycle mod evacuation_reminder_cycle = 0)
	{
		if (first(policemen where each.alive) = self)
		{
			if(show_police_messages) { do status("Evacuation reminder"); }
			do send_msg(every_resident_alive where ( !each.in_safe_place and !each.warned), nil, 'Alert for Residents : Go to shelter');
		}
	}

	//While on alert, policemen will go door to door to alert residents, and if needs be escort people to safety
	reflex evacuate_resident when: on_alert and alive and !escorting and intention = protect //Todo change to BDI plan
	{
		//find resident_to_help
		if ((cycle + 1) mod 30 = 0)
		{
			if (length(residents_who_have_asked_help) > 0) //first go help residents who explicitly asked for help (isolated_and_vulnerable)
			{
				resident_to_help <- residents_who_have_asked_help closest_to self; //find closest resident - should it be organized as a FIFO stack? (First people called first helped)
				if(show_police_messages) { do status("I'm going to help " + resident_to_help); }
				remove resident_to_help from: residents_who_have_asked_help;
			} 
			else if (length(people_to_warn) > 0) //this is dodgy, because they cannot know who hasn't been warned. It should just be a door to door thing to check on people or driving around "making noise" to give the alert
			{
				resident_to_help <- people_to_warn closest_to self;
				remove resident_to_help from: people_to_warn;
				if(show_police_messages) { do status(" : I'm going to help " + resident_to_help); }
			}
		}

		if (resident_to_help != nil)
		{
			if (bool(go_to(resident_to_help))) //go to resident's location
			{
				if (string(resident_to_help) contains "isolated_and_vulnerable") //if isolated_and_vulnerable -> must escort
				{
					speed <- speed - 3; // escorting reduces speed
					escape_target <- get_closest_safe_place();
					escorting <- true;
					resident_to_help.is_escorted <- true;
					resident_to_help.on_alert <- true;
					escorted_res <- resident_to_help;
					remove resident_to_help from: residents_who_have_asked_help;
					if(show_police_messages) { do status("I'm escorting " + escorted_res + " to " + escape_target); }
				} 
				else //try to convice resident to evacuate
				{
					if (flip(0.7)) //70% of chance to convice him. TODO: should be parametrized and influence by cognitive biases
					{
						ask(resident_to_help)
						{
							do add_belief(immediate_danger_belief);
							warned <- true;
							on_alert <- true;
							evacuating <- true;
							speed <- speed + motivation;
						}
						
						if(show_police_messages) { do status("I conviced the resident he should evacuate"); }
						
					} 
					else
					{
						resident_to_help.warned <- true;
						if(show_police_messages) { do status("I warned the resident but could not convince him he should to evacuate"); }
					}

					resident_to_help <- nil;
				}

			}

		}
		else //No one to help? I'm going into shelter
		{
			escape_target <- escape_target = nil ? get_closest_safe_place() : escape_target;
			if (bool(go_to(agent(escape_target))))
			{
				at_home <- false;
				at_work <- false;
				in_safe_place <- true;
			}
		}
	}

	// Si je suis en train d'escorter une personne isolé
	reflex escorting_resident when: escorting and alive and on_alert and intention = protect //TODO change to BDI plan
	{
		if (bool(go_to(escape_target)))
		{
			ask(escorted_res)
			{
				in_safe_place <- true;
				is_escorted <- false;
				location <- target;
			}
			escorting <- false;
			speed <- speed + 3;
			target <- nil;
			escorted_res <- nil;
			resident_to_help <- nil;
			
		} else
		{
			if (!escorted_res.alive) //if he dead, abandon him and find a new target to help. This is mean but!
			{
				escorting <- false;
				escorted_res <- nil;
				speed <- speed + 3;
				target <- nil;
				resident_to_help <- nil;
			}
			else
			{
				escorted_res.location <- { location.x + 3, location.y }; //make resident follow the policeman
			}
		}

		//every two cycles, check if I'm taking a safe escape route (regarding my knowledge)
		if (cycle mod 2 = 0) { do react_to_danger(check_if_danger_is_near()); }

	}
}
