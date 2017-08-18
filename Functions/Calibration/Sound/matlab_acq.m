
usbdux_daq('init')
channel=3;
n_data = 10000;
while 1
    data = usbdux_daq('acquire','physical',1,'n_scan',n_data,'freq',80000,'n_chan',16);
    hold off
    plot(data(channel,:),'linewidth',2);hold on;
    %axis([1 n_data -0.5 0.5])
    axis([1 100 -0.5 0.5])
    disp(['pk-pk: ' num2str(max(data(channel,:))-min(data(channel,:))) '       ' ])
    pause(0.01)
end