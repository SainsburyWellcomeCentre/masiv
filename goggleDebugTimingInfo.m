function goggleDebugTimingInfo(indentLevel, message, value, unit)
%% Params
spacingToMessage=12;
%% Format value 
if nargin>2
    if nargin>3&&~isempty(unit)
        switch unit
            case 's'
                valueStr=sprintf('%1.4fs', value);
            case 'MB'
                valueStr=sprintf('%uMB', round(value));
            otherwise
                valueStr=sprintf('%3.4f%s', value, unit);
        end
    else
        valueStr=sprintf('%3.4f', value);
    end
else
    valueStr='';
end

%% Format and print
spacing=spacingToMessage-length(valueStr);
indent=repmat(' ', 1, indentLevel*4+spacing);
fprintf('%s%s%s\n', valueStr, indent, message);

    
end