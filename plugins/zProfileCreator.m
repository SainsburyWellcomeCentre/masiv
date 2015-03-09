classdef zProfileCreator<goggleBoxPlugin
    %ZPROFILECREATOR Creates a z profile for precise x y adjustment
    %#ok<*ST2NM>
    properties
    end
    
    methods
        function obj=zProfileCreator(caller, ~)
            obj=obj@goggleBoxPlugin(caller);
            mainDisp=obj.goggleViewer.mainDisplay;
            t=obj.mosaicInfo;
            
            %% Default view
            x=num2str(round(mainDisp.viewXLimOriginalCoords(1)));
            y=num2str(round(mainDisp.viewYLimOriginalCoords(1)));
            w=num2str(round(diff(mainDisp.viewXLimOriginalCoords)));
            h=num2str(round(diff(mainDisp.viewYLimOriginalCoords)));
            
            %% Define the region to use to calculate the offsets. x,y, specify the top left corner
            xywh=inputdlg({'x', 'y', 'w', 'h'}, 'Region spec for z-profile calculation', 1, {x y w h});
            if isempty(xywh)
                 deleteRequest(obj)
                return
            else
                try
                    xywh=cellfun(@str2num, xywh);
                catch
                    errordlg('Invalid specification. Aborting.')
                    deleteRequest(obj)
                    return
                end
            end
            try
                chan=obj.goggleViewer.overviewDSS.channel;
                o=mosaicStackOffset(t, chan, xywh);
            catch err
                 deleteRequest(obj)
                 rethrow(err)
            end
            %% Check that in the region you care about, the offsets aren't too far off 0
            
            [xoffset, yoffset]=getOffsetAdjustment(o);
            
            o(:,1)=o(:, 1)+xoffset;
            o(:,2)=o(:, 2)+yoffset;
            
            o=round(o);
            
            %%
            [f,p]=uiputfile({'*.zpfl', 'Z-Profile (*.zpfl)'; '*.csv', 'CSV-File (*.csv)'; '*.*', 'All Files (*.*)'}, 'Select path to save profile', gbSetting('defaultDirectory'));
            if isempty(f)||isempty(p)||isnumeric(p)||~exist(p, 'dir')
                deleteRequest(obj)
            else
            dlmwrite(fullfile(p,f), o);
            end
            deleteRequest(obj)
        end
        
        function deleteRequest(obj)
            deleteRequest@goggleBoxPlugin(obj);
        end
    end
    methods(Static)
        function f=displayString()
            f='Create Z-profile...';
        end
    end

    
end

function offsets=mosaicStackOffset(t, channelToCalculateOn, regionSpec)

    nLayers=t.metaData.layers;
    
    f=fullfile(t.baseDirectory, t.stitchedImagePaths.(channelToCalculateOn));
    
    fSource=f(nLayers+1:nLayers:end);
    fTarget=f(nLayers:nLayers:end-1);
    offsets=getImageFilesXYOffsets(fSource, fTarget, regionSpec, 50, 0);
    
    %% Centre and expand
    offsets=cat(1, zeros(1, 2), offsets);
    offsets=bsxfun(@minus, offsets, median(offsets));
    
    offsets=reshape(repmat(offsets, 1,nLayers)', 2, [])';

end

function offsets=getImageFilesXYOffsets(imageFileListSource, imageFileListTarget, regionSpec, maxMove, exceedMaxBehaviour)
% GETXYOFFSETS Loads specific image regions from a list and calculates the
% registration parameters between consecutive pairs of images. Returns the
% CUMULATIVE offset for each image (i.e. the offset relative to the first
% image)

    if ~all(size(imageFileListSource)==size(imageFileListTarget))
        error('File Lists must be the same size')
    end    
    
    offsets=zeros(numel(imageFileListSource), 2);
    %% Process each pair
    swb=SuperWaitBar(numel(imageFileListTarget), 'Calculating sectional offsets...');

    parfor ii=1:numel(imageFileListTarget)
        swb.progress; %#ok<PFBNS>
        if ~exist(imageFileListTarget{ii}, 'file')||~exist(imageFileListSource{ii}, 'file')
            offsets(ii, :)=[0 0];
        else
            regionSpecAdjusted=checkImagesForCropAndAdjustRegionSpecToMach(imageFileListTarget{ii}, imageFileListSource{ii}, regionSpec);
            targetImageFFT=fft2(openTiff(imageFileListTarget{ii}, regionSpecAdjusted, 1));
            sourceImageFFT=fft2(openTiff(imageFileListSource{ii}, regionSpecAdjusted, 1));
            output=dftregistration(targetImageFFT, sourceImageFFT, 1);
            offsets(ii, :)=output(3:4);
        end
    end
    
    delete(swb)
    clear swb
    % Sort out where it's too much
    eucDist=sqrt(sum(offsets.^2, 2));
    switch exceedMaxBehaviour
        case 0
            offsets(eucDist>maxMove, :)=0;
        case 1
            offsets(eucDist>maxMove, :)=offsets(eucDist>maxMove, :)*maxMove./eucDist;
        otherwise
            error('Unrecognised exceedMaxBehaviour')
    end
    %% Make it cumulative
    offsets=cumsum(offsets);
end

function regionSpec=checkImagesForCropAndAdjustRegionSpecToMach(filePath1, filePath2, regionSpec)
inf1=imfinfo(filePath1);
inf2=imfinfo(filePath2);

if isfield(inf1, 'XPosition')
    xOffset1=inf1.XPosition;
    yOffset1=inf1.YPosition;
else
    xOffset1=0;
    yOffset1=0;
end
if isfield(inf2, 'XPosition')
    xOffset2=inf2.XPosition;
    yOffset2=inf2.YPosition;
else    
    xOffset1=0;
    yOffset1=0;
end

if ~(xOffset1==xOffset2)||~(yOffset1==yOffset2)
    error('Crop offsets should match')
end

regionSpec=regionSpec-[xOffset1, yOffset1, 0, 0]';


end

function [xOffset, yOffset]=getOffsetAdjustment(o)
mainFig=figure('NumberTitle', 'off', 'Name', 'Z profile', 'CloseRequestFcn', '');
hAx=axes(...
    'Parent', mainFig, ...
    'Position', [0.1 0.1 0.7 0.85]);

hPlots=plot(hAx, o);
legend('x offsets', 'y offsets')
xlabel('Image number')
ylabel('Movement (in pixels)')

xOffset=0;
yOffset=0;

%% Adjustment boxes
uicontrol(...
    'Parent', mainFig, ...
    'Units', 'normalized', ...
    'Style', 'text', ...
    'Position', [0.825 0.68 0.15 0.05], ...
    'String', 'X offset');
xBox=uicontrol(...
    'Parent', mainFig, ...
    'Units', 'normalized', ...
    'Style', 'edit', ...
    'Position', [0.825 0.63 0.15 0.06], ...
    'String', '0', ...
    'Callback', @editboxChangeCallback, ...
    'UserData', xOffset);
uicontrol(...
    'Parent', mainFig, ...
    'Units', 'normalized', ...
    'Style', 'text', ...
    'Position', [0.825 0.48 0.15 0.05], ...
    'String', 'Y offset');
yBox=uicontrol(...
    'Parent', mainFig, ...
    'Units', 'normalized', ...
    'Style', 'edit', ...
    'Position', [0.825 0.43 0.15 0.06], ...
    'String', '0', ...
    'Callback', @editboxChangeCallback, ...
    'UserData', yOffset);

uicontrol(...
    'Parent', mainFig, ...
    'Units', 'normalized', ...
    'Style', 'pushbutton', ...
    'Position', [0.825 0.1 0.15 0.1], ...
    'String', 'OK', ...
    'Callback', @carryOn);
%%
uiwait(mainFig)
%% Callback
    function editboxChangeCallback(caller, ~)
        toStr=str2num(caller.String);
        if isempty(toStr)|| isnan(toStr)
            caller.String=caller.UserData;
        else
            caller.UserData=caller.String;
            xOffset=str2num(xBox.String);
            yOffset=str2num(yBox.String);
            hPlots(1).YData=(o(:, 1)+xOffset)';
            hPlots(2).YData=(o(:, 2)+yOffset)';
        end
    end
    function carryOn(~,~)
        uiresume(gcbf);
        delete(mainFig);
    end
end

