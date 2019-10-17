function [] = FDC2214EVM_delay
%% Delay test on FDC2214 EVM using Arduino Nano

  if ispc
    arduinoPort = "COM6";
    EVMPort = "COM5";
  elseif isunix
    arduinoPort = "/dev/ttyUSB0";
    EVMPort = "/dev/ttyACM0";
  end

  % open serial to arduino
  a = serial(arduinoPort, 'BaudRate', 1000000);
  fopen(a);
  % set pin LOW as initial condition
  fwrite(a, '0', 'char', 'sync'); pause(1);

  % open serial to FDC2214EVM
  ts = FDC2x14EVM(EVMPort);
  %ts.open(115200, 2);
  ts.open(4000000, 2);

  % open file for writing
  fileID = fopen('FDC2214data.txt', 'w');
  fprintf(fileID, '%7s %12s %12s %12s %12s %12s %12s %12s\n', ...
    '# count', 'time(sec)', 'samplingTime', 'sensor1', 'sensor2', 'sensor3', 'sensor4', 'arduinoState');
  
  % What to plot?: 1 - frequency; 2 - total capacitance; 3 - sensor Capacitance; 4 - raw data
  iPlot = 2;

  %% create our clean up object
  cleanupObj = onCleanup(@()cleanMeUp(a, ts));

  %% collect data
  samplingSteps = 1000; % loop size
  samplingPause = 0; % samplingTime (in msec)
  
  arduinoPulse = 50; % arduino switch pulse
  arduinoPause = 0;  % after-switch pause (in msec)

  t = zeros(1,samplingSteps);
  data = zeros(4,4,samplingSteps);
  samplingTime = zeros(1,samplingSteps);
  arduinoState = zeros(1,samplingSteps);
  arduinoTime = zeros(1,floor(samplingSteps/arduinoPulse));
  switchTime = zeros(1,floor(samplingSteps/arduinoPulse));

  iSwitch = 0; switchStart = 0; switchTolerance = 5; 
  % start streaming
  ts.startStreaming; pause(0.5);
  % start stopwatch timer
  tStart = clock;
  for i = 1:samplingSteps
    if i ~= 1 && mod(i, arduinoPulse) == 1
      if arduinoState(i-1) == 0
        tic
        fwrite(a, '1', 'char', 'sync'); % pin HIGH
        [asciiRecv, ~] = fread(a,1,'char');
        tArduino = toc;
        arduinoState(i) = 1;
      else
        tic
        fwrite(a, '0', 'char', 'sync'); % pin LOW
        [asciiRecv, ~] = fread(a,1,'char');
        tArduino = toc;
        arduinoState(i) = 0;
      end
      
      switchStart = clock;
      iSwitch = iSwitch + 1;
      arduinoTime(iSwitch) = tArduino;
      
      pause(arduinoPause/1000);
    else
      if i == 1
        arduinoState(i) = 0;
      else
        arduinoState(i) = arduinoState(i-1);
      end
    end
    
    tic;
    %[data(:,1,i), data(:,2,i), data(:,3,i), data(:,4,i), ~] = ts.scanChannels;
    [data(:,1,i), data(:,2,i), data(:,3,i), data(:,4,i), ~] = ts.getStreamingData;
    samplingTime(i) = toc;
    
    if i ~= 1 && abs(data(1,iPlot,i) - data(1,iPlot,i-1)) > switchTolerance
      switchTime(iSwitch) = etime(clock, switchStart);
    end
    
    t(i) = etime(clock, tStart);
    fprintf(fileID, '%7u %u %12.6f %8u %8u %8u %8u %8u\n', ...
      i, t(i), samplingTime(i), data(1:4,iPlot,i), arduinoState(i));
    
    pause(samplingPause/1000);
  end
  ts.stopStreaming;

  %[asciiRecv, nValues] = fscanf(a);

  fclose(fileID);
  % Clean up all serial objects
  cleanMeUp(a, ts);
  
  % plotting
  ax1 = subplot(4,1,1); % top subplot
  plot(ax1, t, samplingTime*1000);
  ylabel(ax1, 'sampling time (msec)');
  ax2 = subplot(4,1,2);
  plot(ax2, t, reshape(data(1,iPlot,:), [numel(data(1,iPlot,:)), 1]));
  ylabel(ax2, 'total capacitance (pF)');
  ax3 = subplot(4,1,3);
  plot(ax3, t, arduinoState);
  ylabel(ax3, 'arduino state');
  ax4 = subplot(4,1,4);
  plot(ax4,switchTime);
  ylabel(ax4, 'delay (sec)')
  
  % statistics
  disp(datastats(switchTime(1:end-1)'));
  disp(datastats(arduinoTime(1:end-1)'));

end

% fires when main function terminates
function cleanMeUp(a, ts)
  stopasync(a); % Stop asynchronous read and write operations
  fclose(a);
  clear a;
  
  ts.delete;
  clear ts;
end