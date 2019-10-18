% --- network communication with xPC Target
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

figure(1), clf, set(1, 'Color', 'w');

hHand = plot(0,0, 'r.', 'MarkerSize', 5);
hold on
hTarget = plot(0,0, 'gx', 'MarkerSize', 15);

xlim([-100 100]);
ylim([-100 100]);
xlabel('x');
ylabel('y');

try
  while(1)
    z = udpMexReceiver('pollGroups');
    
    [tf, idx] = ismember('handInfo', {z.name});
    if ~tf
      handInfo = z(idx).signals;
      set(hHand, 'XData', handInfo.handX, 'YData', sig.handY);
    end
    
    [tf, idx] = ismember('param', {z.name});
    if ~tf
      param = z(idx).signals;
      set(hTarget, 'XData', param.targetX, 'YData', param.targetY);
    end
    
    drawnow
    
    if ~ishandle(1)
      udpMexReceiver('stop');
    end
  end
catch ME
  udpMexReceiver('stop');
  rethrow(ME);
end