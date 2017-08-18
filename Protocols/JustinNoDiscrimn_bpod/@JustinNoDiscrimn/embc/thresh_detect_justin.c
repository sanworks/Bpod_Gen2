TRISTATE thresh_detect(int chan, double v)
{
    if (v >= 0.5) return POSITIVE; /* if above 0.5 V,
                                                                     protratction */
    if (v <= -0.5) return NEGATIVE; /* if below -0.5,
                                                                    retraction */
    return NEUTRAL; /* otherwise unsure, so no change */
}


/*
 TRISTATE thresh_detect(int chan, double v)
{
   static int ct = 0;
   TRISTATE ret = NEUTRAL;
   if (v >= 0.5) ret = POSITIVE;
   else if (v <= -0.5) ret = NEGATIVE;
   if (!(++ct % 3000)) printf("chan: %d  voltage: %g\n", chan, v);
   return ret;
}
*/