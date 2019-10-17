classdef EyelinkModel_Task < DisplayTask
  
  properties
    trialFailed = false;
    
    center       % instance of CircleTarget class
    
    target       % instance of CircleTarget class
    
    targetActive % reference to one of the above fields
    
    cursor       % handInfo
    eyeLeft      % eyeInfo
    eyeRight     % eyeInfo
    
    hold         % holdWindow
    
    sound        % AudioFeedback()
    
    photobox
    
    commandMap   % containers.Map : command string -> method handle
  end
  
  properties
    TargetCenter = 0;
  end
  
  properties
    showHold = false;
  end
  
  methods
    % dc is display controller, which is assigned before initialize is called
    function task = EyelinkModel_Task()
      task.name = 'EyelinkModel_Task';
      task.showHold = true;
      task.buildCommandMap();
    end
    
    % called when task becomes active
    function initialize(task, ~)
      task.center = CircleTarget(0, 0, 0); % Circle(xc, yc, radius)
      task.center.hide();
      task.dc.mgr.add(task.center);  % add to the ScreenObjectManager
      
      task.target = CircleTarget(0, 0, 0); % CircleTarget(xc, yc, radius)
      task.target.hide();
      task.dc.mgr.add(task.target);
      
      task.cursor = CursorRound(); % non-touching Circle(0,0,5)
      task.cursor.hide();
      task.dc.mgr.add(task.cursor);
      
      task.eyeLeft = Cursor(); % non-touching Cross(0,0,10,10)
      task.eyeLeft.color = [0 1 1]; % cyan
      task.eyeLeft.hide();
      task.dc.mgr.add(task.eyeLeft);
      
      task.eyeRight = Cursor(); % non-touching Cross(0,0,10,10)
      task.eyeRight.color = [0.6 0.6 1];
      task.eyeRight.hide();
      task.dc.mgr.add(task.eyeRight);
      
      task.hold = Circle(0,0,0); % Rectangle(xc, yc, radius)
      task.hold.hide();
      task.dc.mgr.add(task.hold);
      
      task.photobox = Photobox(task.dc.cxt); % photobox(DisplayContext)
      task.photobox.off();
      task.dc.mgr.add(task.photobox);
      
      %task.sound = AudioFeedback();
      
      task.dc.showEyes = true; % show eyes position recieved from Eyetracker
    end
    
    % called when task is becoming inactive
    function cleanup(task, data) %#ok<INUSD>
    end
    
    % called once each frame
    function update(task, data)
      if isfield(data, 'handInfo')
        handInfo = data.handInfo;
        task.cursor.xc = handInfo.handX;
        task.cursor.yc = handInfo.handY;
        task.cursor.touching = handInfo.handTouching;
        task.cursor.seen = handInfo.handSeen;
        %task.cursor.show();
      end
      if isfield(data, 'eyeInfo')
        task.dc.showEyes = false; % show only eyes position recieved from Speedgoat
        eyeInfo = data.eyeInfo;
        if strcmp(eyeInfo.eyeSeen, 'LEFT_EYE')
          task.eyeLeft.seen  = 1;
          task.eyeRight.seen = 0;
          task.eyeLeft.xc    = double(eyeInfo.eyeX(1));
          task.eyeLeft.yc    = double(eyeInfo.eyeY(1));
          task.eyeLeft.show();
          task.eyeRight.hide();
        elseif strcmp(eyeInfo.eyeSeen, 'RIGHT_EYE')
          task.eyeLeft.seen  = 0;
          task.eyeRight.seen = 1;
          task.eyeRight.xc   = double(eyeInfo.eyeX(2));
          task.eyeRight.yc   = double(eyeInfo.eyeY(2));
          task.eyeLeft.hide();
          task.eyeRight.show();
        elseif strcmp(eyeInfo.eyeSeen, 'BINOCULAR')
          task.eyeLeft.seen  = 1;
          task.eyeRight.seen = 1;
          task.eyeLeft.xc    = double(eyeInfo.eyeX(1));
          task.eyeLeft.yc    = double(eyeInfo.eyeY(1));
          task.eyeRight.xc   = double(eyeInfo.eyeX(2));
          task.eyeRight.yc   = double(eyeInfo.eyeY(2));
          task.eyeLeft.show();
          task.eyeRight.show();
        else
          task.eyeLeft.seen  = 0;
          task.eyeRight.seen = 0;
        end
      else
        task.dc.showEyes = true;
      end
      
      task.dc.showEyes = false;
      task.eyeLeft.hide();
      task.eyeRight.hide();
    end
    
    % called when a tagged packet <taskCommand>command</taskCommand> comes in
    function runCommand(task, command, data)
      if task.commandMap.isKey(command)
        fprintf('Running taskCommand %s\n', command);
        fn = task.commandMap(command);
        fn(data);
        
        %{
        if isfield(data, 'trialData')
          disp([task.eyeLeft.xc, task.eyeLeft.yc, task.eyeRight.xc, task.eyeRight.yc]);
          disp(data.trialData.eyeTraced);
          disp(data.trialData.eyeSeen);
          disp([data.trialData.inFixationCenterWindow, data.trialData.inFixationTargetWindow]);
          disp(data.trialData.failureCode);
        end
        %}
      
      else
        fprintf('Unrecognized taskCommand %s\n', command);
      end
    end
    
    function buildCommandMap(task)
      map = containers.Map('KeyType', 'char', 'ValueType', 'any'); % Map values to unique keys
      
      % TaskControl
      map('TaskPaused') = @task.pause;
      map('StartTask') = @task.start;
      map('InitTrial') = @task.initTrial;

      % CenterAcquireHold
      map('CenterOnset') = @task.centerOnset;
      map('CenterAcquired') = @task.centerAcquired;
      map('CenterHeld') = @task.centerHeld;
      map('CenterUnacquired') = @task.centerUnacquired;
      
      % DelayPeriodGoCue
      map('GoCueZeroDelay') = @task.goCueZeroDelay;
      map('DelayPeriodStart') = @task.delayPeriodStart;
      map('GoCueNonZeroDelay') = @task.goCueNonZeroDelay;
      map('MoveOnset') = @task.moveOnset;
      
      % TargetAcquireHold
      map('TargetAcquired') = @task.targetAcquired;
      map('TargetHeld') = @task.targetHeld;
      
      % TrailSuccess
      map('Success') = @task.success;
      map('ITI') = @task.iti;
      
      % TrialFailure
      map('FailureCenterFlyAway') = @task.failureCenterFlyAway;
      map('FailureTargetFlyAway') = @task.failureTargetFlyAway;
      
      task.commandMap = map;
    end
        
    function pause(task, ~)
      task.center.hide();
      task.target.hide();
      task.cursor.hide();
      task.eyeLeft.hide();
      task.eyeRight.hide();
      task.hold.hide();
      task.photobox.off();
      
      task.dc.showEyes = true; % show Eyes on the screen if Eyelink is recording
      
      task.dc.logEyelink('Task Paused');
    end
    
    function start(task, ~)
      task.dc.showEyes = false; % hide eyes recieved from Eyelink
      
      %task.eyeLeft.show();
      %task.eyeRight.show();
      task.photobox.off();
      
      task.dc.log('Start Task');
    end

    function initTrial(task, data)
      task.trialFailed = false;
      
      %task.eyeLeft.show();
      %task.eyeRight.show();
      
      P = data.P; % trial's parameters
      C = data.C; % trial's condition
      
      task.center.xc = C.centerX;
      task.center.yc = C.centerY;
      task.center.radius = P.centerDiameter/2;
      task.center.borderWidth = 0;
      task.center.borderColor = [0 0 1]; % blue
      task.center.fillColor = [0 0 1]; % blue
      task.center.normal(); % set defaults
      task.center.hide();
      
      task.hold.borderWidth = 0.25;
      task.hold.borderColor = task.dc.sd.red;
      task.hold.fill = false;
      task.hold.fillColor = task.dc.sd.red;
      task.hold.hide();
      
      task.target.xc = C.targetX;
      task.target.yc = C.targetY;
      task.target.radius = C.targetDiameter/2;
      task.target.vibrateSigma = P.delayVibrateSigma;
      task.target.borderWidth = 1;
      task.target.borderColor = [0 0 1]; % blue
      task.target.fillColor = [0 0 1]; % blue
      task.target.normal(); % set defaults
      task.target.hide();
      
      task.photobox.off();

      %task.center.show();
      %task.target.show();
      %task.photobox.on();
      
      task.dc.logEyelink('Initialize Trial: Target (x,y, diameter) = (%g,%g, %g)', ...
        C.targetX, C.targetY, C.targetDiameter);
    end
    
    function centerOnset(task, ~)
      task.center.show();
      
      task.dc.logEyelink('Center Onset');
    end
    
    function centerAcquired(task, data)
      task.center.borderWidth = 1;
      task.center.borderColor = [0 0 1]; % blue

      if task.showHold
        task.hold.xc = data.C.centerX;
        task.hold.yc = data.C.centerY;
        task.hold.width = data.P.centerDiameter + 2*data.P.acceptanceWindowPadding;
        task.hold.height = task.hold.width;
        task.hold.fill = false;
        task.hold.show();
      end

      task.dc.logEyelink('Center Acquired');
    end
    
    function centerHeld(task, ~)
      task.hold.fill = true;
      task.center.acquire();
      
      task.dc.logEyelink('Center Held');
    end
    
    function centerUnacquired(task, ~)
      task.hold.hide();
      
      task.dc.logEyelink('Center Unacquired');
    end
      
    function goCueZeroDelay(task, ~)
      task.hold.hide();
      task.center.hide();
      
      task.target.stopVibrating();
      task.target.fillIn();
      task.target.show();
      
      task.photobox.flash();
      
      task.dc.logEyelink('Go Cue Zero Delay');
    end
    
    function delayPeriodStart(task, ~)
      task.target.contour();
      task.target.vibrate();
      task.target.show();
      task.photobox.on();
      
      task.dc.logEyelink('Delay Period Start');
    end
    
    function goCueNonZeroDelay(task, ~)
      task.hold.hide();
      task.center.hide();
      
      task.target.stopVibrating();
      task.target.fillIn();
      task.target.show();
      
      task.photobox.off();
      
      task.dc.logEyelink('Go Cue');
    end
    
    function moveOnset(task, ~)
      task.dc.logEyelink('Move Onset');
    end
    
    function targetAcquired(task, data)
      task.target.borderWidth = 1;
      task.target.borderColor = [0 0 1]; % blue
      
      if task.showHold
        task.hold.xc = data.C.targetX;
        task.hold.yc = data.C.targetY;
        task.hold.width = data.C.targetDiameter + 2*data.P.acceptanceWindowPadding;
        task.hold.height = task.hold.width;
        task.hold.fill = false;
        task.hold.show();
      end
      
      task.dc.logEyelink('Target Acquired');
    end
    
    function targetHeld(task, ~)
      task.hold.fill = true;
      task.target.acquire();
      
      task.dc.logEyelink('Target Held');
    end
     
    function success(task, data) %#ok<INUSD>
      task.target.success();
      %task.sound.playSuccess();
      %{
        TD = data.ata;
        rewardToneOff = double(TD.rewardTonePulseInterval - TD.rewardTonePulseLength);
        task.sound.playTonePulseTrain(TD.rewardTonePulseHz, double(TD.rewardTonePulseLength), ...
            rewardToneOff, double(TD.rewardTonePulseReps));
      %}
      task.photobox.off();
      
      task.dc.logEyelink('Trial Success');
    end
    
    function iti(task, ~)
      task.center.hide();
      task.target.hide();
      task.hold.hide();
      
      task.photobox.off();
      
      task.dc.logEyelink('ITI');
    end
    
    function failureCenterFlyAway(task, ~)
      task.trialFailed = true;
      
      task.center.contour();
      task.center.stopVibrating();
      task.center.flyAway(task.eyeLeft.xc, task.eyeLeft.yc); % TODO
      
      task.target.hide();
      
      task.hold.hide();
      
      %task.sound.playFailure();
      
      task.photobox.off();
      
      task.dc.logEyelink('failureCenterFlyAway');
    end
    
    function failureTargetFlyAway(task, ~)
      task.trialFailed = true;
      
      task.center.hide();
      
      task.target.contour();
      task.target.stopVibrating();
      task.target.flyAway(task.eyeLeft.xc, task.eyeLeft.yc); % TODO
      
      task.hold.hide();
      
      %task.sound.playFailure();
      
      task.photobox.off();
      
      task.dc.logEyelink('failureTargetFlyAway');
    end
  end
  
end