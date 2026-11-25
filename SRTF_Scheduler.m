
classdef SRTF_Scheduler
    % SRTF_SCHEDULER Shortest Remaining Time First Scheduling Algorithm
    % Implements preemptive SJF scheduling with Excel I/O
    
    properties
        % Process properties
        ProcessID
        ArrivalTime
        BurstTime
        RemainingTime
        Priority
        StartTime
        CompletionTime
        WaitingTime
        TurnaroundTime
        ResponseTime
        Status % 0=New, 1=Ready, 2=Running, 3=Terminated
        
        % Scheduler properties
        CurrentTime
        ReadyQueue
        RunningProcess
        CompletedProcesses
        GanttChart
        TotalIdleTime
        TimeQuantum
        
        % Performance metrics
        AvgWaitingTime
        AvgTurnaroundTime
        AvgResponseTime
        CPUUtilization
        Throughput
    end
    
    methods
        function obj = SRTF_Scheduler(timeQuantum)
            % SRTF_SCHEDULER Constructor
            % timeQuantum: Minimum scheduling time unit (default: 1)
            if nargin < 1
                timeQuantum = 1;
            end
            obj.TimeQuantum = timeQuantum;
            obj.CurrentTime = 0;
            obj.ReadyQueue = [];
            obj.RunningProcess = [];
            obj.CompletedProcesses = [];
            obj.GanttChart = table('Size',[0, 3], ...
                'VariableTypes', {'double', 'double', 'string'}, ...
                'VariableNames', {'Start', 'Duration', 'Process'});
            obj.TotalIdleTime = 0;
        end
        
        function obj = loadFromExcel(obj, filename, sheetName)
            % LOADFROMEXCEL Load process data from Excel file
            % filename: Excel file name (e.g., 'process_data.xlsx')
            % sheetName: Sheet name containing process data
            
            try
                fprintf('Loading process data from %s...\n', filename);
                
                % Read the data
                data = readtable(filename, 'Sheet', sheetName);
                
                % Validate required columns
                requiredCols = {'ProcessID', 'ArrivalTime', 'BurstTime'};
                for i = 1:length(requiredCols)
                    if ~any(strcmp(data.Properties.VariableNames, requiredCols{i}))
                        error('Missing required column: %s', requiredCols{i});
                    end
                end
                
                % Extract process information
                obj.ProcessID = data.ProcessID;
                obj.ArrivalTime = data.ArrivalTime;
                obj.BurstTime = data.BurstTime;
                
                % Initialize remaining times
                obj.RemainingTime = obj.BurstTime;
                
                % Initialize optional priority if exists
                if any(strcmp(data.Properties.VariableNames, 'Priority'))
                    obj.Priority = data.Priority;
                else
                    obj.Priority = ones(size(obj.ProcessID));
                end
                
                % Initialize other arrays
                numProcesses = length(obj.ProcessID);
                obj.StartTime = NaN(numProcesses, 1);
                obj.CompletionTime = NaN(numProcesses, 1);
                obj.WaitingTime = zeros(numProcesses, 1);
                obj.TurnaroundTime = zeros(numProcesses, 1);
                obj.ResponseTime = NaN(numProcesses, 1);
                obj.Status = zeros(numProcesses, 1); % All processes start as New
                
                fprintf('Loaded %d processes from Excel.\n', numProcesses);
                obj.printProcessTable();
                
            catch ME
                fprintf('Error loading Excel file: %s\n', ME.message);
                rethrow(ME);
            end
        end
        
        function obj = schedule(obj)
            % SCHEDULE Execute SRTF scheduling algorithm
            fprintf('\n%s\n', repmat('=', 60));
            fprintf('SRTF SCHEDULING STARTED\n');
            fprintf('%s\n\n', repmat('=', 60));
            
            % Sort processes by arrival time initially
            [~, order] = sort(obj.ArrivalTime);
            remainingProcesses = order; % Indices of processes not yet arrived
            
            % Reset scheduler state
            obj.CurrentTime = 0;
            obj.ReadyQueue = [];
            obj.RunningProcess = [];
            obj.CompletedProcesses = [];
            obj.GanttChart = table('Size',[0, 3], ...
                'VariableTypes', {'double', 'double', 'string'}, ...
                'VariableNames', {'Start', 'Duration', 'Process'});
            obj.TotalIdleTime = 0;
            
            % Main scheduling loop
            while ~isempty(remainingProcesses) || ~isempty(obj.ReadyQueue) || ~isempty(obj.RunningProcess)
                % Add arriving processes to ready queue
                obj = obj.addArrivingProcesses(remainingProcesses);
                
                % Check for preemption
                if obj.shouldPreempt()
                    obj = obj.preemptCurrentProcess();
                end
                
                % If no process is running, get next from ready queue
                if isempty(obj.RunningProcess) && ~isempty(obj.ReadyQueue)
                    obj = obj.dispatchNextProcess();
                end
                
                % Execute current process
                obj = obj.executeCurrentProcess();
                
                % Update waiting times for processes in ready queue
                obj = obj.updateWaitingTimes();
                
                % Move to next time unit
                obj.CurrentTime = obj.CurrentTime + obj.TimeQuantum;
            end
            
            % Calculate metrics
            obj = obj.calculateMetrics();
            obj = obj.printResults();
        end
        
        function obj = addArrivingProcesses(obj, remainingProcesses)
            % ADDARRIVINGPROCESSES Add processes that have arrived
            
            % Find processes that have arrived at current time
            arrivedIdx = [];
            for i = 1:length(remainingProcesses)
                procIdx = remainingProcesses(i);
                if obj.ArrivalTime(procIdx) <= obj.CurrentTime
                    % Add to ready queue
                    obj.ReadyQueue = [obj.ReadyQueue; procIdx];
                    obj.Status(procIdx) = 1; % Set to Ready
                    arrivedIdx = [arrivedIdx; i];
                    
                    fprintf('Time %d: Process P%d arrived (Burst: %d)\n', ...
                        obj.CurrentTime, obj.ProcessID(procIdx), obj.RemainingTime(procIdx));
                end
            end
            
            % Sort ready queue by remaining time (shortest first)
            if ~isempty(obj.ReadyQueue)
                [~, sortIdx] = sort(obj.RemainingTime(obj.ReadyQueue));
                obj.ReadyQueue = obj.ReadyQueue(sortIdx);
            end
        end
        
        function shouldPreempt = shouldPreempt(obj)
            % SHOULDPREEMPT Check if current process should be preempted
            shouldPreempt = false;
            
            if isempty(obj.RunningProcess) || isempty(obj.ReadyQueue)
                return;
            end
            
            % Get the process with shortest remaining time in ready queue
            nextProcIdx = obj.ReadyQueue(1);
            
            % Check if next process has shorter remaining time
            if obj.RemainingTime(nextProcIdx) < obj.RemainingTime(obj.RunningProcess)
                shouldPreempt = true;
            % If equal remaining time, check arrival time
            elseif obj.RemainingTime(nextProcIdx) == obj.RemainingTime(obj.RunningProcess)
                if obj.ArrivalTime(nextProcIdx) < obj.ArrivalTime(obj.RunningProcess)
                    shouldPreempt = true;
                end
            end
        end
        
        function obj = preemptCurrentProcess(obj)
            % PREEMPTCURRENTPROCESS Preempt the currently running process
            fprintf('Time %d: Preempting P%d (Remaining: %d)\n', ...
                obj.CurrentTime, obj.ProcessID(obj.RunningProcess), ...
                obj.RemainingTime(obj.RunningProcess));
            
            % Change status to Ready
            obj.Status(obj.RunningProcess) = 1;
            
            % Add back to ready queue
            obj.ReadyQueue = [obj.RunningProcess; obj.ReadyQueue];
            
            % Sort ready queue
            [~, sortIdx] = sort(obj.RemainingTime(obj.ReadyQueue));
            obj.ReadyQueue = obj.ReadyQueue(sortIdx);
            
            % Clear running process
            obj.RunningProcess = [];
        end
        
        function obj = dispatchNextProcess(obj)
            % DISPATCHNEXTPROCESS Dispatch next process from ready queue
            obj.RunningProcess = obj.ReadyQueue(1);
            obj.ReadyQueue(1) = []; % Remove from queue
            
            % Set status to Running
            obj.Status(obj.RunningProcess) = 2;
            
            % Set start time if not set
            if isnan(obj.StartTime(obj.RunningProcess))
                obj.StartTime(obj.RunningProcess) = obj.CurrentTime;
                obj.ResponseTime(obj.RunningProcess) = ...
                    obj.CurrentTime - obj.ArrivalTime(obj.RunningProcess);
            end
            
            fprintf('Time %d: Dispatching P%d (Remaining: %d)\n', ...
                obj.CurrentTime, obj.ProcessID(obj.RunningProcess), ...
                obj.RemainingTime(obj.RunningProcess));
        end
        
        function obj = executeCurrentProcess(obj)
            % EXECUTECURRENTPROCESS Execute the current running process
            
            if ~isempty(obj.RunningProcess)
                % Record Gantt chart entry
                newEntry = {obj.CurrentTime, obj.TimeQuantum, ...
                    sprintf('P%d', obj.ProcessID(obj.RunningProcess))};
                obj.GanttChart = [obj.GanttChart; newEntry];
                
                % Execute for one time quantum
                obj.RemainingTime(obj.RunningProcess) = ...
                    obj.RemainingTime(obj.RunningProcess) - obj.TimeQuantum;
                
                % Check if process completed
                if obj.RemainingTime(obj.RunningProcess) <= 0
                    obj = obj.completeCurrentProcess();
                end
            else
                % CPU is idle
                obj.TotalIdleTime = obj.TotalIdleTime + obj.TimeQuantum;
                
                % Record idle time in Gantt chart
                newEntry = {obj.CurrentTime, obj.TimeQuantum, 'IDLE'};
                obj.GanttChart = [obj.GanttChart; newEntry];
                
                fprintf('Time %d: CPU Idle\n', obj.CurrentTime);
            end
        end
        
        function obj = completeCurrentProcess(obj)
            % COMPLETECURRENTPROCESS Complete the current running process
            
            completionTime = obj.CurrentTime + obj.TimeQuantum;
            procIdx = obj.RunningProcess;
            
            obj.CompletionTime(procIdx) = completionTime;
            obj.TurnaroundTime(procIdx) = ...
                completionTime - obj.ArrivalTime(procIdx);
            obj.Status(procIdx) = 3; % Terminated
            
            % Add to completed processes list
            obj.CompletedProcesses = [obj.CompletedProcesses; procIdx];
            
            fprintf('Time %d: Process P%d completed (Turnaround: %d)\n', ...
                completionTime, obj.ProcessID(procIdx), obj.TurnaroundTime(procIdx));
            
            obj.RunningProcess = [];
        end
        
        function obj = updateWaitingTimes(obj)
            % UPDATEWAITINGTIMES Update waiting times for ready processes
            
            for i = 1:length(obj.ReadyQueue)
                procIdx = obj.ReadyQueue(i);
                obj.WaitingTime(procIdx) = obj.WaitingTime(procIdx) + obj.TimeQuantum;
            end
        end
        
        function obj = calculateMetrics(obj)
            % CALCULATEMETRICS Calculate performance metrics
            
            completedIdx = find(obj.Status == 3);
            
            if isempty(completedIdx)
                error('No processes completed!');
            end
            
            obj.AvgWaitingTime = mean(obj.WaitingTime(completedIdx));
            obj.AvgTurnaroundTime = mean(obj.TurnaroundTime(completedIdx));
            obj.AvgResponseTime = mean(obj.ResponseTime(completedIdx));
            
            totalTime = obj.CurrentTime;
            if totalTime > 0
                obj.CPUUtilization = ((totalTime - obj.TotalIdleTime) / totalTime) * 100;
                obj.Throughput = length(completedIdx) / totalTime;
            else
                obj.CPUUtilization = 0;
                obj.Throughput = 0;
            end
        end
        
        function obj = printResults(obj)
            % PRINTRESULTS Print scheduling results
            
            fprintf('\n%s\n', repmat('=', 60));
            fprintf('SCHEDULING RESULTS\n');
            fprintf('%s\n\n', repmat('=', 60));
            
            fprintf('Process Execution Details:\n');
            fprintf('%s\n', repmat('-', 85));
            fprintf('PID\tArrival\tBurst\tStart\tComplete\tWaiting\tTurnaround\tResponse\n');
            fprintf('%s\n', repmat('-', 85));
            
            % Sort by process ID for display
            [~, sortIdx] = sort(obj.ProcessID);
            completedIdx = find(obj.Status == 3);
            displayIdx = intersect(sortIdx, completedIdx);
            
            for i = 1:length(displayIdx)
                idx = displayIdx(i);
                fprintf('P%d\t%d\t%d\t%d\t%d\t\t%d\t%d\t\t%d\n', ...
                    obj.ProcessID(idx), obj.ArrivalTime(idx), ...
                    obj.BurstTime(idx), obj.StartTime(idx), ...
                    obj.CompletionTime(idx), obj.WaitingTime(idx), ...
                    obj.TurnaroundTime(idx), obj.ResponseTime(idx));
            end
            
            fprintf('\n%s\n', repmat('=', 60));
            fprintf('PERFORMANCE METRICS\n');
            fprintf('%s\n', repmat('=', 60));
            fprintf('Average Waiting Time:    %.2f\n', obj.AvgWaitingTime);
            fprintf('Average Turnaround Time: %.2f\n', obj.AvgTurnaroundTime);
            fprintf('Average Response Time:   %.2f\n', obj.AvgResponseTime);
            fprintf('CPU Utilization:         %.2f%%\n', obj.CPUUtilization);
            fprintf('Throughput:              %.3f processes/unit time\n', obj.Throughput);
            fprintf('Total Idle Time:         %d\n', obj.TotalIdleTime);
            fprintf('Total Execution Time:    %d\n', obj.CurrentTime);
        end
        
        function plotGanttChart(obj)
            % PLOTGANTTCHART Plot Gantt chart of process execution
            
            if height(obj.GanttChart) == 0
                fprintf('No data to plot!\n');
                return;
            end
            
            figure('Position', [100, 100, 800, 400]);
            hold on;
            
            % Get unique process IDs
            uniqueProcs = unique(obj.GanttChart.Process);
            colors = lines(length(uniqueProcs));
            
            % Map process to color
            colorMap = containers.Map();
            for i = 1:length(uniqueProcs)
                colorMap(uniqueProcs{i}) = colors(i, :);
            end
            
            % Plot each process block
            yPos = 1;
            yTicks = [];
            yLabels = {};
            
            for i = 1:height(obj.GanttChart)
                proc = obj.GanttChart.Process{i};
                startTime = obj.GanttChart.Start(i);
                duration = obj.GanttChart.Duration(i);
                
                % Create bar for this time slice
                rectangle('Position', [startTime, yPos-0.3, duration, 0.6], ...
                    'FaceColor', colorMap(proc), 'EdgeColor', 'black', 'LineWidth', 1);
                
                % Add process label
                text(startTime + duration/2, yPos, proc, ...
                    'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'middle', ...
                    'Color', 'white', 'FontWeight', 'bold');
                
                % Track y-axis positions
                if i == 1 || ~strcmp(proc, obj.GanttChart.Process{i-1})
                    yTicks = [yTicks, yPos];
                    yLabels = [yLabels, proc];
                    yPos = yPos + 1;
                end
            end
            
            % Format plot
            xlabel('Time', 'FontSize', 12);
            ylabel('Process', 'FontSize', 12);
            title('SRTF Scheduling Gantt Chart', 'FontSize', 14);
            grid on;
            
            % Set y-axis
            ylim([0.5, yPos-0.5]);
            set(gca, 'YTick', yTicks);
            set(gca, 'YTickLabel', yLabels);
            
            % Set x-axis
            xlim([0, max(obj.GanttChart.Start + obj.GanttChart.Duration)]);
            xlabel('Time Units');
            
            hold off;
        end
        
        function exportToExcel(obj, filename)
            % EXPORTTOEXCEL Export results to Excel file
            
            try
                fprintf('Exporting results to %s...\n', filename);
                
                % Prepare process data table
                processData = table(...
                    obj.ProcessID, ...
                    obj.ArrivalTime, ...
                    obj.BurstTime, ...
                    obj.Priority, ...
                    obj.StartTime, ...
                    obj.CompletionTime, ...
                    obj.WaitingTime, ...
                    obj.TurnaroundTime, ...
                    obj.ResponseTime, ...
                    obj.Status, ...
                    'VariableNames', {...
                    'ProcessID', 'ArrivalTime', 'BurstTime', 'Priority', ...
                    'StartTime', 'CompletionTime', 'WaitingTime', ...
                    'TurnaroundTime', 'ResponseTime', 'Status'});
                
                % Prepare metrics table
                metricsData = table({...
                    'Average Waiting Time'; 'Average Turnaround Time'; ...
                    'Average Response Time'; 'CPU Utilization'; ...
                    'Throughput'; 'Total Idle Time'; 'Total Execution Time'}, ...
                    [obj.AvgWaitingTime; obj.AvgTurnaroundTime; ...
                    obj.AvgResponseTime; obj.CPUUtilization; ...
                    obj.Throughput; obj.TotalIdleTime; obj.CurrentTime], ...
                    'VariableNames', {'Metric', 'Value'});
                
                % Prepare Gantt chart table
                ganttData = obj.GanttChart;
                
                % Write to Excel
                writetable(processData, filename, 'Sheet', 'Process_Results');
                writetable(metricsData, filename, 'Sheet', 'Performance_Metrics');
                writetable(ganttData, filename, 'Sheet', 'Gantt_Chart');
                
                fprintf('Results exported successfully!\n');
                
            catch ME
                fprintf('Error exporting to Excel: %s\n', ME.message);
            end
        end
        
        function printProcessTable(obj)
            % PRINTPROCESSTABLE Print loaded process table
            fprintf('\nLoaded Processes:\n');
            fprintf('%s\n', repmat('-', 50));
            fprintf('PID\tArrival\tBurst\tPriority\n');
            fprintf('%s\n', repmat('-', 50));
            
            for i = 1:length(obj.ProcessID)
                fprintf('P%d\t%d\t%d\t%d\n', ...
                    obj.ProcessID(i), obj.ArrivalTime(i), ...
                    obj.BurstTime(i), obj.Priority(i));
            end
        end
    end
end
% SRTF_INTERACTIVE Interactive SRTF scheduling demo

function srtf_interactive()
    % Main interactive function
    
    fprintf('=============================================\n');
    fprintf('    SRTF SCHEDULING INTERACTIVE DEMO\n');
    fprintf('=============================================\n\n');
    
    while true
        fprintf('\nMAIN MENU:\n');
        fprintf('1. Load process data from Excel\n');
        fprintf('2. Enter process data manually\n');
        fprintf('3. Run demo with example data\n');
        fprintf('4. Analyze existing results\n');
        fprintf('5. Exit\n');
        
        choice = input('Enter your choice (1-5): ', 's');
        
        switch choice
            case '1'
                loadFromExcel();
            case '2'
                enterManually();
            case '3'
                runDemo();
            case '4'
                analyzeResults();
            case '5'
                fprintf('Exiting program. Goodbye!\n');
                break;
            otherwise
                fprintf('Invalid choice. Please try again.\n');
        end
    end
end

function loadFromExcel()
    % Load data from Excel file
    fprintf('\n--- Load from Excel ---\n');
    
    filename = input('Enter Excel filename (e.g., data.xlsx): ', 's');
    
    if ~isfile(filename)
        fprintf('File not found: %s\n', filename);
        return;
    end
    
    % List sheets
    try
        [~, sheets] = xlsfinfo(filename);
        fprintf('Available sheets:\n');
        for i = 1:length(sheets)
            fprintf('%d. %s\n', i, sheets{i});
        end
        
        sheetIdx = input('Select sheet number: ');
        if sheetIdx < 1 || sheetIdx > length(sheets)
            fprintf('Invalid sheet selection.\n');
            return;
        end
        
        sheetName = sheets{sheetIdx};
        
        % Create scheduler and load data
        scheduler = SRTF_Scheduler(1);
        scheduler = scheduler.loadFromExcel(filename, sheetName);
        
        % Ask for time quantum
        tq = input('Enter time quantum (default=1): ');
        if isempty(tq)
            tq = 1;
        end
        scheduler.TimeQuantum = tq;
        
        % Run scheduling
        runScheduling(scheduler);
        
    catch ME
        fprintf('Error: %s\n', ME.message);
    end
end

function enterManually()
    % Enter process data manually
    fprintf('\n--- Enter Process Data Manually ---\n');
    
    processes = [];
    procCount = 0;
    
    while true
        fprintf('\nEnter process details (or empty to finish):\n');
        
        pid = input('Process ID: ');
        if isempty(pid)
            break;
        end
        
        arrival = input('Arrival Time: ');
        burst = input('Burst Time: ');
        priority = input('Priority (default=1): ');
        if isempty(priority)
            priority = 1;
        end
        
        procCount = procCount + 1;
        processes(procCount, :) = [pid, arrival, burst, priority];
        
        fprintf('Process P%d added.\n', pid);
    end
    
    if isempty(processes)
        fprintf('No processes entered.\n');
        return;
    end
    
    % Save to temporary Excel file
    tempData = array2table(processes, ...
        'VariableNames', {'ProcessID', 'ArrivalTime', 'BurstTime', 'Priority'});
    writetable(tempData, 'temp_processes.xlsx');
    
    % Create scheduler and load data
    scheduler = SRTF_Scheduler(1);
    scheduler = scheduler.loadFromExcel('temp_processes.xlsx', 'temp_processes');
    
    % Run scheduling
    runScheduling(scheduler);
end

function runDemo()
    % Run demo with example data
    fprintf('\n--- Running Demo ---\n');
    
    % Create example data
    create_example_data('demo_data.xlsx');
    
    % Load and run
    scheduler = SRTF_Scheduler(1);
    scheduler = scheduler.loadFromExcel('demo_data.xlsx', 'Process_Data');
    
    runScheduling(scheduler);
end

function runScheduling(scheduler)
    % Run scheduling and display results
    fprintf('\nRunning SRTF scheduling...\n');
    
    % Execute scheduling
    scheduler = scheduler.schedule();
    
    % Ask for visualization
    showPlot = input('\nShow Gantt chart? (y/n): ', 's');
    if lower(showPlot(1)) == 'y'
        scheduler.plotGanttChart();
    end
    
    % Ask for export
    export = input('\nExport results to Excel? (y/n): ', 's');
    if lower(export(1)) == 'y'
        filename = input('Enter output filename (default: srtf_output.xlsx): ', 's');
        if isempty(filename)
            filename = 'srtf_output.xlsx';
        end
        scheduler.exportToExcel(filename);
    end
    
    % Save to workspace
    saveChoice = input('\nSave scheduler object to workspace? (y/n): ', 's');
    if lower(saveChoice(1)) == 'y'
        assignin('base', 'scheduler', scheduler);
        fprintf('Scheduler object saved as "scheduler" in workspace.\n');
    end
end

function analyzeResults()
    % Analyze existing results file
    fprintf('\n--- Analyze Results ---\n');
    
    filename = input('Enter results filename (e.g., srtf_results.xlsx): ', 's');
    
    if ~isfile(filename)
        fprintf('File not found.\n');
        return;
    end
    
    try
        % Read process results
        processData = readtable(filename, 'Sheet', 'Process_Results');
        metricsData = readtable(filename, 'Sheet', 'Performance_Metrics');
        ganttData = readtable(filename, 'Sheet', 'Gantt_Chart');
        
        fprintf('\nProcess Results:\n');
        disp(processData);
        
        fprintf('\nPerformance Metrics:\n');
        disp(metricsData);
        
        fprintf('\nGantt Chart Data:\n');
        disp(ganttData);
        
        % Visualize if requested
        showPlot = input('\nVisualize Gantt chart from data? (y/n): ', 's');
        if lower(showPlot(1)) == 'y'
            figure;
            hold on;
            
            % Plot Gantt chart from data
            uniqueProcs = unique(ganttData.Process);
            colors = lines(length(uniqueProcs));
            colorMap = containers.Map();
            
            for i = 1:length(uniqueProcs)
                colorMap(uniqueProcs{i}) = colors(i, :);
            end
            
            yPos = 1;
            yTicks = [];
            yLabels = {};
            
            for i = 1:height(ganttData)
                proc = ganttData.Process{i};
                startTime = ganttData.Start(i);
                duration = ganttData.Duration(i);
                
                rectangle('Position', [startTime, yPos-0.3, duration, 0.6], ...
                    'FaceColor', colorMap(proc), 'EdgeColor', 'black', 'LineWidth', 1);
                
                text(startTime + duration/2, yPos, proc, ...
                    'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'middle', ...
                    'Color', 'white', 'FontWeight', 'bold');
                
                if i == 1 || ~strcmp(proc, ganttData.Process{i-1})
                    yTicks = [yTicks, yPos];
                    yLabels = [yLabels, proc];
                    yPos = yPos + 1;
                end
            end
            
            xlabel('Time');
            ylabel('Process');
            title('SRTF Scheduling Gantt Chart (From File)');
            grid on;
            ylim([0.5, yPos-0.5]);
            set(gca, 'YTick', yTicks);
            set(gca, 'YTickLabel', yLabels);
            
            hold off;
        end
        
    catch ME
        fprintf('Error reading file: %s\n', ME.message);
    end
end

scheduler = SRTF_Scheduler();
scheduler = scheduler.loadFromExcel('my_data.xlsx', 'Sheet1');
scheduler = scheduler.schedule();
scheduler.plotGanttChart();
scheduler.exportToExcel('my_results.xlsx');