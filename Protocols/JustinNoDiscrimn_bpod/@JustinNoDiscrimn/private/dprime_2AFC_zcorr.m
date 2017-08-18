function r = dprime_2AFC_zcorr(prop_correct_R,prop_correct_L,num_trials_R,num_trials_L)

if prop_correct_R==1
    prop_correct_R = prop_correct_R-1/(2*num_trials_R);
end
if prop_correct_R==0
    prop_correct_R=1/(2*num_trials_R);
end

if prop_correct_L==1
    prop_correct_L = prop_correct_L-1/(2*num_trials_L);
end
if prop_correct_L==0
    prop_correct_L=1/(2*num_trials_L);
end


r = sqrt(2)*0.5*(norminv(prop_correct_R,0,1)+norminv(prop_correct_L,0,1));