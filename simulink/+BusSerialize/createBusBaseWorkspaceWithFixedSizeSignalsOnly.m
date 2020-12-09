function [bus, vals, busSpec] = createBusBaseWorkspaceWithFixedSizeSignalsOnly(busName, valueStruct)
    % generate a bus by dropping all variable sized elements from the
    % valueStruct struct -> SignalSpec description. 
    import BusSerialize.SignalSpec;
    
    fields = fieldnames(valueStruct);
    nFields = numel(fields);
    
    % keep only fixed size fields
    fixedValueStruct = struct();
    for iF = 1:nFields
        field = fields{iF};
        value = valueStruct.(field);

        if ~isa(value, 'SignalSpec')
            error('All field values must be BusSerialize.SignalSpec instances');
            %spec = SignalSpec.buildFixedForValue(value);
        else
            spec = value;
        end
        
        if spec.isBus
            [busObject, busSpec] = BusSerialize.getBusFromBusName(spec.busName);
            if any([busSpec.signals(:).isVariable])
                fixedName = [erase(busSpec.busName, 'Bus'), 'FixedBus'];
                
                fnName = sprintf('dropVariableLengthSignalsFromBus_%s', spec.busName);
                fileName = BusSerialize.getGeneratedCodeFileName(fnName);
                if ~isfile(fileName)
                    elements = busObject.Elements;
                    for iElement = 1:numel(elements)
                        s.(elements(iElement).Name) = busSpec.signals(iElement);
                    end
                    % Create a version with only the fixed size signals
                    BusSerialize.createBusBaseWorkspaceWithFixedSizeSignalsOnly(fixedName, s);
                    % and code to convert from variable to fixed
                    BusSerialize.writeDropVariableLengthSignalsFromBusCode(busSpec.busName, fixedName);
                end
                fixedValueStruct.(field) = BusSerialize.SignalSpec.Bus(fixedName);
            else
                fixedValueStruct.(field) = spec;
            end
        elseif ~spec.isVariable
            fixedValueStruct.(field) = spec;
        end
        
    end
    
    % defer to normal 
    [bus, vals, busSpec] = BusSerialize.createBusBaseWorkspace(busName, fixedValueStruct);
end