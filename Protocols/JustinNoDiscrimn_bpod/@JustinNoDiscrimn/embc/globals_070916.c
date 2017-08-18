
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
	
	double lickleft;
	double v1; /*touch data 1*/
	double v2; /*touch data 2*/
	double whiskvel;
	unsigned curr_state = state();
	unsigned i;
	
	/*update state*/
	curr_state = state();
	
	/*now update the voltage readings*/
	lickleft = readAI(lick_left_ai_chan);
	v1 = readAI(touch_detector_ai_chan1);
	/*whiskvel = readAI(whisker_velocity_ai);
	
	/*TOUCH SENSOR PRE_PREPROCESSING */
	/*local baseline subtraction estimate for touch sensor..do NOT update during pole moves!*/
	/*fill the circ. buffers for the baseline measurements*/
	if (curr_state < 62 ) {
	
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

	double sum1sq = 0;
	double vBase = 0;
	for (i = 0; i < mean_window_length; i++) {
		sum1sq = sum1sq + (vbaseVect1[i]*vbaseVect1[i]);
		vBase=vBase+vbaseVect1[i];
	}
	vBase=vBase/mean_window_length;
	std1 = sqrt((sum1sq - vBase)*(sum1sq - vBase));

	double absdiff1 = sqrt((sum1 - last_sum1)*(sum1 - last_sum1));
	/*END TOUCH SENSOR PRE_PREPROCESSING */
	
	
	/*RESPONSE DECISION SECTION - can be based on any currently configed AI channel
	* NOTE: requires a threshold VALUE. Later, provided threshold STATE or STATES determine when to apply the decision based on this thresh
	* NOTE: with the proper settings, could be used for example to reward only when the 'whiskvel' AI
	* is within a certain region. Or only if 'whiskvel' AI reaches a certain value in a certain state, followed 
	* by a touch, to get reward
	* NOTE: eventually should have seperate threshold functions for each ai, but here is fine for now/*
	
	/*thresholding for touch sensor*/ 
	if (absdiff1 > touch_thresh && v_state_last == 0)  { 
		v_state = 1;
		touch_state_flag = 1;
		/*logValue("touch", 1.0);*/
		if (blerg == 0) {
			first_touch_time = cycle_counter;
			/*first touch is special. note its'time*/
			blerg = 1;
		}

	} else {
		v_state = 0;
		touch_state_flag = 0;
	}
	
	/*thresholding for lick sensor*/
	if (lickleft > lick_thresh)  { 
		v_state_lick = 1;
		lick_state_flag = 1;
		/*logValue("lick", 1.0);*/

	} else {
		v_state_lick = 0;
		lick_state_flag = 0;
	}
	
	/*thresholding for whisker velocity*/
	if (whiskvel > whiskvel_thresh) { 
		v_state_whiskvel = 1;
		whiskvel_state_flag = 1;
		/*logValue("whiskvel", 1.0);*/

	} else {
		v_state_whiskvel = 0;
		whiskvel_state_flag = 0;
	}
	
	/*STATE MATRIX CODE */

	/*state 40 is just an entry func*/
	if (curr_state == 40) {
		if (blerger == 0) {
			/*logValue("entered_state_40", 1.0); /* Useful time stamp. */
			bypassDOut(1024); /*send the trigger for ephus/si, cameras, etc*/
			triggerSound(0, pole_cue); /*trigger the pole cue*/
			pole_cue_time = cycle_counter;
			blerger = 1;
			forceJumpToState(41, 1); 
			curr_state=41;
		}
			/*statement to end the trigger pulse after 5ms*/
		if (cycle_counter - pole_cue_time >= 60) {
			bypassDOut(0);
		}
	}
	
    /*state 60 is last bitcode state*/
	if (curr_state == 60) { 
		forceJumpToState(61, 2);
		curr_state = 61;
	}
	
    /*state 61 is a pre-pole delay time*/
	if (curr_state == 61) { 
		if  (cycle_counter > pre_pole_delay) {
			forceJumpToState(62, 3);
			curr_state = 62;
		}
	}

	/*state 62 is just an entry function*/
	
	/*state 63 is a hard delay for sensor resonance timeout*/
	if (curr_state == 63) { 
		if ((cycle_counter - resonance_time) > 6000) { /*at ^k sampling, should be 560ms delay*/
			forceJumpToState(64, 5);
			curr_state = 64;
		}
	}

	/*state 64 is the variable delay period*/
	if (curr_state == 64) { 
		if ((cycle_counter - delay_period_time) > 2000) {  /*if delay period is over...*/
			forceJumpToState(65, 6);  /*sound go cue and move to sample period*/
			/*exit func takes care of go cue here*/
			curr_state = 65;
		} else {
			if (delay_touch_state_flag == 1) { 
				forceJumpToState(76, 17);  /*touched during the delay, jump to punish state*/
				/*entry func takes care of punishment, if any, here*/
				curr_state=76;
			} 
		}
	}
	
	/*now were at the samplign period, and need a switch to control things depeneding
	 * on the type of task and the type of inputs we are triggering of*/
/***********************************************************************************/
	/*This controls their ACTION dur sampling period, e.g. touching the pole. This is seperate from their RESPONSE
	 * in some cases, or nothing, as in original go-nogo and 2AFC, with just a lick RESPONSE.
	/*Animals can also make ACTIONS during non-sample periods, but that needs a seperate control - NOT IMPLEMENTED*/
	int toAnsFlag=0;
	if (curr_state == 65) {
		if (strcmp(action_mode,"lick")!=0){  /*animal must lick only to respondd. Reward depends on trial type*/
			if (touch_state_flag == 1 && lick_state_flag==0) {
				/*sampling action and response are the same. go straight to determining whether
				/*the response was correct*/
				bypassDOut(0); /*remove the pole*/
				forceJumpToState(66, 7); /*hm, problem. what to do with answer delay*/
				curr_state=66;
			} 
		}else if (strcmp(action_mode,"touch_lick")!=0){  /*animal must do correct touch response , +lick to get reward*/
			if (touch_state_flag == 1 && lick_state_flag==0) {
				toAnsFlag==1;	
			} 
		}else if (strcmp(action_mode,"whiskvel_touch_lick")!=0){  /*animal must do whisk respinse, then touch response,  +lick to get reward*/
			if (touch_state_flag == 1 && whiskvel_state_flag==1) {
				toAnsFlag==1;	
			} 
		}else if (strcmp(action_mode,"whiskvel_lick")!=0){ /*animal must do correct whisk response,  +lick to get reward*/
			if (touch_state_flag == 1 && whiskvel_state_flag==1) {
				toAnsFlag==1;	
			} 
		}

		/*if we had an approp. answer, allow the answer period to commence*/
		if ((cycle_counter - sample_period_time) < sample_period) { /*if we have not reached the end of the sample period*/
			if (toAnsFlag == 1) { /*if there has been a touch*/
				forceJumpToState(66, 7); /*go to answer delay*/
				curr_state=66;
			} 
		} else if ((cycle_counter - sample_period_time) >= sample_period) { /*end of sampling period reached*/
			bypassDOut(0); /*remove the pole*/
			/*sample period is over and their was no action taken given. Determine what to do*/
			/*we want an 'answer fail' flag, which we dont have as og 7/2016, so just to punish*/
			forceJumpToState(76, 17);
			curr_state=76;
		}
	}
/***********************************************************************************	
	/*state 66 is a variable delay before the reward cue (if there is one) is played and answer period entered*/
	/*if there is an inappropriate ACTION or RESPONSE during this time, proceed as directed by input*/
	/*STILL UNDER CONSTRUCTION*/
	if (curr_state == 66) {
		if (lickleft > lick_thresh) { /*early lick - end trial*/
			lickport_time = cycle_counter;
			forceJumpToState(76, 17); /*jump to a punishment period, if specified*/
			curr_state = 76;
		} else {
			if ((cycle_counter - first_touch_time) >= answer_delay && rew_cue_flag == 0) {
				forceJumpToState(67, 8); /*go to answer period*/
				curr_state = 67;
				rew_cue_time = cycle_counter;
				rew_cue_flag = 1;
			}
		}
	}
/*-------------------------------------------------*/	
	/*now were at the ANSWER period, and need a switch to control things depeneding
	 * on the type of task and the type of inputs we are triggering of*/
/***********************************************************************************/
	/*This controls their RESPONSE to the results of the ACTION taken in the sample period
	 * in ANY task, there must be some RESPONSE.
	/*Animals can ONLY make RESPONSES during the ANSWER PERIOD, whos access is controlled by ACTIONS*/
	if (curr_state == 67) {
		/*flag if any RESPONSE events happened, on the sensors specified in the the function input*/
		if (strcmp(answer_mode,"lick")!=0) {  /*animal must lick only to respondd. Reward depends on trial type*/
			if (touch_state_flag == 1 && lick_state_flag==0) {
				forceJumpToState(70,11); /*go to response state, set resp_flag=1*/
				curr_state=70;
			} 
		}else if (strcmp(answer_mode,"touch_lick")!=0) {  /*animal must do correct touch response , +lick to get reward*/
			if (touch_state_flag == 1 && lick_state_flag==0) {
				forceJumpToState(70,11); /*go to response state, set resp_flag=1*/
				curr_state=70;
			} 
		}else if (strcmp(answer_mode,"whiskvel_touch_lick")!=0) {  /*animal must do whisk respinse, then touch response,  +lick to get reward*/
			if (touch_state_flag == 1 && whiskvel_state_flag==1) {
				forceJumpToState(70,11); /*go to response state, set resp_flag=1*/
				curr_state=70;	
			} 
		}else if (strcmp(answer_mode,"whiskvel_lick")!=0) { /*animal must do correct whisk response,  +lick to get reward*/
			if (touch_state_flag == 1 && whiskvel_state_flag==1) {
				forceJumpToState(70,11); /*go to response state, set resp_flag=1*/
				curr_state=70;	
			} 
		}else {
			/*not familair with this answer_mode...how to notify user?*/
			    forceJumpToState(77,18); /*go final state*/
				curr_state=77;	
			}
	} else {
		forceJumpToState(71,12); /*go to no response state, set resp_flag=0*/
		curr_state=71;	
	}
	
	if (curr_state == 70 || curr_state == 71){ /*response or no response states last
		/*if we had an approp. RESPONSE, move to reward delivery*/
		if ((cycle_counter - rew_cue_time) < answer_period) {  /*still in the answer period*/
			if (strcmp(nxttype,"go")!=0) { /*go trials*/
				if (resp_flag == 1) {
					forceJumpToState(68, 9); /*jump to valve period*/
					curr_state = 68;
					hit_state_flag=1;
				}else { /* go to whatever punish state if any is specified*/
					forceJumpToState(76, 17);
					curr_state = 76;
					miss_state_flag=1;
				}
			}else if (strcmp(nxttype,"nogo")!=0) { /*nogo trials*/
				if (resp_flag == 1) {
					forceJumpToState(76, 17); /* go to whatever punish state if any is specified*/
					curr_state = 76;
					fa_state_flag=1;
				}else { 
					forceJumpToState(68, 9); /*jump to valve period*/
					curr_state = 68;
					cr_state_flag=1;
				}
			}
		} else { /*sample period over with no response*/
			if (strcmp(nxttype,"go")!=0) { /*go trials*/
				forceJumpToState(76, 17); /* go to whatever punish state if any is specified*/
				curr_state = 76;
				miss_state_flag=1;
			} else { /*no go trials*/
				forceJumpToState(68, 9); /*jump to valve period*/
				curr_state = 68;
				hit_state_flag=1;
			}
		}
	}
	
	/*-------------------------------------------*/
	/*state 68 is a fixed vale time trigger*/
	if (curr_state == 68) {
		if ((cycle_counter - valve_flag) > valve_time) {  /*still in the valve open period*/
			bypassDOut(0);
			forceJumpToState(69, 10);
			curr_state=69;
		}
	}

	/*state 69 is a fixed period where the animal can drink*/	
	/*at the end, decide which of the correct states needs to be jumped to*/
	if (curr_state == 69) {
		if ((cycle_counter - start_drink_time) > drink_period) {  /*still in the answer period*/
			bypassDOut(0); /*untrigger the valve (if it isnt already)*/
			if (hit_state_flag==1) {
				forceJumpToState(72, 13);	/*hit*/
				curr_state=72;
				final_timer=cycle_counter;
			} else {
				forceJumpToState(74, 15);	/*correct reject*/
				curr_state=74;
				final_timer=cycle_counter;
			}
					
		}else {
			/*do i need anything here?*/
		}
	}
	
	/*state 76 is an entry func onlu - *punish state* -- just play whitnoise for now*/
	if (curr_state==76) {
			/*go to either miss or fa state*/
		if (miss_state_flag==1){
			forceJumpToState(73, 14);	/*miss*/
			curr_state=73;
			final_timer=cycle_counter;
		}else{
			forceJumpToState(75, 16);	/*false alarm*/
			curr_state=75;
			final_timer=cycle_counter;
		}
	}

	/*finally, enter into a hit/miss/fa/cr state, and count off 500ms or whatever is necessary to detect back at PokesPlot*/
	if (curr_state == 72 || curr_state == 73 || curr_state == 74 || curr_state == 75) {
		if ((cycle_counter - final_timer) > 3000) {
			bypassDOut(0);
			forceJumpToState(77, 18); /*jump to final state*/
			curr_state=77;
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
