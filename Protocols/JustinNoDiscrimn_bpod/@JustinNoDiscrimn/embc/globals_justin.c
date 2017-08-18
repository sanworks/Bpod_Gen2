void tick_func(void);
void init_func(void);
extern void triggerSchedWave(unsigned wave_id);
extern double readAI(unsigned chan);
extern unsigned state();
extern void logValue(const char *varname, double val);
extern int writeDIO(unsigned chan, unsigned bitval);
TRISTATE thresh_func(int chan, double v);
void start_trial_func(void);

/********************************************************************************
 * TEXT BELOW WILL BE FIND-REPLACED FROM MATLAB PRIOR TO SetStateProgram()
 ********************************************************************************/
const double touch_thresh_high = XXX;
const double touch_thresh_low = XXX;
const double numCycThresh = XXX;
const double numCycVal = XXX;
static unsigned states_to_log_touch[XXX]={XXX} /*list of state in which we want to detect touches for SM*/

/********************************************************************************
 * END: FIND-REPLACE TEXT
 ********************************************************************************/
int cycCounter = 0;
int v_state = 0;
int v_state_last = 0;

/*vars fort sensor 1*/
int v_state1 = 0;
int v_state1_last = 0;
int std1;
int mean1;
int sumV1;
int sumV1_sq
int baseMean1;

/* vars for sensor 2*/
int v_state2 = 0;
int v_state2_last = 0;
int std2;
int mean2;
int sumV2;
int sumV2_sq
int baseMean2;

double vVect1[numCycThresh];
double vVect2[numCycThresh];

void tick_func(void)
{

	struct wave_id_list { /* scheduled wave IDs  REPLACE WITH ENUM*/
		unsigned touch_onsets;
	};
	struct wave_id_list wave_ids = {.touch_onsets = 0};
	
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
	struct varlog_val_list varlog_vals = {.touch_trig_on = 1.0, .touch_trig_off = 2.0, .touch_trig_pro_on = 3.0, .touch_trig_pro_off = 4.0, .touch_trig_ret_on = 5.0, .touch_trig_ret_off = 6.0, .touch_trig_med_on = 7.0, .touch_trig_med_off = 8.0, .touch_trig_lat_on = 9.0, .touch_trig_lat_off = 10.0};  

	const unsigned touch_detector_ai_chan1 = 7; /* Analog input channel for axial sensor. */
	const unsigned touch_detector_ai_chan2 = 9; /* Analog input channel for axial sensor. */
	
	double v1;
	double v2;
	
	unsigned i;
	unsigned curr_state; 
	
	int n_touch_state;
	int in_touch_state;

	/*read the touch sensor voltage and store in cycle buffer*/
	v1 = readAI(touch_detector_ai_chan1);
    v2 = readAI(touch_detector_ai_chan2); 
    
	/*keep filling until the cycle buffer for std and thresh val has been filled. Once full, start looping it*/
	if (cycCounter<=numCycThresh+numCycVal){
		vVect1[cycCounter]=v1;
		vVect2[cycCounter]=v1;   
    else if (cycCounter=numCycThresh+numCycVal+1){
	    for (i = 0; i = numCycThresh+numCycVal-1; i++) /*Step back through the buffer replacing old elements*/
			vVect1[i] = vVect1[i+1];
			vVect2[i] = vVect2[i+1];
        }
		vVect1[numCycThresh+numCycVal] = v1; /*last number is now the latest v measure*/
	    vVect2[numCycThresh+numCycVal] = v2; /*last number is now the latest v measure*/
	}
	
	/* if we arent in a state where we care about touches controlling SM transitions, dont bother with touch detection code*/
	/* the last entry in in_touch_state must be the last state of touch*/
	/* n_touch_state = sizeof(states_to_log_touch) / sizeof(unsigned);*/
    n_touch_state = 6; /*just the size of this variable, but unsure the above code isnt giving an error*/
	
	for (i = 0; i<n_touch_state-1; i++){
		if (curr_state == states_to_log_touch[i])
		in_touch_state = 1;
	}

	if (in_touch_state==1){
	
	/*get the standard deviation of the v measuremnts for the last numCycThresh measures*/
		for (i = 0; i = numCycThresh; i++)
			sumV1 = sumV1 + vVect1[i];
			sumV1_sq = sumV1_sq + (vVect1[i]*vVect1[i]);
			
			sumV2 = sumV2 + vVect2[i];
			sumV2_sq = sumV2_sq + (vVect2[i]*vVect2[i]);
	
			std1 = ((sumV1/numCycThresh)-(sumV1_sq/numCycThresh))/numCycThresh;
			std2 = ((sumV2/numCycThresh)-(sumV2_sq/numCycThresh))/numCycThresh;
			baseMean1=(sumV1/numCycThresh);
			baseMean2=(sumV2/numCycThresh);

			/*get the mean of the v measuremnts for the last numCycVal measures*/
			sumV1 = 0;
			sumV2 = 0;
		
		for (i = numCycThresh+1; i = numCycVal; i++) 
			sumV1 = sumV1 + vVect1[i];
			sumV2 = sumV2 + vVect2[i];
	
			mean1=((sumV1/numCycThresh);
			mean2=((sumV2/numCycThresh);
		
		/*thresholding for sensor 1*/
		if (mean1-baseMean1 >= std1*touch_thresh_high)
			v_state1 = 1;   /*sensor threshold high reached, PROTRACTION, POSITIVE dV*/
			
			if (v_state1 == 1 && v_state1_last != 1) { /*begin touch onest */
				logValue("touch_trig_pro_on", varlog_vals.touch_trig_pro_on); /* Log that touch onset */
			else if (v_state1 != 1 && v_state1_last == 1)/*begin touch offest */
				logValue("touch_trig_pro_off", varlog_vals.touch_trig_pro_off); /* Log that touch onset */
			}
	    
		else if (mean1-baseMean1 <= std1*touch_thresh_low)
			v_state1 = 2;   /*sensor threshold high reached, RETRACTION, NEGATIVE dV*/
			mean1=mean1*-1; /*want this to be psotive for when we add to sensor 2*/
			
			if (v_state1 == 2 && v_state1_last != 2) { /*begin touch onest */
				logValue("touch_trig_pro_on", varlog_vals.touch_trig_pro_on); /* Log that touch onset */
			else if (v_state1 != 2 && v_state1_last == 2)/*begin touch offest */
				logValue("touch_trig_pro_off", varlog_vals.touch_trig_pro_off); /* Log that touch onset */
			}
		
		else v_state1 = 0;
	
		/*thresholding for sensor 2*/
		if (mean2-baseMean2 >= std2*touch_thresh_high)
			v_state2 = 1;   /*sensor threshold high reached, MEDTRACTION, POSITIVE dV*/
			
			if (v_state2 == 1 && v_state2_last != 1) { /*begin touch onest */
				logValue("touch_trig_med_on", varlog_vals.touch_trig_med_on); /* Log that touch onset */
			else if (v_state2 != 1 && v_state2_last == 1)/*begin touch offest */
				logValue("touch_trig_med_off", varlog_vals.touch_trig_med_off); /* Log that touch onset */
			}
	    
		else if (mean2-baseMean2 <= std2*touch_thresh_low)
			v_state2 = 2;   /*sensor threshold high reached, LATRACTION, NEGATIVE dV*/
			mean2=mean2*-1; /*want this to be psotive for when we add to sensor 1*/
			
			if (v_state2 == 2 && v_state2_last != 2) { /*begin touch onest */
				logValue("touch_trig_lat_on", varlog_vals.touch_trig_lat_on); /* Log that touch onset */
			else if (v_state2 != 2 && v_state2_last == 2)/*begin touch offest */
				logValue("touch_trig_lat_off", varlog_vals.touch_trig_lat_off); /* Log that touch onset */
			}
		else v_state1 = 0;
	
		/*thresholding for sensor 1 +sensor 2*/
		if ((mean1+mean2)-(baseMean1+baseMean2) >= (std1+std2)*touch_thresh_high)
			v_state = 1;   /*sensor threshold high reached, TOUCH*/
			
			if (v_state == 1 && v_state_last != 1) { /*begin touch onest */
				logValue("touch_trig_on", varlog_vals.touch_trig_on); /* Log that touch onset */
				curr_state=state();
				triggerSchedWave(wave_ids.touch_onsets);  /*trigger touch sched wave*/
			else if (v_state != 1 && v_state_last == 1)/*begin touch offest */
				logValue("touch_trig_off", varlog_vals.touch_trig_off); /* Log that touch onset */
				untriggerSchedWave(wave_ids.touch_onsets);  /*untrigger touch sched wave*/ 
			}
		/*negative values not possible here since we multipled any negative dV signals by -1*/
		else v_state = 0;
	
	} /*ends the section for touch detection and schedling trigg waves*/

	v_state1_last = v_state1;
	v_state2_last = v_state2;
	v_state_last = v_state;
	
	/*update the cyle counter*/
    cycCounter=cycCounter+1;
}

void start_trial_func(void)
{
	logValue("entered_state_40", 1.0); /* Useful time stamp. */
		
}

void init_func(void)
{
	unsigned i
     /* Fill a vector of zeros to keep track of touch sensor v of the last numCycThresh+numCycVal cycles */
	for (i = 0; i >= numCycThresh+numCycVal; i++) {
		vVect1[i] = 0;
	    vVect2[i] = 0;
        }
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
    if (chan == 0 || chan == 1 || chan == 7) { /* Lickport input channels = hardware channels 0 and 1*/
        if (v >= 4.0) return POSITIVE;  /* if above 4.0 V, above threshold */
        if (v <= 3.0) return NEGATIVE;  /* if below 3.0, below threshold */
        return NEUTRAL; /* otherwise unsure, so no change */
    }
    else {
        return NEUTRAL; /* Do not allow "beam-break" events on non-lickport channel */
    }
}

