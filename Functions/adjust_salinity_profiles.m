function cruise_struct = adjust_salinity_profiles(cruise_struct, brob1,brob2,plot_graph,T)
    
    if nargin ==3
        plot_graph=1;
    end
    original_name = evalin('caller', 'inputname(1)');
    original_name = string(original_name);

    % Get the names of the profiles
    subStructNames = fieldnames(cruise_struct);
    
    % Loop through each profile
    for i = 1:length(subStructNames)
        currentSubStruct = subStructNames{i};
        
        % For primary sensor
        CTDSAL_1 = cruise_struct.(currentSubStruct).CTDSAL_1;
        CTDSAL_1_ADJ = (CTDSAL_1-brob1(1))./brob1(2);
        cruise_struct.(currentSubStruct).CTDSAL_1_ADJ = CTDSAL_1_ADJ;

        % For secondary sensor
        CTDSAL_2 = cruise_struct.(currentSubStruct).CTDSAL_2;
        CTDSAL_2_ADJ = (CTDSAL_2-brob2(1))./brob2(2);
        cruise_struct.(currentSubStruct).CTDSAL_2_ADJ = CTDSAL_2_ADJ;


        %Mean of the adjusted QC salinity sensors
        mean_sal = nan(size(CTDSAL_1_ADJ));

        %Find the good data in the profiles
        ind1 = find(cruise_struct.(currentSubStruct).CTDSAL_1_FLAG == 2);
        ind2 = find(cruise_struct.(currentSubStruct).CTDSAL_2_FLAG == 2);

        %Calculating mean salinity at these indices
        mean_sal(ind1) = cruise_struct.(currentSubStruct).CTDSAL_1_ADJ(ind1);
        mean_sal(ind2) = (mean_sal(ind2) + cruise_struct.(currentSubStruct).CTDSAL_2_ADJ(ind2))/2;

        % Interpolate missing data
        mean_sal = fillmissing(mean_sal,'nearest');
        
        %Storing the mean data
        cruise_struct.(currentSubStruct).SAL_MEAN=mean_sal;

        % Create a new figure for the current substructure
        if plot_graph==1
            figure;

            % Plot CTDPRS against CTDSAL_1_ADJ
            plot(cruise_struct.(currentSubStruct).CTDSAL_1, cruise_struct.(currentSubStruct).CTDPRS, ...
                'Color',rgb('deeppink'),'LineWidth',1.5);
            hold on;
            axis ij
            % Plot CTDPRS against CTDSAL_2
            plot(cruise_struct.(currentSubStruct).CTDSAL_2, cruise_struct.(currentSubStruct).CTDPRS, ...
                'Color',rgb('chartreuse'),'LineWidth',1.5);

            plot(cruise_struct.(currentSubStruct).SAL_MEAN,cruise_struct.(currentSubStruct).CTDPRS, ...
                'k','LineWidth',1.5),
           
            %If the bottle data is provided
            if exist('T','var')
                CTD_num=str2double(currentSubStruct(end-2:end));
                ind3=find(ismember(T.CTD,CTD_num));

                scatter(T.AUTOSAL(ind3),T.PRESS(ind3),120,'filled','square','MarkerFaceColor',rgb('deepskyblue'),'MarkerEdgeColor','k')
                

            end

            % Add labels and title
            xlabel('Practical salinity ');
            ylabel('Pressure');
            title(subStructNames{i}, 'Interpreter', 'none');
            legend('Primary sensor', 'Seconday sensor', 'Mean adjusted salinity','Autosal','Location','northeastoutside')
            ax=gca;
            ax.FontSize=16;
            ax.XLim=[min(cruise_struct.(currentSubStruct).SAL_MEAN) max(cruise_struct.(currentSubStruct).SAL_MEAN)];
            axis square; grid on
            
        end
        assignin('base', original_name, cruise_struct);

    end
end