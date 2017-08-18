/*
 * TODO:
 *
 *
 *
 *
 * NOTES: Evidently cannot use "#define" symbolic constants in EmbC--preprocessor
 *      not used on this code?  Have to make variables instead.
 *
 */

extern double readAI(unsigned chan);
extern int writeAO(unsigned chan, double voltage);
extern int writeDIO(unsigned chan, unsigned bitval);
void init_func(void);
void cleanup_func(void);


/* *******************************************************************************
START TEXT-REPLACE VARIABLES SECTION:
       Will do text-replace from MATLAB to set this depending on GUI parameters.
       Make sure spaces in this text are unchanged, for find-replace in MATLAB.
 *********************************************************************************/
const double VOLTAGE_X_GALVO = -2.5; /*-2.5;*/  
const double VOLTAGE_Y_GALVO = 0; 
const double VOLTAGE_AOM_473 = 5.0; /*0.075 or 5.0*/ 

/* *******************************************************************************
 END TEXT-REPLACE VARIABLES SECTION. 
 *********************************************************************************/
                                        
const double ao_chan_offset = 0.075;

const unsigned whisker_detector_ai_chan = 4; /* Analog input channel for whisker position readings. */
const unsigned aom_473_ao_chan = 4; /* Analog output channel for AOM for 473 nm laser. */
const unsigned aom_594_ao_chan = 5; /* Analog output channel for AOM for 594 nm laser. */
const unsigned x_galvo_ao_chan = 1; /* Analog output channel for x galvo. */
const unsigned y_galvo_ao_chan = 2; /* Analog output channel for y galvo. */

const unsigned cam_gate_dio_chan = 8;
const unsigned cam_frame_dio_chan = 9;
const unsigned shutter_dio_chan = 11;

const unsigned num_ao_chans = 8;


void init_func(void)
{ 
    unsigned i;
    
    /* Set all channels to 0 "manually", since Comedi calibration problem
     * leaves a slight voltage offset 
     * Do all channels in for loop instead of this... */
   
    for (i = 1; i <= num_ao_chans; i++)
        writeAO(i,ao_chan_offset);
   
    writeAO(x_galvo_ao_chan, VOLTAGE_X_GALVO);
    writeAO(y_galvo_ao_chan, VOLTAGE_Y_GALVO);
    writeAO(aom_473_ao_chan, VOLTAGE_AOM_473);
    
  /*  writeDIO(shutter_dio_chan, 1); *//* Uncomment to open shutter  */
}

void cleanup_func(void)
{ 
    unsigned i;
    
    /* Set all channels to 0 "manually", since Comedi calibration problem
     * leaves a slight voltage offset 
     * Do all channels in for loop instead of this... */
   
    for (i = 1; i <= num_ao_chans; i++)
        writeAO(i,ao_chan_offset);
    
    /*writeDIO(shutter_dio_chan, 0);*/ /* Close shutter  */  
}



