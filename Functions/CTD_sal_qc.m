function cruise_struct=CTD_sal_qc(cruise_struct,sig,acclim_depth,plot_graph)

%This function quality control the salinity data by identifying which
%values of the CTD profiles falls beyond a specified sigma thresshold. It
%center the test in the diff of the parameter (in this case salinity) with
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
    % Calculate the difference between consecutive values in CTDSAL_1 and CTDSAL_2
    diff_CTDSAL_1 = diff(currentSubStruct.CTDSAL_1);
    diff_CTDSAL_2 = diff(currentSubStruct.CTDSAL_2);

    % Identify outliers in diff_CTDSAL_1 using the standard deviation method
    mu = mean(diff_CTDSAL_1);
    sigma = std(diff_CTDSAL_1);
    outlierIndex_CTDSAL_1 = find(diff_CTDSAL_1 < mu - sig*sigma | diff_CTDSAL_1 > mu + sig*sigma);
    
    % Identify outliers in diff_CTDSAL_2 using the standard deviation method
    mu = mean(diff_CTDSAL_2);
    sigma = std(diff_CTDSAL_2);
    outlierIndex_CTDSAL_2 = find(diff_CTDSAL_2 < mu - sig*sigma | diff_CTDSAL_2 > mu + sig*sigma);
    
    % Create new substructures to store the outlier flags
    CTDSAL_1_FLAG = ones(size(currentSubStruct.CTDSAL_1)) * 2;
    CTDSAL_1_FLAG(outlierIndex_CTDSAL_1) = 3;

    CTDSAL_2_FLAG = ones(size(currentSubStruct.CTDSAL_2)) * 2;
    CTDSAL_2_FLAG(outlierIndex_CTDSAL_2) = 3;

    % Flag data above 20 meters or specified acclim_depth in the downcast
    [~, maxIndex] = max(currentSubStruct.CTDPRS);
    downcastStartIndex = find(currentSubStruct.CTDPRS(1:maxIndex) == min(currentSubStruct.CTDPRS(1:maxIndex)), 1, 'last');
    downcastEndIndex = find(currentSubStruct.CTDPRS(1:maxIndex) > acclim_depth, 1, 'first');
    
    if ~isempty(downcastStartIndex) && ~isempty(downcastEndIndex)
        CTDSAL_1_FLAG(downcastStartIndex:downcastEndIndex) = 3;
        CTDSAL_2_FLAG(downcastStartIndex:downcastEndIndex) = 3;
    end
    CTDSAL_1_FLAG(end-1:end)=3;
    CTDSAL_2_FLAG(end-1:end)=3;

    assignin('caller', inputname(1), setfield(cruise_struct, subStructNames{ii}, 'CTDSAL_1_FLAG', CTDSAL_1_FLAG));
    cruise_struct = evalin('caller', inputname(1));


    assignin('caller', inputname(1), setfield(cruise_struct, subStructNames{ii}, 'CTDSAL_2_FLAG', CTDSAL_2_FLAG));
    cruise_struct = evalin('caller', inputname(1));
    currentSubStruct = cruise_struct.(subStructNames{ii});

    % Create a new figure for the current substructure
    if plot_graph==1
        figure;
        
        % Plot CTDPRS against CTDSAL_1
        plot(currentSubStruct.CTDSAL_1, currentSubStruct.CTDPRS);
        hold on;
        axis ij
        % Plot CTDPRS against CTDSAL_2
        plot(currentSubStruct.CTDSAL_2, currentSubStruct.CTDPRS);
        
        ix1=find(ismember(currentSubStruct.CTDSAL_1_FLAG,3));
        % Plot outliers in CTDSAL_1
        plot(currentSubStruct.CTDSAL_1(ix1), currentSubStruct.CTDPRS(ix1), 'gx','MarkerSize',10,'LineWidth',3);
        
        ix2=find(ismember(currentSubStruct.CTDSAL_2_FLAG,3));
        % Plot outliers in CTDSAL_2
        plot(currentSubStruct.CTDSAL_2(ix2), currentSubStruct.CTDPRS(ix2), 'gx','MarkerSize',10,'LineWidth',3);
        
        % Add labels and title
        xlabel('CTDSAL');
        ylabel('CTDPRS');
        title(subStructNames{ii}, 'Interpreter', 'none');
        legend('Primary sensor', 'Seconday sensor', 'Questionable data','Location','best')
        ax=gca;
        ax.FontSize=16;
        axis square; grid on
    end
end

end