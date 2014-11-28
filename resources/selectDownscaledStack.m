function selectedDSS = selectDownscaledStack(mosaicInfo)
%SELECTDOWNSCALEDSTACK Displays information about downscaled stacks to the
%user, in order to get them to choose one!

%#ok<*AGROW>

fontSz=gbSetting('font.size');
mainFont=gbSetting('font.name');
%%

if ~isa(mosaicInfo, 'TVStitchedMosaicInfo')
    error('Input must a TVStitchedMosaicInfo object')
end

dss=mosaicInfo.downscaledStacks;

% if numel(dss)<1
%     selectedDSS=dss;
% else
    %% UI Declarations
    hFig=dialog(...
        'Name', sprintf('Select pregenerated overview stack for %s',mosaicInfo.experimentName), ...
        'ButtonDownFcn', '', 'CloseRequestFcn', @windowClose);
    % Ensure it's wide enough
    pos=hFig.Position;
    if pos(3)<800
        pos(3)=800;
        hFig.Position=pos;
    end
    
    hStackInfoBox=uicontrol(...
        'Parent', hFig, ...
        'Units', 'normalized', ...
        'Position', [0.24 0.12 0.74 0.86], ...
        'FontName', mainFont, ...
        'FontSize', fontSz, ...
        'Style', 'listbox', ...
        'String', '', ...
        'Callback', @selectedStackChanged);
    hChannels=uicontrol(...
        'Parent', hFig, ...
        'Units', 'normalized', ...
        'Position', [0.02 0.12 0.2 0.86], ...
        'FontName', mainFont, ...
        'FontSize', fontSz, ...
        'Style', 'listbox', ...
        'Callback', @selectedChannelChanged);
    updateAvailableChannels(hChannels, dss);
    hOKButton=uicontrol(...
        'Parent', hFig, ...
        'Units', 'normalized', ...
        'Position', [0.8 0.02 0.18 0.08], ...
        'FontName', mainFont, ...
        'FontSize', fontSz, ...
        'Style', 'pushbutton', ...
        'String', 'OK', ...
        'Callback', 'uiresume(gcbf)'); %#ok<NASGU>
    hCancelButton=uicontrol(...
        'Parent', hFig, ...
        'Units', 'normalized', ...
        'Position', [0.6 0.02 0.18 0.08], ...
        'FontName', mainFont, ...
        'FontSize', fontSz, ...
        'Style', 'pushbutton', ...
        'String', 'Cancel', ...
        'Callback', @cancelButtonClick); %#ok<NASGU>
    hNewButton=uicontrol(...
        'Parent', hFig, ...
        'Units', 'normalized', ...
        'Position', [0.02 0.02 0.18 0.08], ...
        'FontName', mainFont, ...
        'FontSize', fontSz, ...
        'Style', 'pushbutton', ...
        'String', 'New', ...
        'Callback', @newButtonClick);%#ok<NASGU>
    hDeleteButton=uicontrol(...
        'Parent', hFig, ...
        'Units', 'normalized', ...
        'Position', [0.22 0.02 0.18 0.08], ...
        'FontName', mainFont, ...
        'FontSize', fontSz, ...
        'Style', 'pushbutton', ...
        'String', 'Delete', ...
        'Callback', @deleteButtonClick);%#ok<NASGU>
    %% Main
    selectedChannelChanged();
    selectedIdx=[];
    selectedStackChanged();
    uiwait(hFig);
    %% We're done, what have we selected?
    if ~isempty(selectedIdx)
        selectedDSS=dss(selectedIdx);
    else
        selectedDSS=[];
    end
    if ishandle(hFig)
    close(hFig)
    end
% end
%% Callbacks
    function selectedChannelChanged(~,~)
        stacksWithMatchingChannelIdx=find(stacksWhichMatchChannel(dss, hChannels));
        hStackInfoBox.Value=1;
        hStackInfoBox.String='';
        for ii=stacksWithMatchingChannelIdx
            idx=dss(ii).idx;
            step=unique(diff(idx));
            if numel(step)==1
                if step==1
                    thisStackDisplayString=sprintf('Slices %u-%u (Layers %u-%u), every slice', idx(1), idx(end), idx(1)-1, idx(end)-1);
                else
                    thisStackDisplayString=sprintf('Slices %u-%u (Layers %u-%u), every %u slices', idx(1), idx(end), idx(1)-1, idx(end)-1, step);
                end
            else
                thisStackDisplayString=sprintf('Unevenly sampled stack from slice %u to %u (layers % to %u)', idx(1), idx(end), idx(1)-1, idx(end)-1);
            end
            if dss(ii).xyds==1
                thisStackDisplayString=[thisStackDisplayString '. No downsampling'];
            else
                thisStackDisplayString=sprintf('%s. Downsampled %ux in XY', thisStackDisplayString, dss(ii).xyds);
            end
            hStackInfoBox.String{end+1}=thisStackDisplayString;
        end
        selectedStackChanged();
    end

    function selectedStackChanged(~,~)
        stacksWithMatchingChannelIdx=find(stacksWhichMatchChannel(dss, hChannels));
        if isempty(hStackInfoBox.Value)||isempty(stacksWithMatchingChannelIdx)
            selectedIdx=[];
        else
            selectedIdx=stacksWithMatchingChannelIdx(hStackInfoBox.Value);
        end
    end

    function cancelButtonClick(~,~)
        selectedIdx=[];
        selectedDSS=[];
        uiresume(gcbf)
        delete(hFig)
    end

    function windowClose(~, ~)
        delete(hFig)
    end

    function newButtonClick(~, ~)
        a=TVDownscaledStack(mosaicInfo);
        if ~isempty(a.channel)
        if a.fileOnDisk
            msgbox('A stack matching this specification already exists. Cancelling stack creation', 'Generate Downsampled Stack')
            selectMatchingStack(a)
        else
            a.generateStack;
            a.writeStackToDisk;
            dss=mosaicInfo.downscaledStacks;
            selectMatchingStack(a)
        end
        end
    end

    function deleteButtonClick(~, ~)
        doneDelete=dss(selectedIdx).deleteStackFromDisk;
        if doneDelete
            dss=mosaicInfo.downscaledStacks;
            updateAvailableChannels(hChannels, dss)
            selectedChannelChanged();
            uicontrol(hStackInfoBox)
        end
    end

    function selectMatchingStack(a)
        %% Update list of available channels
        updateAvailableChannels(hChannels, dss);
        %% Select matching channel
        hChannels.Value=find(strcmp(a.channel, hChannels.String));
        selectedChannelChanged();

        %% Get stacks which match this channel (and are shown in the stack list)
        channelMatch=stacksWhichMatchChannel(dss, hChannels);
        %% Get stacks which match this idx
        idxMatch=cellfun(@(x) numel(x)==numel(a.idx)&&all(x(:)==a.idx(:)), {dss.idx});
        %% Get stacks which match this xyds
        xydsMatch=(a.xyds==[dss.xyds]);
        %% Put it together, and what have you got?
        totalMatch=channelMatch&idxMatch&xydsMatch;
        if any(totalMatch)
            idxInDisplayList=find(find(channelMatch)==find(totalMatch));
            hStackInfoBox.Value=idxInDisplayList;
        end
        %% Bippity boppity boo. Set focus.
        uicontrol(hStackInfoBox);
        
    end
   
end


function updateAvailableChannels(hChannels, dss)
    if ~isempty(hChannels.String)
        prevAvailable=[hChannels.String{:}];
    else
        prevAvailable='';
    end
    availableChannels=getAvailableChannels(dss);
    if ~strcmp(availableChannels, prevAvailable)
        hChannels.Value=1;
    end
    hChannels.String=availableChannels;

end
function availableChannels=getAvailableChannels(dss)
  if ~isempty(dss)
        availableChannels=unique({dss.channel});
    else
        availableChannels={};
  end
end

function matchIdx=stacksWhichMatchChannel(dss, hChannels)
% returns the index of stack objects in dss which match a given channel
if isempty(dss)||isempty(hChannels.String)
    matchIdx=[];
else
    channelString=hChannels.String(hChannels.Value);
    matchIdx=(strcmp({dss.channel}, channelString));
end
end