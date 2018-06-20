/**
* Name: FireModelBDI
* Author: Pierre Blarre
* Description: 
* Tags: 
*/

model FireModelBDI


global
{
	int displatTextSize <-4;
	int persons_in_shelter <- 0;
	init {
		create fireArea number:10;
		create shelter number: 4;
		create person number: 10;
	}
	
	reflex stop when: persons_in_shelter = 10 {
		do pause;
	}
}


species person skills: [moving] control: simple_bdi{	
	
	rgb color <- rnd_color(150);
	grille myLocation <- one_of(grille);
	int energy <- 100;
	int viewing_distance <- 6;
	bool in_shelter <- false;
	
	shelter closest_shelter;
	
	predicate relax_desire <- new_predicate("relax");
	predicate escape_desire <- new_predicate("escape");
	predicate defend_desire <- new_predicate("defend");
	
	predicate immediate_danger <- new_predicate("immediate_danger");
	
	//Definition of the variables featured in the BDI architecture.
	float plan_persistence <- 1.0; 
	float intention_persistence <- 1.0;
	bool probabilistic_choice <- false;
	
	
	init {
		location<-myLocation.location;
		closest_shelter<-(shelter closest_to location);
		do add_desire( relax_desire );
	}
	
	//The person perceives a fire at a certain distance. 
	//It records the location of the fire it observes. 
	//When it sees a fire, it stops it's intention of relaxing.
	perceive target:fireArea in: viewing_distance  when: not has_desire(escape_desire) and not has_belief(immediate_danger) {
//		focus fireLocation var:location strength:10.0;
//		focus closest_shelter var:location strength:10.0;
		ask myself{
			do add_belief(immediate_danger);
			do remove_desire(relax_desire);
			do add_desire( escape_desire );
			write (string(self) + " : I saw a fire I'm out of here");
		}
	}
	
	
//	//The rules are used to create a desire from a belief. We can specify the priority of the desire with a statement priority.
//	rule belief: new_predicate("fireLocation") new_desire: get_predicate(get_belief_with_name("fireLocation"));
//	rule belief: new_predicate("closest_shelter") new_desire: get_predicate(get_belief_with_name("closest_shelter"));
	
	//The initial plan is to relax (walk around)
	plan relaxing intention:relax_desire when: not in_shelter {
		do wander amplitude: 30 speed: 1.0;
	}
	
	//The plan to do when the intention is to relax (walk around)
	plan escaping intention: escape_desire when: not in_shelter {
		
		closest_shelter<-(shelter closest_to location);
		
		if (self distance_to closest_shelter <= 1 and ! in_shelter) {
			in_shelter <- true;
			persons_in_shelter <- persons_in_shelter + 1;
			write (string(self) + " : I'm safe in a shelter");
		}
		else
		{
			do goto(target: closest_shelter);
		}
		
	}
	
	aspect base {
		draw triangle(1) color:color rotate: 90 + heading;	
		draw circle(viewing_distance) color: color ;	
	}
		
	aspect bdi {
		draw triangle(1) color:color rotate: 90 + heading;	
		draw circle(viewing_distance) color: color empty: true;
//		draw ("B:" + length(belief_base) + ":" + belief_base) color:#black size:displatTextSize; 
//		draw ("D:" + length(desire_base) + ":" + desire_base) color:#black size:displatTextSize at:{location.x,location.y+displatTextSize}; 
//		draw ("I:" + length(intention_base) + ":" + intention_base) color:#black size:displatTextSize at:{location.x,location.y+2*displatTextSize}; 
		draw ("curIntention:" + get_current_intention()) color:#black size:displatTextSize at:{location.x,location.y+3*displatTextSize}; 	
	}
}

species fireArea{
	float size <- 1.0;
	
	init{
		grille place <- one_of(grille);
		location <- place.location;
	}
	
	aspect base {
	  draw circle(size) color: #red;
	}
	
//	reflex grow {
//		size <- size + 0.1;
//	}
}

species shelter {
	aspect default {
		draw circle(1) color: #magenta border: #black;
	}
}

grid grille width: 50 height: 50 neighbors:4 {
	rgb color <- #palegreen;
}


experiment Main type: gui {
	output {					
		display view1 { 
			grid grille lines: #black;
			species fireArea aspect:base;
			species person aspect:bdi;
			species shelter aspect:default;
	//			species waterArea aspect:base;
	//			species firefighter aspect: bdi;
			}
	}

}
	