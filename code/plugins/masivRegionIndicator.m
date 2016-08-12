classdef masivRegionIndicator<masivPlugin
    properties
        hFig
        hAx
        hBackgroundRect
        hViewOutlineRect
        hImg
        
        %Editting these colors will change the displayed higlight colors.
        %Up to 8 separate colors can be used. This is 3 colors (r, g, b):
        overlayColors=hsv2rgb([0    0.3 0.6; 
                               0.8  0.8 0.8; 
                               0.8 0.8 0.8]'); 
        hMarkedOverlay

        
        mnuSetUnset
        
        fontName
        fontSize
        
        panListener
        zoomedListener
        scrollListener
    end
    methods
        function obj=masivRegionIndicator(caller, ~)
            obj=obj@masivPlugin(caller);
            obj.MaSIV=caller.UserData;
            
            %% Settings
            obj.fontName=masivSetting('font.name');
            obj.fontSize=masivSetting('font.size');
            try
                pos=masivSetting('regionIndicator.figurePosition');
            catch
                ssz=get(0, 'ScreenSize');
                lb=[ssz(3)/3 ssz(4)/3];
                pos=round([lb 300 200]);
                masivSetting('regionIndicator.figurePosition', pos)
            end
            %% Main UI initialisation
            obj.hFig=figure(...
                'Position', pos, ...
                'CloseRequestFcn', {@deleteRequest, obj}, ...
                'MenuBar', 'none', ...
                'NumberTitle', 'off', ...
                'Name', ['Overview: ' obj.MaSIV.Meta.stackName], ...
                'Color', masivSetting('viewer.panelBkgdColor'), ...
                'KeyPressFcn', {@setParentFigureFocus, obj}, ...
                'Visible', 'off', ...
                'AlphaMap', [0 0.3 1]);
            obj.hAx=axes(...
                'Parent', obj.hFig, ...
                'Position', [0 0 1 1], ...
                'Visible', 'off');
            bkgdRectPos=[1 1 obj.MaSIV.MainStack.xCoordsVoxels(end) obj.MaSIV.MainStack.yCoordsVoxels(end)];
                
            obj.hBackgroundRect=rectangle('Parent', obj.hAx, 'Position', bkgdRectPos, 'FaceColor', 'k', 'EdgeColor', 'none');
            
           
            %% Image initialisation
            obj.hImg=image(obj.MaSIV.MainStack.xCoordsVoxels([1 end]), ...
                           obj.MaSIV.MainStack.yCoordsVoxels([1 end]), ...
                           [0 0;0 0], 'CDataMapping', 'scaled');
            obj.updateOverviewImage;
            axis(obj.hAx, 'image')
            obj.hAx.Visible='off';
            colormap(obj.hFig, gray);
            caxis(obj.hAx,obj.MaSIV.mainDisplay.contrastLims);
            %% Draw highlighter image and outline rectangles
            hold on
            for ii=1:size(obj.overlayColors, 1)
                blank=ones(bkgdRectPos(4), bkgdRectPos(3), 'uint16');
                highlightImage=uint16(65535*cat(3, blank*obj.overlayColors(ii, 1), ...
                                            blank*obj.overlayColors(ii, 2), ...
                                            blank*obj.overlayColors(ii, 3)));
                                  
                obj.hMarkedOverlay{ii}=image(bkgdRectPos(1):bkgdRectPos(3), bkgdRectPos(2):bkgdRectPos(4), highlightImage, 'AlphaDataMapping', 'Direct');
                obj.hMarkedOverlay{ii}.AlphaData=false(bkgdRectPos(4), bkgdRectPos(3));
            end
            obj.hViewOutlineRect=rectangle('Parent', obj.hAx, 'Position', bkgdRectPos, 'EdgeColor', 'y');
            obj.setOutlineRectPosition
            hold off
            
            %% Menu initialisation
            obj.mnuSetUnset=uicontextmenu;
            setMnu=uimenu(obj.mnuSetUnset, 'Label', 'Add current region marking');
                for ii=1:size(obj.overlayColors, 1)
                    uimenu(setMnu, 'Label', 'Mark', 'ForegroundColor', obj.overlayColors(ii, :), 'Callback', {@setCurrentViewAsMarked, obj, ii});
                end
            unsetMnu=uimenu(obj.mnuSetUnset, 'Label', 'Remove current region marking');
                for ii=1:size(obj.overlayColors, 1)
                    uimenu(unsetMnu, 'Label', 'Unmark', 'ForegroundColor', obj.overlayColors(ii, :), 'Callback', {@resetCurrentViewAsMarked, obj, ii});
                end
                uimenu(unsetMnu, 'Label', 'Remove All Marks', 'Separator', 'on', 'Callback', {@resetCurrentViewAsMarked, obj, 0});
            uimenu(obj.mnuSetUnset, 'Label', 'Save region marking', 'Separator', 'on', 'Callback', {@saveAlphaMap, obj})
            uimenu(obj.mnuSetUnset, 'Label', 'Load region marking', 'Callback', {@loadAlphaMap, obj})
            uimenu(obj.mnuSetUnset, 'Label', 'Adjust Levels', 'Separator', 'on', 'Callback', {@adjustLevels, obj})
            obj.hImg.UIContextMenu=obj.mnuSetUnset;
            obj.hViewOutlineRect.UIContextMenu=obj.mnuSetUnset;
            for ii=1:numel(obj.hMarkedOverlay)
            obj.hMarkedOverlay{ii}.UIContextMenu=obj.mnuSetUnset;
            end
            %% Set listeners
            obj.panListener=event.listener(obj.MaSIV, 'Panned', @obj.setOutlineRectPosition);
            obj.zoomedListener=event.listener(obj.MaSIV, 'Zoomed', @obj.setOutlineRectPosition);
            obj.scrollListener=event.listener(obj.MaSIV, 'Scrolled', @obj.updateOverviewImage);

            %% Ready to roll: Display!
            obj.hFig.Visible='on';
        end
        %% Callbacks
        function setOutlineRectPosition(obj, ~, ~)
            [xPos, yPos]=obj.getCurrentPos;
            pos=[xPos(1) yPos(1) diff(xPos) diff(yPos)];
            obj.hViewOutlineRect.Position=pos;
        end
        function updateOverviewImage(obj, ~,~)
            obj.hImg.CData=obj.MaSIV.MainStack.I(:,:,obj.MaSIV.mainDisplay.currentIndex);
        end
       
        %% Methods
        function [xPos, yPos]=getCurrentPos(obj)
            xPos=obj.MaSIV.mainDisplay.viewXLimOriginalCoords;
            yPos=obj.MaSIV.mainDisplay.viewYLimOriginalCoords;
        end
    end
    methods(Static)
        function d=displayString()
            d='Overview Window';
        end
    end
end

%% Callbacks
function deleteRequest(~, ~, obj)
    masivSetting('regionIndicator.figurePosition', obj.hFig.Position)
    deleteRequest@masivPlugin(obj);
    delete(obj.hFig);
    delete(obj);
end

function setCurrentViewAsMarked(~, ~, obj, n)
    [xPos, yPos]=obj.getCurrentPos;
    xPos=round(xPos);yPos=round(yPos);
    obj.hMarkedOverlay{n}.AlphaData(yPos(1):yPos(2), xPos(1):xPos(2))=true;
end
function resetCurrentViewAsMarked(~, ~,obj, n)
    [xPos, yPos]=obj.getCurrentPos;
    xPos=round(xPos);yPos=round(yPos);
    if n>0
        obj.hMarkedOverlay{n}.AlphaData(yPos(1):yPos(2), xPos(1):xPos(2))=false;
    else
        for ii=1:numel(obj.hMarkedOverlay)
            obj.hMarkedOverlay{ii}.AlphaData(yPos(1):yPos(2), xPos(1):xPos(2))=false;
        end
    end
end

function saveAlphaMap(~,~,obj)
    I=convertAlphaMapsToSingleImage(obj.hMarkedOverlay);
    [f,p]=uiputfile('*.tif', 'Save Mark Map as...', masivSetting('defaultDirectory'));
    if ~isempty(f)&&~isempty(p)&&~isnumeric(p)&&~isnumeric(f)
        imwrite(I,fullfile(p,f))
        msgbox('Image Saved')
    end
end
function outputImage=convertAlphaMapsToSingleImage(imageArray)
set(gcf, 'pointer', 'watch');drawnow
outputImage=zeros(size(imageArray{1}.CData, 1), size(imageArray{1}.CData, 2), 'uint8');
for ii=1:numel(imageArray);
    outputImage=outputImage+uint8(2^(ii-1)*imageArray{ii}.AlphaData);
end
set(gcf, 'pointer', 'arrow');drawnow
end

function loadAlphaMap(~,~,obj)
    [f,p]=uigetfile('*.tif', 'Load Map Markings', masivSetting('defaultDirectory'));
    if ~isempty(f)&&~isempty(p)&&~isnumeric(p)&&~isnumeric(f)
        I=imread(fullfile(p,f));
        convertSingleImageToAlphaMapsAndSet(I, obj);
    end
end
function convertSingleImageToAlphaMapsAndSet(I, obj)
    for ii=1:numel(obj.hMarkedOverlay)
        obj.hMarkedOverlay{ii}.AlphaData=logical(bitget(I, ii));    
    end
end

function setParentFigureFocus(~,~,obj)
figure(obj.MaSIV.hFig)
end
function adjustLevels(~, ~, obj)
    w=380;
    h=150;
    p=obj.hFig.Position;
    pos=[p(1)+(p(3)-w)./2 p(2)+(p(4)-h)./2, w, h];
    
    d = dialog('Position', pos,'Name','Adjust Overview Image Levels');
%% Set up input controls    
    
    axLims=caxis(obj.hAx);

    hMin = uicontrol('Parent',d,...
        'Style','edit',...
        'Position',[65 90 80 20],...
        'String',num2str(axLims(1)), ...
        'Callback', @validateNumericInput);
    hMin.Tag=hMin.String;
    
    uicontrol('Parent',d,...
        'Style','text',...
        'Position',[5 88 55 20],...
        'String','Min:', ...
        'HorizontalAlignment', 'right');
    
    hMax = uicontrol('Parent',d,...
        'Style','edit',...
        'Position',[65 60 80 20],...
        'String',num2str(axLims(2)), ...
        'Callback', @validateNumericInput);
    hMax.Tag=hMax.String;
    
    uicontrol('Parent',d,...
        'Style','text',...
        'Position',[5 58 55 20],...
        'String','Max:', ...
        'HorizontalAlignment', 'right');
    
    uicontrol('Parent',d,...
        'Position',[65 10 70 25],...
        'String','Cancel',...
        'Callback','delete(gcf)');
    
    uicontrol('Parent',d,...
        'Position',[140 10 70 25],...
        'String','Apply',...
        'Callback', @updateLevel);
    
    uicontrol('Parent',d,...
        'Position',[215 10 70 25],...
        'String','Auto', ...
        'Callback', @setAutoLevel);
    
    uicontrol('Parent',d,...
        'Position',[290 10 70 25],...
        'String','OK', ...
        'Callback', {@updateLevel, 1});
    
    %% Callbacks
    function updateLevel(~, ~, doClose)
        if nargin <3 || isempty(doClose)
            doClose=0;
        end
        caxis(obj.hAx, [str2num(hMin.String), str2num(hMax.String)]); %#ok<ST2NM>
        
        if doClose
            close(d)
        end
    end

    function validateNumericInput(src,~)  
        str=src.String;
        if isempty(str2num(str)) %#ok<ST2NM>
            src.String=src.Tag;
        else
            src.Tag=src.String;
        end
    end

    function setAutoLevel(~,~)
        hMin.String=num2str(prctile(obj.hImg.CData(:), 1));
        hMax.String=num2str(prctile(obj.hImg.CData(:), 99));
        updateLevel();
    end
end
    
   



