function [saveTags, searchFolder] = listSaveTags(varargin)
    protocolRoot = MatUdp.DataLoadEnv.buildPathToProtocol(varargin{:});

    if ~exist(protocolRoot, 'dir')
        warning('Date folder %s not found', protocolRoot);
    end

    % enumerate saveTag folders in that directory
    list = dir(protocolRoot);
    mask = false(numel(list), 1);   % falsevec
    saveTags = nan(numel(list), 1); % nanvec

    for i = 1:numel(list)
        if ~list(i).isdir, continue, end
        r = regexp(list(i).name, 'saveTag(\d+)', 'tokens');
        if ~isempty(r)
            saveTags(i) = str2double(r{1});
            mask(i) = true;
        end
    end

    saveTags = saveTags(mask);
    searchFolder = protocolRoot;
end