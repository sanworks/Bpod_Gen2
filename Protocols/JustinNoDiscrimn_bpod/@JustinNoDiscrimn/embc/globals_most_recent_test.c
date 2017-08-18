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
/*double touch_thresh_high = XXX;*/
/*double touch_thresh_low = XXX;*/
/*TIMING SECTION*/
/*double pre_pole_dur = XXX;*/
/*double resonance_dur = XXX;*/
/*double delay_dur = XXX;*/
/*double sample_dur = XXX;*/
/*double answer_dur = XXX;*/
/*double timeout_dur = XXX;*/
/*double mean_window_dur = XXX;*/
/*STATES SECTION*/
/*static unsigned states_to_log_touch_fail[XXX] = {XXX}; */
/*static unsigned states_to_log_touch_succ[XXX] = {XXX}; */

/********************************************************************************
 * END: FIND-REPLACE TEXT
 ********************************************************************************/
double vVect1[10];
double vVect2[10];
double mean1 = 0;
double last_mean1 = 0;
double mean2 = 0;
double last_mean2 = 0;
double std1 = 0;
double std2 = 0;
double default_std = 0.05;

int firstTouchTime = 0;
int rewCueFlag = 0;
int rewCueTime = 0;
int touch_state_flag = 0; 
int cycCounter = 1;
int cycCounter2 = 1;
int poleTimeCounter = 1;
int debugCounter = 1;
int t = 1;
int v_state;
int v_state_last = 0;
unsigned curr_state;
unsigned last_state = 40;

/*vars for sensor 1*/
int v_state1;
int v_state1_last = 0;

/* vars for sensor 2*/
int v_state2;
int v_state2_last = 0;

struct wave_id_list { /* scheduled wave IDs  REPLACE WITH ENUM*/
	unsigned touch_onsets;
	unsigned PoleUpWave;
	unsigned cueWave;
	unsigned goWave;
	unsigned noiseWave;
	unsigned rewardWave;
	unsigned trigger;
};
struct wave_id_list wave_ids = {.touch_onsets = 0, .PoleUpWave = 1, .cueWave = 3, .goWave = 4, .noiseWave = 5, .rewardWave = 6, .trigger = 7};

struct varlog_val_list {
	double touch_trig_on;
	double touch_trig_pro_on;
	double touch_trig_ret_on;
	double touch_trig_med_on;
	double touch_trig_lat_on;
	double touch_trig_off;
	double touch_trig_pro_off;
	double touch_trig_ret_off;
	double touch_trig_med_off;
	double touch_trig_lat_off;
};
struct varlog_val_list varlog_vals = {.touch_trig_on = 1.0, .touch_trig_off = -1.0, .touch_trig_pro_on = 1.0, .touch_trig_pro_off = -1.0, .touch_trig_ret_on = 1.0, .touch_trig_ret_off = -1.0, .touch_trig_med_on = 1.0, .touch_trig_med_off = -1.0, .touch_trig_lat_on = 1.0, .touch_trig_lat_off = -1.0};

const unsigned touch_detector_ai_chan1 = 7; /* Analog input channel for axial sensor. */
const unsigned touch_detector_ai_chan2 = 9; /* Analog input channel for radial sensor. */

void tick_func(void){
	
	double v1;
	double v2;

	unsigned curr_state = state();
	unsigned i;

	int n_touch_state;
	int in_touch_state;

	/*compute sum f squares of voltages from LAST cycle*/
	double sum1sq = 0;
	/*double sum2sq = 0;*/
	for (i = 0; i < 10; i++) {
		sum1sq = sum1sq + (vVect1[i]*vVect1[i]);
		/*sum2sq = sum2sq + (vVect2[i]*vVect1[i]);*/
	}
	
	/*compute std of voltages from LAST cycle*/
	/*
	std1 = sqrt((sum1sq - last_mean1)*(sum1sq - last_mean1));
	std2 = sqrt((sum2sq - last_mean2)*(sum2sq - last_mean2));
	*/
	
	/*now update the voltage readings*/
	v1 = readAI(touch_detector_ai_chan1);
	/*
	v2 = readAI(touch_detector_ai_chan2);
	*/
	
	/*fill the circ. buffers*/
	if (cycCounter > 10) {
		cycCounter = 1;
		vVect1[cycCounter-1] = v1;
		/*
		 vVect2[cycCounter-1] = v2;
		*/ 
		  
	} else {
		vVect1[cycCounter-1] = v1;
		/*
		vVect2[cycCounter-1] = v2;
		*/
	}
	
	double sum1 = 0;
	/*
	double sum2 = 0;	
	*/
	
	/*compute mean of voltages*/
	for (i = 0; i < 10; i++) {
		sum1 = sum1 + vVect1[i];
		/*
		sum2 = sum2 + vVect2[i];
		*/
	}
	
	mean1 = sum1/10;
	/*
	mean2 = sum2/10;
	*/
	
	double absdiff1 = sqrt((mean1 - last_mean1)*(mean1 - last_mean1));
	/*
	double absdiff2 = sqrt((mean2 - last_mean2)*(mean2 - last_mean2));
	*/
	
	/* if we arent in a state where we care about touches controlling SM transitions, dont bother with touch detection code*/
	/*
	n_touch_state = sizeof(states_to_log_touch);

	for (i = 0; i <= n_touch_state - 1; i++) {
		if (curr_state == states_to_log_touch[i]) {
			in_touch_state = 1;
		}
	}
	*/
	 
	
	/*thresholding for sensor 1 sensors*/
	if (absdiff1 > 0.02) {
		v_state = 1;
		if (debugCounter == 60) { /*if there is touching, log it with 10ms precision*/
			logValue("touch_trig_on", 1.0); 
			debugCounter = 0;
		}
	}
	else {
		v_state = 0;
	}

	/*send ephus/fpga trigger, and pole cue (and bitcode?) at entry into state 40*/
	if (curr_state == 40) { 
		bypassDOut(1024); /*send the trigger*/
		bypassDOut(0);
		
		triggerSound(0, 1); /*trigger the pole cue*/
		forceJumpToState(41, 1); /*state 41 is pre-pole time*/
		curr_state = 41;
		last_state = 40;
	}
	
	
    /*wait for a variable amount of time (pre-pole delay)*/
	if (curr_state == 41) { 
		if (cycCounter2 >= 3000) {
			if (last_state == 40) {
				logValue("entered_state_41", 1.0); /* Useful time stamp. */
				last_state = 41;
				curr_state = 41;
			} else if (last_state == 41 && cycCounter2 >= 1500) {/*at ^k sampling, should be 500ms delay*/
				forceJumpToState(42, 2);
				curr_state = 42;
			}
		}
	}
		

	/*raise pole at entry into state 43*/
	if (curr_state == 42 || last_state == 41) { 
		logValue("entered_state_42", 1.0); /* Useful time stamp. */
		bypassDOut(64); /*trigger the pole*/
		poleTimeCounter = cycCounter2;
		forceJumpToState(43, 3);
		curr_state = 43;
		last_state = 42;
	}	
	
	if (curr_state == 43) { /*enfore a delay to wait for sensor resonance*/	
		if (last_state == 42) {
			logValue("entered_state_43", 1.0); /* Useful time stamp. */
			last_state = 43;
			curr_state = 43;
		} else if (cycCounter2 >= 6000) {/*at ^k sampling, should be 500ms delay*/
			forceJumpToState(44, 4);
			logValue("entered_state_44", 1.0); /* Useful time stamp. */
			curr_state = 44;
			last_state = 44;
		}
	}

	/*jump to new trial if touch during delay*/
	if (curr_state == 44) { 
		if (cycCounter2 >= 12000) {  /*if delay period is over...*/
			triggerSound(0, 11);
			forceJumpToState(45, 6);  /*sound go cue and move to sample period*/
			curr_state = 45;
		} else {
			if (v_state == 1 && v_state_last != 1) { 
				forceJumpToState(53, 5);  /*touched during the delay, timeout*/
				triggerSound(0, 12); /*play noise wave*/
				logValue("entered_state_53", 1.0);
				curr_state = 53;
			} 
		}
	}
	
	/*if touch during sampling period, proceed*/
	if (curr_state == 45) {
		if (last_state == 44) { 
			logValue("entered_state_45", 1.0); /* Useful time stamp. */
			last_state = 45;
			curr_state = 45;
		} else if (last_state == 45) {
			if (v_state == 1 && v_state_last != 1) { 
				if (touch_state_flag == 0) {
					firstTouchTime = cycCounter2;
					touch_state_flag = 1;
					/*jump to touch state*/
					forceJumpToState(46, 7);
					curr_state = 46;
					last_state = 46;
				}
			}
		}
	}
	
	/*delay before the reward cue is played */
	if ((cycCounter2 - firstTouchTime) >= 6000 && rewCueFlag == 0) {
		if (last_state == 46) { 
			triggerSound(0, 9); /*play reward wave*/
			forceJumpToState(47, 8); /*go to answer period*/
			logValue("entered_state_47", 1.0); /* Useful time stamp. */	
			curr_state = 47;
			last_state = 47;
			rewCueTime = cycCounter2;
			rewCueFlag = 1;
		}
	}
	
	/*sampling period ending control statements*/
	if (cycCounter2 - poleTimeCounter < 32000) { /*if we have not reached the end of the sample period*/
		if (cycCounter2 - rewCueTime < 6000) { /*we are still in the answer period*/
			if (touch_state_flag == 1) { /*if there has been a touch*/
				forceJumpToState(48, 9); /*go to 'hit' state*/
				/*logValue("entered_state_48", 1.0); 
				*/
				curr_state = 48;
				last_state = 47;
			} 
		} else if (cycCounter2 - rewCueTime >= 6000) { /*answer period is over, still in sample*/
			if (touch_state_flag == 1) { /*if there has been a touch*/
				forceJumpToState(48, 9); /*go to 'hit' state*/
				/*logValue("entered_state_48", 1.0); 
				*/
				curr_state = 48;
				last_state = 47;
			} else {
				if (curr_state < 49) {
					forceJumpToState(49, 10); /* go to miss state*/
					/*logValue("entered_state_49", 1.0); 
					*/
				}
			}
		}
	} else if (cycCounter2 - poleTimeCounter >= 32000) { /*end of sampling period reached*/
			
		if (curr_state == 47 || curr_state == 45) {
			bypassDOut(0); /*untrigger the pole*/	
			forceJumpToState(49, 10); /*...otherwise go to miss state*/
			curr_state = 49;
			/*logValue("entered_state_49", 1.0);*/ 
		}
	}
	
	
	/*matlab takes over here for trial finishing stuff, sicne timing doesnt matter so much*/
	cycCounter = cycCounter + 1;
	cycCounter2 = cycCounter2 + 1;	
	
	/*
	if (debugCounter == 12) {
		logValue("absdiff1",absdiff1);
		logValue("cycCounter2",cycCounter2);
		debugCounter = 0;
	}
	*/
	debugCounter = debugCounter + 1;	
	
	v_state1_last = v_state1;
	/*v_state2_last = v_state2;*/
	v_state_last = v_state;
	last_mean1 = mean1;
	/*last_mean2 = mean2;*/
}

void start_trial_func(void) {
	
	logValue("entered_state_40", 1.0); /* Useful time stamp. */
	
}

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
        if (v >= 4.0) return POSITIVE;  /* if above 4.0 V, above threshold */
        if (v <= 3.0) return NEGATIVE;  /* if below 3.0, below threshold */
        return NEUTRAL; /* otherwise unsure, so no change */
    }
    else {
        return NEUTRAL; /* Do not allow "beam-break" events on non-lickport channel */
    }
}
