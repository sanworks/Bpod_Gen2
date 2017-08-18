TRISTATE thresh_detect(int chan, double v)
{
    if (v >= 4.0) return POSITIVE; /* if above 4.0 V,
                                                                     above threshold */
    if (v <= 3.0) return NEGATIVE; /* if below 3.0,
                                                                    below threshold */
    return NEUTRAL; /* otherwise unsure, so no change */
}


/*
 TRISTATE thresh_detect(int chan, double v)
{
   static int ct = 0;
   TRISTATE ret = NEUTRAL;
   if (v >= 4.0) ret = POSITIVE;
   else if (v <= 3.0) ret = NEGATIVE;
   if (!(++ct % 3000)) printf("chan: %d  voltage: %g\n", chan, v);
   return ret;
}
*/