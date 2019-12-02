function [R, meta] = loadEyelinkSaveTagRaw(folder, saveTag, varargin)

  p = inputParser();
  p.addParameter('maxTrials', Inf, ...
    @(x) validateattributes(x, {'numeric'}, {'scalar', 'integer', 'positive'}));
  p.addParameter('minDuration', 50, ...
    @(x) validateattributes(x, {'numeric'}, {'scalar', 'positive'}));
  p.KeepUnmatched = true;
  p.parse(varargin{:});
  
  maxTrials = p.Results.maxTrials;

  nST = numel(saveTag);
  [trialsC, metaByTrialC] = deal(cell(nST, 1));
  for iST = 1:nST
    folderSaveTag = fullfile(folder, sprintf('saveTag%03d', saveTag(iST)));
    [trialsC{iST}, metaByTrialC{iST}] = MatUdp.DataLoad.loadAllTrialsInDirectoryRaw(folderSaveTag, ...
      'maxTrials', maxTrials, p.Unmatched);
  end

  %debug('Concatenating trial data...\n');
  R = structcat(cat(1, trialsC{:}));
  meta = structcat(cat(1, metaByTrialC{:}));

  % filter min duration
  mask = [R.duration] > p.Results.minDuration;

  %debug('Filtering %d trials with duration < %d\n', nnz(~mask), p.Results.minDuration);
  R = R(mask);
  meta = meta(mask);
  
end