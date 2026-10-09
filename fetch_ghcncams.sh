#!/usr/bin/env bash

# Base NCSS URL configuration
BASE_URL="https://psl.noaa.gov/thredds/ncss/grid/Datasets/ghcncams/air.mon.mean.nc"
PARAMS="var=air&north=90&south=-90&west=0&east=360&horizStride=1&accept=netcdf"

# Ensure target output directory exists
OUT_DIR="${OUT_DIR:-SFS_VERIF_DATA/verifying_truths/GHCNCAMS/monthly}"
mkdir -p ${OUT_DIR}

# Function to download a single YYYYMM month
download_month() {
    local ym="$1"
    local year="${ym:0:4}"
    local month="${ym:4:2}"
    local iso_date="${year}-${month}-01T00:00:00Z"
    local output_file="${OUT_DIR}/ghcncams_${ym}.nc"

    echo "Fetching ${ym} -> ${output_file}..."

    local full_url="${BASE_URL}?${PARAMS}&time_start=${iso_date}&time_end=${iso_date}"

    wget -q --show-progress -O "$output_file" "$full_url"

    if [ $? -eq 0 ] && [ -s "$output_file" ]; then
        echo "Successfully downloaded: ${output_file}"
    else
        echo "Error downloading data for ${ym}. File may not exist yet or connection failed."
        rm -f "$output_file"
    fi
}

# Determine script mode based on arguments
if [ "$#" -eq 0 ]; then
    # Mode 1: No args -> Automatically calculate and fetch the most recent completed month
    TARGET_YM=$(date -d "last month" +%Y%m 2>/dev/null || date -v-1m +%Y%m)
    echo "No dates specified. Defaulting to most recent month (${TARGET_YM})..."
    download_month "$TARGET_YM"

elif [ "$#" -eq 1 ]; then
    # Mode 2: Single date argument (YYYYMM)
    START_YM="$1"
    download_month "$START_YM"

elif [ "$#" -eq 2 ]; then
    # Mode 3: Date range (YYYYMM YYYYMM)
    START_YM="$1"
    END_YM="$2"

    curr_y=${START_YM:0:4}
    curr_m=${START_YM:4:2}
    end_y=${END_YM:0:4}
    end_m=${END_YM:4:2}

    echo "Downloading range from ${START_YM} to ${END_YM} as individual files..."

    while true; do
        # Format month with leading zero (using 10# to force base-10 parsing)
        printf -v m_padded "%02d" $((10#$curr_m))
        ym_label="${curr_y}${m_padded}"

        download_month "$ym_label"

        # Check if we reached the end date
        if [ "$curr_y" -eq "$end_y" ] && [ "$((10#$curr_m))" -eq "$((10#$end_m))" ]; then
            break
        fi

        # Increment month
        curr_m=$((10#$curr_m + 1))
        if [ "$curr_m" -gt 12 ]; then
            curr_m=1
            curr_y=$((curr_y + 1))
        fi
    done

else
    echo "Usage:"
    echo "  $0                      # Download the most recent available month"
    echo "  $0 YYYYMM               # Download a specific month (e.g. $0 202608)"
    echo "  $0 YYYYMM_START YYYYMM_END # Download a range into individual files"
    exit 1
fi
