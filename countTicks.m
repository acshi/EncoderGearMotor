function main
    clc;
    fprintf('Starting to count ticks...\n');
    
    %thresholdForPeak = 300;
    %thresholdForValley = 300;
    minPeakPeakDif = 8; % 7
    definitePeakPeakDif = 15;
    minPeakResetDif = 35; % 35
    minPeakValleyDif = 8; % 3
    maxReturnDif = 10; % 10
    
    minDifFromAvg1 = 4;
    minDifFromAvg2 = 10;
    
    avgRecentVal1 = 0;
    avgRecentBeta1 = 0.01;
    
    avgRecentVal2 = 0;
    avgRecentBeta2 = 0.1;

    d = csvread('nowvals.csv');
    d = flipud(d);%[d; flipud(d)];
    n = size(d, 1);
    ticks = 0;
    allTicks = 0;
    plusTicks = 0;
    minusTicks = 0;
    
    currentTickState = 1;
    
    inValley = true;
    
    foundValleysX = [];
    foundValleysY = [];
    foundPeaksX = [];
    foundPeaksY = [];
    state0X = [];
    state0Y = [];
    state1X = [];
    state1Y = [];
    state2X = [];
    state2Y = [];
    
    lastChange = 0;
    secondLastPeak = -1;
    lastPeak = -1;
    lastUsedPeak = -1;
    secondLastUsedPeak = -1;
    lastValley = -1;
    peak = -1;
    peakI = -1;
    valley = -1;
    valleyI = -1;
    
    % low pass filter stuff
    alpha = 1; % value of 1 effectively disables the filtering
    val = d(1);
    
    global h;
    h = zeros(size(d));
    
    for i = 1:n
        val = floor(alpha * d(i) + (1 - alpha) * val);
        h(i) = val;
        
        % we use another two low pass filters to get average values that
        % can help us ignore spurious small noise-like features
        if avgRecentVal1 == 0
            avgRecentVal1 = val;
            avgRecentVal2 = val;
        else
            avgRecentVal1 = avgRecentVal1 * (1 - avgRecentBeta1) + val * avgRecentBeta1;
            avgRecentVal2 = avgRecentVal2 * (1 - avgRecentBeta2) + val * avgRecentBeta2;
        end
        
        if abs(avgRecentVal1 - val) >= minDifFromAvg1 || abs(avgRecentVal2 - val) >= minDifFromAvg2
            if inValley && val >= valley + minPeakValleyDif
                if valley ~= -1
                    fprintf('Found valley: %d\n', valley);
                    foundValleysX = [foundValleysX, valleyI];
                    foundValleysY = [foundValleysY, valley];
                    
                    lastValley = valley;
                    valley = -1;
                    inValley = false;
                end
            elseif ~inValley && val <= peak - minPeakValleyDif
                if peak ~= -1
                    fprintf('Found peak: %d\n', peak);
                    foundPeaksX = [foundPeaksX, peakI];
                    foundPeaksY = [foundPeaksY, peak];
                    if peakI == 11880
                        fprintf('debug\n');
                    end
                    
                    hadStateChange = false;
                    if peak >= lastValley + minPeakValleyDif
                        allTicks = allTicks + 1;
                        if peak >= lastUsedPeak + minPeakPeakDif && ...
                                (lastChange ~= -1 || abs(secondLastUsedPeak - peak) <= maxReturnDif)
                            if currentTickState < 2
                                % Advance from smaller to bigger peak
                                % (0 to 1, 1 to 2)
                                hadStateChange = true;
                                currentTickState = currentTickState + 1;
                                ticks = ticks + 1;
                                plusTicks = plusTicks + 1;
                                secondLastUsedPeak = lastUsedPeak;
                                lastUsedPeak = peak;
                                % allow next peak to go either way
                                if lastChange == -1; lastChange = 0; else lastChange = 1; end
                            else
                                % Peak got bigger... but we should have
                                % already been at the largest peak...
                                % update our peak for comparison later
                                fprintf('Last peak update from %d to %d. Still at state 2.\n', lastUsedPeak, peak);
                                lastUsedPeak = peak;
                            end
                        elseif peak <= lastUsedPeak - minPeakResetDif && currentTickState == 2 && ...
                                (lastChange ~= -1 || abs(secondLastUsedPeak - peak) <= maxReturnDif)
                            % Advance from biggest peak to smallest
                            % (2 to 0)
                            hadStateChange = true;
                            currentTickState = 0;
                            ticks = ticks + 1;
                            plusTicks = plusTicks + 1;
                            secondLastUsedPeak = lastUsedPeak;
                            lastUsedPeak = peak;
                            if lastChange == -1; lastChange = 0; else lastChange = 1; end
                        elseif peak <= lastUsedPeak - minPeakPeakDif && ...
                                (lastChange ~= 1 || abs(peak - secondLastUsedPeak) <= maxReturnDif || peak <= lastUsedPeak - definitePeakPeakDif)
                            if currentTickState > 0
                                % Back from bigger to smaller peak
                                % (2 to 1, 1 to 0)
                                hadStateChange = true;
                                currentTickState = currentTickState - 1;
                                ticks = ticks - 1;
                                minusTicks = minusTicks + 1;
                                secondLastUsedPeak = lastUsedPeak;
                                lastUsedPeak = peak;
                                if lastChange == 1; lastChange = 0; else lastChange = -1; end
                            else
                                if lastChange == 0 && abs(secondLastUsedPeak - peak) >= minPeakResetDif
                                    % We thought we were going forward,
                                    % having just gone from 2 to 0, but
                                    % considering we have just fallen below
                                    % 0, that 2 to 0 must have actually
                                    % been 2 to 1.
                                    % Correct ticks and state.
                                    hadStateChange = true; % count as a state change anyways...
                                    ticks = ticks - 3;
                                    plusTicks = plusTicks - 1;
                                    minusTicks = minusTicks + 2;
                                    secondLastUsedPeak = lastUsedPeak;
                                    lastUsedPeak = peak;
                                    lastChange = -1;
                                    fprintf('Direction correction from 1 to -1\n');
                                else
                                    % Peak got smaller... but we should have
                                    % already been at the smallest peak...
                                    % update our peak for comparison later
                                    fprintf('Last peak update from %d to %d. Still at state 0.\n', lastUsedPeak, peak);
                                    lastUsedPeak = peak;
                                end
                            end
                        elseif peak >= lastUsedPeak + minPeakResetDif && currentTickState == 0 && ...
                                (lastChange ~= 1 || abs(peak - secondLastUsedPeak) <= maxReturnDif)
                            % Back from smallest to biggest peak
                            % (0 to 2)
                            hadStateChange = true;
                            currentTickState = 2;
                            ticks = ticks - 1;
                            minusTicks = minusTicks + 1;
                            secondLastUsedPeak = lastUsedPeak;
                            lastUsedPeak = peak;
                            if lastChange == 1; lastChange = 0; else lastChange = -1; end
                        elseif peak <= lastUsedPeak - minPeakPeakDif && currentTickState == 1 && ...
                                lastChange == 1 && abs(peak - secondLastUsedPeak) >= maxReturnDif
                            % We just thought we were going forward, but we
                            % are actually going backwards.
                            % The situation is a peak gets smaller
                            % as if from 1 to 0, but the previous 0 was
                            % way lower than this new one, so we know that
                            % isn't the case. Instead we must conclude we
                            % are going from 2 to 1 and we had an error in
                            % our state.
                            % Correct our count and state!
                            hadStateChange = true; % count as a state change anyways...
                            ticks = ticks - 3;
                            plusTicks = plusTicks - 1;
                            minusTicks = minusTicks + 2;
                            secondLastUsedPeak = lastUsedPeak;
                            lastUsedPeak = peak;
                            lastChange = -1;
                            fprintf('Direction correction from 1 to -1\n');
%                         elseif peak >= lastUsedPeak + minPeakPeakDif && ...
%                                 lastChange == -1 && abs(peak - secondLastUsedPeak) >= maxReturnDif
%                             % We are not going in the direction we think.
%                             % We just thought we were going backward, but we
%                             % are actually going forwards.
%                             % Correct our count and state!
%                             hadStateChange = true;
%                             currentTickState = 1;
%                             ticks = ticks + 3;
%                             plusTicks = plusTicks + 2;
%                             minusTicks = minusTicks - 1;
%                             secondLastUsedPeak = lastUsedPeak;
%                             lastUsedPeak = peak;
%                             lastChange = 1;
                        end
                    end
                    
                    if hadStateChange
                        fprintf('%d: Ticks: %d state: %d\n', peakI, ticks, currentTickState);
                        if currentTickState == 0
                            state0X = [state0X, peakI];
                            state0Y = [state0Y, peak];
                        elseif currentTickState == 1
                            state1X = [state1X, peakI];
                            state1Y = [state1Y, peak];
                        elseif currentTickState == 2
                            state2X = [state2X, peakI];
                            state2Y = [state2Y, peak];
                        end
                    end
                    
                    secondLastPeak = lastPeak;
                    lastPeak = peak;
                    peak = -1;
                    inValley = true;
                end
            end
        
            if ~inValley && (peak == -1 || val > peak)
                peak = val;
                peakI = i;
            elseif inValley && (valley == -1 || val < valley)
                valley = val;
                valleyI = i;
            end
        end
    end
    fprintf('%d ticks - %d ticks: %d\n', plusTicks, minusTicks, ticks);
    fprintf('All Ticks: %d\n', allTicks);
    
    figure(2);
    plot(d, '-');
    hold on;
    plot(foundValleysX, foundValleysY, 'o', 'MarkerSize', 10);
    plot(foundPeaksX, foundPeaksY, 's', 'MarkerSize', 10);
    plot(state0X, state0Y, 'rd', 'MarkerSize', 14);
    plot(state1X, state1Y, 'gd', 'MarkerSize', 14);
    plot(state2X, state2Y, 'bd', 'MarkerSize', 14);
    %xlim([7100, 8500]);
    xlim([11200, 12400]);
    ylim([325, 485]);
    
    legend('data', 'valleys', 'peaks', '0', '1', '2');
    hold off;
end