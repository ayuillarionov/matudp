classdef EyelinkNetworkShell < DisplayController
  % This class runs a shell that receives network commands over udp
  % and allows remote control of the task on screen
  %
  % The network commands operate inside a virtual workspace. The evaluation
  % function automatically saves and restores the variables in this workspace
  % so that successively sent commands can access variables created in earlier
  % commands. The evaluation function can automatically add any
  % created ScreenObject instances to the ScreenObjectManager as well,
  % if autoAddScreenObjectsToManager == true (default). This saves repeated calls
  % to mgr.add() and mgr.remove()
  %
  
  properties
    % if true, all ScreenObject instances that exist in the evaluation
    % workspace will be automatically added to the ScreenObjectManager
    % which saves you from needing to send mgr.add(...) and .remove(...)
    % calls across the network
    autoAddScreenObjectsToManager = true;
  end
  
  properties
    netLog % ScreenLog object for logging network incoming commands
    showNetLogs = true; % show netLogs on the desktop screen if true
    
    lastInfoPollTime
  end
  
  properties
    eli  % EyeLink info object
    elc  % EyeLink controller
    lastEyePollTime
    
    eyeLeft           % EYE_LEFT data from EyeTracker
    eyeRight          % EYE_RIGHT data from EyeTracker
    showEyes = false; % speedgoat data used on Display PC if false
    
    lastRecordingStartTime % last recording start time
    
    eyeTrackerLoggerDirectory = [filesep, 'eyeTrackerLogger', filesep, 'data']; % default edf files storage, pwd if empty
  end
  
  properties
    hold % test center circular
  end
  
  properties
    fileID = -1; % eyelink raw data storage file
  end
  
  methods
    function ns = EyelinkNetworkShell(varargin)
      ns = ns@DisplayController(varargin{:});
      ns.name = 'EyelinkNetworkShell';
    end
  end
  
  methods(Access = protected)
    function initialize(ns)
      ns.setTask('DisplayTask');
      
      ns.addNetScreenLogs(); % log of all the received network packets
      
      % set eyes on the screen as cyan/blue crosses
      ns.eyeLeft = Cursor(); % non-touching Cross(0,0,10,10)
      ns.eyeLeft.color = [0 1 1]; % cyan
      ns.mgr.add(ns.eyeLeft);
      ns.eyeLeft.hide();
      
      ns.eyeRight = Cursor(); % non-touching Cross(0,0,10,10)
      ns.eyeRight.color = [0.6 0.6 1];
      ns.mgr.add(ns.eyeRight);
      ns.eyeRight.hide();
      
      ns.hold = Circle(0,0,(15+2*10)/2); % test circle(xc, yc, radius)
      ns.hold.borderWidth = 0.25;
      ns.hold.borderColor = ns.sd.red;
      ns.hold.fillColor = ns.sd.red;
      ns.hold.fill = true;
      ns.mgr.add(ns.hold);
      ns.hold.hide();
      %ns.mgr.remove(ns.hold);
      
      % initialize Eyelink (if ON and connected)
      ns.initializeEyelink();
    end
    
    function addNetScreenLogs(ns)
      % log of all the received network packets
      ns.netLog = ns.addLog('Network Rx Log:');
      ns.netLog.titleColor = ns.sd.red;
      ns.netLog.entrySpacing = 1; % vertical gap between entries in data
      ns.netLog.titleSpacing = 2; % spacing below title before first entry
      if ~ns.showNetLogs
        ns.netLog.hide();
        %dc.mgr.remove(ns.netLog);
      end
    end
    
    function initializeEyelink(ns)
      ns.cleanup();
      
      ns.fileID = fopen('rawEyelinkData.txt', 'a');
      
      ns.lastRecordingStartTime = datetime('now', 'TimeZone', 'Europe/Zurich', 'Format', 'd-MMM-y HH:mm:ss Z');
      ns.eli = EyeLinkInfo(ns.si, 'ns', ['Desktop time: ', char(ns.lastRecordingStartTime)]);
      ns.elc = EyeLinkController(ns.eli, [], ns.eyeTrackerLoggerDirectory);
      
      %ns.elc.saveLastCalibrationFiles('monkey')
      %ns.elc.loadLastStoredCalibrationFiles('monkey')
      %ns.elc.deleteStoredCalibrationFiles()
      
      if (Eyelink('IsConnected') > 0)
        ns.elc.startRecording();
      end
    end
    
    function cleanup(ns)
      if ~isempty(ns.eli) && isvalid(ns.eli)
        if ns.eli.isOpen && (Eyelink('IsConnected') > 0)
          ns.elc.stopRecording();
          ns.elc.downloadFile(['ns', char(datetime(ns.lastRecordingStartTime, 'Format', 'yMMd.HHmmss'))]);
        end
      end
      if isobject(ns.elc)
        ns.elc.delete();
      end
      if isobject(ns.eli)
       ns.eli.delete();
      end
      
      if  ns.fileID >= 0
        fclose(ns.fileID);
        ns.fileID = -1;
      end
    end
    
    function update(ns)
      % called once each frame
      ns.readNetwork();
      ns.hideMouseIfNotPolled();
      
      % check if eyelink is available. try to open if not
      if ns.eli.isOpen && ~Eyelink('IsConnected') % lost connection to EyeTracker. TODO: save ns.edf file on the next opening
        ns.eli.close();
      elseif ~ns.eli.isOpen
        ns.initializeEyelink();
      end
      
      %{
      % send eye data each frame if Eyelink is recording
      if ns.eli.isOpen
        error = Eyelink('CheckRecording');
        if error == 0
          ns.sendEyePacket();
        end
      end
      %}
      
      % get raw data if Eyelink is recording
      if ns.eli.isOpen
        status = ns.elc.getNewestFloatSampleRaw();
        
        %if (status == ns.elc.eli.el.SAMPLE_TYPE) && ...
        %    any(ns.elc.evt.hdata(1:4) ~= ns.elc.eli.el.MISSING_DATA)
        if (status > 0) && ...
            any(ns.elc.evt.hdata(1:4) ~= 0)
          disp(ns.elc.evt)
          disp(ns.elc.raw)
          
          time = ns.elc.evt.time;
          input = ns.elc.evt.input;
          hdata = ns.elc.evt.hdata;
          
          fprintf(ns.fileID,'%12d %12d %12d %12d %12d %12d %12d %12d %12d %12d\n', time, input, hdata);
        end
      end

      %{
      % show Eyes on the screen if Eyelink is recording
      if ns.showEyes && ns.eli.isOpen
        % get the copy of most resent gaze position, if Eyelink is recording
        % -1 if none or error, 0 if old, 1 if new
        [time, gazeX, gazeY, status] = ns.elc.getGazePosition(); %#ok<ASGLU>
        if status
          if ~isnan(gazeX(1)) && ~isnan(gazeY(1))
            ns.eyeLeft.seen = 1;
            ns.eyeLeft.xc = gazeX(1);
            ns.eyeLeft.yc = gazeY(1);
            ns.eyeLeft.show();
          else
            ns.eyeLeft.seen = 0;
            ns.eyeLeft.hide();
          end
          if ~isnan(gazeX(2)) && ~isnan(gazeY(2))
            ns.eyeRight.seen = 1;
            ns.eyeRight.xc = gazeX(2);
            ns.eyeRight.yc = gazeY(2);
            ns.eyeRight.show();
          else
            ns.eyeRight.seen = 0;
            ns.eyeRight.hide();
          end
        end
      else
        ns.eyeLeft.hide();
        ns.eyeRight.hide();
      end
      %}
      
    end
    
    function readNetwork(ns)
      groups = ns.com.readGroups();
      evalCommands = {};
      
      for iG = 1:length(groups)
        group = groups(iG);
        
        switch group.name
          case 'eval'
            if isfield(group.signals, 'eval')
              % evaluate a command directly in the network workspace
              evalCommands{end+1} = group.signals.eval; %#ok<AGROW>
              ns.netLog.add(group.signals.eval);
            else
              ns.log('Eval group received without eval signal');
            end

          case 'setTask'
            if isfield(group.signals, 'setTask')
              taskName = group.signals.setTask;
            elseif isfield(group.signals, 'taskName')
              taskName = group.signals.taskName;
            else
              ns.log('setTask group received without taskName or setTask signal');
              continue;
            end
            if isfield(group.signals, 'taskVersion')
              taskVersion = group.signals.taskVersion;
            else
              taskVersion = NaN;
            end
            ns.setTask(taskName, taskVersion);
            ns.addNetScreenLogs();
            ns.updateControlStatus(); % update controlStatus
            
            ns.logEyelink('dataStore: %s, subject: %s, protocol: %s, protocolVersion: %d, Trial: %d', ...
              ns.controlStatus.dataStore, ns.controlStatus.subject, ...
              ns.controlStatus.protocol, ns.controlStatus.protocolVersion, ...
              ns.controlStatus.currentTrial);
            
          case 'taskCommand'
            % calls .runCommand on the current DisplayTask
            % runCommand receives the name of the command and a containers.Map
            % handle that contains the current net workspace (groups received via
            % 'ds' tags)
            if isfield(group.signals, 'taskCommand')
              taskCommands = group.signals.taskCommand;
              if ischar(taskCommands)
                taskCommands = {taskCommands};
              end
              
              for i = 1:numel(taskCommands)
                ns.task.runCommand(taskCommands{i}, ns.taskWorkspace);
              end
            else
              ns.log('taskCommand group received without taskCommand signal');
            end
            
          case 'infoPoll'
            % xpc has requested the mouse position
            ns.showMouse(); % show the mouse so we know what to point with
            ns.sendInfoPacket(); % send the data back to xpc
            
            ns.log('Sending mouse position');
            
          case 'eyePoll'
            % xpc has requested the eyes position
            ns.sendEyePacket(); % send the data back to xpc
            
            ns.log('Sending eyes position');
            
          case {'eyelinkCommand', 'eyelinkMessage'}
            % xpc sent the command/message to Eyelink
            type = group.signals.type;     % 1 -- command; 2 -- message
            com  = group.signals.command;
            args = group.signals.args;
            
            status = ns.sendCommandtoEyelink(type, com, args);
            
            switch type
              case 1
                ns.log('Sending command to Eyelink. status = %i', status);
              case 2
                ns.log('Sending message to Eyelink. status = %i', status);
              otherwise
            end
            
          otherwise
            % add to the task workspace
            ns.addToTaskWorkspace(group.name, group.signals);
        end
      end
      
      % run all eval commands at once
      if ~isempty(evalCommands)
        ns.evaluate(evalCommands);
      end
    end
    
    % send Command or Message to Eyelink.
    % Only chars and ints allowed in arguments!
    % Allows 500 msec. for command to finish.
    function status = sendCommandtoEyelink(ns, type, com, args)
      status = -1;

      if isvalid(ns.eli) && ns.eli.isOpen
        if Eyelink('IsConnected') > 0
          switch type
            case 1 % command. returns command result
              status = ns.eli.sendCommand(com, args); % sendCommand(char/string, char/string/cell/numeric array)
            case 2 % message. returns any send error
              status = ns.eli.sendMessage(com, args); % sendMessage(char/string, char/string/cell/numeric array)
            otherwise
              status = -1;
          end
        end
      end
    end
    
    function sendInfoPacket(ns)
      % send information about the screen flip
      screenFlip = 1;
      [mouseX, mouseY, buttons] = ns.sd.getMouse();
      mouseClick = any(buttons); % True if any element of a vector is a nonzero number or is logical 1 (TRUE)
      
      data = [...
        uint8('<displayInfo>'), ...
        uint8(screenFlip), ...
        typecast(mouseX, 'uint8'), ...
        typecast(mouseY, 'uint8'), ...
        uint8(mouseClick), ...
        ];
      ns.com.writePacket(data);
      
      ns.lastInfoPollTime = tic;
    end
    
    function sendEyePacket(ns)
      % get the copy of most resent gaze position, if Eyelink is recording
      % -1 if none or error, 0 if old, 1 if new
      [time, gazeX, gazeY, status] = ns.elc.getGazePosition();

      if ~all(isnan(gazeX)) || ~all(isnan(gazeY))
        data = [...
          uint8('<displayEye>'), ...
          uint8(status), ...
          typecast(double(gazeX), 'uint8'), ...
          typecast(double(gazeY), 'uint8'), ...
          typecast(uint32(time), 'uint8'), ...
          ];
        ns.com.writePacket(data);
      end
      
      ns.lastEyePollTime = tic;
    end
    
    function hideMouseIfNotPolled(ns)
      % if lastInfoPollTime was sufficiently long ago, then we hide the
      % mouse cursor
      
      pollExpireTimeSec = 0.1; % seconds for poll
      
      if isempty(ns.lastInfoPollTime) || toc(ns.lastInfoPollTime) >= pollExpireTimeSec
        ns.hideMouse();
      end
    end
    
    function evaluate(ns, cmdList)
      % assign these commonly used items to the workspace so they are accessible
      % by the network commands
      % cmdList is a cell array (or single string) of commands sent across the network
      
      % mgr is the ScreenObjectManager which draws everything
      mgr = ns.mgr;
      
      % sd is the ScreenDraw object
      sd = ns.sd;
      
      if ischar(cmdList)
        cmdList = {cmdList};
      end
      local.cmdList = cmdList;
      clear cmdList;
      
      % list of names not to overwrite or save as part of the network workspace
      local.excludedNames = {'mgr', 'ns', 'sd', 'local'};
      
      % expand the saved workspace
      if ~isempty(ns.taskWorkspace)
        ns.restoreWorkspace(ns.taskWorkspace, local.excludedNames);
      end
      
      % attempt to evaluate
      local.iCmd = 1;
      while local.iCmd <= length(local.cmdList)
        local.cmd = local.cmdList{local.iCmd};
        
        try
          eval(local.cmd);
        catch exc
          fprintf('Error: %s\n', local.report);
          % log the exception in the debugLog
          local.report = exc.message;
          % remove html tags like <a> from the report as they won't display well
          local.report = regexprep(local.report, '<[^>]*>([^<>])*</[^>]*>', '$1');
          ns.log('NetworkShell_withEyeLink: error executing %s\n%s', local.cmd, local.report);
          clear exc;
        end
        
        local.iCmd = local.iCmd + 1;
      end
      
      % now grab all the screen objects and store them in the manager
      %ns.saveFoundScreenObjectsInMgr(local.excludedNames);
      
      % save the workspace for next time
      ns.taskWorkspace = ns.saveWorkspace(local.excludedNames);
    end
    
    function clear(ns)
      % clear all objects of type ScreenObject from calling workspace
      vars = evalin('caller', 'whos');
      varNames = {vars.name};
      
      for i = 1:length(varNames)
        if ismember(varNames{i}, {'ans'})
          continue;
        end
        val = evalin('caller', varNames{i});
        if isa(val, 'ScreenObject')
          evalin('caller', sprintf('clear(''%s'')', varNames{i}));
        end
      end
    end
    
    function saveFoundScreenObjectsInMgr(ns, excludedNames)
      % find all ScreenObjects in calling workspace and save them into ns.mgr
      vars = evalin('caller', 'whos');
      varNames = {vars.name};
      varNames = setdiff(varNames, excludedNames);
      
      objList = [];
      for i = 1:length(varNames)
        val = evalin('caller', varNames{i});
        if isa(val, 'ScreenObject')
          %fprintf('Adding to manager : %s\n', varNames{i});
          objList = [objList val]; %#ok<AGROW>
        end
      end
      
      ns.mgr.objList = objList;
    end
    
    function [objList, objNames] = getWorkspaceScreenObjects(ns, excludedNames)
      % assemble a list of all the ScreenObject instances saved in ns.taskWorkspace
      if ~exist('excludeNames', 'var')
        excludedNames = {};
      end
      
      objList = [];
      objNames = {};
      
      ws = ns.taskWorkspace;
      if isempty(ws)
        return;
      end
      
      varNames = fieldnames(ws);
      varNames = setdiff(varNames, excludedNames);
      
      for i = 1:length(varNames)
        val = ws.(varNames{i});
        if isa(val, 'ScreenObject')
          objList = [objList val]; %#ok<AGROW>
          objNames = [objNames varNames{i}]; %#ok<AGROW>
        end
      end
    end
    
    function ws = saveWorkspace(ns, excludedNames) %#ok<INUSL>
      % save every variable in calling workspace into a struct
      % except for variables whos names are in excludeNames
      ws = struct();
      
      if ~exist('excludeNames', 'var')
        excludedNames = {};
      end
      
      vars = evalin('caller', 'whos');
      varNames = {vars.name};
      varNames = setdiff(varNames, excludedNames);
      
      for i = 1:length(varNames)
        %fprintf('Saving to workspace : %s\n', varNames{i});
        
        % grab the value in the calling workspace
        val = evalin('caller', varNames{i});
        ws.(varNames{i}) = val;
      end
    end
    
    function restoreWorkspace(ns, ws, excludedNames) %#ok<INUSL,INUSD>
      if ~exist('excludeNames', 'var')
        excludedNames = {}; %#ok<NASGU>
      end
      
      varNames = ws.keys;
      for i = 1:length(varNames)
        %if ismember(varNames{i}, union(excludedNames, 'ans'))
        %    continue;
        %end
        
        %                fprintf('Restoring var %s\n', varNames{i});
        % write this variable into the calling workspace
        assignin('caller', varNames{i}, ws(varNames{i}));
      end
    end
  end
  
  methods
    % send log message to Eyelink with printf like arguments
    function status = logEyelink(ns, message, varargin)
      status = -1;
      
      messageStr = sprintf(message, varargin{:});
      ns.log(messageStr); % send also to debugLog
      % add local time
      str = sprintf('[ %12s ] : %s', datestr(now, 'HH:MM:SS.FFF'), messageStr);
      
      if isvalid(ns.eli) && ns.eli.isOpen
        if (Eyelink('IsConnected') > 0 && Eyelink('CheckRecording') == 0)
          status = ns.sendCommandtoEyelink(2, str, []);
        end
      end
    end
  end
  
end