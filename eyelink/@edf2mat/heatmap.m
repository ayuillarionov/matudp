function [heatMap, gaze, plotRange] = heatmap(obj, startIdx, endIdx, eye)
%% HEATMAP generating heatMap data
%
%% Description
%   This function generates the data array (heatMap) for visualize a heatmap of the
%   eyetracker. As a second output it returns an array (gaze) with all
%   positions rated the same.

  %% Initialization,checking
  assert(isa(obj, 'edf2mat'), 'edf2mat:edf_plot:heatmap', ...
    'Only objects of type edf2mat can be plotted!');

  if ~exist('startIdx', 'var')
    startIdx = 1;
  end

  if ~exist('endIdx', 'var')
    endIdx = size(obj.Samples.posX, 1);
  end

  if ~exist('eye', 'var')
    eye = 1;
  end

  range = startIdx:endIdx;
  assert(numel(range) > 0, 'edf2mat:edf_plot:heatmap:range', ...
    'Start Index == End Index, nothing do be plotted');

  %% variables
  gaussSize = 80;
  gaussSigma = 20;

  posX = obj.Samples.posX(range, eye);
  posY = obj.Samples.posY(range, eye);

  %% generating data for heatmap
  gazedata = [posY, posX];
  gazedata = gazedata(~isnan(gazedata(:, 1)), :);

  % set minimum x and y to zero
  for i=1:size(gazedata, 2)
    gazedata(:, i) = gazedata(:, i) - min(gazedata(:, i));
  end

  gazedata = ceil(gazedata) + 1;
  data = accumarray(gazedata, 1);
  data = flipud(data); % flip array in up/down direction

  %% smoothing the Data
  gaze = zeros(size(data));
  cut = mean(data(:));
  data(data > cut) = cut;

  kernel = createGauss2D(gaussSize, gaussSigma);
  heatMap = conv2(data, kernel, 'same');

  % map with gazepoints on the value of the mean of the heatmap
  gaze(data > 0) = mean(heatMap(:));

  % calculated plotrange (min to max on each axes)
  plotRange = [min(posX), max(posX), min(posY), max(posY)];
  if plotRange(1) < 0
    plotRange(1:2) = [0, max(posX) + abs(plotRange(1))];
  end
  if plotRange(3) < 0
    plotRange(3:4) = [0, max(posY) + abs(plotRange(3))];
  end
  
  plotRange = [0, obj.screenWidthMM, 0, obj.screenHeightMM]; % fit to screen coordinate
  
  plotRange = floor(plotRange);
end

function gauss = createGauss2D(size, sigma)
  [Xm, Ym] = meshgrid(linspace(-.5, .5, size));

  s = sigma / size; % gaussian width as fraction of imageSize
  gauss = exp( -(( (Xm.^2) + (Ym.^2) ) ./ (2*s^2)) ); % formula for 2D gaussian
end