function table = adjust_btl_salinity(table, brob1,brob2)
    
    original_name = evalin('caller', 'inputname(1)');
    original_name = string(original_name);

    % For primary sensor
    SAL_1 = table.Sal00;
    SAL_1_ADJ = (SAL_1-brob1(1))./brob1(2);
    table.Sal00_ADJ = SAL_1_ADJ;

    % For secondary sensor
    SAL_2 = table.Sal11;
    SAL_2_ADJ = (SAL_2-brob2(1))./brob2(2);
    table.Sal11_ADJ = SAL_2_ADJ;

    assignin('base', original_name, table);

end