function main
    clc;
    fprintf('Starting to count ticks...\n');
    
    % These filters determine what are actually peaks
    % If either "min dif" value is set to 0, the filtering is disabled
    % If either difference from average is met, then the peak passes.
    minDifFromAvg1 = 0; % 6
    minDifFromAvg2 = 6; % 10
    
    avgRecentVal1 = 0;
    avgRecentBeta1 = 0.01;
    
    avgRecentVal2 = 0;
    avgRecentBeta2 = 0.1;
    
    % If this difference is met, the peak is considered to be a "tick"
    minPeakValleyDif = 7; % 3, 8
    minPeakPeakDif = 8; % 7

    d = csvread('nowvals.csv');
    %d = flipud(d);
    d = [d; flipud(d)];
    d = [d; flipud(d)];
    n = size(d, 1);
    
    plusTicks = 0;
    minusTicks = 0;
    
    startUp = true;
    currentTickState = 0;
    
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
    
    lastUsedPeak = -1;
    
    % When we find unique peaks, we shift them into this peak buffer,
    % and only then determine/decide what the second peak in the list
    % represents. This gives us 2 older peaks and 2 newer peaks to use in
    % that determination.
    peakBuffer = [-1, -1, -1, -1, -1];
    peakIBuffer = [-1, -1, -1, -1, -1];
    
    % This corresponds to peakBuffer(1) while currentTickState
    % corresponds to peakBuffer(2)
    lastTickState = -1;
    
    % Sometimes we determine that two ticks are actually identical to each
    % other after we have seen some ticks that follow them. In this case,
    % we do a partial shift to merge the two ticks, instead of a full one.
    doMergeShift = false;
    
    lastValley = -1;
    peak = -1;
    peakI = -1;
    valley = -1;
    valleyI = -1;
    
    for i = 1:n
        val = d(i);
        
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
                    %fprintf('Found valley: %d\n', valley);
                    foundValleysX = [foundValleysX, valleyI];
                    foundValleysY = [foundValleysY, valley];
                    
                    lastValley = valley;
                    valley = -1;
                    inValley = false;
                end
            elseif ~inValley && val <= peak - minPeakValleyDif
                if peak ~= -1
                    %fprintf('Found peak: %d\n', peak);
                    foundPeaksX = [foundPeaksX, peakI];
                    foundPeaksY = [foundPeaksY, peak];
                    
                    hadStateChange = false;
                    if peak >= lastValley + minPeakValleyDif
                        if abs(peak - peakBuffer(5)) < minPeakPeakDif
                            % not a different peak, so just update value if
                            % it makes it more different than previous
                            if abs(peak - peakBuffer(4)) > abs(peakBuffer(5) - peakBuffer(4))
                                peakBuffer(5) = peak;
                                peakIBuffer(5) = peakI;
                            end
                        else
                            % shift in the new peak
                            if doMergeShift
                                doMergeShift = false;
                                % keep the peak that minimizes difference
                                if abs(peakBuffer(3) - peakBuffer(4)) < abs(peakBuffer(2) - peakBuffer(4))
                                    peakBuffer(2:4) = peakBuffer(3:5);
                                    peakIBuffer(2:4) = peakIBuffer(3:5);
                                else
                                    peakBuffer(3:4) = peakBuffer(4:5);
                                    peakIBuffer(3:4) = peakIBuffer(4:5);
                                end
                            else
                                peakBuffer(1:4) = peakBuffer(2:5);
                                peakIBuffer(1:4) = peakIBuffer(2:5);
                            end
                            
                            peakBuffer(5) = peak;
                            peakIBuffer(5) = peakI;
                            
                            if peakBuffer(1) ~= -1
                                isRisingMid = peakBuffer(2) < peakBuffer(3) && ...
                                              peakBuffer(3) < peakBuffer(4) && ...
                                              currentTickState == 0;

                                isFallingMid = peakBuffer(2) > peakBuffer(3) && ...
                                               peakBuffer(3) > peakBuffer(4) && ...
                                               currentTickState == 2;

                                isRisingHigh = peakBuffer(2) < peakBuffer(3) && ...
                                               peakBuffer(3) > peakBuffer(4) && ...
                                               currentTickState == 1;

                                isFallingHigh = peakBuffer(2) < peakBuffer(3) && ...
                                                peakBuffer(3) > peakBuffer(4) && ...
                                                currentTickState == 0;

                                isRisingLow = peakBuffer(2) > peakBuffer(3) && ...
                                              peakBuffer(3) < peakBuffer(4) && ...
                                              currentTickState == 2;

                                isFallingLow = peakBuffer(2) > peakBuffer(3) && ...
                                               peakBuffer(3) < peakBuffer(4) && ...
                                               currentTickState == 1;
                                
                                nextTickState = currentTickState;
                                % determine identity of list's second peak
                                if isRisingMid || isFallingMid
                                    nextTickState = 1;
                                elseif isRisingHigh || isFallingHigh
                                    nextTickState = 2;
                                elseif isRisingLow || isFallingLow
                                    nextTickState = 0;
                                end
                                
                                isLowToFuture = peakBuffer(3) < peakBuffer(4) && ...
                                                peakBuffer(3) < peakBuffer(5);
                                            
                                isHighToFuture = peakBuffer(3) > peakBuffer(4) && ...
                                                 peakBuffer(3) > peakBuffer(5);
                                             
                                isLowToPast = peakBuffer(3) < peakBuffer(2) && ...
                                              peakBuffer(3) < peakBuffer(1);
                                          
                                isHighToPast = peakBuffer(3) > peakBuffer(2) && ...
                                               peakBuffer(3) > peakBuffer(1);
                                             
                                isFutureFalling = peakBuffer(4) > peakBuffer(5);
                                isFutureRising = peakBuffer(4) < peakBuffer(5);
                                
                                isFutureFarAway = peakIBuffer(4) - peakIBuffer(3) > (peakIBuffer(3) - peakIBuffer(1)) * 1.5;
                                isPastFarAway = peakIBuffer(3) - peakIBuffer(2) > (peakIBuffer(5) - peakIBuffer(3)) * 1.5;
                                
                                % if in a possible turn around situation,
                                % use a different metric to determine pos.
                                if lastTickState == nextTickState
                                    if ~isFutureFarAway
                                        if isLowToFuture
                                            nextTickState = 0;
                                        elseif isHighToFuture
                                            nextTickState = 2;
                                        else
                                            nextTickState = 1;
                                        end
                                    else
                                        if isLowToPast
                                            nextTickState = 0;
                                        elseif isHighToPast
                                            nextTickState = 2;
                                        else
                                            nextTickState = 1;
                                        end
                                    end
                                % This tick appears to be a repeat mid
                                % since there was drift time from the last
                                % peak and a higher peak soon.
                                % ...and so forth with the other conditions...
                                elseif isRisingHigh && ~isHighToFuture && isPastFarAway
                                    nextTickState = 1;
                                elseif isFallingHigh && ~isHighToFuture && isPastFarAway
                                    nextTickState = 0;
                                elseif isRisingLow && ~isLowToFuture && isPastFarAway
                                    nextTickState = 2;
                                elseif isFallingLow && ~isLowToFuture && isPastFarAway
                                    nextTickState = 1;
                                elseif isRisingMid && isLowToFuture && isFutureRising
                                    nextTickState = 0;
                                elseif isFallingMid && isHighToFuture && isFutureFalling
                                    nextTickState = 2;
                                end
                                
                                if peakBuffer(3) == 458 && peakIBuffer(3) > 10000
                                    fprintf('debug\n');
                                end
                                
                                newTickRising = nextTickState == mod(currentTickState + 1, 3);
                                newTickFalling = nextTickState == mod(currentTickState + 2, 3);
                                
                                if newTickRising && ~startUp
                                    plusTicks = plusTicks + 1;
                                elseif newTickFalling && ~startUp
                                    minusTicks = minusTicks + 1;
                                end
                                startUp = false;
                                
                                if nextTickState == currentTickState
                                    % New tick is the same as the last
                                    % So we merge them!
                                    doMergeShift = true;
                                else
                                    lastTickState = currentTickState;
                                    currentTickState = nextTickState;
                                end
                                
                                hadStateChange = true;
                            elseif peakBuffer(2) ~= -1
                                % determine initial currentTickState
                                if peakBuffer(3) < peakBuffer(4) && ...
                                   peakBuffer(4) < peakBuffer(5)
                                    currentTickState = 0;
                                elseif peakBuffer(3) > peakBuffer(4) && ...
                                       peakBuffer(4) > peakBuffer(5)
                                    currentTickState = 2;
                                else
                                    currentTickState = 1;
                                end
                            end
                        end
                    end
                    
                    if hadStateChange
                        fprintf('%d: Ticks: %d state: %d\n', peakIBuffer(3), plusTicks - minusTicks, currentTickState);
                        if currentTickState == 0
                            state0X = [state0X, peakIBuffer(3)];
                            state0Y = [state0Y, peakBuffer(3)];
                        elseif currentTickState == 1
                            state1X = [state1X, peakIBuffer(3)];
                            state1Y = [state1Y, peakBuffer(3)];
                        elseif currentTickState == 2
                            state2X = [state2X, peakIBuffer(3)];
                            state2Y = [state2Y, peakBuffer(3)];
                        end
                    end
                    
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
    fprintf('%d ticks - %d ticks: %d\n', plusTicks, minusTicks, plusTicks - minusTicks);
    fprintf('All Ticks: %d\n', plusTicks + minusTicks);
    
    figure(2);
    plot(d, '-');
    hold on;
    plot(foundValleysX, foundValleysY, 'o', 'MarkerSize', 10);
    plot(foundPeaksX, foundPeaksY, 's', 'MarkerSize', 10);
    plot(state0X, state0Y, 'rd', 'MarkerSize', 14);
    plot(state1X, state1Y, 'gd', 'MarkerSize', 14);
    plot(state2X, state2Y, 'bd', 'MarkerSize', 14);
    %xlim([7100, 8500]);
    %xlim([7100, 12000]);
    %xlim([11200, 14200]);
    %xlim([15000, 18000]);
    %xlim([19000, 21500]);
    %xlim([13500, 19000]);
    %xlim([5700, 8200]);
    %xlim([9500, 14500]);
    %xlim([27000, 32000]);
    xlim([26000, 28000]);
    ylim([325, 485]);
    
    legend('data', 'valleys', 'peaks', '0', '1', '2');
    hold off;
end