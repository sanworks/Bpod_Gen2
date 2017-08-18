extern double sqrt(double);
extern unsigned state();
extern void logValue(const char *varname, double val);
extern int forceJumpToState(unsigned state, int event_id_for_history);
extern void triggerSchedWave(unsigned wave_id);
extern double readAI(unsigned chan);
extern int writeDIO(unsigned chan, unsigned bitval);
extern int writeAO(unsigned chan, double voltage);
extern int bypassDOut(unsigned bitmask);
extern void triggerSound(unsigned card, unsigned snd);
extern void untriggerSound(unsigned card, unsigned snd);
TRISTATE thresh_func(int chan, double v);
void tick_func(void);
void init_func(void);
void start_trial_func(void);
/********************************************************************************
 * TEXT BELOW WILL BE FIND-REPLACED FROM MATLAB PRIOR TO SetStateProgram()
 ********************************************************************************/
/*THRESHOLD SECTION*/
double touch_thresh = XXX;
/*TIMING SECTION*/
double pre_pole_delay = XXX;
double resonance_delay = XXX;
double answer_delay = XXX;
double delay_period = XXX;
double sample_period = XXX;
double answer_period = XXX;
double mean_window_length = XXX;
double vVect1[XXX];
double vVect2[XXX];
double log_analog_freq = XXX;
/*SOUNDS SECTION*/
int go_cue = XXX;
int fail_cue = XXX;
int pole_cue = XXX;
/********************************************************************************
 * END: FIND-REPLACE TEXT
 ********************************************************************************/
double mean1 = 0;
double last_mean1 = 0;
double mean2 = 0;
double last_mean2 = 0;

int first_touch_time = 0;
int pole_up_time = 0;
int rew_cue_time = 0;
int go_cue_time = 0;
int pole_cue_time = 0;

int rew_cue_flag = 0;
int touch_state_flag = 0; 

int log_analog_window_counter = 1;
int cycle_counter = 1;
int mean_window_counter = 1;
int debug_counter = 1;
int t = 1;

int v_state;
int v_state_last = 0;
int v_state1;
int v_state1_last = 0;
int v_state2;
int v_state2_last = 0;

unsigned curr_state;
unsigned last_state = 40;

const unsigned lick_left = 0; /* Analog input channel for left lick port. */
const unsigned touch_detector_ai_chan1 = 7; /* Analog input channel for axial sensor. */
const unsigned touch_detector_ai_chan2 = 9; /* Analog input channel for radial sensor. */

/*TICK FUNCTION TO RUN EACH CYCLE*/
void tick_func(void){
	
	double v1;
	double v2;
	unsigned curr_state = state();
	unsigned i;
	
	/*compute sum f squares of voltages from LAST cycle*/
	double sum1sq = 0;
	double sum2sq = 0;
	for (i = 0; i < mean_window_length; i++) {
		sum1sq = sum1sq + (vVect1[i]*vVect1[i]);
		sum2sq = sum2sq + (vVect2[i]*vVect1[i]);
	}
	
	/*now update the voltage readings*/
	v1 = readAI(touch_detector_ai_chan1);
	v2 = readAI(touch_detector_ai_chan2);
	
	/*fill the circ. buffers*/
	if (mean_window_counter > mean_window_length) {
		mean_window_counter  = 0;
		vVect1[mean_window_length-1] = v1;
		vVect2[mean_window_length-1] = v2;    
	} else {
		vVect1[mean_window_counter-1] = v1;
		vVect2[mean_window_counter-1] = v2;
	}
	
	double sum1 = 0;
	double sum2 = 0;	
	
	/*compute mean of voltages*/
	for (i = 0; i < mean_window_length; i++) {
		sum1 = sum1 + vVect1[i];
		sum2 = sum2 + vVect2[i];
	}
	mean1 = sum1/mean_window_length;
	mean2 = sum2/mean_window_length;
	
	double absdiff1 = sqrt((mean1 - last_mean1)*(mean1 - last_mean1));
	double absdiff2 = sqrt((mean2 - last_mean2)*(mean2 - last_mean2));

	/*thresholding for sensor 1 sensors*/
	if (absdiff1 > touch_thresh) {
		v_state = 1;
		if (log_analong_window_counter == log_analog_freq) { /*if there is touching, log it with n ms precision*/
			logValue("touch_trig_on", 1.0); 
			log_analog_window_counter = 0;
		}
	}
	else {
		v_state = 0;
	}

	/*STATE MATRIX CODE */

	/*state 40 is just an entry func*/
	
    /*state 41 is a pre-pole delay time*/
	if (curr_state == 41) { 
		if  (cycle_counter >= pre_pole_delay) {
			forceJumpToState(42, 2);
			curr_state = 42;
		}
	}

	/*state 42 is just an entry function*/
	
	/*state 43 is a hard delay for sensor resonance timeout*/
	if (curr_state == 43) { 
		if (cycle_counter - pole_up_time >= resonance_delay) {/*at ^k sampling, should be 500ms delay*/
			forceJumpToState(44, 4);
			curr_state = 44;
		}
	}

	/*state 44 is the variable delay period*/
	if (curr_state == 44) { 
		if (cycle_counter - pole_cue_time >= delay_period) {  /*if delay period is over...*/
			forceJumpToState(45, 5);  /*sound go cue and move to sample period*/
			/*exit func takes care of go cue here*/
			curr_state = 45;
		} else {
			if (v_state == 1 && v_state_last != 1) { 
				forceJumpToState(50, 10);  /*touched during the delay, timeout*/
				/*entry func takes care of fail cue here*/
				curr_state = 50;
			} 
		}
	}
	
	/*state 45 is the sampling period*/
	if (curr_state == 45) {
		if (cycle_counter - pole_up_time < sample_period) { /*if we have not reached the end of the sample period*/
			if (touch_state_flag == 1) { /*if there has been a touch*/
				forceJumpToState(46, 6); /*go to answer delay*/
				curr_state = 46;
			} 
		} else if (cycle_counter - pole_up_time >= sample_period) { /*end of sampling period reached*/
			bypassDOut(0); /*remove the pole*/
				forceJumpToState(49, 9); /*go to miss state*/
				curr_state = 49;
		}
	}
	
	/*state 46 is a variable delay before the reward cue is played and answer period entered*/
	if (curr_state == 46) {
		if ((cycle_counter - first_touch_time) >= answer_delay && rew_cue_flag == 0) {
			forceJumpToState(47, 7); /*go to answer period*/
			curr_state = 47;
			rew_cue_time = cycle_counter;
			rew_cue_flag = 1;
		}
	}

	cycle_counter = cycle_counter + 1;
	mean_window_counter = mean_window_counter + 1;	
	log_analong_window_counter = log_analong_window_counter + 1;
	
	/*DEBUGGING SECTION*/
	/*
	if (debugCounter == 12) {
		logValue("absdiff1",absdiff1);
		logValue("cycCounter2",cycCounter2);
		debugCounter = 0;
	}
	*/
	debugCounter = debugCounter + 1;	
	
	v_state1_last = v_state1;
	v_state2_last = v_state2;
	v_state_last = v_state;
	last_mean1 = mean1;
	last_mean2 = mean2;
}

/*START TRIAL FUNCTION*/
void start_trial_func(void) {	
}

/*INIT FUNCTION*/
void init_func(void) {
}

/*STATE ENTRY FUNCTIONS*/
/*state 40 sends triggers, plays pole cue, and ends*/
void enter_state_40(void){
	logValue("entered_state_40", 1.0); /* Useful time stamp. */
	bypassDOut(1024); /*send the trigger*/
	bypassDOut(0);
	triggerSound(0, pole_cue); /*trigger the pole cue*/
	pole_cue_time = cycle_counter;
	forceJumpToState(41, 1); /*state 41 is pre-pole time*/
	curr_state = 41;
}

/*state 41 engages in a variable pre-pole delay, then ends*/
void enter_state_41(void){
	pre_pole_time = cycle_counter;
	logValue("entered_state_41", 1.0); /* Useful time stamp. */
}	

/*state 42 triggers the pole up, flags the time, updates logs/states*/
void enter_state_42(void){
	pole_up_time = cycle_counter;
	logValue("entered_state_42", 1.0); 
	bypassDOut(64); /*trigger the pole*/
	forceJumpToState(43, 3);
	curr_state = 43;
}

/*state 43 entry triggers a log write, updates current state*/
void enter_state_43(void){
	logValue("entered_state_43", 1.0); 
}	

/*state 44 entry triggers a log write, updates current state*/
void enter_state_44(void){
	logValue("entered_state_43", 1.0); 
}	

/*state 45 entry triggers the go cue and a log write, updates current state*/
void enter_state_45(void){
	triggerSound(0, go_cue); /*trigger the pole cue*/
	logValue("entered_state_45", 1.0); 
}

/*state 46 is a delay period entered after the first touch*/
void enter_state_46(void){
	logValue("entered_state_46", 1.0);
	first_touch_time = cycle_counter;
}

/*state 47 is the answer period*/
void enter_state_47(void){
	logValue("entered_state_47", 1.0);
	triggerSound(0, rew_cue); /*play reward wave*/
}

/*state 48 is hit*/
void enter_state_48(void){
	logValue("entered_state_48", 1.0);
	forceJumpToState(51, 11); /*go to final state*/
	logValue("entered_state_51", 1.0);
}

/*state 49 is miss*/
void enter_state_49(void){
	logValue("entered_state_49", 1.0);
	forceJumpToState(51, 11); /*go to final state*/
	logValue("entered_state_51", 1.0);
}

/*state 50 is the timeout state*/
void enter_state_50(void){
	logValue("entered_state_50", 1.0);
	triggerSound(0, noise_cue); /*play noise wave*/
	forceJumpToState(51, 11); //*go to final state*/
	logValue("entered_state_51", 1.0);
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
        if (v >= 4.0) return POSITIVE;  /* if above 4.0 V, above threshold */
        if (v <= 3.0) return NEGATIVE;  /* if below 3.0, below threshold */
        return NEUTRAL; /* otherwise unsure, so no change */
    }
    else {
        return NEUTRAL; /* Do not allow "beam-break" events on non-lickport channel */
    }
}
