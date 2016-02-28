classdef masivDistanceMeasurePlugin<masivPlugin
    %GOGGLEDISTANCEMEASUREPLUGIN A simple plugin to allow the drawing of a
    %line to measure distance (in pixels/units)
    
    properties
        hLn
    end
    
    methods
        function  obj=masivDistanceMeasurePlugin(caller, ~)
            obj=obj@masivPlugin(caller);
            obj.MaSIV=caller.UserData;
            %% present line
            obj.hLn=imline(obj.MaSIV.hMainImgAx);
            pos=obj.hLn.getPosition();
            dx=pos(1,1)-pos(2,1);
            dy=pos(1,2)-pos(2,2);
            
            distancePixels=sqrt(dx.^2 + dy.^2);
            
            uiwait(msgbox(sprintf('Distance in pixels: %3.1f', distancePixels)))
            
            deleteRequest(obj)
        end
    end
    
    methods(Static)
        function d=displayString()
            d='Measure Distance';
        end
    end
    
end

function deleteRequest(obj)
delete(obj.hLn)
deleteRequest@masivPlugin(obj);
end

