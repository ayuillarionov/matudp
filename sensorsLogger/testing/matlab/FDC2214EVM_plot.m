function [] = FDC2214EVM_plot(serialPort)
%% Real time data collection example
% This MATLAB function generates a real time plot of total capacitance values collected from
% an FDC1004EVM or FDC2214EVM (4 Channel Capacitive Sensing to Digital Converter Evaluation Module)
% over the serial port(RS232).
% The data is collected and plotted until the predefined stop time is reached.
% This example also demonstrates automating a query based interaction with an instrument
% while monitoring the results live.
%
% This function can be modified to be used on any platform by changing the serialPort variable.
% 
% Example:-
% On Linux:     serialPort = '/dev/ttyS0';
% On MacOS:     serialPort = '/dev/tty.KeySerial1';
% On Windows:   serialPort = 'COM1';
%
% The script may also be updated to use any instrument/device to collect
% real time data. You may need to update the SCPI commands based on
% information in the instrument's programming manual.
%
% To generate a report of this entire script, you may use the PUBLISH
% command at the MATLAB(R) command line as follows:
% publish(FDC2214EVM_plot);
% 
% Author: Alexey Yu. Illarionov (ayuillarionov(at)ini(dot)uzh(dot)ch)
% Copyright 2018 - INI UZH, Zurich

%% Number of sensors plotted
nSensors = 4;
% What to plot?: 1 - frequency; 2 - total capacitance; 3 - sensor Capacitance; 4 - raw data
iPlot = 2;

%% Create the serial object
PORTLIST = seriallist;
if ~isempty(PORTLIST) && isstring(PORTLIST)
  if nargin == 0 || (nargin == 1 && ~any(strcmp(PORTLIST, serialPort)))
    serialPort = PORTLIST(end);
  end
else
  if ispc
    serialPort = "COM5";                % Windows
  elseif isunix
    serialPort = "/dev/ttyACM0";        % Linux
  elseif ismac
    serialPort = "/dev/tty.KeySerial1"; % MAC
  end
end

ts = FDC2x14EVM(serialPort);
ts.open(1000000, 2);

%% open file for writing
fileID = fopen('FDC2214data.txt','w');
fprintf(fileID, '%5s %12s %12s %8s %8s %8s %8s\n', ...
  '# count', 'time', 'samplingTime', 'sensor1', 'sensor2', 'sensor3', 'sensor4');

%% create our clean up object
cleanupObj = onCleanup(@()cleanMeUp(ts, fileID));

%% Set up the figure window
time = now;

data(1:4, 4) = 0;

figureHandle = figure('NumberTitle', 'off', ...
  'Name', 'Proximity', ...
  'Color', [0 0 0], 'Visible', 'off');

% Set axes
axesHandle = axes('Parent', figureHandle, ...
  'YGrid', 'on', ...
  'YColor', [0.9725 0.9725 0.9725], ...
  'XGrid', 'on', ...
  'XColor', [0.9725 0.9725 0.9725], ...
  'Color', [0 0 0]);

hold on;

plotHandle = plot(axesHandle, ...
  time, data(:, iPlot), ...
  'Marker', '.', 'LineWidth', 1, 'Color', [0 1 0]);

xlim(axesHandle, [min(time) max(time+0.001)]);

% Create xlabel
xlabel('Time', 'FontWeight', 'bold', 'FontSize', 14, 'Color', [1 1 0]);

% Create ylabel
switch(iPlot)
  case 1
    ylabel('Frequency [MHz]', 'FontWeight', 'bold', 'FontSize', 14, 'Color', [1 1 0]);
  case 2
    ylabel('Total Capacitance [pF]', 'FontWeight', 'bold', 'FontSize', 14, 'Color', [1 1 0]);
  case 3
    ylabel('Sensor Capacitance [pF]', 'FontWeight', 'bold', 'FontSize', 14, 'Color', [1 1 0]);
  case 4 && default
    ylabel('Raw Data', 'FontWeight', 'bold', 'FontSize', 14, 'Color', [1 1 0]);
end

% Create title
title('Proximity', ...
  'FontSize', 15, 'Color', [1 1 0]);

%% Allow to stop by pressing the return key
global PLOTLOOP; PLOTLOOP = true; % used to exit the loop
set(figureHandle, 'KeyPressFcn', @stopStream);

%% Set the time span and interval for data collection
stopTime = '06/01 18:00';
timeInterval = 0.01;

%% Collect data
count = 1;
samplingTime = 0; % samplingTime on first channel only
tStart = clock;

while PLOTLOOP || ~isequal(datestr(now,'mm/DD HH:MM'), stopTime)
    time(count) = datenum(clock);

    t = tic;
    [data(:,1,count), data(:,2,count), data(:,3,count), data(:,4,count), ~] = ts.getStreamingData;
    
    if count > 1
      for i = 1:4
        if data(i,4,count) == 0
          data(i,:,count) = data(i,:,count-1);
        end
      end
    end
    
    if count > 1 && data(1,4,count) ~= data(1,4,count-1)
      samplingTime = toc(t);
    end

    fprintf(fileID,'%5u %u %12.6f %8u %8u %8u %8u\n', ...
      count, etime(clock, tStart), samplingTime, data(1:nSensors,iPlot,count));
    
    for i = 1:nSensors
      plotHandle(i).XData = time;
      plotHandle(i).YData = data(i,iPlot,:);
    end
    
    if count > 3 % start ploting with 3 points
      figureHandle.Visible = 'on';

      % Date formatted tick labels
      %datetick('x','mm/DD HH:MM');
      datetick('x','HH:MM:SS');

      pause(timeInterval);
    end
    
    count = count + 1;
end

%% Clean up the serial object
cleanMeUp(ts, fileID);

end

% Loop Control Function
function [] = stopStream(obj, event)
  global PLOTLOOP;
  
  if strcmp(event.Key, 'return')
    PLOTLOOP = false;
    disp('Return key pressed.');
  end
end

% fires when main function terminates
function cleanMeUp(ts, fileID)
  ts.stopStreaming;
  ts.delete;
  clear ts;
  
  fclose(fileID);
end