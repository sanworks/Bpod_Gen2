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
double whiskang_thresh = XXX;
double whiskang_thresh_states[] = {XXX};
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
char *response_mode = XXX;
char *intfail = XXX;
char *dlyfail = XXX;
char *rspfail = XXX;
char *rspdlyfail = XXX;
char *incrspfail = XXX;
char *nxtside = XXX;
int nxttype = XXX;
int time_out_time = XXX;
int init_hold_time = XXX;

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

int no_action_flag = 0;
int first_touch_pro_time = 0;
int first_touch_ret_time = 0;
int first_touch_time = 0;
int first_lick_time = 0;
int first_whisk_time = 0;
int first_response_time = 0;
int first_response_flag = 0;
int first_answer_time = 0;
int whisk_ans_flag=0;
int touch_ans_flag=0;
int lick_ans_flag=0;
int whisk_ans_time=0;
int touch_ans_time=0;
int lick_ans_time=0;
int answer_time=0;
int init_fail_flag = 0;
int delay_fail_flag = 0;
int resp_fail_flag = 0;
int pre_pole_time = 0;
int pole_up_time = 0;
int rew_cue_time = 0;
int v_state_trans = 0;
int go_cue_time = 0;
int pole_cue_time = 0;
int delay_period_time = 0;
int sample_period_time = 0;
int resonance_time = 0;
int lickport_time = 0;
int rew_time = 0;
int start_drink_time = 0;
int valve_flag = 0;
int touchblerg = 0;
int touchproblerg = 0;
int touchretblerg = 0;
int lickblerg = 0;
int whiskblerg = 0;
int blerger = 0;
int whisk_state_flag=0;
int ans_delay_fail_flag=0;
int punish_time=0;
int rew_cue_flag = 0;
int ans_flag = 0;
int touch_state_up_flag = 0; 
int touch_state_down_flag = 0; 
int touch_pro_state_flag = 0; 
int touch_ret_state_flag = 0; 
int touch_state_flag = 0; 
int delay_touch_state_flag = 0;
int hit_state_flag=0;
int miss_state_flag=0;
int cr_state_flag=0;
int fa_state_flag=0;
int final_timer=0;
int resp_flag=0;
int incorrect_answer_fail_flag = 0;
int log_analog_window_counter = 1;
int cycle_counter = 1;
int mean_window_counter = 1;
int log_touch_counter = 1;
int log_whisk_counter = 1;
int baseline_counter = 1;

/*not v_state1,2, etc are touch sensors*/
int v_state;
int v_state_last = 0;
int v_state1;
int v_state1_last = 0;
int v_state_up= 0;
int v_state_down= 0;
int v_state_up_last= 0;
int v_state_down_last= 0;
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
int iti_flag = 0;
int puff_flag = 0;

unsigned curr_state;
unsigned last_state = 40;

const unsigned lick_left_ai_chan = 0; /* Analog input channel for left lick port. */
/*const unsigned lick_right = 1; /* Analog input channel for left lick port. */
const unsigned touch_detector_ai_chan1 = 7; /* Analog input channel for axial sensor. */
const unsigned touch_detector_ai_chan2 = 9; /* Analog input channel for axial sensor. */
const unsigned whisker_ang_ai = 6; /* whisker velocity from fpga. */


/*TICK FUNCTION TO RUN EACH CYCLE*/

void tick_func(void){
	
	double lickleft;
	double v1; /*touch data 1*/
	double v2; /*touch data 2*/
	double whiskang;
	double whiskvel = 0; /*eventually this will be the delta of whiskang*/
	unsigned curr_state = state();
	unsigned i;
	
	/*update state*/
	curr_state = state();
	
	/*now update the voltage readings*/
	lickleft = readAI(lick_left_ai_chan);
	v1 = readAI(touch_detector_ai_chan1);
	whiskang = readAI(whisker_ang_ai);
	
	/*subtract measured baseline
	 */
	v1 = v1 - 0.005;
	whiskang = whiskang - 0.003;
	 /*testing*/
	  mean_window_length = 64;
      median_window_length = 16;
	
	/*TOUCH SENSOR PRE_PREPROCESSING */
	/*local baseline subtraction estimate for touch sensor..do NOT update during pole moves!*/
	/*fill the circ. buffers for the baseline measurements*/
	/*if (curr_state < 62 ) { /*this needs to be made an expliict input argument*/
	/*
		if (baseline_counter > baseline_length - 1) {
			baseline_counter  = 0;
			vbaseVect1[baseline_length-1] = v1;
		} else {
			vbaseVect1[baseline_length-1] = v1;
		}
		double bsum1 = 0;
		for (i = 0; i < baseline_length - 1; i++) {
			bsum1 = bsum1 + vbaseVect1[i];
		}
	
		real_baseline = bsum1/baseline_length;
	} 
	*/ 
	/*fill the circ. buffers for the signal measurements*/
	if (mean_window_counter > mean_window_length) {
		mean_window_counter  = 0;
		vVect1[mean_window_length-1] = v1;
	} else {
		vVect1[mean_window_counter-1] = v1;
	}

    /*median filtering*/
	/*home-made sort since we have no libraries*/
	/*sort signal window data*/

	int j, p, z, imin; 
	double tmp;	
	for (z = 0 ; z < mean_window_length - 1; z++){ /*step the small median window, zero-padded orig vect at end*/
		for (j = 0 ; j < median_window_length - 1 ; j++){  /*loop through the small median window*/
			tmpMedianVect[j]=vVect1[j+z];
		}
		for (j = 0 ; j < median_window_length - 1 ; j++){  /*loop through the small median window*/
			imin = j;
			for (p = j + 1; p < median_window_length ; p++){
				if (tmpMedianVect[p] < tmpMedianVect[imin]){
					imin = p;
				}
			}
			tmp = tmpMedianVect[j];
			tmpMedianVect[j] = tmpMedianVect[imin];
			tmpMedianVect[imin] = tmp;
		}
	
		/*end sort*/

		/*compute median of voltages in signal windows*/
		if (median_window_length % 2 == 0) {
			median1 = (tmpMedianVect[median_window_length / 2 - 1] + tmpMedianVect[median_window_length / 2]) / 2;
		}
		else  {
		median1 = tmpMedianVect[median_window_length / 2];
		}
		/*median filter*/
		for (i = 0; i < median_window_length; i++) {
			tmpMedianVect[i] = median1;
		}
		/*assign this value back into the proper section of the original vector*/
		for (j = 0 ; j < median_window_length - 1 ; j++){  /*loop through the small median window*/
			tmpMeanVect[j+z]=median1;
		}
	}
	
	/*compute mean over the median-filtered average window*/
    double sum1 = 0;
	for (i = 0; i < mean_window_length - 1; i++) {
		sum1 = sum1 + tmpMeanVect[i];
	}
	mean1 = sum1/mean_window_length;
	
	/*compute sum f squares of voltages from LAST cycle*/
    /*the baseline vect is 2x the length of the signal vect, so use tyhe first half of that*/

	/*double sum1sq = 0;
	double vBase = 0;
	for (i = 0; i < mean_window_length; i++) {
		sum1sq = sum1sq + (vbaseVect1[i]*vbaseVect1[i]);
		vBase=vBase+vbaseVect1[i];
	}
	vBase=vBase/mean_window_length;
	std1 = sqrt((sum1sq - vBase)*(sum1sq - vBase));

	double absdiff1 = sqrt((sum1 - last_sum1)*(sum1 - last_sum1));*/
	
	/*END TOUCH SENSOR PRE_PREPROCESSING */
	
	
	/*RESPONSE DECISION SECTION - can be based on any currently configed AI channel
	* NOTE: requires a threshold VALUE. Later, provided threshold STATE or STATES determine when to apply the decision based on this thresh
	* NOTE: with the proper settings, could be used for example to reward only when the 'whiskvel' AI
	* is within a certain region. Or only if 'whiskvel' AI reaches a certain value in a certain state, followed 
	* by a touch, to get reward
	
	/*thresholding for touch sensor*/ 
	
	/************************************************/
	/*STATE MATRIX CODE */
	/************************************************/

	curr_state = state();

	if (curr_state == 40) {
		bypassDOut(1024); /*send the trigger for ephus/si, cameras, etc*/
		triggerSound(0, pole_cue); /*trigger the pole cue*/
		pole_cue_time = cycle_counter;
		forceJumpToState(41, 2); 
	}
	
    /*state 60 is last bitcode state*/
	if (curr_state == 60) { 
		curr_state = 61;
	}
	
    /*state 61 is a pre-pole delay time*/
	if (curr_state == 61) { 
		if  (cycle_counter > pre_pole_delay) {
			forceJumpToState(62, 4);
			curr_state = 62;
		}
	}

	/*state 62 is just an entry function*/


	/*state 63 is a hard delay for sensor resonance timeout*/
	if (curr_state == 63) { 
		if ((cycle_counter - resonance_time) > resonance_delay) { /*at ^k sampling, should be 560ms delay*/
			forceJumpToState(64, 6);
			curr_state = 64;
		}
	}


	/*state 64 is the variable delay period*/
	if (curr_state == 64) { 
		if ((cycle_counter - pole_cue_time) >= delay_period) {  /*if delay period is over...INCLUSIVE OF RESONANCE PERIOD*/
			forceJumpToState(65, 7);  /*sound go cue and move to sample period*/
			/*exit func takes care of go cue here*/
			curr_state = 65;
		} else {
			if (resp_flag == 1) { 
				forceJumpToState(76, 18);  /*made a response during the delay, jump to punish state*/
				/*entry func takes care of punishment, if any, here*/
				curr_state=76;
			} 
		}
	}

	if (curr_state == 65) { /*sampling period - for now, REQUIRES a response of some kind to move to answer period. Eventually, want to give the option to have no response here be correct*/
		if ((cycle_counter - sample_period_time) < sample_period) { /*if we have not reached the end of the sample period*/
			if (resp_flag==1) { /*an accepted response type for this behav has been made in the sample period*/
				forceJumpToState(66, 8); /*jump to answer delay*/
				curr_state=66;
			} else if (resp_flag==0 && first_response_flag==1) { /*non-accpeted response made during delay period*/
				forceJumpToState(76, 18); /*jump to a punishment period, if specified*/
				curr_state = 76;
			}
		} else if ((cycle_counter - sample_period_time) >= sample_period) { /*no action AT ALL and sampling over. End Trial*/
			forceJumpToState(71, 13); /*jump to no response, then end*/
			curr_state = 71;		
			no_action_flag=1;	
		}
	}
	
	/***********************************************************************************	
	/*state 66 is a variable delay before the reward cue (if there is one) is played and answer period entered*/
	/*for now, just enforcing a no answer policy during this period*/
	if (curr_state == 66) {
		if ((cycle_counter - first_response_time) >= answer_delay) { /*answer delay period has passed*/
			triggerSound(0,rew_cue); /*trigger a RESPONSE MADE cue*/
			forceJumpToState(67, 9); /*go to answer period*/
			curr_state = 67;
		} else { /*delay not over yet. check if there have been actions, and what do do about it*/
			if (ans_flag==1) {
				ans_delay_fail_flag=1;
				forceJumpToState(76, 18); /*jump to a punishment period, if specified*/
			}
		}
	}
	if (curr_state == 67) { /*answer period*/
		if ((cycle_counter - rew_time) < 5000) {  /* 'rew_time' not a good name at all. still in the answer period*/
			if (lick_ans_flag == 1) {
				triggerSound(0,fail_cue); /*trigger a RESPONSE MADE cue*/
				forceJumpToState(70, 12); /* go to no response state*/
			    curr_state = 70;
			}

		} else { /*answer period has ended without an an action -determine what action to take*/
			forceJumpToState(71, 13); /* go to no response state*/
			curr_state = 71;
		}
	}

	/*-------------------------------------------*/
	/*state 68 is a fixed vale time trigger*/
	if (curr_state == 68) {
		if ((cycle_counter - valve_flag) >= valve_time) {  /*still in the valve open period*/
			bypassDOut(0);
			forceJumpToState(69, 11);
			curr_state=69;
		}
	}

	/*state 69 is a fixed period where the animal can drink*/	
	/*at the end, decide which of the correct states needs to be jumped to*/
	if (curr_state == 69) {
		if ((cycle_counter - start_drink_time) >= 5000) {  /* SHOULD BE DRINO PERIOD, BUT THIS IS TOO LONG - still in the answer period*/
			bypassDOut(0); /*untrigger the valve (if it isnt already)*/
			if (hit_state_flag==1) {
				forceJumpToState(72, 14);	/*hit*/
				curr_state=72;
				final_timer=cycle_counter;
			} else {
				forceJumpToState(74, 16);	/*correct reject*/
				curr_state=74;
				final_timer=cycle_counter;
			}
		}
	}
	
	/*state 76 a *punish state* -- punishment depends on deifferent fail modes specified in embec call (see entry func)*/
	if (curr_state==76) {
		if (cycle_counter - punish_time >= 1000){ /*make suire we stay in punish long enough to register with matlan
			/*note, if giving noise, the entry func takes care of it*/
			if (puff_flag == 1) { /*apply puff if requested - NOT IMPLEMENTED YET*/
				/*bypassDOut()*/
			}
			if (iti_flag == 1) {
				if ((cycle_counter - punish_time) >= time_out_time) {
					/*can go to either miss or fa state from a punish state*/
					if (miss_state_flag==1) {
						forceJumpToState(73, 15);	/*miss*/
						curr_state=73;
						final_timer=cycle_counter;
					} else {
						forceJumpToState(75, 17);	/*false alarm*/
						curr_state=75;
						final_timer=cycle_counter;
					}
				}
			}
			/*go to either miss or fa state*/
			if (miss_state_flag==1) {
				forceJumpToState(73, 15);	/*miss*/
				curr_state=73;
				final_timer=cycle_counter;
			}else if (fa_state_flag==1) {
				forceJumpToState(75, 17);	/*false alarm*/
				curr_state=75;
				final_timer=cycle_counter;
			} else {
				forceJumpToState(77, 19);	/*if this state was reached before a miss or fa decision could be made, just end it*/
				curr_state=77;
			}
		}
	}

	/*finally, enter into a hit/miss/fa/cr state, and count off ~500ms or whatever is necessary to detect back at PokesPlot*/
	if (curr_state == 72 || curr_state == 73 || curr_state == 74 || curr_state == 75) {
		if ((cycle_counter - final_timer) >= 3000) {
			bypassDOut(0);
			forceJumpToState(77, 19); /*jump to final state*/
			curr_state=77;
		}
	}
  

	if (curr_state == 70 ) { /*answer given - determine if it was correct given a go or no go trial*/
		if (nxttype == 1) { /*go trials*/
			forceJumpToState(68, 9); /*jump to valve period*/
			curr_state = 68;
			hit_state_flag=1;
			triggerSound(0, rew_cue); /*trigger the rew cue*/
		}else { /* go to whatever punish state if any is specified*/
			forceJumpToState(76, 17);
			curr_state = 76;
			fa_state_flag=1;
		}
		final_timer=cycle_counter;
	}


	if (curr_state == 71) { /*no answer given - determine if it was correct given a go or no go trial*/
		
		if (no_action_flag == 0){ /*he at least did SOMETHING before the sampling period was up*/
			if (nxttype == 0) { /*nogo trials*/
				forceJumpToState(68, 9); /*jump to valve period*/
				curr_state = 68;
				cr_state_flag=1;
				triggerSound(0, rew_cue); 
			}else { 
				forceJumpToState(76, 17); /* go to whatever punish state if any is specified*/
				curr_state = 76;
				miss_state_flag=1;
			}
			
			final_timer=cycle_counter;
		}else {
			forceJumpToState(77, 19); /*jump to final state*/
			curr_state=77;
		}
	}
	

	cycle_counter = cycle_counter + 1;
	mean_window_counter = mean_window_counter + 1;	
	log_analog_window_counter = log_analog_window_counter + 1;
	
	/*LOGGING SECTION*/
	
	if (log_touch_counter == 120) { /*(12 cycles is every 2ms, or 500HZ, at 6kHz**/ 
		logValue('touch_ret_on',v_state_down);
		logValue('touch_pro_on',v_state_up);

		logValue("touch1", mean1);	
		log_touch_counter = 0;
	}
	/*if (log_whisk_counter == 38) { /*(38 cycles is every ~6ms, or ~120HZ, at 6kHz*, */ 
	/*	/*logValue("absdiff1", absdiff1);*/
	/*	logValue("whiskang", whiskang);
	/*	log_whisk_counter = 0;
	/*}
	*/
	log_touch_counter = log_touch_counter + 1;
	log_whisk_counter = log_whisk_counter + 1;		
	
	v_state1_last = v_state1;
	v_state2_last = v_state2;
	v_state_down_last = v_state_down;
	v_state_up_last = v_state_up;
	last_mean1 = mean1;
	last_mean2 = mean2;
	last_sum1 = sum1;

}

/*STATE EXIT FUNCTIONS*/

void exit_state_67(void) {
	bypassDOut(0); 
}


/*STATE ENTRY FUNCTIONS*/
void enter_state_40(void) {
	
}

void enter_state_61(void) {
	pre_pole_time = cycle_counter;
}	

/*state 62 triggers the pole up, flags the time, updates logs/states*/
void enter_state_62(void) {
	pole_up_time = cycle_counter;
	bypassDOut(16); /*trigger the pole*/
	forceJumpToState(63, 5);
	curr_state = 63;
	resonance_time = cycle_counter;
}

void enter_state_63(void) {
}	

/*state 64 entry triggers a log write, updates current state*/
void enter_state_64(void) {
	delay_period_time = cycle_counter;
}	

/*state 65 entry triggers the go cue and a log write, updates current state*/
void enter_state_65(void) {
	triggerSound(0, go_cue); /*trigger the go cue*/
	sample_period_time = cycle_counter;

}

void enter_state_66(void) {
	rew_cue_time = cycle_counter; /*RESPONSE TIME FLAG*/
}

/*state 67 is the answer period*/
void enter_state_67(void) {
	triggerSound(0, rew_cue); /*play reward wave*/
	rew_time = cycle_counter;
}


/*state 68 is the valve opening*/
void enter_state_68(void) {
	valve_flag = cycle_counter;
	bypassDOut(256); /* turn the valve on*/
}

/*state 69 is the drink period*/
void enter_state_69(void) {
	start_drink_time = cycle_counter;
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

void enter_state_76(void) { /*have reached a failure state. decide what to do depending on how we got hjere*/
	punish_time = cycle_counter;
	if (init_fail_flag == 1) { /*failed dto initate sampling period*/
		if (strcmp(intfail,"ITI")!=0) {  /*impose ITI before next trial*/
			iti_flag = 1; /*gets imposed in tick func*/
		} else if (strcmp(intfail,"puff")!=0) {  /*puff'm in da face*/
			puff_flag = 1; /*gets imposed in tick func*/
		} else if (strcmp(intfail,"noise")!=0) { /*play white noise*/
			triggerSound(0, fail_cue); /*trigger the fail cue*/
		}
	} else if (resp_fail_flag == 1) { /*failed to make correct response*/
		if (strcmp(rspfail,"ITI")!=0) {  /*impose ITI before next trial*/
			iti_flag = 1; /*gets imposed in tick func*/
		} else if (strcmp(rspfail,"puff")!=0) {  /*puff'm in da face*/
			puff_flag = 1; /*gets imposed in tick func*/
		} else if (strcmp(rspfail,"noise")!=0) { /*play white noise*/
			triggerSound(0, fail_cue); /*trigger the fail cue*/
		}
	} else if (delay_fail_flag ==1) { /*failed during response delay*/
		if (strcmp(dlyfail,"ITI")!=0) {  /*impose ITI before next trial*/
			iti_flag = 1; /*gets imposed in tick func*/
		} else if (strcmp(dlyfail,"puff")!=0) {  /*puff'm in da face*/
			puff_flag = 1; /*gets imposed in tick func*/
		} else if (strcmp(dlyfail,"noise")!=0) { /*play white noise*/
			triggerSound(0, fail_cue); /*trigger the fail cue*/
		}
	} else if (ans_delay_fail_flag == 1) { /*failed during answer delay*/
		if (strcmp(rspdlyfail,"ITI")!=0) {  /*impose ITI before next trial*/
			iti_flag = 1; /*gets imposed in tick func*/
		} else if (strcmp(rspdlyfail,"puff")!=0) {  /*puff'm in da face*/
			puff_flag = 1; /*gets imposed in tick func*/
		} else if (strcmp(rspdlyfail,"noise")!=0) { /*play white noise*/
			triggerSound(0, fail_cue); /*trigger the fail cue*/
		}
	} else if (incorrect_answer_fail_flag) {/*failed to make correct response*/
		if (strcmp(incrspfail,"ITI")!=0) {  /*impose ITI before next trial*/
			iti_flag = 1; /*gets imposed in tick func*/
		} else if (strcmp(incrspfail,"puff")!=0) {  /*puff'm in da face*/
			puff_flag = 1; /*gets imposed in tick func*/
		} else if (strcmp(incrspfail,"noise")!=0) { /*play white noise*/
			triggerSound(0, fail_cue); /*trigger the fail cue*/
		}
	}
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
