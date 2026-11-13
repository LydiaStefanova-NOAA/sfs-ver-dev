#!/bin/bash
set -u

MAX_JOBS="${MAX_JOBS:-4}"
REFC_BASE="${REFC_BASE:-/NCEPDEV/emc-global/5year/Yangxing.Zheng/URSA/scratch/SFSbeta2.0_C192mx025_reforecast_Sep01_CPCICS}"
FCST_BASE="${FCST_BASE:-/NCEPDEV/emc-global/5year/Yangxing.Zheng/WCOSS2/scratch/SFSbeta2.0_C192mx025_NRT_forecast_Sep01_CPCICS}"
BASE_DIR="${BASE_DIR:-/lfs/h2/emc/vpppg/noscrub/lydia.b.stefanova/sfs-ver-dev/SFS_VERIF_DATA}"
version="${version:-sfs_b2}"

PRODUCTS=("inst" "acc")

get_hpss_file() {
    local base_path="$1"
    local yyyy="$2"
    local init_mm="$3"
    local mem="$4"
    local set_type="$5"

    if [ "$set_type" = "hindcasts" ]; then
        local target_dir="${BASE_DIR}/hindcasts/${version}/init_${init_mm}/raw/${yyyy}/mem${mem}"
    else
        local target_dir="${BASE_DIR}/forecasts/${version}/init_${init_mm}/${yyyy}/mem${mem}"
    fi

    mkdir -p "$target_dir"

    for prod in "${PRODUCTS[@]}"; do
        local hpss_path="${base_path}/${yyyy}${init_mm}0100/atmos_product_${prod}_monthly_mem${mem}.tar"
        local log_file="${target_dir}/extract_${prod}.log"

        # Skip check: if .grb2 files matching this product already exist
        if compgen -G "${target_dir}/${prod}.monthly.*.grb2" >/dev/null; then
            echo "[$(date -u +'%H:%M:%S')] [SKIP] ${set_type} (${yyyy}${init_mm}, mem${mem}, ${prod}) already exists"
            continue
        fi

        echo "[$(date -u +'%H:%M:%S')] Extracting ${set_type} (${yyyy}${init_mm}, mem${mem}, ${prod})..."
        (
            cd "$target_dir" || exit 1
            # Run htar and retain log for diagnostics
            if htar -xvf "$hpss_path" > "$log_file" 2>&1; then
                # Move grb2 files from subdirectories without colliding with files already in target_dir
                find . -mindepth 2 -type f -name "*.grb2" -exec mv -f {} . \;
                # Clean unpacked subdirectories safely
                find . -maxdepth 1 -type d -name "sfs.*" -exec rm -rf {} +
                rm -f "$log_file"
            fi
        )

        if compgen -G "${target_dir}/${prod}.monthly.*.grb2" >/dev/null; then
            echo "[$(date -u +'%H:%M:%S')] Finished ${set_type} (${yyyy}${init_mm}, mem${mem}, ${prod})"
        else
            echo "[!] ERROR: Failed extraction for ${set_type} (${yyyy}${init_mm}, mem${mem}, ${prod}). See log: ${log_file}"
        fi
    done
}

fetch_month() {
    local ym="$1"
    local yyyy="${ym:0:4}"
    local init_mm="${ym:4:2}"
    
    # Switch between Hindcast (<=2025, mem 000-010) and Forecast (>=2026, mem 000-030)
    if [ "$yyyy" -le 2025 ]; then
        echo "--> Fetching Hindcast for ${ym} (mem 000-010)..."
        for m in {0..10}; do
            printf -v mem "%03d" $m
            get_hpss_file "$REFC_BASE" "$yyyy" "$init_mm" "$mem" "hindcasts" &
            
            if [[ $(jobs -r -p | wc -l) -ge $MAX_JOBS ]]; then
                wait -n
            fi
        done
    else
        echo "--> Fetching Real-Time Forecast for ${ym} (mem 000-030)..."
        for m in {0..30}; do
            printf -v mem "%03d" $m
            get_hpss_file "$FCST_BASE" "$yyyy" "$init_mm" "$mem" "forecasts" &
            
            if [[ $(jobs -r -p | wc -l) -ge $MAX_JOBS ]]; then
                wait -n
            fi
        done
    fi
    wait
}

echo "======================================================="
echo " Starting SFS HPSS Dual Extraction (inst + acc)"
echo " Start Time: $(date)"
echo "======================================================="

if [ "$#" -eq 0 ]; then
    TARGET_YM=$(date -d "last month" +%Y%m 2>/dev/null || date -v-1m +%Y%m)
    echo "No dates specified. Defaulting to most recent month (${TARGET_YM})..."
    fetch_month "$TARGET_YM"

elif [ "$#" -eq 1 ]; then
    fetch_month "$1"

elif [ "$#" -eq 2 ]; then
    START_YM="$1"
    END_YM="$2"

    curr_y=${START_YM:0:4}
    init_m=${START_YM:4:2}
    end_y=${END_YM:0:4}

    echo "Fetching SFS range from ${START_YM} to ${END_YM} (annual steps for init month ${init_m})..."

    while [ "$curr_y" -le "$end_y" ]; do
        ym_label="${curr_y}${init_m}"
        fetch_month "$ym_label"
        curr_y=$((curr_y + 1))
    done
else
    echo "Usage:"
    echo "  $0                          # Download most recent month"
    echo "  $0 YYYYMM                   # Download specific month"
    echo "  $0 YYYYMM_START YYYYMM_END  # Download annual range (e.g., $0 199109 202609)"
    exit 1
fi

echo "======================================================="
echo " Extraction Complete: $(date)"
echo "======================================================="
