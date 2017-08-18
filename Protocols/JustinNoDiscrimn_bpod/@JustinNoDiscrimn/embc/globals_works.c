void tick_func(void);
extern void triggerSchedWave(unsigned wave_id);
extern double readAI(unsigned chan);
extern unsigned state();
extern void logValue(const char *varname, double val);
extern int writeDIO(unsigned chan, unsigned bitval);
TRISTATE thresh_func(int chan, double v);
void init_func(void);
void start_trial_func(void);

/********************************************************************************
 * TEXT BELOW WILL BE FIND-REPLACED FROM MATLAB PRIOR TO SetStateProgram()
 ********************************************************************************/
const double touch_thresh_high = XXX;
const double touch_thresh_low = XXX;

const double numCycThresh = XXX;
const double numCycVal = XXX;

static unsigned vVect1[XXX] = {XXXX};
static unsigned vVect2[XXX] = {XXXX};

static unsigned states_to_log_touch[XXX] = {XXX}; /*list of states in which we want to detect touches for SM*/

/********************************************************************************
 * END: FIND-REPLACE TEXT
 ********************************************************************************/
int cycCounter = 1;

double v_state;
double v_state_last = 0;

/*vars for sensor 1*/
double v_state1;
double v_state1_last = 0;
double std1;
double mean1;
double sumV1;
double sumV1_sq;
double baseMean1;

/* vars for sensor 2*/
double v_state2;
double v_state2_last = 0;
double std2;
double mean2;
double sumV2;
double sumV2_sq;
double baseMean2;


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
	
 	unsigned curr_state = state();
 	unsigned i;

 	int n_touch_state;
 	int in_touch_state;

	/*reset some tracking buffers*/
  	sumV1 = 0;
 	sumV2 = 0;
 	sumV1_sq = 0;
 	sumV2_sq = 0;

	/*read the touch sensor voltage and store in cycle buffer*/
  	v1 = readAI(touch_detector_ai_chan1);
	v2 = readAI(touch_detector_ai_chan2);

	/*keep filling until the cycle buffer for std and thresh val has been filled. Once full, start looping it*/
  	/*if (cycCounter <= numCycThresh + numCycVal){
		vVect1[cycCounter] = v1;
 		vVect2[cycCounter] = v2;
 	}
 	
 	if (cycCounter > numCycThresh + numCycVal) {
 		for (i = 0; i <= numCycThresh + numCycVal - 2; i++) { 
			vVect1[i] = vVect1[i+1];
			vVect2[i] = vVect2[i+1];
  		}
		
 		vVect1[sizeof(vVect1) - 1] = v1; 
 		vVect2[sizeof(vVect1) - 1] = v2; 
	}
	*/
}

void start_trial_func(void)
{
	/*logValue("entered_state_40", 1.0); /* Useful time stamp. */

}

void init_func(void)
{
	unsigned i = 1;
	/* Fill a vector of zeros to keep track of touch sensor v of the last numCycThresh+numCycVal cycles */
	for (i = 0; i < 36; i++) {
	 	vVect1[1] = 0;
	 	vVect2[1] = 0;
		
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
	} else {
		return NEUTRAL; /* Do not allow "beam-break" events on non-lickport channel */
	}
}
