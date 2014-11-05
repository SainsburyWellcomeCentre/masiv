classdef TVDownscaledStackDisplay<handle
    % encapsulates a tv downscaled stack, with additional properties and
    % methods for display
    properties(SetAccess=protected)
        tvdss
        axes
        currentIndex
        hImg
    end
    properties
        contrastLims
        minZoomLevelForDetailedLoad=2;
    end
    
    properties(Dependent, Access=protected)
        currentPlaneData
    end
    properties(Dependent, SetAccess=protected)
        currentZPlaneOriginalCoords
        zoomLevel
    end
    
    methods
        %% Constructor
        function obj=TVDownscaledStackDisplay(TVDSS, hAx)
           obj.tvdss=TVDSS;
           if ~obj.tvdss.imageInMemory
               obj.tvdss.loadStackFromDisk;
           end
           obj.axes=hAx;
           obj.hImg=[];
           obj.currentIndex=1;
           obj.contrastLims=[0 65536];
           obj.drawNow();
        end
        %% Methods
        function stdout=advanceImage(obj)
            stdout=0;
            if obj.currentIndex < numel(obj.tvdss.idx)
                obj.currentIndex=obj.currentIndex+1;
                obj.drawNow();
                stdout=1;
            end
        end
        function stdout=previousImage(obj)
            stdout=0;
             if obj.currentIndex > 1
                obj.currentIndex=obj.currentIndex-1;
                obj.drawNow();
                stdout=1;
            end
        end
        function drawNow(obj)   
            % Draws the correct plane from the downscaled stack in to the
            % axes
            if ~isempty(obj.hImg)
                obj.hImg.CData=obj.currentPlaneData;
            else
                obj.hImg=image('XData', obj.tvdss.xCoords, 'YData', obj.tvdss.yCoords, ...
                    'CData', obj.currentPlaneData, 'CDataMapping', 'scaled', ...
                    'Parent', obj.axes);  
            end
            caxis(obj.axes, obj.contrastLims);
        end 
        
       
        function createZoomedView(obj)
            if obj.zoomLevel>obj.minZoomLevelForDetailedLoad
                tic
                [img, xPos, yPos]=getTiffRegionForDisplay(obj);
                image( 'XData', xPos, 'YData', yPos,'CData', img, 'CDataMapping', 'Scaled', 'Parent', obj.axes);
                toc
            end
        end
       
        function cpd=get.currentPlaneData(obj)
            cpd=obj.tvdss.I(:,:,obj.currentIndex);
        end
        function czpoc=get.currentZPlaneOriginalCoords(obj)
            czpoc=obj.tvdss.idx(obj.currentIndex);
        end
        function zl=get.zoomLevel(obj)
            zl=range(obj.tvdss.xCoords)./range(xlim(obj.axes));
        end
    end
end


function [img, xl, yl] = getTiffRegionForDisplay(obj)
%% Params
resolution=1500;
%%
xl=round(xlim(obj.axes));
yl=round(ylim(obj.axes));

stitchedFileName=obj.tvdss.originalStitchedFilePaths{obj.currentZPlaneOriginalCoords};
ds = ceil(range(xl)/resolution);

img=openTiff(stitchedFileName, [xl(1) yl(1) range(xl) range(yl)], ds);

end