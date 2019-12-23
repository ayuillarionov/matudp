function [timeRange, pupilSize] = getPupilSize(obj, startIdx, endIdx)
  assert(isa(obj, 'edf2mat'), 'edf2mat:edf_plot:getPupilSize', ...
    'Only objects of type edf2mat can be plotted!');

  if ~exist('startIdx', 'var')
    startIdx = 1;
  end

  if ~exist('endIdx', 'var')
    endIdx = numel(obj.Samples.posX);
  end

  range = startIdx:endIdx;

  assert(numel(range) > 0, ...
    'edf2mat:edf_plot:getPupilSize:range','Start Index == End Index, nothing do be plotted');

  pupilSize = obj.Samples.pupilSize(range);
  timeRange = obj.Samples.time(range);
end