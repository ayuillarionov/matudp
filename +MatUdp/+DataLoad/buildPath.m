% Build the path to the protocol folder /dataRoot/subject/date/protocol
function folder = buildPath(varargin)
  p = inputParser();
  p.addRequired('subject', @ischar);
  p.addRequired('protocol', @ischar);
  p.addParameter('dateStr', datestr(now, 'yyyy-mm-dd'), @ischar);
  p.addParameter('dataRoot', '', @(x) ischar(x));
  p.parse(varargin{:});

  if ~isempty(p.Results.dataRoot)
    dataRoot = p.Results.dataRoot;
  else
    dataRoot = getenvCheckPath('MATUDP_DATAROOT');
  end

  folder = fullfile(dataRoot, p.Results.subject, p.Results.dateStr, p.Results.protocol);
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