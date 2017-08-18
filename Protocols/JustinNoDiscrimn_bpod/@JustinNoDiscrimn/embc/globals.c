void tick_func(void);
extern void logValue(const char *varname, double val);
extern void triggerSound(unsigned card, unsigned snd);
extern int strcmp(const char *, const char *);
extern double sqrt(double);
extern unsigned state();
extern int forceJumpToState(unsigned state, int event_id_for_history);
extern double readAI(unsigned chan);
void init_func(void);
void enter_state_41(void);
void enter_state_42(void);
void enter_state_43(void);
void enter_state_44(void);
void exit_state_45(void);
void enter_state_45(void);
void enter_state_46(void);
void enter_state_47(void);
void enter_state_48(void);
void enter_state_49(void);
void exit_state_49(void);
void enter_state_50(void);
/********************************************************************************
 * TEXT BELOW WILL BE FIND-REPLACED FROM MATLAB PRIOR TO SetStateProgram()*/
double touch_thresh = XXX;
double actionXr = XXX;
double rewXr = XXX;
double lick_thresh = XXX;
double whiskvel_thresh = XXX;
double whiskang_thresh = XXX;
double pre_pole_delay = XXX;
double resonance_delay = XXX;
double answer_delay = XXX;
double delay_period = XXX;
double sample_period = XXX;
double answer_period = XXX;
double drink_period = XXX;
double vVect1[XXX];
double tmpMeanVect[XXX];
double tmpMedianVect[XXX];
double valve_time = XXX;
double stim_epoch = XXX;
int go_cue = XXX;
int fail_cue = XXX;
int pole_cue = XXX;
int rew_cue = XXX;
char *answer_mode = XXX;
char *sampend_mode = XXX;
char *response_mode = XXX;
char *dlyfail = XXX;
char *rspfail = XXX;
char *rspdlyfail = XXX;
char *sampfail = XXX;
char *nxtside = XXX;
int nxttype = XXX;
int time_out_time = XXX;
int punish_on = XXX;
/********************************************************************************
 * END: FIND-REPLACE TEXT
 ********************************************************************************/
double mean1 = 0;
double median1 = 0;
double last_mean1 = 0;
double last_sum1 = 0;
double baseline = 0;
int lick_vac_counter = 0;
int no_action_flag = 0;
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
int delay_fail_flag = 0;
int resp_fail_flag = 0;
int pre_pole_time = 0;
int pre_pole_start = 0;
int pole_up_time = 0;
int rew_cue_time = 0;
int v_state_trans = 0;
int pole_cue_time = 0;
int delay_period_time = 0;
int sample_period_time = 0;
int resonance_time = 0;
int rew_time = 0;
int start_drink_time = 0;
int valve_flag = 0;
int touchblerg = 0;
int lickblerg = 0;
int whiskblerg = 0;
int whisk_state_flag=0;
int ans_delay_fail_flag=0;
int punish_time=0;
int rew_cue_flag = 0;
int ans_flag = 0;
int touch_state_flag = 0; 
int hit_state_flag=0;
int miss_state_flag=0;
int cr_state_flag=0;
int fa_state_flag=0;
int final_timer=0;
int resp_flag=0;
int blergerr = 0;
int incorrect_answer_action_flag = 0;
int incorrect_sample_action_flag = 0;
int log_analog_counter = 1;
int cycle_counter = 1;
int mean_window_counter = 1;
int v_state_up= 0;
int v_state= 0;
int v_state_last=0;
int v_state_down= 0;
int v_state_up_last= 0;
int v_state_down_last= 0;
int v_state_lick;
int v_state_lick_last=0;
int v_state_whiskvel;
int v_state_whiskvel_last=0;
int lick_state_flag=0;
int resonance_period_time=0;
int whiskvel_state_flag=0;
int delay_whiskvel_state_flag=0;
int delay_lick_state_flag =0;
int bypassChanIds_trigger = 2;  
int bypassChanIds_bitcode = 4;  
int bypassChanIds_festo = 16;  
int bypassChanIds_stateTrigs = 32; 
int bypassChanIds_touchtrig = 64;  
int bypassChanIds_lickport = 256;  
int bypassChanIds_lickport2 = 128;  
int bypassChanIds_lickvac = 1024;  
int bypassChanIds_touchtrigBehav = 65536;  
int bypassChanState_bitcode = 0;  
int bypassChanState_festo = 0; 
int bypassChanState_stateTrigs = 0; 
int bypassChanState_touchtrig = 0;  
int bypassChanState_lickport = 0;  
int bypassChanState_lickport2 = 0; 
int bypassChanState_lickvac = 0;   
int bypassChanState_trigger = 0; 
int bypassChanState_touchtrigBehav = 0;  
int timeoutlock = 0;
int nmeans=1;
int mean_window_length=12;
int median_window_length=3;
int timeoutcounter;
unsigned curr_state;
unsigned last_state = 40;
const unsigned lick_left_ai_chan = 5; /* Analog input channel for left lick port. */
const unsigned lick_right_ai_chan = 4; /* Analog input channel for left lick port. */
const unsigned touch_detector_ai_chan1 = 7; /* Analog input channel for axial sensor. */
const unsigned whisker_ang_ai_chan = 6; /* whisker velocity from fpga. */
double lickleft;
double v1; 
double whiskang;
double whiskvel = 0; /*eventually this will be the delta of whiskang*/
unsigned i;
char *punish_type = "none";
/*for appendation of trial outcome to bitstream at end of trial*/
double bittm = 3.0; /* bit time, in ms*/
double gaptm = 7.0; /* gap (inter-bit) time, in ms*/
double pattern[4];
double waittimer=1;
double counter=1;
int g = 0;

/*TICK FUNCTION TO RUN EACH CYCLE*/
void tick_func(void){
	curr_state = state();/*update state*/
	lickleft = readAI(lick_left_ai_chan);
	v1 = readAI(touch_detector_ai_chan1);
	whiskang = readAI(whisker_ang_ai_chan);
	/*subtract  baseline*/
	/*v1 = v1 - baseline;*/
	whiskang = whiskang - 0.003;
	/*fill the circ. buffers for the signal measurements*/
	if (mean_window_counter > mean_window_length) {
		mean_window_counter  = 0;
		vVect1[mean_window_length-1] = v1;
	} else {
		vVect1[mean_window_counter-1] = v1;
	}
    /*median filtering*/
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
    double sum1 = 0;
	for (i = 0; i < mean_window_length - 1; i++) {
		sum1 = sum1 + tmpMeanVect[i];
	}
	
	mean1 = sum1/mean_window_length;
	
	/*compute baseline*/
	if (curr_state < 43){
		baseline=baseline+mean1;
		baseline=baseline/nmeans;
		nmeans=nmeans+1;
	}

	double absdiff1 = sqrt((mean1 - last_mean1)*(mean1 - last_mean1));

	/*thresholding for touch sensor - set so FAs happen, and use threshXr to modulate*/ 
	if (curr_state > 43 && curr_state < 46){ 
		/*if (mean1 >= touch_thresh)  {*/
		if (absdiff1 > touch_thresh){
			bypassChanState_touchtrig = 1; /*trigger touch on*/
			v_state_up = 1;
				/*if ((mean1 >= touch_thresh * actionXr) && curr_state > 43) {*/
				if ((absdiff1 >= touch_thresh * actionXr) && curr_state > 43) {
					touch_state_flag = 1;
					bypassChanState_touchtrigBehav = 1; /*trigger touch on*/
					if (touchblerg == 0) {
						first_touch_time = cycle_counter;
						touchblerg = 1;
					}
				}
		/*} else if (mean1 <= -1* touch_thresh){
		/*	bypassChanState_touchtrig = 1; /*trigger touch on*/
		/*	v_state_down = 1;
		/*	if ((mean1 <= -1* touch_thresh * actionXr) && curr_state > 43){
		/*		touch_state_flag = 1;
		/*		bypassChanState_touchtrigBehav = 1; /*trigger touch on*/
		/*		if (touchblerg == 0) {
		/*			first_touch_time = cycle_counter;
		/*			touchblerg = 1;
		/*		}
		/*	}*/
		}else {
			bypassChanState_touchtrig = 0; /*trigger touch on*/
			bypassChanState_touchtrigBehav = 0; /*trigger touch on*/
			v_state = 0;
			v_state_up = 0;
			v_state_down = 0;
			touch_state_flag = 0;
		}
		if (v_state_up == 1 || v_state_down == 1){ /*can just use ret or pro eventually if wantewd*/
			v_state = 1;
		}
	}
	if (v_state_up != v_state_up_last ){
		v_state_trans = cycle_counter;
	}else if (v_state_down != v_state_down_last ){
		v_state_trans = cycle_counter;
	}else{	
		v_state_trans = 0;
	}
	if (curr_state >= 40 && curr_state <= 57) {
		if  (v_state_trans > 0 ) {	
			if (v_state_up == 1 && v_state_up_last == 0 ){	
				logValue("touch_pro_on", v_state_up);
			}else if (v_state_up == 0 && v_state_up_last == 1 ){
				logValue("touch_pro_off", v_state_up);	
			}else if (v_state_up == 1 && v_state_up_last == 0 ){
				logValue("touch_ret_on", v_state_down);	
			}else if (v_state_down == 0 && v_state_up_last == 1 ){
				logValue("touch_ret_off", v_state_down);
			}
		}
	}
	/*thresholding for lick sensor*/
	if (curr_state == 44 || curr_state == 45 || curr_state == 46 || curr_state == 47 || curr_state == 56){  
		if (lickleft > lick_thresh)  { 
			v_state_lick = 1;
			lick_state_flag = 1;
			if (lickblerg == 0) {
				first_lick_time = cycle_counter;
				lickblerg = 1;
			}
		} else {
			v_state_lick = 0;
			lick_state_flag = 0;
		}
	}
	/*thresholding for whisker velocity*/
	if (whiskvel > whiskvel_thresh) { 
		v_state_whiskvel = 1;
		whiskvel_state_flag = 1;
		if (whiskblerg == 0) {
			first_whisk_time = cycle_counter;
			whiskblerg = 1;
		}
	} else {
		v_state_whiskvel = 0;
		whiskvel_state_flag = 0;
	}
	/*ACTTION STATE FLAGGING, e.g. actions during delay and sample period*/
	if (curr_state == 44 || curr_state == 45) { 
		if (strcmp(response_mode,"lick")==0) {  /*animal must lick only to respondd. Reward depends on trial type*/
			if (lick_state_flag==1) {
				if (strcmp(sampend_mode,"action")==0){
					resp_flag=1;
				}else{ /*wait till sampling period is (nearly) over tyo do anything about this response*/
					if ((cycle_counter - sample_period_time) == sample_period - 2) {
						resp_flag=1;
					}
				}
			} 
			if (touch_state_flag == 1 || whisk_state_flag ==1) {
				incorrect_sample_action_flag = 1;
			}
		}
		if (strcmp(response_mode,"touch")==0) {  /*animal must lick only to respondd. Reward depends on trial type*/
			if (touch_state_flag==1) {
				if (strcmp(sampend_mode,"action")==0){
					resp_flag=1;
				}else{ /*wait till sampling period is (nearly) over tyo do anything about this response*/
					if ((cycle_counter - sample_period_time) >= 3000) {
						resp_flag=1;
						/*triggerSound(0, fail_cue); /*trigger the go cue*/
					}
				}
			}
			if (lick_state_flag == 1 || whisk_state_flag ==1) {
				incorrect_sample_action_flag = 1;
			}
		}
		if (strcmp(response_mode,"whisk")==0) {  /*animal must lick only to respondd. Reward depends on trial type*/
			if (whisk_state_flag==1) {
				if (strcmp(sampend_mode,"action")==0){
					resp_flag=1;
				}else{ /*wait till sampling period is (nearly) over tyo do anything about this response*/
					if ((cycle_counter - sample_period_time) == sample_period - 2) {
						resp_flag=1;
					}
				}
			}
			if (lick_state_flag == 1 || touch_state_flag ==1) {
				incorrect_sample_action_flag = 1;
			}
		}
		if (strcmp(response_mode,"none")==0) {  /*no response required,*/
			if ((cycle_counter - sample_period_time) == sample_period-2){ /*end of sample period causes a 'response'*/
				resp_flag=1;
			}
			if (lick_state_flag == 1 || touch_state_flag ==1 || whisk_state_flag ==1) {
				incorrect_sample_action_flag = 1;
			}
		}
		if (blergerr == 0 && resp_flag ==1) {
			first_response_time = cycle_counter;
			blergerr = 1;
		}
	}
	
	/*ANSWER STATES FLAGGING, e.g. actions during answer period and answer delay*/
	if (curr_state == 46 || curr_state == 47) { 
		if (strcmp(answer_mode,"lick")==0) {  /*animal must lick only to respondd. Reward depends on trial type*/
			if (lick_state_flag==1) {
				lick_ans_flag=1;
				first_response_time=cycle_counter; 
			} 
		}if (strcmp(answer_mode,"touch")==0) {  /*animal must do correct touch response ,*/
			if (touch_state_flag == 1) {
				touch_ans_flag=1;
				first_response_time=cycle_counter; 
			} 
		}if (strcmp(answer_mode,"whisk")==0) {  /*animal must do whisk response, then touch response,  +lick to get reward*/
			if (whisk_state_flag==1) {
				whisk_ans_flag=1;
				first_response_time=cycle_counter; 
			} 
		}
	}
	/************************************************/
	/*STATE MATRIX CODE */
	if (curr_state == 40) {
		bypassChanState_trigger = 1; /*trigger*/
		bypassChanState_stateTrigs = 0; /*ensure first timepoiit is a 0*/
		forceJumpToState(58, 18);  /*first bitcode state is 58, handled in matlab*/
	}
	if (curr_state == 58) {
		bypassChanState_stateTrigs = 1; 
	}
	if (curr_state == 175){ /*last bitcode state*/
		bypassChanState_trigger = 0; /*trigger*/
		forceJumpToState(41, 1); 
		triggerSound(0, pole_cue); /*trigger the pole cue*/
		cycle_counter=1; /*reset the cyle counter once bitcode has finished*/
		delay_period_time=1;
	}
	if (curr_state == 41) { 
		if  ((cycle_counter-pre_pole_time) > pre_pole_delay) { 
			forceJumpToState(42, 2); /*pole gets triggewred in entry func here*/
			curr_state = 42;
			resonance_time = cycle_counter;

		}
	}
	/*state 43 is a hard delay for sensor resonance timeout*/
	if (curr_state == 43) { 
		if ((cycle_counter - resonance_time) > resonance_delay) { /*at ^k sampling, should be 560ms delay*/
			forceJumpToState(44, 4);
			curr_state = 44;
			last_state=43;
		}
	}
	
	/*if we have a resonance period to deal with, make sure it is included as part od the delay, that
	 * delays cant be shorter than resonance*/
	if (resonance_delay != 0){
		if ((pre_pole_delay + resonance_delay)>delay_period){ /*cant have a delay shorter then the resonacne period*/
			delay_period = pre_pole_delay+resonance_delay;
		}
	}
	
	/*state 44 is the variable delay period*/
	if (curr_state == 44) { 
		if ((cycle_counter - delay_period_time) > delay_period) {  /*if delay period is over...*/
			forceJumpToState(45, 5);  /*sound go cue and move to sample period*/
			curr_state = 45;
			last_state=44;
		} else {
			/*if (lick_state_flag == 1 || touch_state_flag == 1) { /*bit of a hack*/
			if (resp_flag == 1){
				triggerSound(0, fail_cue); /*trigger the go cue*/
				curr_state=56;
				last_state=44;
				forceJumpToState(56, 16);  /*made a response during the delay, jump to punish state*/
			} 
		}
	}
	if (curr_state == 45) { /*sampling period */
		if ((cycle_counter - sample_period_time) <= sample_period) { /*if we have not reached the end of the sample period*/
			if (resp_flag==1) { /*an accepted response type for this behav has been made in the sample period*/
				if (strcmp(sampend_mode,"action")==0){
					forceJumpToState(46, 6); /*jump to answer delay*/
					bypassChanState_touchtrig = 0; /*trigger touch on*/
					bypassChanState_touchtrigBehav = 0; /*trigger touch on*/
					bypassChanState_festo=0;
					curr_state=46;
				    last_state=45;
				}

			} else if (resp_flag==0 && lick_state_flag==1 && punish_on ==1) { /*non-accpeted response made during delay period*/
				forceJumpToState(56, 16); /*jump to a punishment period, if specified*/
				curr_state = 56;
				last_state=45;
			} 
				
		} else if ((cycle_counter - sample_period_time) >= sample_period) { /*no action AT ALL and sampling over. */
			if (resp_flag==1) { /*an accepted response type for this behav has been made in the sample period*/
				forceJumpToState(46, 6);
				bypassChanState_touchtrig = 0; /*trigger touch on*/
				bypassChanState_touchtrigBehav = 0; /*trigger touch on*/
				bypassChanState_festo=0;
				curr_state=46;
				last_state=45;
			} else {
				forceJumpToState(51, 11); 
				curr_state = 51;	
				last_state=45;
			}
		}
	}
	/*state 66 is a variable delay before the answer period entered*/
	if (curr_state == 46) {
		if ((cycle_counter - first_response_time) >= answer_delay) { /*answer delay period has passed*/
			forceJumpToState(47, 7); /*go to answer period*/
			triggerSound(0, rew_cue); /*trigger the go cue*/
			curr_state = 47;
			last_state=46;
		} else { /*delay not over yet. check if there have been actions, and what do do about it*/
			if (ans_flag==1) {
				ans_delay_fail_flag=1;
				forceJumpToState(56, 16); /*jump to a punishment period, if specified*/
				last_state=46;
			}
		}
	}
	if (curr_state == 47) { /*answer period*/
		if ((cycle_counter - rew_time) < answer_period) {  /* 'rew_time' not a good name at all. still in the answer period*/
			if (lick_ans_flag == 1) {
				forceJumpToState(50, 10); /* go to response state*/
			    curr_state = 50;
				last_state=47;
			}
		} else { /*answer period has ended without an an action -determine what action to take*/
			forceJumpToState(51, 11); /* go to no response state*/
			curr_state = 51;
			last_state=47;
		}
	}
	/*state 48 is a fixed vale time trigger*/
	if (curr_state == 48) {
		if ((cycle_counter - valve_flag) >= valve_time * rewXr) {  /*still in the valve open period*/
			bypassChanState_lickport = 0; /*turn off lickport*/
			forceJumpToState(49, 9);
			curr_state=49;
			last_state=48;
		}
	}
	/*state 49 is a fixed period where the animal can drink*/	
	if (curr_state == 49) {
		if ((cycle_counter - start_drink_time) >= drink_period) {  /* SHOULD BE DRINK PERIOD, BUT THIS IS TOO LONG - still in the answer period*/
			if (hit_state_flag==1) {
				forceJumpToState(52, 12);	/*hit*/
				curr_state=52;
				last_state=49;
				final_timer=cycle_counter;
			} else {
				forceJumpToState(54, 14);	/*correct reject*/
				curr_state=54;
				last_state=49;
				final_timer=cycle_counter;
			}
		}
	}
	/*state 56 a *punish state*/
	if (curr_state==56) {
		if (punish_on==1 && last_state==44) {
			timeoutlock=1;
			miss_state_flag=0;
			fa_state_flag=0;
			if (lick_state_flag == 0){
				timeoutlock=0;
				cycle_counter = (cycle_counter - delay_period); /*reset sample delay period*/
				forceJumpToState(44,4);
				curr_state=44;
				last_state=56;
			}			
		}
		if(punish_on==1 && last_state==45){ /*sample licking*/
				timeoutlock=1;
				miss_state_flag=0;
				fa_state_flag=0;
				if (lick_state_flag == 0){
					timeoutlock=0;
					cycle_counter = (cycle_counter - sample_period);  /*reset sample period*/
					forceJumpToState(45,5);
					curr_state=45;
				} 
			}
		if (punish_on==1 && last_state==46){ /*answer delay licking*/
				timeoutlock=1;
				miss_state_flag=0;
				fa_state_flag=0;
				if (lick_state_flag == 0){
					timeoutlock=0;
					cycle_counter = (cycle_counter - sample_period);
					forceJumpToState(46,6);
					curr_state=66;
				} 
			}
		if (miss_state_flag==1) {
			forceJumpToState(53, 13);	/*miss*/
			curr_state=53;
			final_timer=cycle_counter;
		} else if (fa_state_flag==1) {
			forceJumpToState(55, 15);	/*false alarm*/
			curr_state=55;
			final_timer=cycle_counter;
		} else if (timeoutlock==0 && curr_state >= 46){
			bypassChanState_festo = 0; /*lower pole*/
			forceJumpToState(57, 17);	/*if this state was reached before a miss or fa decision could be made, just end it*/
			curr_state=57;
		}
	}
	
	/* enter into a hit/miss/fa/cr state, and count off ~500ms or whatever is necessary to detect back at PokesPlot*/
	/*if (curr_state == 52 || curr_state == 53 || curr_state == 54 || curr_state == 55) {
		if ((cycle_counter - final_timer) >= 3000) {
			forceJumpToState(57, 17); /*jump to final state*/
	/*		curr_state=57;
	/*	}
	/*}
	*/
	
	/*encode final state into bitstream*/
	
	/*hold for the lick vac counter*/
	if (curr_state >= 49 && cycle_counter - lick_vac_counter >= (valve_time/40)){
		bypassChanState_lickvac = 0;
	}
	
	if (curr_state == 52 || curr_state == 53 || curr_state == 54 || curr_state == 55) {
		if (curr_state == 52){ /*hit*/
			pattern[0] = 1;
			pattern[1] = 0;
			pattern[2] = 0;
			pattern[3] = 0;
		}else if (curr_state == 53){ /*miss*/
			pattern[0] = 1;
			pattern[1] = 0;
			pattern[2] = 1;
			pattern[3] = 0;
		}else if (curr_state == 54){ /*correct reject*/
			pattern[0] = 1;
			pattern[1] = 0;
			pattern[2] = 0;
			pattern[3] = 1;
		}else if (curr_state == 55){ /*false alarm*/
			pattern[0] = 1;
			pattern[1] = 1;
			pattern[2] = 0;
			pattern[3] = 0;
		}else{ /*didnt make it far enough for a decision*/
			pattern[0] = 1;
			pattern[1] = 1;
			pattern[2] = 1;
			pattern[3] = 1;
		}
		/*loop through bit pattern WITH gaps and encode*/
		if (g <=8){
			if (g == 0 || g == 2 || g == 4 || g == 6 ){ /*bit states*/
				waittimer=bittm*6;
				if (counter >= waittimer){
					if (pattern[g/2] == 1){
						bypassChanState_bitcode = 1;
					}else if (pattern[g/2] == 0){
						bypassChanState_bitcode = 0;
					}
					counter=0;
					g=g+1;
				}
				counter=counter+1;
			} else { /*encode gaps*/
				waittimer=gaptm*6;
				if (counter >= waittimer){
					bypassChanState_bitcode = 0;
					counter=0;
					g=g+1;
				}
				counter=counter+1;
			}
		}
		
		if (g==8){
			bypassChanState_bitcode = 0;
			forceJumpToState(57,18); /*jump to final state*/
		}
	}
	
	if (curr_state == 50 ) { /*answer given - determine if it was correct given a go or no go trial*/
		bypassChanState_stateTrigs = 0;
		if (nxttype == 1) { /*go trials*/
			forceJumpToState(48, 8); /*jump to 'valve' state*/
			curr_state = 48;
			last_state=50;
			hit_state_flag=1;
		}else { /* go to whatever punish state if any is specified*/
			forceJumpToState(56, 16);
			curr_state = 56;
			fa_state_flag=1;
		}
		final_timer=cycle_counter;
	}
	if (curr_state == 51) { /*no answer given - determine if it was correct given a go or no go trial*/
		bypassChanState_stateTrigs = 0;
		if (last_state==45) { /*no response during sample. end trial*/
			forceJumpToState(57, 17); /*jump to final state*/
			final_timer=cycle_counter;
			curr_state=57;
			last_state=51;
		} else {
			if (nxttype == 0) { /*nogo trials*/
				forceJumpToState(54, 14); /*go stright to cr*/
				final_timer=cycle_counter;
				curr_state = 54;
				last_state=51;
			}else { 
				forceJumpToState(56, 16); /* go to miss state*/
				curr_state = 56;
				last_state=51;
				miss_state_flag=1;
			}
		}
	}
	if ((curr_state > 49 && curr_state < 56) || curr_state== 57){ 
		bypassChanState_festo=0;
		bypassChanState_touchtrig = 0;
		bypassChanState_touchtrigBehav = 0;
		bypassChanState_stateTrigs = 0;

	}
	mean_window_counter = mean_window_counter + 1;	
	log_analog_counter = log_analog_counter + 1;
	if (timeoutlock == 0) {
		cycle_counter = cycle_counter + 1;
	}else {
		timeoutcounter = timeoutcounter + 1;
	}
	/*use bypassDout to trigger all digital outs on or off as set in this past cycle*/
	int bitmask = 0;
	bypassDOut(bitmask);
	if (bypassChanState_bitcode == 1){
		bitmask=bitmask+bypassChanIds_bitcode;
	}
	if (bypassChanState_festo == 1){
		bitmask=bitmask+bypassChanIds_festo;
	}
	if (bypassChanState_stateTrigs == 1){
		bitmask=bitmask+bypassChanIds_stateTrigs;
	}
	if (bypassChanState_lickport == 1){
		bitmask=bitmask+bypassChanIds_lickport;
	}
	if (bypassChanState_trigger == 1){
		bitmask=bitmask+bypassChanIds_trigger;
	}
	if (bypassChanState_touchtrig == 1){
		bitmask=bitmask+bypassChanIds_touchtrig;
	}
	if (bypassChanState_lickvac == 1){
		bitmask=bitmask+bypassChanIds_lickvac;
	}
	if (bypassChanState_touchtrigBehav == 1){
		bitmask=bitmask+bypassChanIds_touchtrigBehav;
	}
	bypassDOut(bitmask);
	
	/*LOGGING SECTION*/
	if (curr_state >= 40 && curr_state <= 57) {
		/*if (log_analog_counter == 50) { /*(38 cycles is every ~6ms, or ~120HZ, at 6kHz*, */ 
		/*	logValue("whiskang", whiskang);
		/*	log_analog_counter = 0;
		/*}
		/*log_analog_counter = log_analog_counter + 1;	
		*/
	}
	v_state_last = v_state;
    v_state_up_last = v_state_up;
	v_state_down_last = v_state_down;
	last_mean1 = mean1;
	last_sum1 = sum1;
}
/*STATE ENTRY FUNCTIONS*/
void enter_state_41(void) { /*prepole*/
	pre_pole_start = cycle_counter;
	bypassChanState_stateTrigs = 0;
}	
void enter_state_42(void) { /*raise pole*/
	pole_up_time = cycle_counter;
	bypassChanState_festo = 1;	
	forceJumpToState(43, 3);
	curr_state = 43;
	bypassChanState_stateTrigs = 0; /*this state doesnt need to be tracked, leavce at 0*/
}
void enter_state_43(void) { /*resonance*/
}	
void enter_state_44(void) { /*sample delay*/
	bypassChanState_stateTrigs = 0;
}	
void enter_state_45(void) { /*sample*/
	triggerSound(0, go_cue); /*trigger the go cue*/
	sample_period_time = cycle_counter;
	bypassChanState_stateTrigs = 1;
}
void exit_state_45(void) { 
	sample_period_time = cycle_counter;
}
void exit_state_49(void) { /*exit drink period*/
	bypassChanState_lickvac = 1; /*open the lick vac*/
	lick_vac_counter=cycle_counter;
}
void enter_state_46(void) {/*answer delay*/
	rew_cue_time = cycle_counter; /*RESPONSE TIME FLAG*/
	bypassChanState_stateTrigs = 0;
	bypassChanState_festo = 0; /*lower pole once sampling is done*/
}
void enter_state_47(void) {/*answer period*/
	bypassChanState_stateTrigs = 1;
	rew_time = cycle_counter;
}
/*state 48 is the valve opening*/
void enter_state_48(void) { /*valve period*/
	bypassChanState_stateTrigs = 0;
	valve_flag = cycle_counter;
	bypassChanState_lickport = 1; /* turn the valve on*/
}
/*state 49 is the drink period*/
void enter_state_49(void) {
	bypassChanState_stateTrigs = 1;
	start_drink_time = cycle_counter;
}
void enter_state_50(void) { /*response made*/
	punish_time = cycle_counter;
}
/*INIT FUNCTION*/
void init_func(void){
}

