classdef (Abstract) singleImage_DisplayProcesor
    %singleImage_DisplayProcesor Base class for image processing modules
      
    methods (Abstract)
        processImage(I, zoomedViewObject)
        toString(obj)
    end
    methods (Abstract, Static)
        displayName()
    end
    
end

