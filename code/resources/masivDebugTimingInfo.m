function masivDebugTimingInfo(indentLevel, message, value, unit)

    if ~(masivSetting('debug.logging')==1)
        return
    end
    spacingToMessage=masivSetting('debug.outputSpacing');
    %% Format value
    if nargin>2
        if nargin>3&&~isempty(unit)
            switch unit
                case 's'
                    if value>1
                        valueStr=sprintf('%1.3fs', value);
                    else
                        valueStr=sprintf('%ums', round(value*1000));
                    end
                case 'MB'
                    if value<1000
                        valueStr=sprintf('[%uMB]', round(value));
                    else
                        valueStr=sprintf('[%2.1fGB]', value/1000);
                    end
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