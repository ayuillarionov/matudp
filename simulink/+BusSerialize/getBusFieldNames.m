function fields = getBusFieldNames(busObject)

    if ischar(busObject)
        busObject = BusSerialize.getBusFromBusName(busObject);
    end

    if isempty(busObject)
        fields = {};
    else
        fields = {busObject.Elements.Name}';
    end

end