function selectedmasivStack = selectMasivStack(meta)
% Displays information about MaSIV stacks to the user, in order to get them to choose one
%
% function selectedmasivStack = selectDownscaledStack(meta)
%
% This function will be superceded by selectmasivStack

%#ok<*AGROW>

fontSz=masivSetting('font.size');
mainFont=masivSetting('font.name');
%% Check input

if ~isa(meta, 'masivMeta')
    error('Input must a masivMeta object')
end

stacks=meta.masivStacks;

    %% UI Declarations
    hFig=dialog(...
        'Name', sprintf('Select pregenerated MaSIV stack for %s',meta.stackName), ...
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
    updateAvailableChannels(hChannels, stacks);
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
        selectedmasivStack=stacks(selectedIdx);
    else
        selectedmasivStack=[];
    end
    if ishandle(hFig)
    close(hFig)
    end

    %% Callbacks
    function selectedChannelChanged(~,~)
        stacksWithMatchingChannelIdx=find(stacksWhichMatchChannel(stacks, hChannels));
        hStackInfoBox.Value=1;
        hStackInfoBox.String='';
        for ii=stacksWithMatchingChannelIdx
            idx=stacks(ii).idx;
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
            if stacks(ii).xyds==1
                thisStackDisplayString=[thisStackDisplayString '. No downsampling'];
            else
                thisStackDisplayString=sprintf('%s. Downsampled %ux in XY', thisStackDisplayString, stacks(ii).xyds);
            end
            hStackInfoBox.String{end+1}=thisStackDisplayString;
        end
        selectedStackChanged();
    end

    function selectedStackChanged(~,~)
        stacksWithMatchingChannelIdx=find(stacksWhichMatchChannel(stacks, hChannels));
        if isempty(hStackInfoBox.Value)||isempty(stacksWithMatchingChannelIdx)
            selectedIdx=[];
        else
            selectedIdx=stacksWithMatchingChannelIdx(hStackInfoBox.Value);
        end
    end

    function cancelButtonClick(~,~)
        selectedIdx=[];
        selectedmasivStack=[];
        uiresume(gcbf)
        delete(hFig)
    end

    function windowClose(~, ~)
        delete(hFig)
    end

    function newButtonClick(~, ~)
        a=masivStack(meta);
        if ~isempty(a.channel)
            if a.fileOnDisk
                msgbox('A stack matching this specification already exists. Cancelling stack creation', 'Generate MaSIV Stack')
                selectMatchingStack(a)
            else
                a.generateStack;
                a.writeStackToDisk;
                stacks=meta.masivStacks;
                selectMatchingStack(a)
            end
        end
    end

    function deleteButtonClick(~, ~)
        doneDelete=stacks(selectedIdx).deleteStackFromDisk;
        if doneDelete
            stacks=meta.masivStacks;
            updateAvailableChannels(hChannels, stacks)
            selectedChannelChanged();
            uicontrol(hStackInfoBox)
        end
    end

    function selectMatchingStack(a)
        %% Update list of available channels
        updateAvailableChannels(hChannels, stacks);
        %% Select matching channel
        hChannels.Value=find(strcmp(a.channel, hChannels.String));
        selectedChannelChanged();

        %% Get stacks which match this channel (and are shown in the stack list)
        channelMatch=stacksWhichMatchChannel(stacks, hChannels);
        %% Get stacks which match this idx
        idxMatch=cellfun(@(x) numel(x)==numel(a.idx)&&all(x(:)==a.idx(:)), {stacks.idx});
        %% Get stacks which match this xyds
        xydsMatch=(a.xyds==[stacks.xyds]);
        %% Put it together, and what have you got?
        totalMatch=channelMatch&idxMatch&xydsMatch;
        if any(totalMatch)
            idxInDisplayList=find(find(channelMatch)==find(totalMatch));
            hStackInfoBox.Value=idxInDisplayList;
        end
        %% Bippity boppity boo. Set focus.
        uicontrol(hStackInfoBox);
        
    end
   
end %function selectedmasivStack = selectDownscaledStack(meta)


function updateAvailableChannels(hChannels, stacks)
    if ~isempty(hChannels.String)
        prevAvailable=[hChannels.String{:}];
    else
        prevAvailable='';
    end
    availableChannels=getAvailableChannels(stacks);
    if ~strcmp(availableChannels, prevAvailable)
        hChannels.Value=1;
    end
    hChannels.String=availableChannels;

end

function availableChannels=getAvailableChannels(stacks)
  if ~isempty(stacks)
        availableChannels=unique({stacks.channel});
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