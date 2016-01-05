classdef simpleUI<goggleBoxPlugin %simpleUI inherits goggleBoxPlugin


	% Purpose 
	% simpleUI is an example plugin to show how the plugin system works. It simply
    % pops up a small GUI with an exit button and a message. The plugin can be closed
    % using either the exit button, the regular menubar close button or the key 
    % combination ctrl-e. Pressing other keys reports the key-presses to the command line. 
	%
    % The plugin system is written using object oriented MATLAB code. If this is new
    % to you, you might want to read up on this in the MATLAB docs. 
	%
	%
	% Rob Campbell - Basel 2015



	%Define properties of testPlug
	properties   
	    hFig
        fontName
        fontSize

        markers
        hDisplayedMarkers
        hDisplayedMarkerHighlights

        keyPressListener
	end

    %Define protected properties
    properties(Dependent, SetAccess=protected)
        currentType
        cursorZVoxels
        cursorZUnits
    end


	%Define methods of testPlug
	methods 
	   %Constructor - runs once when testPlug is loaded
	   function obj = simpleUI(caller,~)
	   	obj=obj@goggleBoxPlugin(caller);
	   	obj.goggleViewer=caller.UserData;            

	   	%% Get settings from main GUI so we can apply to plugin GUI
        obj.fontName=gbSetting('font.name');
        obj.fontSize=gbSetting('font.size');

        %Create GUI window for plugin and position nicely on screen
        ssz=get(0, 'ScreenSize');
        lb=[ssz(3)/3 ssz(4)/3];
        pos=round([lb 400 400]);

        obj.hFig=figure(...
                'Position', pos, ...
                'CloseRequestFcn', {@deleteRequest, obj}, ...
                'MenuBar', 'none', ...
                'NumberTitle', 'off', ...
                'Name', ['Test Plugin: ' obj.goggleViewer.mosaicInfo.experimentName], ...
                'Color', gbSetting('viewer.panelBkgdColor'), ...
                'KeyPressFcn', {@keyPress, obj});


        %Add exit button
        uicontrol(...
         'Parent', obj.hFig, ...
         'Style', 'pushbutton', ...
         'Units', 'normalized', ...
         'FontName', obj.fontName, ...
         'FontSize', obj.fontSize, ...          
         'BackgroundColor', gbSetting('viewer.mainBkgdColor'), ...
         'ForegroundColor','red',...
         'Position', [0.05 0.05 0.39 0.08], ...
         'String', 'EXIT', ...
         'FontWeight','bold',...
         'Value', 0, ...
         'Callback', {@deleteRequest, obj}); 

        %Add a text panel with instructional information
        uicontrol(...
            'Parent', obj.hFig, ...
            'Units', 'normalized', ...
            'Style','text',...
            'String',['This is the simpleUI plugin. ',... 
                     'Key presses are reported to command line window. ',... 
                    'Quit with ctrl+e, the EXIT button, or the GUI close button'],...
            'FontName', obj.fontName, ...
            'FontSize', obj.fontSize, ...          
            'BackgroundColor', gbSetting('viewer.mainBkgdColor'), ...
            'ForegroundColor','white',...
            'Position', [0.05 0.30 0.9 0.6]);


        %Set up a listener for the keyboard. This will allow the plugin to 
        %respond to key presses in order to build a short-cut system. The plugin
        %can also listen to other events, such clicks and scroll wheel moves. For
        %more examples see the source code of goggleCellCounter or the tutorial plugin,
        %drawRandomPoints
        obj.keyPressListener=event.listener(obj.goggleViewer, 'KeyPress', @obj.parentKeyPress);

	   end %close constructor method



        function parentKeyPress(obj, ~,ev) %monitors key press events
            keyPress([], ev.KeyPressData, obj);
        end

        function parentClosing(obj, ~, ~)
            deleteRequest([],[], obj,1) %force quit if the parent GUI (goggleViewer) closes
        end




    end %methods


    methods(Static)
       %This is what the plugin is named in the goggleViewer "plugins" menu
       function d=displayString
        d='simpleUI';
       end % close displayString method

    end %close methods(Static)

end %classdef testPlug<goggleBoxPlugin 


%----------------------------------------------------------------------------------------------
% Callback functions (http://mathworks.com/help/matlab/creating_plots/callback-definition.html)
% These are called when the user presses a button on the keyboard or clicks a UI element in the
% plugin GUI


%The keyPress function is run whenever the user presses a key. It's used to provide
%short-cut key controls for the plugin. Here we just echo what the user pressed,
%and exit the plugin if the user pressed "ctrl+e"

function keyPress(~, eventdata, obj)
 key=eventdata.Key;
 key=strrep(key, 'numpad', '');

 ctrlMod=ismember('control', eventdata.Modifier);

 switch key
     case {'0' '1' '2' '3' '4' '5' '6' '7' '8' '9'}
         fprintf('You pressed a number key\n')
     case 'e'
         if ctrlMod
         	 fprintf('You pressed ctrl+e. EXIING\n')
             deleteRequest(0,0,obj);
         end
     otherwise
     	fprintf('%s\n',key)
 end

end



%Closes the GUI and and detaches the plugin from goggleViewer. 
function deleteRequest(~, ~, obj, forceQuit)
    
    obj.deregisterPluginAsOpenWithParentViewer; %inherited from goggleBoxPlugin
    deleteRequest@goggleBoxPlugin(obj); %inherited from goggleBoxPlugin
    delete(obj.hFig);
    delete(obj);
    
end
