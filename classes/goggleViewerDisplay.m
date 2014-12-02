classdef goggleViewerDisplay<handle
    % Controls display of a goggleBox TissueVision dataset, managing the
    % overview (pre-generated, downscaled stack) and detail (less- or not-
    % downsampled images read from disk as needed) images
    properties(SetAccess=protected)
        parentViewer
        overviewStack
        axes
        currentIndex
        hImg
        zoomedViewManager
        
    end
    properties
        contrastLims
    end
    properties(Dependent, Access=protected)
        currentPlaneData
    end
    properties(Dependent, SetAccess=protected)
        currentZPlaneOriginalVoxels
        currentZPlaneUnits
        currentZPlaneOriginalLayerID
        zoomLevel
        downSamplingForCurrentZoomLevel
        
        imageXLimOriginalCoords
        imageYLimOriginalCoords
        imageXLimPixels
        imageYLimPixels
        
        viewXLimOriginalCoords
        viewYLimOriginalCoords
        viewXLimPixels
        viewYLimPixels
        
        viewPixelSizeOriginalVoxels
        
        currentImageViewData
    end
    
    methods
        %% Constructor
        function obj=goggleViewerDisplay(parent)
            obj.parentViewer=parent;
            obj.overviewStack=parent.overviewDSS;
            if ~obj.overviewStack.imageInMemory
                obj.overviewStack.loadStackFromDisk;
            end
            obj.axes=parent.hImgAx;
            obj.currentIndex=1;
            obj.hImg=image('Visible', 'on', ...
                'XData', obj.overviewStack.xCoordsUnits, ...
                'YData', obj.overviewStack.yCoordsUnits, ...
                'CData', obj.currentPlaneData, ...
                'CDataMapping', 'scaled', ...
                'Parent', obj.axes, ...
                'HitTest', 'off');
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
            goggleDebugTimingInfo(1, 'GVD.updateZoomedView: Call started. Checking need...', toc, 's')
            z=obj.zoomLevel;
            goggleDebugTimingInfo(1, 'GVD.updateZoomedView: zoomLevel calculated...', toc, 's')
            if z>gbSetting('viewerDisplay.minZoomLevelForDetailedLoad')
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
        function civ=get.currentImageViewData(obj)
           x=obj.viewXLimPixels;
           y=obj.viewYLimPixels;
           cpd=obj.currentPlaneData;
           civ=cpd(y(1):y(2), x(1):x(2));
        end
        function czpofn=get.currentZPlaneOriginalVoxels(obj)
            czpofn=obj.overviewStack.idx(obj.currentIndex);
        end
        function czpolid=get.currentZPlaneOriginalLayerID(obj)
            czpolid=obj.currentZPlaneOriginalVoxels-1;
        end
        function czpofn=get.currentZPlaneUnits(obj)
            czpofn=obj.overviewStack.zCoordsUnits(obj.currentIndex);
        end
        function ps=get.viewPixelSizeOriginalVoxels(obj)
            obj.parentViewer.hImgAx.Units='pixels';
            nPixelsWidthInAxesWidth=obj.parentViewer.hImgAx.Position(3);
            obj.parentViewer.hImgAx.Units='normalized';
            
            ps=nPixelsWidthInAxesWidth./range(obj.viewXLimOriginalCoords);
        end
        function zl=get.zoomLevel(obj)
            ovRange=(obj.overviewStack.xCoordsVoxels(end)-obj.overviewStack.xCoordsVoxels(1));
            xlRange=(obj.axes.XLim(2)-obj.axes.XLim(1));
            zl=ovRange/xlRange;
                
        end
        function dsfczl=get.downSamplingForCurrentZoomLevel(obj)
            xl=round(xlim(obj.axes));
            dsfczl=ceil(range(xl)/gbSetting('viewerDisplay.nPixelsWidthForZoomedView'));
        end
        % Image and view in pixels and original
            function x=get.imageXLimOriginalCoords(obj)
                x=obj.hImg.XData([1 end]);
            end
            function y=get.imageYLimOriginalCoords(obj)
                y=obj.hImg.YData([1 end]);
            end
            function x=get.imageXLimPixels(obj)
                x=obj.imageXLimOriginalCoords/obj.overviewStack.xyds;
                if x(1)<1;x(1)=1;end
            end
            function y=get.imageYLimPixels(obj)
                y=obj.imageYLimOriginalCoords/obj.overviewStack.xyds;
                if y(1)<1;y(1)=1;end
            end
            function x=get.viewXLimOriginalCoords(obj)
                x=obj.axes.XLim;
            end
            function y=get.viewYLimOriginalCoords(obj)
                y=obj.axes.YLim;
            end
            function x=get.viewXLimPixels(obj)
                x=round(obj.viewXLimOriginalCoords/obj.overviewStack.xyds);
                x(1)=max(x(1),1);
                x(2)=min(x(2), size(obj.overviewStack.I, 2));
            end
            function y=get.viewYLimPixels(obj)
                y=round(obj.viewYLimOriginalCoords/obj.overviewStack.xyds);
                y(1)=max(y(1),1);
                y(2)=min(y(2), size(obj.overviewStack.I, 1));
            end
        %% Setters
        function set.contrastLims(obj, val)
            obj.contrastLims=val;
            caxis(obj.axes, val); %#ok<MCSUP>
        end
    end
end



