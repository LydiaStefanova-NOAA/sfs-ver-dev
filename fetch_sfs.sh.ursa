#!/usr/bin/env bash
MAX_JOBS="${MAX_JOBS:-4}"
REFC_BASE="${REFC_BASE:-/NCEPDEV/emc-global/5year/Yangxing.Zheng/URSA/scratch/SFSbeta2.0_C192mx025_reforecast_Sep01_CPCICS}"
FCST_BASE="${FCST_BASE:-/NCEPDEV/emc-global/5year/Yangxing.Zheng/WCOSS2/scratch/SFSbeta2.0_C192mx025_NRT_forecast_Sep01_CPCICS}"
BASE_DIR="${BASE_DIR:-SFS_VERIF_DATA}"

PRODUCTS=("inst" "acc")

get_hpss_file() {
    local base_path="$1"
    local yyyy="$2"
    local init_mm="$3"
    local mem="$4"
    local set_type="$5"

    if [ "$set_type" = "hindcasts" ]; then
        local target_dir="${BASE_DIR}/hindcasts/raw/init_${init_mm}/${yyyy}/mem${mem}"
    else
        local target_dir="${BASE_DIR}/forecasts/init_${init_mm}/${yyyy}/mem${mem}"
    fi

    mkdir -p "$target_dir"

    for prod in "${PRODUCTS[@]}"; do
        local hpss_path="${base_path}/${yyyy}${init_mm}0100/atmos_product_${prod}_monthly_mem${mem}.tar"

        # Skip check: see if .grb2 files matching this product already exist
        if ls "${target_dir}"/${prod}.monthly.*.grb2 >/dev/null 2>&1; then
            echo "[$(date -u +'%H:%M:%S')] [SKIP] ${set_type} (${yyyy}${init_mm}, mem${mem}, ${prod}) already exists"
            continue
        fi

        echo "[$(date -u +'%H:%M:%S')] Extracting ${set_type} (${yyyy}${init_mm}, mem${mem}, ${prod})..."
        (
            cd "$target_dir" || exit 1
            htar -xvf "$hpss_path" > /dev/null 2>&1
            find . -type f -name "*.grb2" -exec mv {} . \;
            rm -rf sfs.*
        )

        if ls "${target_dir}"/${prod}.monthly.*.grb2 >/dev/null 2>&1; then
            echo "[$(date -u +'%H:%M:%S')] Finished ${set_type} (${yyyy}${init_mm}, mem${mem}, ${prod})"
        else
            echo "[!] ERROR: Failed extraction for ${set_type} (${yyyy}${init_mm}, mem${mem}, ${prod})"
        fi
    done
}

fetch_month() {
    local ym="$1"
    local yyyy="${ym:0:4}"
    local init_mm="${ym:4:2}"
    
    # Automatically switch between Hindcast (<=2025, mem 000-010) and Forecast (>=2026, mem 000-030)
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

export -f get_hpss_file
export -a PRODUCTS
export REFC_BASE FCST_BASE BASE_DIR

echo "======================================================="
echo " Starting SFS HPSS Dual Extraction (inst + acc)"
echo " Start Time: $(date)"
echo "======================================================="

# Determine script mode based on arguments
if [ "$#" -eq 0 ]; then
    # Mode 1: No args -> Automatically calculate and fetch the most recent completed month
    TARGET_YM=$(date -d "last month" +%Y%m 2>/dev/null || date -v-1m +%Y%m)
    echo "No dates specified. Defaulting to most recent month (${TARGET_YM})..."
    fetch_month "$TARGET_YM"

elif [ "$#" -eq 1 ]; then
    # Mode 2: Single date argument (YYYYMM)
    START_YM="$1"
    fetch_month "$START_YM"

elif [ "$#" -eq 2 ]; then
    # Mode 3: Date range with 12-month annual step (YYYYMM_START YYYYMM_END)
    START_YM="$1"
    END_YM="$2"

    curr_y=${START_YM:0:4}
    init_m=${START_YM:4:2}
    end_y=${END_YM:0:4}

    echo "Fetching SFS range from ${START_YM} to ${END_YM} (stepping 12 months per step)..."

    while [ "$curr_y" -le "$end_y" ]; do
        ym_label="${curr_y}${init_m}"

        fetch_month "$ym_label"

        curr_y=$((curr_y + 1))
    done

else
    echo "Usage:"
    echo "  $0                          # Download the most recent available month"
    echo "  $0 YYYYMM                   # Download a specific month (e.g. $0 202608)"
    echo "  $0 YYYYMM_START YYYYMM_END  # Download an annual range for a single month (e.g. $0 199909 202509)"
    exit 1
fi

echo "======================================================="
echo " Extraction Complete: $(date)"
echo "======================================================="
