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
        zoomedViewManager
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
           obj.currentIndex=1;
           obj.hImg=image('Visible', 'on', ...
               'XData', obj.overviewStack.xCoords, ...
               'YData', obj.overviewStack.yCoords, ...
               'CData', obj.currentPlaneData, ...
               'CDataMapping', 'scaled', ...
               'Parent', obj.axes);
           obj.contrastLims=[0 65536];           
           obj.zoomedViewManager=goggleZoomedViewManager(obj);
           
           obj.drawNewZ();
        end
        %% Methods
        function stdout=seekZ(obj, n)
            goggleDebugTimingInfo(1, 'GVD: seekZ starting',toc, 's')
            stdout=0;
            newIdx=obj.currentIndex+n;
            if newIdx>=1&&newIdx<=numel(obj.overviewStack.idx)
                obj.currentIndex=newIdx;
                obj.drawNewZ();
                stdout=1;
            end
            goggleDebugTimingInfo(1, 'GVD: seekZ finished',toc, 's')
        end
        
        function drawNewZ(obj)   
            % Draws the correct plane from the downscaled stack in to the
            % axes, reusing the main Image Object if available
            goggleDebugTimingInfo(1, 'GVD: drawNewZ starting',toc, 's')
            obj.hImg.CData=obj.currentPlaneData;
            goggleDebugTimingInfo(1, 'GVD: drawNewZ DS CData changed',toc, 's')
        end
               
        function updateZoomedView(obj)
            if obj.zoomLevel>obj.minZoomLevelForDetailedLoad
                goggleDebugTimingInfo(1, 'GVD.updateZoomedView: Zoomed image needed. Updating view...', toc, 's')
                obj.zoomedViewManager.updateView()
                goggleDebugTimingInfo(1, 'GVD.updateZoomedView: View updated', toc, 's')
            else
                goggleDebugTimingInfo(1, 'GVD.updateZoomedView: No zoomed image needed', toc, 's')
                obj.zoomedViewManager.hide;
                goggleDebugTimingInfo(1, 'GVD.updateZoomedView: Zoomed image hidden', toc, 's')
            end
        end
        %% Getters       
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



