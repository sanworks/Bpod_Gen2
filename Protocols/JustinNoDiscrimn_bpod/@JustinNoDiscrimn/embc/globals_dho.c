/*
 * TODO:
 *
 *  NEED TO take out stim_type_for_EmbC and replace w/ stim_state_for_EmbC
 *
 *
 * NOTES: Evidently cannot use "#define" symbolic constants in EmbC--preprocessor
 *      not used on this code?  Have to make variables instead.
 *
 */

void tick_func(void);
extern void triggerSchedWave(unsigned wave_id);
extern double readAI(unsigned chan);
extern int writeAO(unsigned chan, double voltage);
extern int writeDIO(unsigned chan, unsigned bitval);
extern unsigned state();
extern void logValue(const char *varname, double val);
extern unsigned logGetSize(void);
TRISTATE thresh_func(int chan, double v);
void init_func(void);
void start_trial_func(void);

/********************************************************************************
 * TEXT BELOW WILL BE FIND-REPLACED FROM MATLAB PRIOR TO SetStateProgram()
 ********************************************************************************/
const unsigned STIM_TRIAL_BOOL = 0; /* If 0, no stim will be given.
                                     Will do text-replace from MATLAB to set this depending on trial type.
                                     Make sure spaces in "STIM_TRIAL_BOOL = 1" are unchanged, for find-replace in MATLAB.
                                     */

static unsigned stim_state[XXX]={XXX};   /* passed down from make_and_upload_state_matrix, first entry specifies the stim type */

static unsigned stim_queue[XXX + 1];  /* Will do text-replace from MATLAB to set this depending on trial type.
                                     Make sure spaces in this expression are unchanged, for find-replace in MATLAB.
                                       */

const unsigned stim_dur_473 = XXX; /* Duration of pulse (train, if >1 pulse) for 473 nm laser. In units of task period.
                                    Hack required to compensate for -75 mV offset of baseline in AO channels going to AOMs.*/

const double whisker_pos_thresh_high = XXX;
const double whisker_pos_thresh_low = XXX;

const double stim_AOM_power = XXX;



/********************************************************************************
 * END: FIND-REPLACE TEXT
 ********************************************************************************/

const double ao_chan_offset = -0.112;

struct wave_id_list { /* scheduled wave IDs  REPLACE WITH ENUM*/
    unsigned masking_flash_blue;
    unsigned masking_flash_orange;
    unsigned x_galvo;
    unsigned y_galvo;
    unsigned shutter;
    unsigned aom_473;
    unsigned aom_594;
};

struct wave_id_list wave_ids = {.masking_flash_blue = 14, .masking_flash_orange = 15,
.x_galvo = 16, .y_galvo = 17, .aom_473 = 18, .aom_594 = 19, .shutter = 20};

const unsigned whisker_detector_ai_chan = 5; /* Analog input channel for whisker position readings. */
const unsigned aom_473_chan = 4; /* Analog output channel for AOM for 473 nm laser. */
const unsigned aom_594_chan = 5; /* Analog output channel for AOM for 594 nm laser. */

const unsigned num_ao_chans = 8;

int v_state;
int v_state_last = 0;

unsigned curr_state = 0;  /* 9/13/11*/
unsigned last_state = 0;  /* 9/13/11*/

unsigned wave_task_period_cnt = 0;
unsigned wave_stim_output_flag = 0;

struct varlog_val_list {
    double target_crossing;
    double stim_473nm;
};
struct varlog_val_list varlog_vals = {.target_crossing = 1.0, .stim_473nm = 2.0};  /* THESE SHOULD BE SIZE OF STIM DELAY TO RECORD*******/


void tick_func(void)
{
    
    unsigned in_stim_state = 0;
    unsigned stim_delay;
    double v;
    int i;
    int n_stim_state;

    /* the last entry in in_stim_state must be the last state of stimulation*/
    n_stim_state = sizeof(stim_state) / sizeof(unsigned) - 1;
    
     /* Must be in right state (pole descending or answer period) to trigger stim, and STIM_TRIAL_BOOL must be 1 */
     curr_state = state();
     for (i = 1; i<(n_stim_state+1); i++){
        if (curr_state == stim_state[i])
            in_stim_state = 1;
     }
    
    if (stim_state[0] == 0) {   /* inactivation during whisker contact only*/
        
        
        stim_delay = sizeof(stim_queue) / sizeof(unsigned) - 1;
        
        v = readAI(whisker_detector_ai_chan);
        
        if (v >= whisker_pos_thresh_high)
            v_state = 1;
        else if (v <= whisker_pos_thresh_low)
            v_state = 0;
        
    /******** FOR TESTING ************/
 /*   unsigned num_log_items;
    num_log_items = logGetSize();
    if (num_log_items > 10)
        writeAO(4,5.0); */
    /********************/
        
     /* First, check if a target-crossing event has "emerged" from the time-delay cue.
     If so, trigger a stim. */
        if (stim_queue[stim_delay + 1] == 1) {
            triggerSchedWave(wave_ids.aom_473);
            /*logValue("stim_473nm", varlog_vals.stim_473nm);*/
            logValue("stim_473nm", (double)stim_delay); /* Log that stim was delivered and give the delay in task periods. */
            wave_stim_output_flag = 1;
        }

     /* Next, advance each element one time step in FIFO queue. Queue works like a
     time-delay tunnel, where each element gets advanced one place at each
     time step, and where when an element makes it to the end a stim is triggered. */
        for (i = stim_delay; i > 0; i--) {
            stim_queue[i+1] = stim_queue[i];
        }
        stim_queue[1] = 0; /* This line must come before checking for and queueing new events. */
        
        
    /* Finally, check for a new target crossing event, and if there is one, put
     *it in the queue. */
        if (v_state == 1 && v_state_last != 1) { /* Whisker is moving toward center of target */
            logValue("target_crossing", varlog_vals.target_crossing); /* Log that whisker crossed target. */
            if (in_stim_state==1 && STIM_TRIAL_BOOL == 1) { /* In state 41, might want to wait ~ 0.5 s for typical pole drop time before enabling stim. */
                stim_queue[1] = 1; /* Queue a stimulation pulse. */
            }
        }
        
        
        if (wave_stim_output_flag == 1) {
            wave_task_period_cnt++;
            if (wave_task_period_cnt == (stim_dur_473 + 2)) { /* For some reason + 1 task period doesn't work, need + 2.
                                                                                        Then do get 2 sample periods of -0.75 mV, but this isn't too bad.*/
                writeAO(aom_473_chan,ao_chan_offset);
                wave_stim_output_flag = 0;
                wave_task_period_cnt = 0;
            }
        }
        
        v_state_last = v_state;
        
        
    }  else if (stim_state[0] == 1) {   /* inactivation during sample or delay period*/
        
        /* (10/4/11 NL note, below, the inactivation is inappropriate, check state carefully!!!) */
        /*stim during sample period*/
        curr_state = state();
        if (in_stim_state==1 && last_state != curr_state && STIM_TRIAL_BOOL == 1) { /* stim in state 41 */
            writeAO(aom_473_chan,stim_AOM_power+ao_chan_offset);                            /* write to 5V */
        } else if (in_stim_state==0 && last_state == stim_state[n_stim_state] && STIM_TRIAL_BOOL == 1) {
            writeAO(aom_473_chan,ao_chan_offset);                /* write to 0V */
        }
        last_state = curr_state;
    }
}


void init_func(void)
{
    
    unsigned i, stim_delay;
    
    
    stim_delay = sizeof(stim_queue) / sizeof(unsigned) - 1;
    
    /* Set all channels to 0 "manually", since Comedi calibration problem
     * leaves a slight voltage offset
     * Do all channels in for loop instead of this... */
    
    for (i = 1; i <= num_ao_chans; i++)
        writeAO(i,ao_chan_offset);
    
    /* Make sure we start with no "stims" in the queue*/
    for (i = 1; i < stim_delay + 1; i++)
        stim_queue[i] = 0;
    
    }

void start_trial_func(void)
{
    logValue("entered_state_40", 1.0); /* Useful time stamp. */
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

