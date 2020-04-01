function [taskName, taskVersion] = getTaskInfoFromPath(file)
% Infers the task version based on the folder where this file is located
% assumes I live in path ending in /TaskName/vVersionNumber/

if (nargin < 1)
  % Return the path to the folder in which the currently executing file is located
  
  % display the stack trace info, returned as m-by-1 structure (file, called name, current line)
  stack = dbstack('-completenames');
  if numel(stack) <= 2
    % assume executing in cell mode
    file = matlab.desktop.editor.getActiveFilename(); % find file name of active document
  else
    file = stack(2).file;
  end
end

while( ~isempty(file) )
  [parent, leaf, ext] = fileparts(file);
  % parent has /taskName/vVersionNumber/ in it, leaf is file name
  [parent, vstring] = fileparts(parent);
  [~, taskName] = fileparts(parent);
  
  if vstring(1) ~= 'v'
    file = fileparts(file);
    continue;
  else
    taskVersion = str2double(vstring(2:end));
    return;
  end
end

error('Parent folder must begin with v########');

end