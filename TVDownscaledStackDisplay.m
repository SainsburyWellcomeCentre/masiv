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
    end
    
    properties(Dependent, Access=protected)
        currentPlaneData
    end
    
    methods
        %% Constructor
        function obj=TVDownscaledStackDisplay(TVDSS, hAx)
           obj.tvdss=TVDSS;
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
            if ~isempty(obj.hImg)
                obj.hImg.CData=obj.currentPlaneData;
            else
                obj.hImg=image('XData', obj.tvdss.xCoords, 'YData', obj.tvdss.yCoords, ...
                    'CData', obj.currentPlaneData, 'CDataMapping', 'scaled', ...
                    'Parent', obj.axes);  
            end
            caxis(obj.axes, obj.contrastLims);
        end
        %% Getters
        function cpd=get.currentPlaneData(obj)
            cpd=obj.tvdss.I(:,:,obj.currentIndex);
        end
    end
end


