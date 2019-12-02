function [trials, meta] = loadAllFilesInDirectoryRaw(folder, varargin)
  % returns all trials and meta files as cell arrays
  p = inputParser();
  p.addParameter('maxTrials', Inf, ...
    @(x) validateattributes(x, {'numeric'}, {'scalar', 'positive'}));
  p.parse(varargin{:});
  maxTrials = p.Results.maxTrials;

  if ~exist(folder, 'dir')
    error('Folder %s does not exist', folder);
  end

  files = dir(fullfile(folder, '*.edf'));
  if isempty(files)
    error('No EDF files found in %s', folder);
  end

  names = {files.name};
  nFiles = numel(files);

  data = cell(nFiles+1, 1);
  meta = cell(nFiles, 1);
  valid = false(nFiles, 1);

  %prog = ProgressBar(nFiles, 'Loading .mat in %s', folder);
  for i = 1:nFiles
    %prog.update(i);
    
    data{i} = EyelinkDataLoad.parseEDFFile(fullfile(folder,names{i}));
    
    
    %{
    d = load(fullfile(folder,names{i}), 'trial', 'meta');
    if ~isempty(d) && isfield(d, 'trial') && isfield(d, 'meta')
      % strip groups
      [data{i}, meta{i}] = deal(d.trial, d.meta);
      valid(i) = true;
    end
    %}
    
    valid(i) = true;
  end
  %prog.finish();

  trials = data(valid);
  %meta = meta(valid);

end