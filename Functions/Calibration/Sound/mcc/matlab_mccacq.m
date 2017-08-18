
channel=1;
n_data = 100;
while 1
    data = mcc_daq('n_scan',n_data,'freq',100000,'n_chan',1);
    hold off
    plot(data(channel,:),'linewidth',2);hold on;
    %axis([1 n_data -0.5 0.5])
    axis([1 100 -10 10])
    disp(['pk-pk: ' num2str(max(data(channel,:))-min(data(channel,:))) '       ' ])
    pause(0.01)
end