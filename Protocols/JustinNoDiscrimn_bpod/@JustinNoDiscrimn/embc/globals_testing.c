
void tick_func(void);
extern void triggerSchedWave(unsigned wave_id);
extern void logValue(const char *varname, double val);
extern void triggerSound(unsigned card, unsigned snd);
extern void untriggerSound(unsigned card, unsigned snd);
extern double ceil(double);
extern double floor(double);

/*extern struct EmbCTransition transition()
 */
extern double sqrt(double);
extern unsigned state();
extern int forceJumpToState(unsigned state, int event_id_for_history);
extern double readAI(unsigned chan);
extern int writeDIO(unsigned chan, unsigned bitval);
extern int writeAO(unsigned chan, double voltage);
extern int bypassDOut(unsigned bitmask);

TRISTATE thresh_func(int chan, double v);
void init_func(void);
void enter_state_40(void);
void enter_state_61(void);
void enter_state_62(void);
void enter_state_63(void);
void enter_state_64(void);
void enter_state_65(void);
void enter_state_66(void);
void enter_state_67(void);
void enter_state_68(void);
void enter_state_69(void);
void enter_state_70(void);
void enter_state_71(void);
void enter_state_72(void);
void enter_state_73(void);
void enter_state_74(void);
void enter_state_75(void);
void enter_state_76(void);
void exit_state_67(void);

/********************************************************************************
 * TEXT BELOW WILL BE FIND-REPLACED FROM MATLAB PRIOR TO SetStateProgram()
 ********************************************************************************/
/*THRESHOLD SECTION*/
double touch_thresh = XXX;
double touch_thresh_states[] = {XXX};
double lick_thresh = XXX;
double lick_thresh_states[] = {XXX};
double whiskvel_thresh = XXX;
double whiskvel_thresh_states[] = {XXX};
/*TIMING SECTION*/
double pre_pole_delay = XXX;
double resonance_delay = XXX;
double answer_delay = XXX;
double delay_period = XXX;
double sample_period = XXX;
double answer_period = XXX;
double drink_period = XXX;
int mean_window_length = XXX;
int median_window_length = XXX;
int baseline_length = XXX;
double vVect1[XXX];
double vVect2[XXX];
double tmpMeanVect[XXX];
double tmpMedianVect[XXX];
double vbaseVect1[XXX];
double vbaseVect2[XXX];
double log_analog_freq = XXX;
double valve_time = XXX;
/*SOUNDS SECTION*/
int go_cue = XXX;
int fail_cue = XXX;
int pole_cue = XXX;
int rew_cue = XXX;
/*STRINGS*/
char *answer_mode = XXX;
char *action_mode = XXX;
char *intfail = XXX;
char *dlyfail = XXX;
char *rspfail = XXX;
char *rspdlyfail = XXX;
char *incrspfail = XXX;
char *nxtside = XXX;
char *nxttype = XXX;
/********************************************************************************
 * END: FIND-REPLACE TEXT
 ********************************************************************************/
double mean1 = 0;
double median1 = 0;
double basemedian1 = 0;
double last_mean1 = 0;
double last_sum1 = 0;
double last_median1 = 0;
double mean2 = 0;
double last_mean2 = 0;
double last_median2 = 0;
double basemean1 = 0;
double last_basemean1 = 0;
double baseline = 0;
double real_baseline = 0;
double std1;

int first_touch_time = 0;
int num_touches = 0;
int pre_pole_time = 0;
int pole_up_time = 0;
int rew_cue_time = 0;
int go_cue_time = 0;
int pole_cue_time = 0;
int delay_period_time = 0;
int sample_period_time = 0;
int resonance_time = 0;
int answer_time = 0;
int lickport_time = 0;
int rew_time = 0;
int start_drink_time = 0;
int valve_flag = 0;
int blerg = 0;
int blerger = 0;

int rew_cue_flag = 0;
int touch_state_flag = 0; 
int delay_touch_state_flag = 0;
int hit_state_flag=0;
int miss_state_flag=0;
int cr_state_flag=0;
int fa_state_flag=0;
int final_timer=0;
int resp_flag=0;

int log_analog_window_counter = 1;
int cycle_counter = 1;
int mean_window_counter = 1;
int debug_counter = 1;
int baseline_counter = 1;

/*not v_state1,2, etc are touch sensors*/
int v_state;
int v_state_last = 0;
int v_state1;
int v_state1_last = 0;
int v_state2;
int v_state2_last = 0;
int v_state_lick;
int v_state_lick_last=0;
int v_state_whiskvel;
int v_state_whiskvel_last=0;
int lick_state_flag=0;
int whiskvel_state_flag=0;
int delay_whiskvel_state_flag=0;
int delay_lick_state_flag =0;

unsigned curr_state;
unsigned last_state = 40;

const unsigned lick_left_ai_chan = 0; /* Analog input channel for left lick port. */
/*const unsigned lick_right = 1; /* Analog input channel for left lick port. */
const unsigned touch_detector_ai_chan1 = 7; /* Analog input channel for axial sensor. */
const unsigned touch_detector_ai_chan2 = 9; /* Analog input channel for axial sensor. */
const unsigned whisker_velocity_ai = 6; /* whisker velocity from fpga. */

/*TICK FUNCTION TO RUN EACH CYCLE*/
void tick_func(void) {
	
	/*STATE MATRIX CODE */

	/*state 40 is just an entry func*/
	if (curr_state == 40) {
	
			forceJumpToState(41, 1); 
			curr_state=41;
		}

	
    /*state 60 is last bitcode state*/
	if (curr_state == 60) { 
		forceJumpToState(61, 2);
		curr_state = 61;
	}
	
    /*state 61 is a pre-pole delay time*/
	if (curr_state == 61) { 
		
			forceJumpToState(62, 3);
			curr_state = 62;
		}
	}

	/*state 62 is just an entry function*/
	
	/*state 63 is a hard delay for sensor resonance timeout*/
	if (curr_state == 63) { 
			forceJumpToState(64, 5);
			curr_state = 64;
	}

	/*state 64 is the variable delay period*/
	if (curr_state == 64) { 
		
			forceJumpToState(65, 6);  /*sound go cue and move to sample period*/
	
			curr_state = 65;
		
	}
	
	

	if (curr_state == 65) {
	
				forceJumpToState(66, 7); /*hm, problem. what to do with answer delay*/
				curr_state=66;
	
		}

		
	
	if (curr_state == 66) {
		
				forceJumpToState(67, 8); /*go to answer period*/
				curr_state = 67;
		
	}

	if (curr_state == 67) {
		
				forceJumpToState(70,11); /*go to response state, set resp_flag=1*/

	}
	
	if (curr_state == 70 || curr_state == 71){ /*response or no response states last*/

					forceJumpToState(68, 9); /*jump to valve period*/
					curr_state = 68;

	}
	
	/*-------------------------------------------*/
	/*state 68 is a fixed vale time trigger*/
	if (curr_state == 68) {
	
			bypassDOut(0);
			forceJumpToState(69, 10);
			curr_state=69;
	}

	
	if (curr_state == 69) {
		
				forceJumpToState(72, 13);	/*hit*/
	
				curr_state=74;
			}

	
	
	if (curr_state==76) {
			/*go to either miss or fa state*/
		if (miss_state_flag==1){
			forceJumpToState(73, 14);	/*miss*/
			final_timer=cycle_counter;
		}else{
			forceJumpToState(75, 16);	/*false alarm*/
			final_timer=cycle_counter;
		}
	}

	/*finally, enter into a hit/miss/fa/cr state, and count off 500ms or whatever is necessary to detect back at PokesPlot*/
	if (curr_state == 72 || curr_state == 73 || curr_state == 74 || curr_state == 75) {
		if ((cycle_counter - final_timer) > 3000) {
			bypassDOut(0);
			forceJumpToState(77, 18); /*jump to final state*/
		}
	}
  

	cycle_counter = cycle_counter + 1;
	mean_window_counter = mean_window_counter + 1;	
	log_analog_window_counter = log_analog_window_counter + 1;
	
	/*DEBUGGING SECTION*/
	
	if (debug_counter ==12) {
		/*logValue("absdiff", absdiff1);*/
		/*logValue("v_state", v_state);	*/
		debug_counter = 0;
	}
	
	debug_counter = debug_counter + 1;		
	v_state1_last = v_state1;
	v_state2_last = v_state2;
	v_state_last = v_state;
	last_mean1 = mean1;
	last_mean2 = mean2;
	last_sum1 = sum1;

}

/*STATE EXIT FUNCTIONS*/
/*exiting state 40 jumps to first bitcode state*/
/*void exit_state_40(void) {
	forceJumpToState(101, 16); 
}*/

/*exiting state 67 turns off dout bypas so matlab can trigger lick port*/
/*kind of kludgy*/
void exit_state_67(void) {
	bypassDOut(0); 
}

/*STATE ENTRY FUNCTIONS*/
/*state 40 sends triggers, plays pole cue, and ends*/
void enter_state_40(void) {

	
}

/*state 61 engages in a variable pre-pole delay, then ends*/
void enter_state_61(void) {
	pre_pole_time = cycle_counter;
	/*logValue("entered_state_61", 1.0); /* Useful time stamp. */
}	

/*state 62 triggers the pole up, flags the time, updates logs/states*/
void enter_state_62(void) {
	pole_up_time = cycle_counter;
	bypassDOut(16); /*trigger the pole*/
	forceJumpToState(63, 4);
	curr_state = 63;
	resonance_time = cycle_counter;
}

/*state 63 entry triggers a log write, updates current state*/
void enter_state_63(void) {
	/*logValue("entered_state_63", 1.0); */
}	

/*state 64 entry triggers a log write, updates current state*/
void enter_state_64(void) {
	/*logValue("entered_state_64", 1.0); */
	delay_period_time = cycle_counter;
}	

/*state 65 entry triggers the go cue and a log write, updates current state*/
void enter_state_65(void) {
	triggerSound(0, go_cue); /*trigger the go cue*/
	/*logValue("entered_state_65", 1.0);*/ 
	sample_period_time = cycle_counter;
	
}

/*state 66 is a delay period entered after the first touch*/
void enter_state_66(void) {
	/*logValue("entered_state_66", 1.0);*/
	
}

/*state 67 is the answer period*/
void enter_state_67(void) {
	/*logValue("entered_state_67", 1.0);*/
	triggerSound(0, rew_cue); /*play reward wave*/
	rew_time = cycle_counter;
}


/*state 68 is the valve opening*/
void enter_state_68(void) {
	/*logValue("entered_state_68", 1.0);*/
	valve_flag = cycle_counter;
	bypassDOut(256); /* turn the valve on*/
}

/*state 69 is the drink period*/
void enter_state_69(void) {
	/*logValue("entered_state_69", 1.0);*/
	start_drink_time = cycle_counter;
}

/*state 70 is respnse*/
void enter_state_70(void) {
	/*logValue("entered_state_70", 1.0);*/
	/*resp_flag=1;*/
 }

/*state 71 is nosresponse*/
void enter_state_71(void) {
	/*logValue("entered_state_71", 1.0);*/
	/*resp_flag=0;*/
}

/*state 76 is the punish state*/
void enter_state_76(void) {
	/*logValue("entered_state_76", 1.0);*/
	triggerSound(0, fail_cue); /*play noise wave*/
}

/*INIT FUNCTION*/
void init_func(void) {
}


/* Want to configure second analog input channel (beyond lickport channel)
* with SetInputEvents.m in order to (1)
* read in whisker position with readAI(); and (2) to record times of stimulation
* using scheduled waves event triggering. These events get recorded and made
* available to MATLAB as input events on this second channel.  We *don't* however
* want actual input events to get triggered on this channel.  Thus, we re-define
* the built-in threshold detection function in order to detect events *only* on
* the lickport channel.
*/
TRISTATE thresh_func(int chan, double v) 
{
    if (chan == 0 || chan == 1) { /* Lickport input channels = hardware channels 0 and 1*/
        /*if (v >= 4.0) return POSITIVE;  /* if above 4.0 V, above threshold */
        /*if (v <= 3.0) return NEGATIVE;  /* if below 3.0, below threshold */
        
		return NEUTRAL; /* otherwise unsure, so no change */
    }
    else {
        return NEUTRAL; /* Do not allow "beam-break" events on non-lickport channel */
    }
}
