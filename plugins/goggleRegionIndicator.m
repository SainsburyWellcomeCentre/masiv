classdef goggleRegionIndicator<goggleBoxPlugin
    properties
        hFig
        hAx
        hBackgroundRect
        hMarkedOverlay
        hViewOutlineRect
        hImg
        
        mnuSetUnset
        
        fontName
        fontSize
        
        panListener
        zoomedListener
        scrollListener
    end
    methods
        function obj=goggleRegionIndicator(caller, ~)
            obj=obj@goggleBoxPlugin(caller);
            obj.goggleViewer=caller.UserData;
            
            %% Settings
            obj.fontName=gbSetting('font.name');
            obj.fontSize=gbSetting('font.size');
            try
                pos=gbSetting('regionIndicator.figurePosition');
            catch
                ssz=get(0, 'ScreenSize');
                lb=[ssz(3)/3 ssz(4)/3];
                pos=round([lb 300 200]);
                gbSetting('regionIndicator.figurePosition', pos)
            end
            %% Main UI initialisation
            obj.hFig=figure(...
                'Position', pos, ...
                'CloseRequestFcn', {@deleteRequest, obj}, ...
                'MenuBar', 'none', ...
                'NumberTitle', 'off', ...
                'Name', ['Overview: ' obj.goggleViewer.mosaicInfo.experimentName], ...
                'Color', gbSetting('viewer.panelBkgdColor'), ...
                'KeyPressFcn', {@setParentFigureFocus, obj});
            obj.hAx=axes(...
                'Parent', obj.hFig, ...
                'Position', [0 0 1 1], ...
                'Visible', 'off');
            bkgdRectPos=[1 1 obj.goggleViewer.overviewDSS.xCoordsVoxels(end) obj.goggleViewer.overviewDSS.yCoordsVoxels(end)];
                
            obj.hBackgroundRect=rectangle('Parent', obj.hAx, 'Position', bkgdRectPos, 'FaceColor', 'k', 'EdgeColor', 'none');
            
           
            %% Image initialisation
            obj.hImg=image(obj.goggleViewer.overviewDSS.xCoordsVoxels([1 end]), ...
                           obj.goggleViewer.overviewDSS.yCoordsVoxels([1 end]), ...
                           [0 0;0 0], 'CDataMapping', 'scaled');
            obj.updateOverviewImage;
            axis(obj.hAx, 'image')
            obj.hAx.Visible='off';
            colormap(obj.hFig, gray);
            caxis(obj.hAx,obj.goggleViewer.mainDisplay.contrastLims);
            %% Draw highlighter image and outline rectangle
            hold on
            redBox=cat(3, ones(bkgdRectPos(4), bkgdRectPos(3)), zeros(bkgdRectPos(4), bkgdRectPos(3)),zeros(bkgdRectPos(4), bkgdRectPos(3)));
            obj.hMarkedOverlay=image(bkgdRectPos(1):bkgdRectPos(3), bkgdRectPos(2):bkgdRectPos(4), redBox);
            obj.hMarkedOverlay.AlphaData=zeros(bkgdRectPos(4), bkgdRectPos(3));
            
            obj.hViewOutlineRect=rectangle('Parent', obj.hAx, 'Position', bkgdRectPos, 'EdgeColor', 'y');
            obj.setOutlineRectPosition
            hold off
            
            %% Menu initialisation
            obj.mnuSetUnset=uicontextmenu;
            uimenu(obj.mnuSetUnset, 'Label', 'Set current region as marked', 'Callback', {@setCurrentViewAsMarked, obj})
            uimenu(obj.mnuSetUnset, 'Label', 'Set current region as unmarked', 'Callback', {@resetCurrentViewMarked, obj})
            uimenu(obj.mnuSetUnset, 'Label', 'Save region marking', 'Callback', {@saveAlphaMap, obj})
            uimenu(obj.mnuSetUnset, 'Label', 'Load region marking', 'Callback', {@loadAlphaMap, obj})
            obj.hImg.UIContextMenu=obj.mnuSetUnset;
            obj.hViewOutlineRect.UIContextMenu=obj.mnuSetUnset;
            obj.hMarkedOverlay.UIContextMenu=obj.mnuSetUnset;
            %% Set listeners
            obj.panListener=event.listener(obj.goggleViewer, 'Panned', @obj.setOutlineRectPosition);
            obj.zoomedListener=event.listener(obj.goggleViewer, 'Zoomed', @obj.setOutlineRectPosition);
            obj.scrollListener=event.listener(obj.goggleViewer, 'Scrolled', @obj.updateOverviewImage);

            
        end
        %% Callbacks
        function setOutlineRectPosition(obj, ~, ~)
            [xPos, yPos]=obj.getCurrentPos;
            pos=[xPos(1) yPos(1) diff(xPos) diff(yPos)];
            obj.hViewOutlineRect.Position=pos;
        end
        function updateOverviewImage(obj, ~,~)
            obj.hImg.CData=obj.goggleViewer.overviewDSS.I(:,:,obj.goggleViewer.mainDisplay.currentIndex);
        end
       
        %% Methods
        function [xPos, yPos]=getCurrentPos(obj)
            xPos=obj.goggleViewer.mainDisplay.viewXLimOriginalCoords;
            yPos=obj.goggleViewer.mainDisplay.viewYLimOriginalCoords;
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
    gbSetting('regionIndicator.figurePosition', obj.hFig.Position)
    deleteRequest@goggleBoxPlugin(obj);
    delete(obj.hFig);
    delete(obj);
end

function setCurrentViewAsMarked(~, ~, obj)
    [xPos, yPos]=obj.getCurrentPos;
    xPos=round(xPos);yPos=round(yPos);
    obj.hMarkedOverlay.AlphaData(yPos(1):yPos(2), xPos(1):xPos(2))=0.3;
end
function resetCurrentViewMarked(~, ~,obj)
    [xPos, yPos]=obj.getCurrentPos;
    xPos=round(xPos);yPos=round(yPos);
    obj.hMarkedOverlay.AlphaData(yPos(1):yPos(2), xPos(1):xPos(2))=0;
end
function saveAlphaMap(~,~,obj)
I=obj.hMarkedOverlay.AlphaData;
[f,p]=uiputfile('*.tif', 'Save Mark Map as...', gbSetting('defaultDirectory'));
if ~isempty(f)&&~isempty(p)&&~isnumeric(p)&&~isnumeric(f)
    imwrite(I,fullfile(p,f))
end
end
function loadAlphaMap(~,~,obj)
[f,p]=uigetfile('*.tif', 'Load Map Markings', gbSetting('defaultDirectory'));
if ~isempty(f)&&~isempty(p)&&~isnumeric(p)&&~isnumeric(f)
    I=im2double(imread(fullfile(p,f)));
    obj.hMarkedOverlay.AlphaData=I;
end
end
function setParentFigureFocus(~,~,obj)
figure(obj.goggleViewer.hFig)
end

