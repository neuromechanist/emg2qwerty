% test_single_file - Quick test of emg2qwerty BIDS converter on one file
%
% Description:
%   Tests the MATLAB BIDS converter on a single HDF5 file to verify
%   functionality before running the full batch conversion.
%
% Usage:
%   1. Edit the paths section below
%   2. Run: test_single_file
%
% Author: Yahya Shirazi, SCCN, INC, UCSD
% Date: 2025-09-30

clear all; close all;

%% ========== CONFIGURATION ==========
% Edit these paths for your system

% Path to EEGLAB
eeglabPath = '/Users/yahya/Documents/git/eeglab';

% Path to eeg-bids plugin (development version)
bidsPluginPath = '/Users/yahya/Documents/git/eeg-bids';

% Path to test HDF5 file
testFile = '/Volumes/data/FRL/emg2qwerty/2020-08-13-1597354281-keystrokes.hdf5';

% Output BIDS directory for test
testOutput = '/Users/yahya/Documents/git/emg2qwerty_bids_test';

% Path to this converter directory
converterPath = '/Users/yahya/Documents/git/emg2qwerty/matlab_bids_conversion';

%% ========== SETUP ==========
fprintf('==========================================================\n');
fprintf('emg2qwerty Single File Test\n');
fprintf('==========================================================\n\n');

% Add EEGLAB to path
fprintf('Setting up EEGLAB...\n');
addpath(eeglabPath);
eeglab nogui;

% Remove any installed eeg-bids plugin and add development version
fprintf('Setting up eeg-bids plugin...\n');
installedPlugins = dir(fullfile(eeglabPath, 'plugins', 'EEG-BIDS*'));
for i = 1:length(installedPlugins)
    pluginDir = fullfile(installedPlugins(i).folder, installedPlugins(i).name);
    rmpath(genpath(pluginDir));
    fprintf('  Removed: %s\n', installedPlugins(i).name);
end
addpath(bidsPluginPath);
fprintf('  Added: %s\n', bidsPluginPath);

% Add converter scripts
fprintf('Adding converter scripts...\n');
addpath(converterPath);

% Verify dependencies
fprintf('Verifying dependencies...\n');
if ~exist('bids_export', 'file')
    error('bids_export not found. Check eeg-bids plugin path: %s', bidsPluginPath);
end
if ~exist('emg2qwerty_load_hdf5', 'file')
    error('emg2qwerty_load_hdf5 not found. Check converter path: %s', converterPath);
end
if ~exist('emg2qwerty_convert_to_bids', 'file')
    error('emg2qwerty_convert_to_bids not found. Check converter path: %s', converterPath);
end

% Check test file exists
if ~exist(testFile, 'file')
    error('Test HDF5 file not found: %s', testFile);
end

fprintf('All dependencies found.\n\n');

%% ========== TEST CONVERSION ==========
fprintf('==========================================================\n');
fprintf('Testing Conversion\n');
fprintf('==========================================================\n\n');

fprintf('Input file:  %s\n', testFile);
fprintf('Output dir:  %s\n\n', testOutput);

% Create clean output directory
if exist(testOutput, 'dir')
    fprintf('Removing existing test output...\n');
    rmdir(testOutput, 's');
end
mkdir(testOutput);

% Start timer
tic;

try
    % Run conversion
    emg2qwerty_convert_to_bids(testFile, testOutput, 'task', 'typing');

    % Stop timer
    elapsedTime = toc;

    fprintf('\n==========================================================\n');
    fprintf('Test Successful!\n');
    fprintf('==========================================================\n\n');
    fprintf('Conversion time: %.2f seconds\n\n', elapsedTime);

catch ME
    fprintf('\n==========================================================\n');
    fprintf('Test Failed!\n');
    fprintf('==========================================================\n\n');
    fprintf('Error: %s\n\n', ME.message);
    fprintf('Stack trace:\n');
    for i = 1:length(ME.stack)
        fprintf('  %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
    end
    fprintf('\n');
    rethrow(ME);
end

%% ========== INSPECT OUTPUT ==========
fprintf('==========================================================\n');
fprintf('Inspecting Output\n');
fprintf('==========================================================\n\n');

% List output files
fprintf('Output directory structure:\n');
system(sprintf('tree -L 4 "%s"', testOutput));

fprintf('\n');

% Check required files
requiredFiles = {
    'dataset_description.json',
    'participants.json',
    'participants.tsv'
};

fprintf('Checking required files:\n');
for i = 1:length(requiredFiles)
    filepath = fullfile(testOutput, requiredFiles{i});
    if exist(filepath, 'file')
        fprintf('  ✓ %s\n', requiredFiles{i});
    else
        fprintf('  ✗ MISSING: %s\n', requiredFiles{i});
    end
end

fprintf('\n');

% Find subject directory
subDirs = dir(fullfile(testOutput, 'sub-*'));
if ~isempty(subDirs)
    subDir = fullfile(testOutput, subDirs(1).name);
    fprintf('Subject directory: %s\n', subDirs(1).name);

    % Find EMG files
    emgFiles = dir(fullfile(subDir, '**', '*_emg.*'));
    if ~isempty(emgFiles)
        fprintf('\nEMG files found:\n');
        for i = 1:length(emgFiles)
            fprintf('  %s (%d bytes)\n', emgFiles(i).name, emgFiles(i).bytes);
        end

        % Try to read the EDF file
        edfFile = fullfile(emgFiles(1).folder, emgFiles(1).name);
        fprintf('\nReading EDF file...\n');
        try
            EEG = pop_biosig(edfFile);
            fprintf('  Channels: %d\n', EEG.nbchan);
            fprintf('  Samples:  %d\n', EEG.pnts);
            fprintf('  Duration: %.2f s\n', EEG.xmax);
            fprintf('  Events:   %d\n', length(EEG.event));
            fprintf('  ✓ EDF file readable\n');
        catch ME
            fprintf('  ✗ Failed to read EDF: %s\n', ME.message);
        end
    end
end

%% ========== NEXT STEPS ==========
fprintf('\n==========================================================\n');
fprintf('Next Steps\n');
fprintf('==========================================================\n\n');

fprintf('1. Validate with BIDS validator:\n');
fprintf('   bids-validator "%s"\n\n', testOutput);

fprintf('2. Test import back into EEGLAB:\n');
fprintf('   [STUDY ALLEEG] = pop_importbids(''%s'');\n\n', testOutput);

fprintf('3. If test passes, run batch conversion:\n');
fprintf('   batch_convert_emg2qwerty\n\n');

fprintf('==========================================================\n');

% Optional: Open output directory in Finder (macOS)
% system(sprintf('open "%s"', testOutput));
