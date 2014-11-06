classdef goggleViewerDisplay<handle
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
        minZoomLevelForDetailedLoad=1.5;
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
        function obj=goggleViewerDisplay(TVDSS, hAx)
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
           stdout=seekZ(obj, +1);
        end
        function stdout=previousImage(obj)
            stdout=seekZ(obj, -1);
        end
        function stdout=seekZ(obj, n)
            stdout=0;
            newIdx=obj.currentIndex+n;
            if newIdx>=1&&newIdx<=numel(obj.tvdss.idx)
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
                image( 'XData', xPos, 'YData', yPos,...
                    'CData', img, 'CDataMapping', 'Scaled', ...
                    'Parent', obj.axes, ...
                    'Tag', 'zoomedView');
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
%% Params
resolution=2000;
%%
xl=round(xlim(obj.axes));
yl=round(ylim(obj.axes));

stitchedFileName=obj.tvdss.originalStitchedFilePaths{obj.currentZPlaneOriginalCoords};
stitchedFileFullPath=fullfile(obj.tvdss.baseDirectory, stitchedFileName);
ds = ceil(range(xl)/resolution);

img=openTiff(stitchedFileFullPath, [xl(1) yl(1) range(xl) range(yl)], ds);

end