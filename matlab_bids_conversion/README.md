# emg2qwerty MATLAB BIDS Converter

MATLAB-based conversion tool for emg2qwerty HDF5 datasets to BIDS-EMG format using the eeg-bids plugin.

## Overview

This converter provides a proper MATLAB implementation for converting emg2qwerty HDF5 session files to BIDS format. Unlike the original Python script (`scripts/convert_to_bids.py`) which treats EMG as EEG and has limitations with events and timestamps, this MATLAB implementation:

- ✅ Uses proper EMG-BIDS format (BEP-042)
- ✅ Handles non-uniform timestamps correctly
- ✅ Properly exports keystroke events with precise timing
- ✅ Includes prompt events with full text descriptions
- ✅ Sets anatomically-accurate channel locations
- ✅ Generates complete BIDS metadata (JSON sidecars)
- ✅ Uses the validated eeg-bids export pipeline

## Dependencies

1. **MATLAB** (R2019b or later recommended)
2. **EEGLAB** - Download from https://sccn.ucsd.edu/eeglab/
3. **eeg-bids plugin** - Clone from https://github.com/sccn/eeg-bids

## Installation

1. Install EEGLAB and add to MATLAB path
2. Install eeg-bids plugin (place in EEGLAB's plugins directory)
3. Add this directory to MATLAB path:
   ```matlab
   addpath('/path/to/emg2qwerty/matlab_bids_conversion');
   ```

## Usage

### Single File Conversion

```matlab
% Convert a single HDF5 session file
hdf5_file = '/Volumes/data/FRL/emg2qwerty/2020-08-13-1597354281-keystrokes.hdf5';
bids_root = '/Users/yahya/Documents/git/emg2qwerty_bids';

emg2qwerty_convert_to_bids(hdf5_file, bids_root);
```

### Batch Conversion

Use the provided batch script:

```matlab
% Edit batch_convert_emg2qwerty.m to set paths
% Then run:
batch_convert_emg2qwerty;
```

Or create your own batch script:

```matlab
% Define paths
data_dir = '/Volumes/data/FRL/emg2qwerty';
bids_root = '/path/to/output/bids';

% Get all HDF5 files
files = dir(fullfile(data_dir, '*.hdf5'));

% Convert each file
for i = 1:length(files)
    hdf5_file = fullfile(files(i).folder, files(i).name);
    fprintf('Processing %d/%d: %s\n', i, length(files), files(i).name);

    try
        emg2qwerty_convert_to_bids(hdf5_file, bids_root);
    catch ME
        warning('Failed to convert %s: %s', files(i).name, ME.message);
    end
end
```

## Files

- **emg2qwerty_load_hdf5.m** - Loads HDF5 file into EEGLAB structure
  - Reads 32-channel EMG data (16 left + 16 right)
  - Parses keystroke and prompt events
  - Creates proper EEGLAB event structure

- **emg2qwerty_set_chanlocs.m** - Sets channel locations
  - Based on emg_TwoWristbands BIDS example
  - Anatomically-informed 2D electrode positions
  - Matches coordinate system from paper

- **emg2qwerty_convert_to_bids.m** - Main conversion function
  - Orchestrates the full conversion pipeline
  - Calls eeg-bids export with proper EMG metadata
  - Handles subject/session naming

- **batch_convert_emg2qwerty.m** - Batch processing script
  - Processes all HDF5 files in a directory
  - Error handling and progress reporting

## Output Structure

The converter creates a BIDS-compliant dataset:

```
bids_output/
├── dataset_description.json
├── participants.json
├── participants.tsv
├── space-leftForearm_coordsystem.json
├── space-rightForearm_coordsystem.json
└── sub-<subjectID>/
    └── ses-<sessionID>/
        └── emg/
            ├── sub-<subjectID>_ses-<sessionID>_task-typing_channels.tsv
            ├── sub-<subjectID>_ses-<sessionID>_task-typing_emg.edf
            ├── sub-<subjectID>_ses-<sessionID>_task-typing_emg.json
            ├── sub-<subjectID>_ses-<sessionID>_task-typing_events.tsv
            └── sub-<subjectID>_ses-<sessionID>_task-typing_electrodes.tsv
```

## Data Details

### EMG Data
- **Channels**: 32 (16 per wrist)
- **Sampling Rate**: 2000 Hz
- **Hardware Filters**: 20-850 Hz bandpass
- **Format**: EDF (European Data Format)

### Events
Two types of events are exported:

1. **Keystroke events** (`keystroke_<key>`)
   - Precise key-down timing
   - Duration (key-down to key-up)
   - Key character

2. **Prompt events** (`prompt`)
   - Text prompts shown to user
   - Duration of prompt display
   - Full prompt text

### Channel Locations
- Electrode positions around wrist circumference
- Coordinate system:
  - **Left**: X: USP → RSP; Y: Right-hand rule; Z: midpoint RSP-USP → LHE
  - **Right**: Mirrored placement
- Units: percent of forearm circumference

## Differences from Original Python Script

| Feature | Python Script | MATLAB Script |
|---------|--------------|---------------|
| Format | Treats EMG as EEG | Proper EMG-BIDS |
| Events | Poor keystroke handling | Full keystroke + prompt events |
| Timestamps | Assumes uniform spacing | Handles non-uniform correctly |
| Channel locations | None | Anatomically accurate |
| Metadata | Minimal | Complete BIDS metadata |
| Validation | Not validated | Uses validated eeg-bids pipeline |

## Citation

If you use this converter, please cite both the original dataset and the eeg-bids plugin:

**emg2qwerty dataset:**
```
Sivakumar et al. (2024). emg2qwerty: A Large Dataset with Baselines for
Touch Typing using Surface Electromyography. NeurIPS 2024.
```

**eeg-bids plugin:**
```
Pernet et al. (2019). EEG-BIDS, an extension to the brain imaging data
structure for electroencephalography. Scientific Data, 6(1), 103.
```

## Author

Yahya Shirazi
Swartz Center for Computational Neuroscience (SCCN)
Institute for Neural Computation (INC)
University of California San Diego (UCSD)

## License

This converter follows the same license as the emg2qwerty dataset: CC-BY-NC-SA-4.0
