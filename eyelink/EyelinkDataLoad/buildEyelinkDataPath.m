function folder = buildEyelinkDataPath(varargin)
% Build the path to the protocol folder /dataRoot/dataStore/subject/date/protocol
  
  p = inputParser();
  p.addRequired('subject', ...
    @(x) validateattributes(x, {'char'}, {'nonempty', 'row'}));
  p.addRequired('protocol', ...
    @(x) validateattributes(x, {'char'}, {'nonempty', 'row'}));
  p.addParameter('dateStr', datestr(now, 'yyyy-mm-dd'), ...
    @(x) validateattributes(x, {'char'}, {'nonempty', 'row', 'numel', 10}));
  p.addParameter('dataStore', 'NCCLab_Rig1', ...
    @(x) validateattributes(x, {'char'}, {'nonempty', 'row'}));
  p.addParameter('dataRoot', '', ...
    @(x) validateattributes(x, {'char'}, {'row'}));
  p.parse(varargin{:});

  if ~isempty(p.Results.dataRoot)
    dataRoot = p.Results.dataRoot;
  else
    % add to your .bashrc if not system wide:
    % export EYELINK_DATAROOT=/eyeTrackerLogger/data
    dataRoot = getenvCheckPath('EYELINK_DATAROOT');
  end
  
  folder = fullfile(dataRoot, ...
    p.Results.dataStore, p.Results.subject, p.Results.dateStr, p.Results.protocol);
end

% Check the path from evironment variable
function val = getenvCheckPath(key)
  val = getenvString(key);
  assert(exist(val, 'dir') > 0, 'Directory %s not found, from environment variable %s', val, key);
end

% Get environment variable. The key must be a string scalar or character vector.
% Returns the enviroment variable as a character vector.
function val = getenvString(key)
  val = getenv(key);
  if isempty(val)
    error('Environment variable %s not found. Use setenv to create it.', key);
  end
end