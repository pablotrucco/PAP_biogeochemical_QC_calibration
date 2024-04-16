function table=add_lat_lon_table(table,cruise_struct)
    %This function is designed to extract the lat and lon from the CTD cast
    %and store it in the Winkler table. This is because the winkler data is
    %in umol L and we need the lat and lon to calculate it in umol kg 
    %(because of absolute salinity needs the location info)
    original_name = evalin('caller', 'inputname(1)');

    % Extract CTD cast numbers from winkler_table
    ctd_casts = table.CTD;


    % Initialize latitudes and longitudes
    latitudes = NaN(size(table, 1), 1);
    longitudes = NaN(size(table, 1), 1);

    % Iterate over CTD casts in winkler_table
    for i = 1:numel(ctd_casts)
        % Construct field name for corresponding CTD cast
        try
            field_name = sprintf('CTD_%03d', ctd_casts(i));

            % Extract latitude and longitude from latlon_struct
            latitude = unique(cruise_struct.(field_name).LATITUDE);
            longitude = unique(cruise_struct.(field_name).LONGITUDE);
        catch
            field_name = sprintf('CTD_%02d', ctd_casts(i));

            % Extract latitude and longitude from latlon_struct
            latitude = unique(cruise_struct.(field_name).LATITUDE);
            longitude = unique(cruise_struct.(field_name).LONGITUDE);
        end
        % Store latitude and longitude in corresponding rows of winkler_table
        latitudes(i) = latitude;
        longitudes(i) = longitude;
    end

    % Add latitudes and longitudes to winkler_table
    table.Lat = latitudes;
    table.Lon = longitudes;

    assignin('base', original_name, table);

end