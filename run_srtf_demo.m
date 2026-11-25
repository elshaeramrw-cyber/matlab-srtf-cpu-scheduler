%% Main Script to Run SRTF Scheduler
clear; clc; close all;

%% Step 1: Create the Excel data file
fprintf('Creating Excel data file...\n');

% Create process data
processID = [1; 2; 3; 4; 5];
arrivalTime = [0; 1; 2; 3; 4];
burstTime = [8; 4; 9; 5; 2];
priority = [1; 2; 1; 3; 2];

% Create table
processData = table(processID, arrivalTime, burstTime, priority, ...
    'VariableNames', {'ProcessID', 'ArrivalTime', 'BurstTime', 'Priority'});

% Write to Excel
writetable(processData, 'process_data.xlsx', 'Sheet', 'Process_Data');
fprintf('Excel file created: process_data.xlsx\n');

%% Step 2: Display the data
fprintf('\nProcess Data:\n');
disp(processData);

%% Step 3: Create and run scheduler
fprintf('\nCreating SRTF scheduler...\n');
scheduler = SRTF_Scheduler(1);  % Create instance with time quantum = 1

% Load data from Excel
fprintf('Loading data from Excel...\n');
scheduler = scheduler.loadFromExcel('process_data.xlsx', 'Process_Data');

%% Step 4: Run scheduling algorithm
fprintf('\nRunning SRTF scheduling...\n');
scheduler = scheduler.schedule();

%% Step 5: Plot Gantt chart
fprintf('\nGenerating Gantt chart...\n');
scheduler.plotGanttChart();

%% Step 6: Export results
fprintf('\nExporting results to Excel...\n');
scheduler.exportToExcel('srtf_results.xlsx');
fprintf('Results saved to: srtf_results.xlsx\n');

%% Step 7: Display summary
fprintf('\n%s\n', repmat('=', 60));
fprintf('SCHEDULING COMPLETED SUCCESSFULLY!\n');
fprintf('%s\n', repmat('=', 60));