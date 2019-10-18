% build_udpMexReceiver;
% to be used with testSerializeWithMultiUDP.mdl

% 1. broadcast UDP to the target (receiveAtIP on xpcDisplay)
%cxt.networkTargetIP = '127.0.0.1'; % to the localhost for testing
networkTargetIP = '100.1.1.3';
% 2. (receivePort on xpcDisplay Target)
networkTargetPort = 10001;
% 3. receive UDP from broadcast (destIP on xpcDisplay Target)
networkReceiveIP = '100.1.1.2';
% 4. must match whatever the send UDP block on the target is set to
% (destPort on xpcDisplay Target)
networkReceivePort = 25001;

udpMexReceiver('start', ...
  sprintf('%s:%d', networkReceiveIP, networkReceivePort), ...
  sprintf('%s:%d', networkTargetIP, networkTargetPort));

figure(1), clf; set(1, 'Color', 'w');

% -- Data from UDP plot
subplot(1, 2, 1);
hold on

nPts = 100;
xData = nan(nPts, 1);
yData = nan(nPts, 1);
h = plot(xData, yData, 'g-', 'LineWidth', 2);
xlabel('X');
ylabel('Y');
title('Data from UDP');
xlim([-1.5 1.5]);
ylim([-1.5 1.5]);
box off

% -- Mex Function Time plot
subplot(1,2,2);
tocVec = nan(1000, 1);
hToc = plot(tocVec, 'k.');
xlim([1 length(tocVec)]);
ylim([0 2]);
xlabel('Poll iteration');
ylabel('Time (ms)');
title('Mex Function Time');
box off

fprintf('Waiting for data from xPC...\n');

while(true)
   tocVec = [tocVec(2:end); NaN];
   tic
   
   g = udpMexReceiver('pollGroups');
   if ~isempty(g)
    value = double(g(end).signals.x);
    timestamp = uint32(g(end).signals.t);
    udpMexReceiver('send', '#', value, timestamp);
   end
   
   tocVec(end) = toc*1000;
   
   for i = 1:length(g)
       xData = [xData(2:end); g(i).signals.x];
       yData = [yData(2:end); g(i).signals.y];
       set(h, 'XData', xData, 'YData', yData);
   end
   
   set(hToc, 'YData', tocVec);
   
   if ~isempty(g)
       drawnow;
   end
   
   pause(0.001);
   
   if ~ishandle(1)
       udpMexReceiver('stop');
       break;
   end
end