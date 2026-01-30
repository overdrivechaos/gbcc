#!/bin/bash
config_file="$1"

if [[ ! -f "$config_file" ]]; then
    echo "Config file not found: $config_file"
    exit 1
fi

kw_T1=$(jq -r '.T1' "$config_file")
kw_func=$(jq -r '.FUNC' "$config_file")
taskname=$(jq -r '.TASK' "$config_file")
kw_fieldmap_phase=$(jq -r '.FIELDMAP_PHASE' "$config_file")
kw_fieldmap_magnitude1=$(jq -r '.FIELDMAP_MAG1' "$config_file")
kw_fieldmap_magnitude2=$(jq -r '.FIELDMAP_MAG2' "$config_file")
kw_subject=$(jq -r '.SUBJ' "$config_file")
dicom_dir=$(jq -r '.DIR_DICOM' "$config_file")
output_dir=$(jq -r '.DIR_OUTPUT' "$config_file")
dcm2niix_cmd=$(jq -r '.CMD_DCM2NIIX' "$config_file")

for subject_dir in "$dicom_dir"/*/; do
    # Get subject name
    subj_folder=$(basename "$subject_dir")
    subj_id=$(echo "$subj_folder" | grep -o -E "$kw_subject")
    if [[ -d "$output_dir/$subj_id" ]]; then
        echo "Converted directory already exists for: $subject_dir."
    else
        echo "Creating directory for: $subj_id"
        mkdir -p "$output_dir/$subj_id"
    fi
    echo "Processing subject: $subj_id"

    for sequence_dir in "$subject_dir"/*/; do
        # Get sequence name
        sequence_name=$(basename "$sequence_dir")
        if [[ -n "$kw_T1" && $sequence_name == *"$kw_T1"* ]]; then
                    echo "Found T1 sequence: $sequence_name"
            if [[ -d "$output_dir/$subj_id/anat" ]]; then
                echo "Anatomical directory already exists for: $subj_id, skipping..."
                continue
            else
                echo "Creating anatomical directory for: $subj_id"
                mkdir -p "$output_dir/$subj_id/anat"
                $dcm2niix_cmd -z n -f "${subj_id}_T1w" -o "$output_dir/$subj_id/anat" --terse "$sequence_dir"
                mv "$output_dir/$subj_id/anat/${subj_id}_T1w.nii" "$output_dir/$subj_id/anat/${subj_id}_T1w.nii"
            fi
        elif [[ -n "$kw_func" && $sequence_name == *"$kw_func"* ]]; then
            echo "Found functional sequence: $sequence_name"
            if [[ -d "$output_dir/$subj_id/func" ]]; then
                echo "Functional directory already exists for: $subj_id, skipping..."
                continue
            else
                echo "Creating functional directory for: $subj_id"
                mkdir -p "$output_dir/$subj_id/func"
                $dcm2niix_cmd -z n -f "${subj_id}_task-${taskname}_bold" -o "$output_dir/$subj_id/func" --terse "$sequence_dir" 
            fi
        elif [[ -n "$kw_fieldmap_phase" && $sequence_name == *"$kw_fieldmap_phase"* ]]; then
            echo "Found fieldmap phase sequence: $sequence_name"
            if [[ -d "$output_dir/$subj_id/fmaps" ]]; then
                echo "fmaps directory already exists for: $subj_id"
            else
                echo "Creating fmaps directory for: $subj_id"
                mkdir -p "$output_dir/$subj_id/fmaps"
            fi
            
            if [[ -f "$output_dir/$subj_id/fmaps/${subj_id}_phasediff.nii" ]]; then
                echo "Phasediff already exists for: $subj_id, skipping..."
                continue
            else
                $dcm2niix_cmd -z n -f "${subj_id}_phasediff" -o "$output_dir/$subj_id/fmaps" --terse "$sequence_dir"
            fi
        elif [[ -n "$kw_fieldmap_magnitude1" && $sequence_name == *"$kw_fieldmap_magnitude1"* ]]; then
            echo "Found fieldmap magnitude1 sequence: $sequence_name"
            if [[ -d "$output_dir/$subj_id/fmaps" ]]; then
                echo "Fieldmaps directory already exists for: $subj_id"
            else
                echo "Creating fieldmaps directory for: $subj_id"
                mkdir -p "$output_dir/$subj_id/fmaps"
            fi
            
            if [[ -f "$output_dir/$subj_id/fmaps/${subj_id}_magnitude1.nii" ]]; then
                echo "Magnitude1 already exists for: $subj_id, skipping..."
                continue
            else
                $dcm2niix_cmd -z n -f "${subj_id}_magnitude1" -o "$output_dir/$subj_id/fmaps" --terse "$sequence_dir"
            fi
        elif [[ -n "$kw_fieldmap_magnitude2" && $sequence_name == *"$kw_fieldmap_magnitude2"* ]]; then
            echo "Found fieldmap magnitude2 sequence: $sequence_name"
            if [[ -d "$output_dir/$subj_id/fmaps" ]]; then
                echo "Fieldmaps directory already exists for: $subj_id"
            else
                echo "Creating fieldmaps directory for: $subj_id"
                mkdir -p "$output_dir/$subj_id/fmaps"
            fi
            # Check if the fieldmaps directory already exists
            if [[ -f "$output_dir/$subj_id/fmaps/${subj_id}_magnitude2.nii" ]]; then
                echo "Magnitude2 already exists for: $subj_id, skipping..."
                continue
            else
                $dcm2niix_cmd -z n -f "${subj_id}_magnitude2" -o "$output_dir/$subj_id/fmaps" --terse "$sequence_dir"
            fi
        else
            echo "Unknown sequence found: $sequence_name, skipping..."
        fi
    done
done

echo "All subjects processed. Data organized in: $output_dir"
# End of script
exit 0
