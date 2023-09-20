function graph_profiles_CTD(cruise_struct,varname)

cruise_name = evalin('caller', 'inputname(1)');
cruise_name = string(cruise_name);
cruise_name = extractBefore(cruise_name,6);

% Get the names of the profiles
subStructNames = fieldnames(cruise_struct);

if strcmp(varname,'temp')
    var1='CTDTMP_1';
    var2='CTDTMP_2';
    text_label='Temperature (°C)';
end

if strcmp(varname,'sal')
    var1='CTDSAL_1';
    var2='CTDSAL_2';
    text_label='Salinity';
end

if strcmp(varname,'oxy_ml_l')
    var1='CTDOXY_ml_L_1';
    var2='CTDOXY_ml_L_2';
    text_label='Dissolved oxygen (ml l^-^1)';
end

if strcmp(varname,'oxy_umol_kg')
    var1='CTDOXY_umol_kg_1';
    var2='CTDOXY_umol_kg_2';
    text_label='Dissolved oxygen (\mumol kg^-^1)';
end



for i = 1:length(subStructNames)
    figure;
    plot(cruise_struct.(subStructNames{i}).(var1), cruise_struct.(subStructNames{i}).CTDPRS, ...
        'Color',rgb('deeppink'),'LineWidth',1.5);
    hold on;
    axis ij
    plot(cruise_struct.(subStructNames{i}).(var2), cruise_struct.(subStructNames{i}).CTDPRS, ...
        'Color',rgb('chartreuse'),'LineWidth',1.5);
    ylabel('CTDPRS');
    legend('Primary sensor', 'Seconday sensor','Location','best')
    ax=gca;
    ax.XLabel.String=text_label;
    ax.FontSize=16;
    title(cruise_name + ' ' + subStructNames{i}, 'Interpreter', 'none')


end

end


