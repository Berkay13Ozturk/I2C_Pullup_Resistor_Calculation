%I2C interface
function I2C()

    %Units
    kilo  = 10^3;
    mili  = 10^-3;
    micro = 10^-6; 
    nano  = 10^-9;
    pico  = 10^-12;

    pullupResLim = 120;    %kohms

    %Application parameters for pull-up resistance limits calculation
    imargin = 1;           % [0: 0]
                           % [1: 100]  
    iihIn   = [(1 * micro), (1 * micro), (1 * micro), (1 * micro)]; %Each master and slave [Total iih]
    iihIn   = (1  + imargin) * sum(iihIn);                  %µA

    vddIn   = 3.3;                                          %V
    vol     = [(0.4), (0.2 * vddIn)];                       %V
    vih     = [(0.7 * vddIn), (0.8 * vddIn)];               %V
    iol     = [(3 * mili), (6 * mili), (20 * mili)];        %mA [Standard & Fast (VOL = 0.4 V), Fast (VOL = 0.6 V), Fast Plus VOL = 0.4 V]
    tr      = [(1000 * nano), (300 * nano), (120 * nano)];  %ns [Standard, Fast, Fast Plus]
    cbus    = 400 * pico;                                   %pF
    
    %Pull-up resistance limits and its ideal value for best margin
        %Standard mode
    pullup_resistor_limits(nano, vddIn, vol(2), iol(1), tr(1), cbus, vih(1), iihIn);    
        %Fast mode
    pullup_resistor_limits(nano, vddIn, vol(2), iol(1), tr(2), cbus, vih(1), iihIn);    
        %Fast mode plus 
    pullup_resistor_limits(nano, vddIn, vol(2), iol(1), tr(3), cbus, vih(1), iihIn);    
        
    
    %Pull-up resistance min and max
    [capacitance, pullupResMax, vdd, pullupResMin] = pullup_resistor_sizing(mili, nano, pico);
    %Leakage current
    [~, iih, vdd2, rp]                             = input_leagage_current(kilo);
       
    %Rp (max) vs Cb
    figure('Name', 'Pull-up Resistance (Max)');
    plot(capacitance ./ pico, pullupResMax ./ kilo);
    ylim([0 pullupResLim]);
    xticks(0:10:400);
    yticks(0:5:120);
    xlabel('C_b (pF)');
    ylabel('R_{p_{max}} (k_{ohms (\Omega)})');
    grid on;
    title('Pull-up resistance (max) as a function of bus capacitance');
    legend('Standard Mode', 'Fast Mode', 'Fast Mode Plus');

    %Rp (min) vs VDD
    figure('Name', 'Pull-up Resistance (Min) [Sink = 2 mA]');
    plot(vdd, pullupResMin(:,:,1) ./ kilo);
    xticks(0:0.5:20);
    yticks(0:0.25:7);
    xlabel('VDD (V)');
    ylabel('R_{p_{min}} (k_{ohms (\Omega)})');
    grid on;
    title('Pull-up resistance (min) as a function of supply voltage [Sink = 2 mA]');
    legend('Standard Mode & Fast Mode (VOL = 0.4 V)', 'Fast Mode (VOL = 0.6 V)', 'Fast Mode Plus (VOL = 0.4 V)');

    figure('Name', 'Pull-up Resistance (Min) [Sink = 3 mA]');
    plot(vdd, pullupResMin(:,:,2) ./ kilo);
    ylim([0 7]);
    xticks(0:0.5:20);
    yticks(0:0.25:7);
    xlabel('VDD (V)');
    ylabel('R_{p_{min}} (k_{ohms (\Omega)})');
    grid on;
    title('Pull-up resistance (min) as a function of supply voltage [Sink = 3 mA]');
    legend('Standard Mode & Fast Mode (VOL = 0.4 V)', 'Fast Mode (VOL = 0.6 V)', 'Fast Mode Plus (VOL = 0.4 V)');

    %Leakage current
    figure('Name', 'Leakage current');
    plot(iih ./ micro, rp ./ kilo);
    xticks(0:10:200);
    yticks(0:5:120);
    xlim([0 200]);
    ylim([0 120]);
    xlabel('Input leakage (µA)');
    ylabel('R_{p_{max}} (k_{ohms (\Omega)})');
    grid on;
    title('Leakage current asa function of R_p (Max) with VDD as parameter');
    legend(strcat(num2str(vdd2), 'V'));

end

%Pull-up resistor sizing
function [capacitance, pullupResMax, vdd, pullupResMin] = pullup_resistor_sizing(mili, nano, pico)

    riseTimeStd      = 1000 * nano;
    riseTimeFastMax  = 300  * nano;
    riseTimeFastPlus = 120  * nano;

    vdd              = linspace(0, 20, 4000);
    volMax2mA        = 0.2 .* vdd; %VDD <= 2V
    volMax3mA        = 0.4;        %VDD >  2V
    iol              = [3 * mili; 6 * mili; 20 * mili]; %Standard / Fast (0.4 V VOL); Fast (0.6 V VOL); Fast Plus (0.4 V VOL)

    riseTime         = [riseTimeStd riseTimeFastMax riseTimeFastPlus];
    capacitance      = linspace(0, 400 * pico, 4000);

    pullupResMax     = transpose(transpose(riseTime) ./ (0.847297860387203 .* capacitance));
    pullupResMin2mA  = (vdd - volMax2mA) ./ iol;
    pullupResMin3mA  = (vdd - volMax3mA) ./ iol;

    pullupResMin(:,:,1) = transpose(pullupResMin2mA);
    pullupResMin(:,:,2) = transpose(pullupResMin3mA);

end

%Input leakage current
    %Required noise margin = 0.2 VDD
function [iil, iih, vdd, rp] = input_leagage_current(kilo)

    rp           = linspace(0, 120 * kilo, 4000);
    safetyMargin = 0.2;
    vdd          = transpose(0:1:20);
    vilMax       = 0.3 * vdd;
    vihMax       = 0.7 * vdd;

    iil          = (vdd - (vilMax - (safetyMargin .* vdd))) ./ rp;
    iih          = (vdd - (vihMax + (safetyMargin .* vdd))) ./ rp;

end

%Limitations for a given application
function pullup_resistor_limits(nano, vddIn, vol, iol, tr, cbus, vih, iihIn)

    %Supply voltage (VDD)
    lowerLimit = (vddIn - vol) ./ iol;
    
    %Total bus capacitance (Cbus)
    temp(1)    = tr ./ (0.847297860387203   .* cbus);
        
    %Total high-level input current (IIH)
    temp(2)    = (vddIn - (vih + (0.2       .* vddIn))) ./ iihIn;
    
    upperLimit = min(temp);
    idealVal   = (lowerLimit + upperLimit)  ./ 2;
    
    %Plot the results
    plot_pullup_resistor_limits(nano, lowerLimit, idealVal, upperLimit, vddIn, vol, iol, tr, cbus, vih, iihIn);

end

%Plot
function plot_pullup_resistor_limits(nano, lowerLimit, idealVal, upperLimit, vddIn, vol, iol, tr, cbus, vih, iihIn)

    %Parameters
    orange    = [1 0.549 0];
    darkRed   = [0.50196 0 0];
    darkGreen = [0.133 0.5451 0.133];
    golden    = [0.855 0.647 0.1255];
    
    %Minimum, ideal and maximum values of the pull-up resistor
    barName   = categorical({'(a) Lower Limit', '(b) Ideal Value', '(c) Upper Limit'});
    barData   = [lowerLimit idealVal upperLimit];
    
    figure('Name', 'Pull-up Resistance Values');
    hold on;
        %Minimum
    barPlot           = bar(barName(1), barData(1), 0.25);
    barPlot.FaceColor = darkRed;
    barPlot.EdgeColor = darkRed;
    text(barName(1), min(lowerLimit, upperLimit) /2, strcat(num2str(lowerLimit), ' \Omega'),    'FontSize', 8, 'FontWeight', 'bold',            ...
                                                                                                'HorizontalAlignment', 'center', 'Color', 'white');
        %Ideal
    barPlot           = bar(barName(2), barData(2), 0.25);
    barPlot.FaceColor = darkGreen;
    barPlot.EdgeColor = darkGreen;
    text(barName(2), min(lowerLimit, upperLimit) /2,   strcat(num2str(idealVal),   ' \Omega'),  'FontSize', 8, 'FontWeight', 'bold',            ...
                                                                                                'HorizontalAlignment', 'center', 'Color', 'white');
        %Maximum
    barPlot           = bar(barName(3), barData(3), 0.25);
    barPlot.FaceColor = darkRed;
    barPlot.EdgeColor = darkRed;    
    text(barName(3), min(lowerLimit, upperLimit) /2, strcat(num2str(upperLimit), ' \Omega'),    'FontSize', 8, 'FontWeight', 'bold',            ...
                                                                                                'HorizontalAlignment', 'center', 'Color', 'white');
    grid on;
    if (tr == 1000 * nano)
        mode = ' [Standard Mode]';
    elseif (tr == 300 * nano)
        mode = ' [Fast Mode]';        
    elseif (tr == 120 * nano)
        mode = ' [Fast Mode Plus]';        
    end
    title(strcat('Pull-up Resistor Range (R_p)', mode));
    ylabel('ohms (\Omega)');

    if (upperLimit >= lowerLimit)
        paramPlace  = barName(1);
        text(barName(2), (max(lowerLimit, upperLimit) * 0.025) + max(lowerLimit, upperLimit), strcat(num2str(lowerLimit),                       ...
                                                               ' \Omega\leq R_p \leq', num2str(upperLimit), ' \Omega'),                         ...
                                                               'FontSize', 12, 'FontWeight', 'bold',                                            ...
                                                               'HorizontalAlignment', 'center', 'Color', orange);
    else
        paramPlace  = barName(3);
        text(barName(2), (max(lowerLimit, upperLimit) * 0.025) + max(lowerLimit, upperLimit), 'Impossible to operate in this mode!',            ...
                                                               'FontSize', 12, 'FontWeight', 'bold',                                            ...
                                                               'HorizontalAlignment', 'center', 'Color', darkRed);
    end
    text(paramPlace, max(lowerLimit, upperLimit) - (max(lowerLimit, upperLimit) * 0.125),                                                       ...
                                                               strcat('V_{DD}: ', num2str(vddIn), sprintf(' V\nV_{OL}:'), num2str(vol),         ...
                                                               sprintf(' V\nV_{IH}:'),  num2str(vih),   sprintf(' V\nI_{OL}:'), num2str(iol),   ...
                                                               sprintf(' A\nI_{IH}:'),  num2str(iihIn), sprintf(' A\nt_{R}:'),  num2str(tr),    ...
                                                               sprintf(' s\nC_{BUS}:'), num2str(cbus), ' F'), 'FontSize', 10, 'FontWeight',     ...
                                                               'bold', 'HorizontalAlignment', 'left', 'Color', golden);
    ylim([0 ((max(lowerLimit, upperLimit) * 0.1) + max(lowerLimit, upperLimit))]);
    hold off;
    
end
