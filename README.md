# global BOLD-CSF Coupling (GBCC) Processing Scripts

Overview
- This repository contains scripts used to process fMRI and structural DICOMs and compute globalBOLD–CSF coupling. The workflow covers DICOM→NIfTI conversion, reorientation, preprocessing (with or without field map), CSF ROI drawing, and final coupling calculation.
- Methodology based on Fultz et al., Science 366, 628–631 (2019).
- Tested on: macOS 26.1 MATLAB_R2025b with SPM25; Windows 10 MATLAB_R2021a with SPM12.

Repository layout (relevant files)
- `config4dicomconversion.json` — JSON config used by the DICOM conversion script.
- `gbcc_1dicomconversion.sh` / `gbcc_1dicomconversion.ps1` — DICOM to NIfTI conversion wrappers (shell and PowerShell).
- `gbcc_2reorient.p` — Reorientation script (MATLAB).
- `gbcc_3preproc.p` — Preprocessing including fieldmap-based correction (MATLAB).
- `gbcc_3preproc_nofmap.p` — Preprocessing without fieldmap (MATLAB).
- `gbcc_4csfroi.p` — Draw/extract CSF ROI masks (MATLAB).
- `gbcc_5calccoupling.p` — Compute globalBOLD–CSF coupling from preprocessed data (MATLAB).
- `Templates/HarvardOxford-cort-maxprob-thr25-1mm.nii` — Cortical atlas used for globalBOLD extraction.
- `SPMFolder/` - (Recommended naming) Data folder containing files during preprocessing.
- `SPMOutput/` - (Recommended naming) Data folder containing preprocessed files essential for globalBOLD-CSF coupling calculation.

Prerequisites
- MATLAB (recommended with SPM installed and on MATLAB path).
- `dcm2niix` for DICOM→NIfTI conversion (or the platform-specific converter invoked by provided scripts).
- For shell automation: terminal shell on macOS. For Windows: PowerShell.

Typical workflow
1. Prepare `dcmdata/` with subject DICOM folders (see existing structure).
2. Edit `config4dicomconversion.json` to set any conversion options or folder paths.
3. Convert DICOM → NIfTI:

```bash
# macOS
bash ./gbcc_1dicomconversion.sh config4dicomconversion.json

# Windows (PowerShell)
./gbcc_1dicomconversion.ps1 config4dicomconversion.json

Windows users may run into a policy error prohibiting the script to execuate.
Try running `Set-ExecutionPolicy RemoteSigned` and select `Y` first.
```

4. Start MATLAB and run the following scripts in the following order:

```matlab
% 1) Reorient images
Change the current directory to the gbcc repository.
Run in MATLAB command line:
gbcc_2reorient(input_dir)
- data_dir - (optional) directory containing subject sub-directories with imaging data (default:./SPMFolder)

% 2) Preprocess (choose one)
gbcc_3preproc(input_dir, output_dir)           % with fieldmap
% or
gbcc_3preproc_nofmap(input_dir, output_dir)   % without fieldmap
- data_dir - (optional) directory containing subject subdirectories with imaging data (default:./SPMFolder)
- output_dir - (optional) directory to save the preprocessed data (default:./SPMOutput)

% 3) Draw/extract CSF ROI
gbcc_4csfroi(input_dir)
- data_dir - (optional) directory containing the preprocessed data (default:./SPMOutput)

% 4) Calculate coupling
gbcc_5calccoupling(input_dir, max_lag_sec, coupling_lag_sec)
- data_dir - directory containing subject subdirectories with imaging data
- max_lag_sec - (optional) maximum lag time in seconds (default: 10 seconds)
- coupling_lag_sec - (optional) array of lag times in seconds to compute coupling (default: 2:8 seconds)
```

Tips and troubleshooting
- If MATLAB cannot find SPM functions, add the SPM folder to MATLAB path before running preprocessing: `addpath('SPMFolder')`.
- If using field maps, confirm the fieldmap DICOM conversion produced the expected Echo1/Echo2 and B0 map files.
- For batch processing many subjects, you can loop the MATLAB calls or adapt the shell script to trigger MATLAB in batch mode.
