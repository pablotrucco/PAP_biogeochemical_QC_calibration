function cruise_struct=CTD_O2_qc(cruise_struct,sig,acclim_depth,plot_graph)

%This function quality control the oxygen data by identifying which
%values of the CTD profiles falls beyond a specified sigma thresshold. It
%center the test in the diff of the parameter (in this case oxygen) with
%respect of depth, and assign a quality flag of 3 to the values that falls
%beyond the sigma thresshold. The default sigma is 3 stdev of the entire
%derviative values of the CTD profile.
%
%It also assig a QF of 3 to the values of the downcast that are above the
%assigned acclimatation depth (acclim_depth). This can be specified upon
%input or leave to the defaul 20 m.
%
%Finally you can opt to plot the graphs that shows you the profiles of each
%sensor (primary and seconday) and the identified outliers (QF=3). 
% 
% The flagging scheme followed here obey to those stablished for the Ocean
%Carbon and Acidification Data System (OCADS) and despite that here is just
%assessed values as questionable or acceptable, the flagging system is as
%follow:
%
%       2  =  acceptable
%       3  =  questionable
%       4  =  known bad
%       6  =  median replicate
%       9  =  missing value


if nargin ==1
    sig=3;
    acclim_depth=20;
    plot_graph=1;
end

if nargin ==2
    acclim_depth=20;
    plot_graph=1;
end

if nargin ==3
    plot_graph=1;
end

subStructNames = fieldnames(cruise_struct);
% Loop through each substructure
for ii = 1:length(subStructNames)
    % Get the current substructure
    currentSubStruct = cruise_struct.(subStructNames{ii});
    % Calculate the difference between consecutive values in CTDOXY_umol_kg_1 and CTDOXY_umol_kg_2
    diff_CTDOXY_1 = diff(currentSubStruct.CTDOXY_umol_kg_1);
    diff_CTDOXY_2 = diff(currentSubStruct.CTDOXY_umol_kg_2);

    % Identify outliers in diff_CTDSAL_1 using the standard deviation method
    mu = mean(diff_CTDOXY_1);
    sigma = std(diff_CTDOXY_1);
    outlierIndex_CTDOXY_1 = find(diff_CTDOXY_1 < mu - sig*sigma | diff_CTDOXY_1 > mu + sig*sigma);
    
    % Identify outliers in diff_CTDSAL_2 using the standard deviation method
    mu = mean(diff_CTDOXY_2);
    sigma = std(diff_CTDOXY_2);
    outlierIndex_CTDOXY_2 = find(diff_CTDOXY_2 < mu - sig*sigma | diff_CTDOXY_2 > mu + sig*sigma);
    
    % Create new substructures to store the outlier flags
    CTDOXY_1_FLAG = ones(size(currentSubStruct.CTDOXY_umol_kg_1)) * 2;
    CTDOXY_1_FLAG(outlierIndex_CTDOXY_1) = 3;

    CTDOXY_2_FLAG = ones(size(currentSubStruct.CTDOXY_umol_kg_2)) * 2;
    CTDOXY_2_FLAG(outlierIndex_CTDOXY_2) = 3;

    % Flag data above 20 meters or specified acclim_depth in the downcast
    [~, maxIndex] = max(currentSubStruct.CTDPRS);
    downcastStartIndex = find(currentSubStruct.CTDPRS(1:maxIndex) == min(currentSubStruct.CTDPRS(1:maxIndex)), 1, 'last');
    downcastEndIndex = find(currentSubStruct.CTDPRS(1:maxIndex) > acclim_depth, 1, 'first');
    
    if ~isempty(downcastStartIndex) && ~isempty(downcastEndIndex)
        CTDOXY_1_FLAG(downcastStartIndex:downcastEndIndex) = 3;
        CTDOXY_2_FLAG(downcastStartIndex:downcastEndIndex) = 3;
    end
    CTDOXY_1_FLAG(end-1:end)=3;
    CTDOXY_2_FLAG(end-1:end)=3;

    %Extra quality control measurements rate of change (similar to sigma 
    % but different approach), spike_test and flat line
    %
    %The following tests incorporate the guidelines for QC test outlined in:
    %
    %QARTOD (2015). Manual for Real-Time Quality Control of Dissolved Oxygen 
    % Observations: A Guide to Quality Control and Quality Assurance for Dissolved 
    % Oxygen Observations in Coastal Oceans. Version 2.0. U.S. Integrated Ocean Observing System.
    %
    %Wong, A., Keeley, R., Carval, T., & the Argo Data Management Team (2019). 
    % Argo Quality Control Manual for CTD and Trajectory Data. 
    % Version 3.2. http://dx.doi.org/10.13155/33951
    
    %Primary sensor
 
    TimeV=currentSubStruct.Time_elapsed_s;
    [flag,~]=spike_test(currentSubStruct.CTDOXY_umol_kg_1,'spike_suspect',0.5, ...
        'spike_fail',2,'time',TimeV);
    CTDOXY_1_FLAG(ismember(flag,3))=3;
    CTDOXY_1_FLAG(ismember(flag,4))=4;

    [flag,~]=rate_of_change_test(currentSubStruct.CTDOXY_umol_kg_1, ...
        'rate_suspect',2,'time',TimeV,'threshold_rate','pertimestep');
    CTDOXY_1_FLAG(ismember(flag,3))=3;
    CTDOXY_1_FLAG(ismember(flag,4))=4;

    [flag,~]=flat_line_test(currentSubStruct.CTDOXY_umol_kg_1);
    CTDOXY_1_FLAG(ismember(flag,3))=3;
    CTDOXY_1_FLAG(ismember(flag,4))=4;

    %Seconday sensor
 
    TimeV=currentSubStruct.Time_elapsed_s;
    [flag,~]=spike_test(currentSubStruct.CTDOXY_umol_kg_2,'spike_suspect',0.5, ...
        'spike_fail',2,'time',TimeV);
    CTDOXY_2_FLAG(ismember(flag,3))=3;
    CTDOXY_2_FLAG(ismember(flag,4))=4;

    [flag,~]=rate_of_change_test(currentSubStruct.CTDOXY_umol_kg_2, ...
        'rate_suspect',2,'time',TimeV,'threshold_rate','pertimestep');
    CTDOXY_2_FLAG(ismember(flag,3))=3;
    CTDOXY_2_FLAG(ismember(flag,4))=4;

    [flag,~]=flat_line_test(currentSubStruct.CTDOXY_umol_kg_2);
    CTDOXY_2_FLAG(ismember(flag,3))=3;
    CTDOXY_2_FLAG(ismember(flag,4))=4;

    assignin('caller', inputname(1), setfield(cruise_struct, subStructNames{ii}, 'CTDOXY_1_FLAG', CTDOXY_1_FLAG));
    cruise_struct = evalin('caller', inputname(1));


    assignin('caller', inputname(1), setfield(cruise_struct, subStructNames{ii}, 'CTDOXY_2_FLAG', CTDOXY_2_FLAG));
    cruise_struct = evalin('caller', inputname(1));
    currentSubStruct = cruise_struct.(subStructNames{ii});

    % Create a new figure for the current substructure
    if plot_graph==1
        figure;
        
        % Plot CTDPRS against CTDSAL_1
        plot(currentSubStruct.CTDOXY_umol_kg_1, currentSubStruct.CTDPRS);
        hold on;
        axis ij
        % Plot CTDPRS against CTDSAL_2
        plot(currentSubStruct.CTDOXY_umol_kg_2, currentSubStruct.CTDPRS);
        
        ix1=find(ismember(currentSubStruct.CTDOXY_1_FLAG,3));
        ix2=find(ismember(currentSubStruct.CTDOXY_1_FLAG,4));
        
        ix3=find(ismember(currentSubStruct.CTDOXY_2_FLAG,3));
        ix4=find(ismember(currentSubStruct.CTDOXY_2_FLAG,4));
        % Plot Questionable data
        plot([currentSubStruct.CTDOXY_umol_kg_1(ix1);currentSubStruct.CTDOXY_umol_kg_2(ix3)], ...
            [currentSubStruct.CTDPRS(ix1);currentSubStruct.CTDPRS(ix3)], 'gx','MarkerSize',10,'LineWidth',3);

        %plot(currentSubStruct.CTDOXY_umol_kg_1(ix1), currentSubStruct.CTDPRS(ix1), 'gx','MarkerSize',10,'LineWidth',3);
        %plot(currentSubStruct.CTDOXY_umol_kg_2(ix3), currentSubStruct.CTDPRS(ix3), 'gx','MarkerSize',10,'LineWidth',3);
       

        %Plot Bad data
        
        plot([currentSubStruct.CTDOXY_umol_kg_1(ix2);currentSubStruct.CTDOXY_umol_kg_2(ix4)], ...
            [currentSubStruct.CTDPRS(ix2);currentSubStruct.CTDPRS(ix4)], 'or','MarkerSize',30,'LineWidth',3);
        %plot(currentSubStruct.CTDOXY_umol_kg_1(ix2), currentSubStruct.CTDPRS(ix2), 'or','MarkerSize',30,'LineWidth',3);
        %plot(currentSubStruct.CTDOXY_umol_kg_2(ix4), currentSubStruct.CTDPRS(ix4), 'or','MarkerSize',30,'LineWidth',3);

        % Add labels and title
        xlabel('CTDOXY [\mumol kg^-^1]');
        ylabel('CTDPRS');
        title(subStructNames{ii}, 'Interpreter', 'none');
        ax=gca;
        ax.FontSize=16;
        axis square; grid on
        legend_labels = {'Primary sensor', 'Seconday sensor'};

        % Create a legend only if flagged data points are present
            if any(CTDOXY_1_FLAG == 3) || any(CTDOXY_1_FLAG == 4) || any(CTDOXY_2_FLAG == 3) || any(CTDOXY_2_FLAG == 4)
                if any(CTDOXY_1_FLAG == 3) || any(CTDOXY_2_FLAG == 3)
                    legend_labels{end+1} = 'Questionable data';
                end

                if any(CTDOXY_1_FLAG == 4) || any(CTDOXY_2_FLAG == 4)
                    legend_labels{end+1} = 'Bad data';
                end

            end
                legend(legend_labels, 'Interpreter', 'none');
    end
end


end