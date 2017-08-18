function r = dprime(hr,far,num_s1,num_s0)

if hr==1
    hr = hr-1/(2*num_s1);
end
if far==0
    far = 1/(2*num_s0);
end
if hr==0
    hr=1/(2*num_s1);
end
if far==1
    far = far-1/(2*num_s0);
end

r = norminv(hr,0,1) + norminv(1-far,0,1);