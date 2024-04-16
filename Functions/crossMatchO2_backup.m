function [brob1,stats1,brob2,stats2,cross_match_table1,cross_match_table2]=crossMatchO2_backup(varargin)
%Function to match up Winkle oxygen measurements against the CTD measurements 
%at the bottle closure. This function search for the corresponding cast and
%corresponding Niskin bottle. Then a robust linear fit is adjusted to 
%this match up, the results are ploted and the coefficients are stored to
%adjust the CTD oxygen profiles

%This is a different function structure than the correspondign crossMatchSal
% because the Winkler table do not have lat lon and it is needed to convert 
% the values from umol L-1 to umol kg-1. So in order to execute this
% function the STEP FIVE that consist on importing the .btl data into the
% workspace and the STEP 11 (import winkler measurements) and STEP 12 
% (add lat and lon to the winkler table), have been executed before
%Example:
%     [brob1,stats1,brob2,stats2]=crossMatchO2(table1,table2);
%
% NOTE: it is important that in both cases the table of the imported .bl files is 
% the first imput, and the O2_winkler imported table is the 
% second input.  To decide to get (or not) the output graph of the
% robust linear fit and the identified outliers, the option is to set the
% last value to 0. If is set to 1 or empty, you will have the graphs.
%IMPORTANT: THE IMPORTED TABLE WITH THE NISKIN CLOSURE DATA (.btl files) GOES FIRST
%FOLLOWED BY THE WINKLER TABLE
% Example:
%      [brob1,stats1,brob2,stats2]=crossMatchSal(Niskin_table,Winkler_table,0);
%       NO GRAPHS WOULD BE DISPLAYED
%
%See also import_O2_winkler.m  &  cruise_btl2table.m
    Niskin = varargin{1};
    Winkler = varargin{2};
    table1Name = evalin('caller', 'inputname(1)');
    table1Name = string(table1Name);
    
    table2Name = evalin('caller', 'inputname(2)');
    table2Name = string(table2Name);

CruiseName = extractBefore(table2Name,6);

idx = [];
found = false(height(Winkler), 1);
% Loop through each row in Winkler
for i = 1:height(Winkler)
    % Find the rows in Niskin where Niskin.CTD is equal to Winkle.CTD and Niskin.Niskin_Bottle is equal to Winkler.CTD
    tempo_idx = find(Niskin.CTD == Winkler.CTD(i) & Niskin.Niskin_Bottle == Winkler.Niskin_Bottle(i));

    % Append the indices to the idx array
    idx = [idx; tempo_idx];

    % Keep track of which rows in Winkler were found in Niskin
    if ~isempty(tempo_idx)
        found(i) = true;
    end
end

% Find the row in Winkler that was not found in Niskin
not_found = find(~found);

% Display a warning message if a row in Winkler was not found in Niskin
if ~isempty(not_found)
    warning('The following row(s) in the Winkler table was not found in the corresponding Niskin bottle table:')
    disp(Winkler(not_found,:))
    warning('This row(s) will be not considered in the analysis and remove from the corresponding table. If you want to include them, considere to review the original files (.btl and .xls) and the logsheet to find the source of the error')
    %Contact me if you want to keep the values for some reason and fill the
    %missing imported values from Niskin with a NaN. I have done it like
    %this because of practicalities after find it an error by appliying
    %these collection of functions to a new cruise
end

Winkler(~found,:)=[];

%Adding new values to the Winkler table
Winkler.PRESS=Niskin.PrDM(idx);
Winkler.TEMP=(Niskin.T090C(idx)+Niskin.T190C(idx))./2;
Winkler.SAL=(Niskin.Sal00_ADJ(idx)+Niskin.Sal11_ADJ(idx))./2;

 %Absolute salinity
 %SA=gsw_SA_from_SP(Winkler.SAL,Winkler.PRESS,Winkler.Lon,Winkler.Lat);
 Winkler.SA=gsw_SA_from_SP(Winkler.SAL,Winkler.PRESS,Winkler.Lon,Winkler.Lat);

 %Conservative temperature
 %CT=gsw_CT_from_t(SA,Winkler.Fixing_Temp_deg,0);
 Winkler.CT=gsw_CT_from_t(Winkler.SA,Winkler.TEMP,Winkler.PRESS);

 %rho is in situ density in kg/m3
 %rho=gsw_rho_CT_exact(SA,CT,0);
 Winkler.rho=gsw_rho_CT_exact(Winkler.SA,Winkler.CT,Winkler.PRESS);
 Winkler.O2_umol_kg_1=((Winkler.O2_umol_l_1))./(Winkler.rho./1000);

% Store the information in the original table
assignin('base', table2Name, Winkler);


%Adding new values to the Niskin table
Niskin.mean_temp=(Niskin.T090C+Niskin.T190C)./2;
Niskin.mean_sal=(Niskin.Sal00_ADJ+Niskin.Sal11_ADJ)./2;

%Absolute salinity
Niskin.SA=gsw_SA_from_SP(Niskin.mean_sal,Niskin.PrDM,Niskin.Lon,Niskin.Lat);

%Conservative temperature
Niskin.CT=gsw_CT_from_t(Niskin.SA,Niskin.mean_temp,Niskin.PrDM);

%rho is in situ density in kg/m3
Niskin.rho=gsw_rho_CT_exact(Niskin.SA,Niskin.CT,Niskin.PrDM);

Niskin.primary_O2_umol_kg_1=((Niskin.('Sbeox0ML/L')).*44.661)./(Niskin.rho./1000);

Niskin.secondary_O2_umol_kg_1=((Niskin.('Sbeox1ML/L')).*44.661)./(Niskin.rho./1000);

% Store the information in the original table
assignin('base', table1Name, Niskin);

X=Winkler.O2_umol_kg_1;
Y1=Niskin.primary_O2_umol_kg_1(idx); %For the primary oxygen of the CTD
Y2=Niskin.secondary_O2_umol_kg_1(idx); %For the secondary oxygen of the CTD

Depth=Winkler.PRESS;
Winkler_CTD = Winkler.CTD;
unique_CTD = unique(Winkler_CTD);

exclude_outliers_1=zeros(size(Winkler_CTD));
exclude_outliers_2=zeros(size(Winkler_CTD));
if nargin ==4
    exclude_outliers=varargin{4};
    exclude_outliers_1=exclude_outliers(:,1);
    exclude_outliers_2=exclude_outliers(:,2);
end

%% Primary oxygen sensor
X1=X(~exclude_outliers_1);Y1=Y1(~exclude_outliers_1);
[brob1,stats1]=robustfit(X1,Y1);%Robust linear regression

% no_outliers_ind1=find(abs(stats.resid)<stats.mad_s);
% X_no_outliers = X(no_outliers_ind1); % Select only the elements of X that are not outliers
% Y1_no_outliers = Y1(no_outliers_ind1); % Select only the elements of Y1 that are not outliers
% [brob1,stats1] = robustfit(X_no_outliers,Y1_no_outliers); % Perform a robust linear fit on the data without outliers

%%  RANSAC model (Random sample consensus) UNDER EVALUATION. IF STILL COMMENTED APPOLOGIES I FORGOT. PLEASE ERASE

% data1=[X, Y1];
% % https://uk.mathworks.com/discovery/ransac.html
% 
% % Define the fit function
% fitFcn = @(x) polyfit(x(:,1), x(:,2), 1);
% 
% % Define the distance function
% distFcn = @(model, x) abs(x(:,2) - polyval(model, x(:,1)));
% 
% % Define the sample size
% sampleSize = 2;
% 
% % Define the maximum distance
% maxDistance = 0.1;
% 
% % Use RANSAC to fit a line to noisy data
% [model, inlierIdx] = ransac(data1, fitFcn, distFcn, sampleSize, maxDistance);
% 
% % Fit a linear model to your data set
% modelInliers = polyfit(data1(inlierIdx,1),data1(inlierIdx,2),1);
% inlierPts = data1(inlierIdx,:);
% x = [min(inlierPts(:,1)) max(inlierPts(:,1))];
% y = modelInliers(1)*x + modelInliers(2);
%   plot(x, y, 'r', 'LineWidth', 2);

%%

if nargin < 3 || varargin{3} == 1
    %dealing with outliers. mad= median absolute residuals
    outliers_ind1=find(abs(stats1.resid)>stats1.mad_s);

    fs=16;
    figure
    bar(abs(stats1.resid))
    hold on
    yl=yline(stats1.mad_s,'k--');
    yl_y=yl.Value;
    yl_x=mean(xlim);
    text(yl_x,yl_y,'Median Absolute Residuals','FontWeight','bold','FontSize',fs)
    hold off
    xlabel('sample')
    ylabel('Residuals')
    ax=gca;
    ax.FontSize=fs;
    title(CruiseName + ' ' +'Primary oxygen')

    figure
    scatter(X1,Y1,20,'Filled')
    hold on
    plot(X1(outliers_ind1),Y1(outliers_ind1),'mo','LineWidth',2)
    plot(X1,brob1(1)+brob1(2)*X1,'g')
    hold off
    xlabel('Winkler Oxygen [\mumol kg^-^1]')
    ylabel('CTD Oxygen [\mumol kg^-^1]')
    legend('Data','Outlier','Robust Regression','Location','best')
    grid on; box on;
    ax=gca;
    ax.FontSize=fs;
    title(CruiseName + ' ' +'Primary Oxygen')
    axis equal;axis square


    resid1 = stats1.resid;

    Depth1=Depth(~exclude_outliers_1);
    Winkler_CTD1=Winkler_CTD(~exclude_outliers_1);
    unique_CTD1 = unique(Winkler_CTD1);
    
    figure
    scatter(resid1, Depth1, 60,Winkler_CTD1,'filled','MarkerEdgeColor','k');
    cmap=colormap(parula(length(unique_CTD1)));
    axis ij

    hold on;
    h=zeros(length(unique_CTD1),1);
    lineStyles={'-','--'};
    for i = 1:length(unique_CTD1)
        idx = find(Winkler_CTD1 == unique_CTD1(i));
        h(i)=plot(resid1(idx), Depth1(idx), 'Color', cmap(i,:), 'LineWidth', 2,'LineStyle', lineStyles{mod(i,2)+1});
    end
    legendLabels = cellstr(num2str(unique_CTD1)); 
    xline(0,'LineWidth',1.5)
    lgd = legend(h, legendLabels,'location','northeastoutside'); 
    lgd.Title.String = 'CTD'; 

    ax=gca;
    ax.FontSize=fs;
    ax.YLabel.String='Pressure (dbar)';
    ax.XLabel.String='Residual_{Winkler-CTD} [\mumol kg^-^1]';
    title(CruiseName + ' ' +'Primary Oxygen')
    box on; grid on



end

%% Secondary oxygen sensor
X2=X(~exclude_outliers_2);Y2=Y2(~exclude_outliers_2);
[brob2,stats2]=robustfit(X2,Y2);%Robust linear regression
% no_outliers_ind2=find(abs(stats2.resid)<stats2.mad_s);
% X_no_outliers = X(no_outliers_ind2); % Select only the elements of X that are not outliers
% Y2_no_outliers = Y2(no_outliers_ind2); % Select only the elements of Y1 that are not outliers
% [brob2,stats2] = robustfit(X_no_outliers,Y2_no_outliers); % Perform a robust linear fit on the data without outliers





if nargin < 3 || varargin{3} == 1
    %dealing with outliers. mad= median absolute residuals
    outliers_ind1=find(abs(stats2.resid)>stats2.mad_s);

    fs=16;
    figure
    bar(abs(stats2.resid))
    hold on
    yl=yline(stats2.mad_s,'k--');
    yl_y=yl.Value;
    yl_x=mean(xlim);
    text(yl_x,yl_y,'Median Absolute Residuals','FontWeight','bold','FontSize',fs)
    hold off
    xlabel('sample')
    ylabel('Residuals')
    ax=gca;
    ax.FontSize=fs;
    title(CruiseName + ' ' +'Secondary Oxygen')

    figure
    scatter(X2,Y2,20,'Filled')
    hold on
    plot(X2(outliers_ind1),Y2(outliers_ind1),'mo','LineWidth',2)
    plot(X2,brob2(1)+brob2(2)*X2,'g')
    hold off
    xlabel('Winkler Oxygen [\mumol kg^-^1]')
    ylabel('CTD Oxygen [\mumol kg^-^1]')
    legend('Data','Outlier','Robust Regression','Location','best')
    grid on; box on;
    ax=gca;
    ax.FontSize=fs;
    title(CruiseName + ' ' +'Secondary Oxygen')
    axis equal;axis square

    resid2 = stats2.resid;

    Depth2=Depth(~exclude_outliers_2);
    Winkler_CTD2=Winkler_CTD(~exclude_outliers_2);
    unique_CTD2 = unique(Winkler_CTD2);


    figure
    scatter(resid2, Depth, 60,Winkler_CTD2,'filled','MarkerEdgeColor','k');
    cmap=colormap(parula(length(unique_CTD2)));
    axis ij

    hold on;
    h=zeros(length(unique_CTD2),1);
    lineStyles={'-','--'};
    for i = 1:length(unique_CTD2)
        idx = find(Winkler_CTD2 == unique_CTD2(i));
        h(i)=plot(resid2(idx), Depth2(idx), 'Color', cmap(i,:), 'LineWidth', 2,'LineStyle', lineStyles{mod(i,2)+1});
    end
    legendLabels = cellstr(num2str(unique_CTD2)); 
    xline(0,'LineWidth',1.5)
    lgd = legend(h, legendLabels,'location','northeastoutside'); 
    lgd.Title.String = 'CTD'; 

    ax=gca;
    ax.FontSize=fs;
    ax.YLabel.String='Pressure (dbar)';
    ax.XLabel.String='Residual_{Winkler-CTD} [\mumol kg^-^1]';
    title(CruiseName + ' ' +'Secondary Oxygen')
    box on; grid on


    mad_s_value_1 = stats1.mad_s * ones(size(Winkler_CTD1));
    mad_s_abs_1 = abs(stats1.resid) > stats1.mad_s;

    mad_s_value_2 = stats2.mad_s * ones(size(Winkler_CTD2));
    mad_s_abs_2 = abs(stats2.resid) > stats2.mad_s;


    cross_match_table1=table(Winkler_CTD1,Depth1,X1,Y1,resid1,mad_s_value_1,...
        mad_s_abs_1);
    cross_match_table1.Properties.VariableNames={'CTD_num','Pressure_dbar',...
        'Winkler','Prim_oxygen','Resid_primary','MAD_primary','Outlier_1'};

    cross_match_table2=table(Winkler_CTD2,Depth2,X2,Y2,resid2,mad_s_value_2, ...
        mad_s_abs_2);
    cross_match_table2.Properties.VariableNames={'CTD_num','Pressure_dbar',...
        'Winkler','Second_oxygen','Resid_secondary','MAD_secondary','Outlier_2'};


end
end