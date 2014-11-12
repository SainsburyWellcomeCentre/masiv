classdef goggleZoomedView<handle
    properties(SetAccess=protected)
        imageData
    end
    properties(SetAccess=protected)
        regionSpec
        downSampling
        filePath
        parentZoomedViewManager
        z
    end
    properties(SetAccess=protected, Dependent)
        x
        y
        sizeMB
        imageInMemory
    end
    
    methods
        %% Constructor
        function obj=goggleZoomedView(filePath, regionSpec, downSampling, z, parentZoomedViewManager)
            if nargin>0
                obj.regionSpec=regionSpec;
                obj.downSampling=downSampling;
                obj.filePath=filePath;
                obj.z=z;
                obj.parentZoomedViewManager=parentZoomedViewManager;
                
                loadViewImageInBackground(obj)
            else
                obj.z=-1;
            end
        end
        %% Getters
        function szMB=get.sizeMB(obj)
            szBytes=numel(obj.imageData)*2; % 16 bit images
            szMB=szBytes/(1000*1000);
        end
        function inmem=get.imageInMemory(obj)
            inmem=~isempty(obj.imageData);
        end
        function x=get.x(obj)
            x=obj.regionSpec(1):obj.downSampling:obj.regionSpec(1)+obj.regionSpec(3)-1;
        end
        function y=get.y(obj)
            y=obj.regionSpec(2):obj.downSampling:obj.regionSpec(2)+obj.regionSpec(4)-1;
        end
    end
end

function loadViewImageInBackground(obj)
fprintf('         GZV.loadViewImageInBackground starting: \t\t%1.4fs\n', toc)
p=gcp();

f=parfeval(p, @openTiff, 1, obj.filePath, obj.regionSpec, obj.downSampling);
fprintf('         GZV.loadViewImageInBackground: parfeval started: \t%1.4fs\n', toc)

t=timer('BusyMode', 'queue', 'ExecutionMode', 'fixedRate', 'Period', 0.01, 'TimerFcn', {@checkForLoadedImage, obj, f});
start(t)
fprintf('         GZV.loadViewImageInBackground: Timer started: \t\t%1.4fs\n', toc)



end

function checkForLoadedImage(t, ~, obj, f)
 [idx, r]=fetchNext(f, 0.001);
    if ~isempty(idx)
        obj.imageData=r;
        
        stop(t)
        delete(t)
        obj.parentZoomedViewManager.updateView();
    end
end

