classdef RewardPredictiveTargets_Task < DisplayTask
    
    properties
        trialFailed = false;
        
        target       % instance of CircleTarget class
        
        targetActive % reference to one of the above fields
        
        cursor       % handInfo
        eye          % eyeInfo
        
        photobox
        
        sound        % AudioFeedback()
        
        commandMap   % containers.Map : command string -> method handle
    end
    
    methods
        % dc is display controller, which is assigned before initialize is called
        function task = RewardPredictiveTargets_Task()
            task.name = 'RewardPredictiveTargets_Task';
            task.buildCommandMap();
        end
        
        % called when task becomes active
        function initialize(task, ~)
            task.target = CircleTarget(0, 0, 0); % CircleTarget(xc, yc, radius)
            task.target.hide();
            task.dc.mgr.add(task.target);
            
            task.cursor = CursorRound(); % non-touching Circle(0,0,5)
            task.cursor.hide();
            task.dc.mgr.add(task.cursor);
            
            task.eye = Cursor(); % non-touching Cross(0,0,10,10)
            task.eye.hide();
            task.dc.mgr.add(task.eye);
            
            task.photobox = Photobox(task.dc.cxt); % photobox(DisplayContext)
            task.photobox.off();
            task.dc.mgr.add(task.photobox);
            
            task.sound = AudioFeedback();
            
            % -- hide logs from subject screen
            task.dc.debugLog.hide();
            task.dc.netLog.hide();
        end
        
        
        % called when task is becoming inactive
        function cleanup(task, data) %#ok<INUSD>
          if task.dc.showDebugLogs
            task.dc.debugLog.show();
          end
          if task.dc.showNetLogs
            task.dc.netLog.show();
          end
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
                eyeInfo = data.eyeInfo;
                % save the last eye position only
                task.eye.xc = eyeInfo.eyeX(end);
                task.eye.yc = eyeInfo.eyeY(end);
                task.eye.seen = eyeInfo.eyeSeen;
                if ~strcmp(task.eye.seen, 'NOT_SEEN')
                  %task.eye.show();
                end
            end
        end
        
        % called when a tagged packet <taskCommand>command</taskCommand> comes in
        function runCommand(task, command, data)
            if task.commandMap.isKey(command)
                fprintf('Running taskCommand %s\n', command);
                fn = task.commandMap(command);
                fn(data);
            else
                fprintf('Unrecognized taskCommand %s\n', command);
            end
        end
        
        function buildCommandMap(task)
            map = containers.Map('KeyType', 'char', 'ValueType', 'any'); % Map values to unique keys
            
            % Mask State
            map('MaskAcquired') = @task.maskAcquired;
            
            % TaskControl
            map('TaskPaused') = @task.pause;
            map('StartTask') = @task.start;
            map('InitTrial') = @task.initTrial;
            
            % Target
            map('TargetNeutralOn') = @task.targetNeutralOn;
            map('TargetPredictiveOn') = @task.targetPredictiveOn;
            map('TargetOff') = @task.targetOff;
            
            % TrailSuccess
            map('RewardTonePlay') = @task.rewardTonePlay;
            map('ITI') = @task.iti;
            
            % TrialFailure
            map('FailureEdeNotSeen') = @task.failureEyeNotSeen;
            
            task.commandMap = map;
        end
        
        function pause(task, ~) % 'TaskPaused'
            task.target.hide();
            task.cursor.hide();
            task.eye.hide();
            task.photobox.off();
        end
        
        function start(task, ~) % 'StartTask'
            %task.eye.show();
            task.photobox.off();
        end
        
        function initTrial(task, data) % 'InitTrial'
            task.trialFailed = false;
            
            %task.eye.show();
            
            % -- screen background
            bColor = double(data.P.backgroundColorRGBA)'/255;
            task.dc.sd.fill(bColor);
            
            % -- target
            task.target.xc = data.C.targetXMM;
            task.target.yc = data.C.targetYMM;
            task.target.radius = data.P.targetDiameterMM/2;
            task.target.borderWidth = 1;
            task.target.borderColor = [0 0 1]; % initially blue
            task.target.fillColor = [0 0 1];   % initially blue
            task.target.normal();
            task.target.hide();
            
            % -- photobox
            task.photobox.off();
            
            task.dc.log('Initialize Trial');
        end
        
        function maskAcquired(task, data) %#ok<INUSD> % 'MaskAcquired'
          task.sound.playMaskAcquired();
          
          task.photobox.toggle();
          
          task.dc.log('Mask Acquired');
        end

        function targetNeutralOn(task, data) % 'TargetNeutralOn'
            fColor = double(data.P.targetNeutralColorRGBA)'/255;
            task.target.borderColor = fColor;
            task.target.fillColor = fColor;
            task.target.show();
            
            task.photobox.toggle();
            
            task.dc.log('Target Neutral On');
        end
        
        function targetPredictiveOn(task, data) % 'TargetPredictiveOn'
            fColor = double(data.P.targetPredictiveColorRGBA)'/255;
            task.target.borderColor = fColor;
            task.target.fillColor = fColor;
            task.target.show();
            
            task.photobox.toggle();
            
            task.dc.log('Target Predictive On');
        end
        
        function targetOff(task, ~) % 'TargetOff'
            task.target.hide();
            
            task.photobox.toggle();
            
            task.dc.log('Target Off');
        end
        
        function rewardTonePlay(task, data) %#ok<INUSD>
            task.target.success();
            task.sound.playSuccess();
            
            %{
            TD = data.trialData;
            rewardToneOff = double(TD.rewardTonePulseInterval - TD.rewardTonePulseLength);
            task.sound.playTonePulseTrain(TD.rewardTonePulseHz, double(TD.rewardTonePulseLength), ...
              rewardToneOff, double(TD.rewardTonePulseReps));
            %}
            
            task.photobox.off();
            
            task.dc.log('Reward Tone Play: Trial Success');
        end
        
        function iti(task, ~)
            task.target.hide();
            
            task.photobox.off();
            
            task.dc.log('ITI');
        end
        
        function failureEyeNotSeen(task, data) %#ok<INUSD>
          task.sound.playFailure();
          
          task.photobox.toggle();
          
          task.dc.log('Eye Not Seen');
        end
    end
    
end