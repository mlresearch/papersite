#!/bin/bash
# Check if a volume name is provided
if [ $# -eq 0 ]; then
    echo "Please provide a volume name as an argument."
    exit 1
fi

volume_name=$1

# Get the directory where the current script is located
script_dir=$(dirname "$0")

# Update the pull request template
"$script_dir/setup_pr_template.sh" $volume_name 
