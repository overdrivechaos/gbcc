# Usage: .\dicomconversiongbold.ps1 -ConfigFile "path\to\config.json"

param(
    [Parameter(Mandatory=$true)]
    [string]$ConfigFile
)

# Check if config file exists
if (-not (Test-Path -Path $ConfigFile -PathType Leaf)) {
    Write-Host "Config file not found: $ConfigFile" -ForegroundColor Red
    exit 1
}

# Read JSON config file
try {
    $raw = Get-Content -Path $ConfigFile -Raw
    try {
        $config = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        # Common issue: unescaped backslashes in Windows paths inside JSON (e.g. C:\Users vs C:\Users)
        # Try an automatic fix by doubling backslashes and retrying parsing.
        $fixedRaw = $raw -replace '\\','\\\\'
        try {
            $config = $fixedRaw | ConvertFrom-Json -ErrorAction Stop
            Write-Host "Config parsed after auto-escaping backslashes." -ForegroundColor Yellow
        } catch {
            Write-Host "Error reading config file (attempted auto-fix): $_" -ForegroundColor Red
            Write-Host "Ensure JSON uses double backslashes (\\\\) or forward slashes (/) in paths." -ForegroundColor Red
            exit 1
        }
    }
} catch {
    Write-Host "Error reading config file: $_" -ForegroundColor Red
    exit 1
}

# Extract configuration parameters
$kw_T1 = $config.T1
$kw_func = $config.FUNC
$taskname = $config.TASK
$kw_fieldmap_phase = $config.FIELDMAP_PHASE
$kw_fieldmap_magnitude1 = $config.FIELDMAP_MAG1
$kw_fieldmap_magnitude2 = $config.FIELDMAP_MAG2
$kw_subject = $config.SUBJ
$dicom_dir = $config.DIR_DICOM
$output_dir = $config.DIR_OUTPUT
$dcm2niix_cmd = $config.CMD_DCM2NIIX

# Validate paths
if (-not (Test-Path -Path $dicom_dir -PathType Container)) {
    Write-Host "DICOM directory not found: $dicom_dir" -ForegroundColor Red
    exit 1
}

# Clear macos generated files
Get-ChildItem -Path $dicom_dir -Recurse -Force -Include ".DS_Store" | Remove-Item -Force -ErrorAction SilentlyContinue
Get-ChildItem -Path $dicom_dir -Recurse -Force -Include "._*" | Remove-Item -Force -ErrorAction SilentlyContinue

# Process each subject directory
$subject_dirs = Get-ChildItem -Path $dicom_dir -Directory

foreach ($subject_dir in $subject_dirs) {
    $subj_folder = $subject_dir.Name
    
    # Extract subject ID using regex
    if ($subj_folder -match $kw_subject) {
        $subj_id = $matches[0]
    } else {
        Write-Host "Could not extract subject ID from: $subj_folder" -ForegroundColor Yellow
        continue
    }
    
    # Check if output directory already exists
    $subj_output_dir = Join-Path -Path $output_dir -ChildPath $subj_id
    if (Test-Path -Path $subj_output_dir -PathType Container) {
        Write-Host "Converted directory already exists for: $subj_folder" -ForegroundColor Yellow
    } else {
        Write-Host "Creating directory for: $subj_id"
        New-Item -ItemType Directory -Path $subj_output_dir -Force | Out-Null
    }
    
    Write-Host "Processing subject: $subj_id" -ForegroundColor Cyan
    
    # Process each sequence directory
    $sequence_dirs = Get-ChildItem -Path $subject_dir.FullName -Directory
    
    foreach ($sequence_dir in $sequence_dirs) {
        $sequence_name = $sequence_dir.Name
        
        # T1 sequence
        if ($kw_T1 -and $sequence_name -like "*$kw_T1*") {
            Write-Host "Found T1 sequence: $sequence_name" -ForegroundColor Green
            $anat_dir = Join-Path -Path $subj_output_dir -ChildPath "anat"
            
            if (Test-Path -Path $anat_dir -PathType Container) {
                Write-Host "Anatomical directory already exists for: $subj_id, skipping..." -ForegroundColor Yellow
                continue
            } else {
                Write-Host "Creating anatomical directory for: $subj_id"
                New-Item -ItemType Directory -Path $anat_dir -Force | Out-Null
                
                # Run dcm2niix command
                $output_file = Join-Path -Path $anat_dir -ChildPath "${subj_id}_T1w.nii"
                & $dcm2niix_cmd -z n -f "${subj_id}_T1w" -o "$anat_dir" --terse "$($sequence_dir.FullName)"
                
                Write-Host "T1 conversion completed for: $subj_id" -ForegroundColor Green
            }
        }
        # Functional sequence
        elseif ($kw_func -and $sequence_name -like "*$kw_func*") {
            Write-Host "Found functional sequence: $sequence_name" -ForegroundColor Green
            $func_dir = Join-Path -Path $subj_output_dir -ChildPath "func"
            
            if (Test-Path -Path $func_dir -PathType Container) {
                Write-Host "Functional directory already exists for: $subj_id, skipping..." -ForegroundColor Yellow
                continue
            } else {
                Write-Host "Creating functional directory for: $subj_id"
                New-Item -ItemType Directory -Path $func_dir -Force | Out-Null
                
                # Run dcm2niix command
                & $dcm2niix_cmd -z n -f "${subj_id}_task-${taskname}_bold" -o "$func_dir" --terse "$($sequence_dir.FullName)"
                
                Write-Host "Functional conversion completed for: $subj_id" -ForegroundColor Green
            }
        }
        # Fieldmap phase sequence
        elseif ($kw_fieldmap_phase -and $sequence_name -like "*$kw_fieldmap_phase*") {
            Write-Host "Found fieldmap phase sequence: $sequence_name" -ForegroundColor Green
            $fmaps_dir = Join-Path -Path $subj_output_dir -ChildPath "fmaps"
            
            if (Test-Path -Path $fmaps_dir -PathType Container) {
                Write-Host "fmaps directory already exists for: $subj_id" -ForegroundColor Yellow
            } else {
                Write-Host "Creating fmaps directory for: $subj_id"
                New-Item -ItemType Directory -Path $fmaps_dir -Force | Out-Null
            }
            
            $phasediff_file = Join-Path -Path $fmaps_dir -ChildPath "${subj_id}_phasediff.nii"
            if (Test-Path -Path $phasediff_file -PathType Leaf) {
                Write-Host "Phasediff already exists for: $subj_id, skipping..." -ForegroundColor Yellow
                continue
            } else {
                & $dcm2niix_cmd -z n -f "${subj_id}_phasediff" -o "$fmaps_dir" --terse "$($sequence_dir.FullName)"
            }
        }
        # Fieldmap magnitude1 sequence
        elseif ($kw_fieldmap_magnitude1 -and $sequence_name -like "*$kw_fieldmap_magnitude1*") {
            Write-Host "Found fieldmap magnitude1 sequence: $sequence_name" -ForegroundColor Green
            $fmaps_dir = Join-Path -Path $subj_output_dir -ChildPath "fmaps"
            
            if (Test-Path -Path $fmaps_dir -PathType Container) {
                Write-Host "Fieldmaps directory already exists for: $subj_id" -ForegroundColor Yellow
            } else {
                Write-Host "Creating fieldmaps directory for: $subj_id"
                New-Item -ItemType Directory -Path $fmaps_dir -Force | Out-Null
            }
            
            $magnitude1_file = Join-Path -Path $fmaps_dir -ChildPath "${subj_id}_magnitude1.nii"
            if (Test-Path -Path $magnitude1_file -PathType Leaf) {
                Write-Host "Magnitude1 already exists for: $subj_id, skipping..." -ForegroundColor Yellow
                continue
            } else {
                & $dcm2niix_cmd -z n -f "${subj_id}_magnitude1" -o "$fmaps_dir" --terse "$($sequence_dir.FullName)"
            }
        }
        # Fieldmap magnitude2 sequence
        elseif ($kw_fieldmap_magnitude2 -and $sequence_name -like "*$kw_fieldmap_magnitude2*") {
            Write-Host "Found fieldmap magnitude2 sequence: $sequence_name" -ForegroundColor Green
            $fmaps_dir = Join-Path -Path $subj_output_dir -ChildPath "fmaps"
            
            if (Test-Path -Path $fmaps_dir -PathType Container) {
                Write-Host "Fieldmaps directory already exists for: $subj_id" -ForegroundColor Yellow
            } else {
                Write-Host "Creating fieldmaps directory for: $subj_id"
                New-Item -ItemType Directory -Path $fmaps_dir -Force | Out-Null
            }
            
            $magnitude2_file = Join-Path -Path $fmaps_dir -ChildPath "${subj_id}_magnitude2.nii"
            if (Test-Path -Path $magnitude2_file -PathType Leaf) {
                Write-Host "Magnitude2 already exists for: $subj_id, skipping..." -ForegroundColor Yellow
                continue
            } else {
                & $dcm2niix_cmd -z n -f "${subj_id}_magnitude2" -o "$fmaps_dir" --terse "$($sequence_dir.FullName)"
            }
        }
        else {
            Write-Host "Unknown sequence found: $sequence_name, skipping..." -ForegroundColor Yellow
        }
    }
}

Write-Host "All subjects processed. Data organized in: $output_dir" -ForegroundColor Cyan
Write-Host "Script completed successfully." -ForegroundColor Green
exit 0
