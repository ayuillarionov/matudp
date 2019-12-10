function trials = parseEDFFile(varargin)
  p = inputParser();
  p.addRequired('fileName', ...
    @(x) validateattributes(x, {'char'}, {'nonempty', 'row'}));
  p.parse(varargin{:});
  fileName = p.Results.fileName;
  
  trials = {};
  
  command = 'edf2asc -v -y -p /tmp'; % EyeLink EDF file -> ASCII (text) file translator
  
  % outputs sample GAZE data if present (default)
  [status_gaze, cmdout] = system([command, ' -sg ', fileName, ' gaze.asc']);
  % outputs sample RAW PUPIL position if present
  %[status_raw, cmdout] = system([command, ' -sp ', fileName, ' raw_pupil.asc']);
  % outputs sample HREF angle data if present
  %[status_href, cmdout] = system([command, ' -sh ', fileName, ' href.asc']);
  
  headerLines = {};
  preScaler = 1;
  
  iTrial = 0;
  
  % parse GAZE output
  fName = '/tmp/gaze.asc';
  fid = fopen(fName, 'r');
  if fid == -1
    error('Cannot open file: %s', FileName);
  end
  
  while ~feof(fid)
    line = fgetl(fid);
    
    % read the header
    if strncmp(line, '** ', 3)
      headerLines{end+1} = line;
      continue;
    end
    
    % get DISPLAY_COORDS
    
    % get prescaler
    if strncmp(line, 'PRESCALER', 9)
      preScaler = str2double(line(10:end));
      continue;
    end
    
    [check, trialInfo] = isStartTrial(line);
    if check
      iTrial = iTrial +1;
      disp(trialInfo)
      continue;
    end
      
  end
  
  disp(iTrial)
  
  fclose(fid);

end

function check = isMSG(line)
  check = strncmp(line, 'MSG', 3);
end

function [check, trialInfo] = isStartTrial(line)
  trialInfo = struct([]);
  
  if isMSG(line)
    check = any(contains(line, 'TrialId'));
  else
    check = false;
  end
  if check
    c = strsplit(line);
    trialInfo.eyelinkTime = str2double(c(2));
    trialInfo.displayTime = char(c(4));
    trialInfo.dataStore   = char(c(8));
    trialInfo.subject     = char(c(10));
    trialInfo.protocol    = char(c(12));
    trialInfo.protocolVersion = str2double(c(14));  % TODO strip ,
    trialInfo.trialId     = str2double(c(16));
  end
end