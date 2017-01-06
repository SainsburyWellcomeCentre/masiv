function setupMaSIV_path
	%Add MaSIV directories to the MATLAB path
    MaSIVBasePath = fileparts(which('masiv'));
    MaSIVDirs = fullfile(MaSIVBasePath,'code');
    
    if ispc
        splitString=';';
    else
        splitString=':';
    end
    
    MaSIVPath=strsplit(genpath(MaSIVDirs), splitString);
    p=strsplit(path, splitString);
    
    toAddToPath=setdiff(MaSIVPath, p); %only add to path if dirs aren't already present
    toAddToPath(cellfun(@isempty, toAddToPath))=[]; %remove any blank entries
    
    if numel(toAddToPath)>0
	    fprintf('Adding MaSIV to path for this session\n')
	    addpath(toAddToPath{:},'-end')
    end
end
