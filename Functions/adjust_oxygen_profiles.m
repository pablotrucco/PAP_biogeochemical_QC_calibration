function cruise_struct = adjust_oxygen_profiles(cruise_struct, brob1, brob2, plot_graph, T)

if nargin < 3 || isempty(brob2)
    secondarySensorAvailable = false;
else
    secondarySensorAvailable = true;
end

if nargin < 4
    plot_graph = 1;
end

original_name = evalin('caller', 'inputname(1)');
original_name = string(original_name);

% Get the names of the profiles
subStructNames = fieldnames(cruise_struct);

% Loop through each profile
for i = 1:length(subStructNames)
    currentSubStruct = subStructNames{i};

    % For primary sensor
    CTDOXY_umol_kg_1 = cruise_struct.(currentSubStruct).CTDOXY_umol_kg_1;
    CTDOXY_umol_kg_1_ADJ = (CTDOXY_umol_kg_1 - brob1(1)) ./ brob1(2);
    cruise_struct.(currentSubStruct).CTDOXY_umol_kg_1_ADJ = CTDOXY_umol_kg_1_ADJ;

    if secondarySensorAvailable
        % For secondary sensor
        CTDOXY_umol_kg_2 = cruise_struct.(currentSubStruct).CTDOXY_umol_kg_2;
        CTDOXY_umol_kg_2_ADJ = (CTDOXY_umol_kg_2 - brob2(1)) ./ brob2(2);
        cruise_struct.(currentSubStruct).CTDOXY_umol_kg_2_ADJ = CTDOXY_umol_kg_2_ADJ;
    end

    % Mean of the adjusted QC oxygen sensors
    mean_oxy = nan(size(CTDOXY_umol_kg_1_ADJ));

    % Find the good data in the profiles
    ind1 = find(cruise_struct.(currentSubStruct).CTDOXY_1_FLAG == 2);
    mean_oxy(ind1) = CTDOXY_umol_kg_1_ADJ(ind1);

    if secondarySensorAvailable
        ind2 = find(cruise_struct.(currentSubStruct).CTDOXY_2_FLAG == 2);
        for j = 1:length(ind2)
            if isnan(mean_oxy(ind2(j)))
                mean_oxy(ind2(j)) = cruise_struct.(currentSubStruct).CTDOXY_umol_kg_2_ADJ(ind2(j));
            else
                mean_oxy(ind2(j)) = (mean_oxy(ind2(j)) + cruise_struct.(currentSubStruct).CTDOXY_umol_kg_2_ADJ(ind2(j))) / 2;
            end
        end
    end

    % Interpolate missing data
    mean_oxy = fillmissing(mean_oxy, 'nearest');

    % Storing the mean data
    cruise_struct.(currentSubStruct).OXY_MEAN = mean_oxy;

    % Create a new figure for the current substructure
    if plot_graph == 1
        figure;

        % Plot CTDPRS against CTDOXY_umol_kg_1
        plot(cruise_struct.(currentSubStruct).CTDOXY_umol_kg_1, cruise_struct.(currentSubStruct).CTDPRS, ...
            'Color', rgb('deeppink'), 'LineWidth', 1.5);
        hold on;
        axis ij

        if secondarySensorAvailable
            % Plot CTDPRS against CTDOXY_umol_kg_2
            plot(cruise_struct.(currentSubStruct).CTDOXY_umol_kg_2, cruise_struct.(currentSubStruct).CTDPRS, ...
                'Color', rgb('chartreuse'), 'LineWidth', 1.5);
        end

        plot(cruise_struct.(currentSubStruct).OXY_MEAN, cruise_struct.(currentSubStruct).CTDPRS, ...
            'k', 'LineWidth', 1.5),

        % If the bottle data is provided
        if nargin == 5
            CTD_num = str2double(currentSubStruct(end-1:end));
            ind3 = find(ismember(T.CTD, CTD_num));

            scatter(T.O2_umol_kg_1(ind3), T.PRESS(ind3), 120, 'filled', 'square', 'MarkerFaceColor', rgb('deepskyblue'), 'MarkerEdgeColor', 'k')
        end


        % Add labels and title
        xlabel('Oxygen [\mumol kg^-^1]');
        ylabel('Pressure (dbar)');
        title(subStructNames{i}, 'Interpreter', 'none');
        legendEntries = {'Primary sensor', 'Mean adjusted oxygen'};
        if secondarySensorAvailable
            legendEntries = [legendEntries, 'Secondary sensor'];
        end
        legendEntries = [legendEntries, 'Winkler'];
        legend(legendEntries, 'Location', 'northeastoutside');
        ax = gca;
        ax.FontSize = 16;
        axis square; grid on
    end
    assignin('base', original_name, cruise_struct);
end
end
