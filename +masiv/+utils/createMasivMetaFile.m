function createMasivMetaFile(mode)
% createMasivMetaFile: Interactive prompt to create a metadata file for MaSIV image viewer
%
% Will ask for the following parameters needed to run MaSIV, and save these
% to a metadata file
%
% MaSIV Directory: The folder in which the metadata file itself, and all
% generated downsampled stacks, will reside
%
% VoxelSize: The size of the image voxels in X, Y, Z
%
% stackName: The name of the MaSIV stack. This will be used mostly for
% display purposes only; it need not match in any way the nomenclature used
% for individual image slices. The metadata file generated will be of the
% format <stackName>_Meta.yml, and generated downsampled image stacks will
% be of the format <stackName>_<channelName>_<downsampling>.tif
%
% imageBaseDirectory: The directory relative to which ImageList files can
% be found. For example:
% 
%    imageBaseDirectory: /foo/bar
%    <stackName>_ImageList_<channelName>.txt contains:
%       folder1/image1.tif
%       folder1/image2.tif
%       folder2/image3.tif
% 
%   In this case, the second image is found at /foo/bar/folder1/image1.tif
%
%   imageBaseDirectory may be an absolute path, or specified relative to
%   the masiv directory defined earlier, since it is often simplest to keep
%   the metadata with the image data. The GUI creation mode, however, will
%   always save this as a full absolute path. This can simply be changed by
%   opening the resulting _Meta.yml file and editing this entry
%
%  Alex Brown, August 2017
%


    %#ok<*ST2NM>

    %% Input parsing
    if nargin < 1 || isempty(mode)
        if masiv.utils.isGraphicsAvailable
            mode='gui';
        else
            mode='cl';
        end
    end

    if ~masiv.utils.isGraphicsAvailable && strcmpi(mode, 'gui')
        warning('Graphical interface not available. Falling back to command line interface')
        mode='cl';
    end
    %% Processing
    switch lower(mode)
        case 'gui'
            
            %% Directory
            masivDirectory           = uigetdir([], 'MaSIV directory for this experiment');
            
            %% Dimensions
            dims=inputdlg({'X:', 'Y:', 'Z:'}, 'MaSIV Meta File Voxel Size', 1, {'1', '1', '5'});
            while all(cellfun(@(x) ~isempty(str2num(x)), dims))
                dims=inputdlg({'X:', 'Y:', 'Z:'}, 'MaSIV Meta File Voxel Size', 1, {'1', '1', '5'});
            end
            S.VoxelSize.X = str2num(dims{1});
            S.VoxelSize.Y = str2num(dims{2});
            S.VoxelSize.Z = str2num(dims{3});
            
            %% Name
            name =inputdlg('Stack Name:', 'MaSIV Meta File Creation', 1);
            while isempty(name)
                name =inputdlg('Stack Name:', 'MaSIV Meta File Creation', 1);
            end
            S.stackName = name;
            
            %% Image Base Directory
            
            S.imageBaseDirectory = uigetdir([], 'MaSIV Image Base Directory');
            
        case 'cl'
            masivDirectory          = getAndValidateCommandLineInput('\nPlease enter full path to the MaSIV directory for this experiment: ', @(x) exist(x, 'dir'));
            S.VoxelSize.X           = getAndValidateCommandLineInput('\nPlease enter voxel size in X: ', @(x) ~isempty(str2num(x)), @str2num); 
            S.VoxelSize.Y           = getAndValidateCommandLineInput('\nPlease enter voxel size in Y: ', @(x) ~isempty(str2num(x)), @str2num);
            S.VoxelSize.Z           = getAndValidateCommandLineInput('\nPlease enter voxel size in Z: ', @(x) ~isempty(str2num(x)), @str2num);
            S.stackName             = getAndValidateCommandLineInput('\nPlease enter stack name (used for display purposes only): ', @(x) ischar(x));
            S.imageBaseDirectory    = getAndValidateCommandLineInput('\nPlease enter image base directory (may be relative to this metadata file): ', @(x) testAbsoluteRelativeExistence(masivDirectory, x));
        otherwise
            error('Unknown mode. Available options are ''gui'' [graphical user interface] or ''cl'' [command line]')
    end
    
    %% Output
    masiv.yaml.writeSimpleYAML(S, fullfile(masivDirectory, [S.stackName '_Meta.yml']))
    
end


function v=getAndValidateCommandLineInput(prompt, conditionFunction, conversionFunction)

     v=input(prompt, 's');   

     while isempty(v) || ~conditionFunction(v)
         warning('Data validation failed, please try again or press ctrl+c to cancel')
         v=input(prompt, 's');  
     end

     if nargin > 2 && ~isempty(conversionFunction)
         v=conversionFunction(v);
     end
 
end

function t=testAbsoluteRelativeExistence(masivDirectory, pth)
    if strmp(pth(1:2), '..')
        t=exist(fullfile(masivDirectory, pth), 'dir');
    else
        t=exist(pth, 'dir');
    end
end