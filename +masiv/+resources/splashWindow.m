classdef splashWindow
    properties
        hWin
    end
    methods
        function obj=splashWindow(displayString, title)
            if nargin<2||isempty(title)
                title='';
            end
            obj.hWin=dialog;
            uicontrol(...
                'Style', 'text', ...
                'Parent', obj.hWin, ...
                'Units', 'normalized', ...
                'Position', [0.2 0.4 0.6 0.2], ...
                'String', displayString, ...
                'FontSize', 18);
           obj.hWin.Name=title;
           obj.hWin.Position(4)=obj.hWin.Position(4)/2;
        end
        function delete(obj)
            delete(obj.hWin)
        end
    end
end