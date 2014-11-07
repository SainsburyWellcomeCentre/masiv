classdef goggleViewerDisplay<handle
    % Controls display of a goggleBox TissueVision dataset, managing the
    % overview (pre-generated, downscaled stack) and detail (less- or not-
    % downsampled images read from disk as needed) images
    properties(SetAccess=protected)
        overviewStack
        axes
        currentIndex
        hImg
        nPixelsWidthForZoomedView=2000;
        minZoomLevelForDetailedLoad=1.5;
    end
    properties
        contrastLims
        InfoPanel
    end
    properties(Dependent, Access=protected)
        currentPlaneData
    end
    properties(Dependent, SetAccess=protected)
        currentZPlaneOriginalFileNumber
        currentZPlaneOriginalLayerID
        zoomLevel
        downSamplingForCurrentZoomLevel
    end
    
    methods
        %% Constructor
        function obj=goggleViewerDisplay(overviewStack, hAx)
           obj.overviewStack=overviewStack;
           if ~obj.overviewStack.imageInMemory
               obj.overviewStack.loadStackFromDisk;
           end
           obj.axes=hAx;
           obj.hImg=[];
           obj.currentIndex=1;
           obj.contrastLims=[0 65536];
           obj.drawNow();
        end
        %% Methods
        function stdout=advanceImage(obj)
           stdout=seekZ(obj, +1);
        end
        function stdout=previousImage(obj)
            stdout=seekZ(obj, -1);
        end
        function stdout=seekZ(obj, n)
            stdout=0;
            newIdx=obj.currentIndex+n;
            if newIdx>=1&&newIdx<=numel(obj.overviewStack.idx)
                obj.currentIndex=newIdx;
                obj.drawNow();
                stdout=1;
            end
        end
        
        function drawNow(obj)   
            % Draws the correct plane from the downscaled stack in to the
            % axes, reusing the main Image Object if available
            
            clearZoomedViews(obj.axes)
            
            if ~isempty(obj.hImg)
                obj.hImg.CData=obj.currentPlaneData;
            else
                obj.hImg=image('XData', obj.overviewStack.xCoords, 'YData', obj.overviewStack.yCoords, ...
                    'CData', obj.currentPlaneData, 'CDataMapping', 'scaled', ...
                    'Parent', obj.axes);  
            end
            caxis(obj.axes, obj.contrastLims);
        end 
        
       
        function createZoomedView(obj)
            if obj.zoomLevel>obj.minZoomLevelForDetailedLoad
                tic
                [img, xPos, yPos]=getTiffRegionForDisplay(obj);
                image( 'XData', xPos, 'YData', yPos,...
                    'CData', img, 'CDataMapping', 'Scaled', ...
                    'Parent', obj.axes, ...
                    'Tag', 'zoomedView');
                toc
            end
        end
               
        function cpd=get.currentPlaneData(obj)
            cpd=obj.overviewStack.I(:,:,obj.currentIndex);
        end
        function czpofn=get.currentZPlaneOriginalFileNumber(obj)
            czpofn=obj.overviewStack.idx(obj.currentIndex);
        end
        function czpolid=get.currentZPlaneOriginalLayerID(obj)
            czpolid=obj.currentZPlaneOriginalFileNumber-1;
        end
        function zl=get.zoomLevel(obj)
            zl=range(obj.overviewStack.xCoords)./range(xlim(obj.axes));
        end
        function dsfczl=get.downSamplingForCurrentZoomLevel(obj)
            xl=round(xlim(obj.axes));
            dsfczl=ceil(range(xl)/obj.nPixelsWidthForZoomedView);
        end
        %% Setters
        function set.contrastLims(obj, val)
            obj.contrastLims=val;
            caxis(obj.axes, val); %#ok<MCSUP>
        end
    end
end



function clearZoomedViews(hAx)
zv=findobj(hAx, 'Tag', 'zoomedView');
delete(zv);
end

function [img, xl, yl] = getTiffRegionForDisplay(obj)

xl=round(xlim(obj.axes));
yl=round(ylim(obj.axes));

stitchedFileName=obj.overviewStack.originalStitchedFileNames{obj.currentZPlaneOriginalFileNumber};
stitchedFileFullPath=fullfile(obj.overviewStack.baseDirectory, stitchedFileName);

img=openTiff(stitchedFileFullPath, [xl(1) yl(1) range(xl) range(yl)], obj.downSamplingForCurrentZoomLevel);

end