function flagData(tableName,variable,QF_value)
    % This function is designed for visually inspect plotted Bottle data, and select
    % suspected or bad data and assign the corresponding QF_value.
    % The selection of points will continue until the key "Enter" is pressed or
    % a click occurs outside of the ploted area.
    % Is neccesary to specify which variable is being evaluatee. For this
    % case 'oxy' for oxygen and 'sal' for salinity needs to be specified as
    % variable.
    % It was designed for salinity or Winkler discreate mesasurements.
    % Might be possible to use it with other data with identical structure 
    % and add another specification of the type of variable.


    % Select points and modify quality flag
    while true
        [x,y,button] = ginput(1);

        if isempty(button) || button ~= 1  % Break if not left-click
            break;
        end

        if isempty(x) || isempty(y)
            break;
        end

        if strcmp(variable,'oxy')
            [~, idx] = min(hypot(tableName.O2_umol_kg_1 - x, tableName.PRESS - y));
            %idx = find(tableName.O2_umol_kg_1 == x & tableName.PRESS == y);
        end
        
        if strcmp(variable,'sal')
            [~, idx] = min(hypot(tableName.AUTOSAL - x, tableName.PRESS - y));
            %idx = find(tableName.AUTOSAL == x & tableName.PRESS == y);
        end
        idx
        tableName.QF(idx) = QF_value;
    end

end

