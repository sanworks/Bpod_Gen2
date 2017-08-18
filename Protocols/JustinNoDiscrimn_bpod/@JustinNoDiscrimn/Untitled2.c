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

unsigned curr_state=40;

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

void tick_func(void){

	/*STATE MATRIX CODE */

	curr_state = state();

	if (curr_state == 40) {
			logValue("entered_state_40", 1.0); /* Useful time stamp. */
			forceJumpToState(41, 2); 
	}
	
	
    /*state 60 is last bitcode state*/
	if (curr_state == 60) { 
		forceJumpToState(61, 3);
		curr_state = 61;
	}
	


	if (curr_state == 61) {

		forceJumpToState(62, 4);
		triggerSound(0, 3);
		curr_state = 62;

	}



	if (curr_state == 62) {

		forceJumpToState(63, 5);
		triggerSound(0, 4);
		curr_state = 63;

	}



	if (curr_state == 63) {

		forceJumpToState(64, 6);
		triggerSound(0, 5);
		curr_state = 64;

	}



	if (curr_state == 64) {

		forceJumpToState(65, 7);  

		curr_state = 65;

	}


	if (curr_state == 65) {

		forceJumpToState(66, 8); 

		curr_state=66;

	}


	if (curr_state == 66) {

		forceJumpToState(67, 9); 

		curr_state = 67;

	}

	if (curr_state == 67) {

		forceJumpToState(68, 10);
		
		curr_state=68;

	}


	if (curr_state == 68) {

		forceJumpToState(69, 11);

		curr_state=69;

	}


	if (curr_state == 69) {

		forceJumpToState(70, 12);	

		curr_state=70;

	}

	if (curr_state == 70 ) { 
		forceJumpToState(71, 13); 
		curr_state = 71;

	}



	if (curr_state == 71) {

		forceJumpToState(72, 14);	

		curr_state=72;

	}

	if (curr_state == 72 ) {

		forceJumpToState(73, 15); 

		curr_state=73;

	}


	if (curr_state == 73 ) {

		forceJumpToState(74, 16);

		curr_state=74;

	}


	if (curr_state == 74 ) {

		forceJumpToState(75, 17); 
		curr_state=75;

	}

	if (curr_state == 75 ) {

		forceJumpToState(76, 18); 

		curr_state=76;

	}


	if (curr_state==76) {
		
		forceJumpToState(77, 19);	

		curr_state=77;

	}

}

/*STATE EXIT FUNCTIONS*/

void exit_state_67(void) {

}

/*STATE ENTRY FUNCTIONS*/
void enter_state_40(void) {
	
}

void enter_state_61(void) {

}	

void enter_state_62(void) {
}

void enter_state_63(void) {
}	

void enter_state_64(void) {

}	

void enter_state_65(void) {

}

void enter_state_66(void) {
	
}

void enter_state_67(void) {

}


void enter_state_68(void) {

}

void enter_state_69(void) {

}

void enter_state_70(void) {

 }

void enter_state_71(void) {

}

void enter_state_72(void) {

}

void enter_state_73(void) {

}


void enter_state_74(void) {

}

void enter_state_75(void) {

}

void enter_state_76(void) {

}

/*INIT FUNCTION*/

void init_func(void){

}


TRISTATE thresh_func(int chan, double v){

	if (chan == 0 || chan == 1) { /* Lickport input channels = hardware channels 0 and 1*/

		/*if (v >= 4.0) return POSITIVE;  /* if above 4.0 V, above threshold */

		/*if (v <= 3.0) return NEGATIVE;  /* if below 3.0, below threshold */



		return NEUTRAL; /* otherwise unsure, so no change */

	} else {

		return NEUTRAL; /* Do not allow "beam-break" events on non-lickport channel */

	}

}
