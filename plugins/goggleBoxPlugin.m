classdef(Abstract) goggleBoxPlugin<handle
    %GOGGLEBOXPLUGIN Base class for goggleBoxPlugins. 
    
    properties
        parentMenuItem
        goggleViewer
        mosaicInfo
    end
    
    methods
        function obj=goggleBoxPlugin(caller)
            obj.goggleViewer=caller.UserData;
            obj.mosaicInfo=obj.goggleViewer.mosaicInfo;
            
            items=get(obj.goggleViewer.mnuPlugins, 'Children');
            obj.parentMenuItem=findall(items, 'Label', obj.displayString);
            set(obj.parentMenuItem, 'Enable', 'off');
        end
        function deleteRequest(obj)
            set(obj.parentMenuItem, 'Enable', 'on');
        end
        
    end
    methods(Static)
        displayString
    end
    
end

