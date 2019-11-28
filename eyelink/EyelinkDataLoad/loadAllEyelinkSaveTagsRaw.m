function [R, meta, saveTags] = loadAllEyelinkSaveTagsRaw(folder)

  if nargin < 1 || strcmp(folder, '')
    folder = uigetdir('', 'Choose Eyelink protocol folder');
  end

  % enumerate saveTag folders in that directory
  list = dir(folder);
  mask = false(numel(list), 1);
  saveTags = nan(numel(list), 1);

  for i = 1:numel(list)
    if ~list(i).isdir, continue, end
    r = regexp(list(i).name, 'saveTag(\d+)', 'tokens');
    if ~isempty(r)
      saveTags(i) = str2double(r{1});
      mask(i) = true;
    end
  end

  saveTags = saveTags(mask);
  list = list(mask);

  if isempty(saveTags)
    error('Could not find any save tags in directory %s', folder);
  end

  nST = numel(saveTags);
  %prog = ProgressBar(nST, 'Loading %d save tags', nST);
  [Rc, metac] = deal(cell(nST));

  for iST = 1:nST
    [Rc{iST}, metac{iST}] = loadEyelinkSaveTagRaw(folder, saveTags(iST));
  end

  R    = MatUdp.Utils.structcat(cat(1, Rc{:}));
  meta = MatUdp.Utils.structcat(cat(1, metac{:}));
  
end