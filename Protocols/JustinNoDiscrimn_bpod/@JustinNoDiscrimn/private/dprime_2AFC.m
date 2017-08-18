function r = dprime_2AFC(prop_correct,num_trials)

if prop_correct==1
    prop_correct = prop_correct-1/(2*num_trials);
end
if prop_correct==0
    prop_correct=1/(2*num_trials);
end

r = sqrt(2)*norminv(prop_correct,0,1);