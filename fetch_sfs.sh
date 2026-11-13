#!/bin/bash
set -u

# HPSS limit on WCOSS2/Ursa is typically 4 simultaneous connections per user
MAX_JOBS="${MAX_JOBS:-4}"

REFC_BASE="${REFC_BASE:-/NCEPDEV/emc-global/5year/Yangxing.Zheng/GAEAC6/scratch/SFSbeta2.0_C192mx025_reforecast_Sep01_CPCICS}"
FCST_BASE="${FCST_BASE:-/NCEPDEV/emc-global/5year/Yangxing.Zheng/GAEAC6/scratch/SFSbeta2.0_C192mx025_NRT_forecast_Sep01_CPCICS}"

BASE_DIR="${BASE_DIR:-/lfs/h2/emc/vpppg/noscrub/lydia.b.stefanova/sfs-ver-dev/SFS_VERIF_DATA}"
version="${version:-sfs_b2}"

PRODUCTS=("inst" "acc")

# Helper to manage the worker pool without draining between years
queue_job() {
    "$@" &
    while [[ $(jobs -r -p | wc -l) -ge $MAX_JOBS ]]; do
        wait -n || true
    done
}

extract_single_product() {
    local base_path="$1"
    local yyyy="$2"
    local init_mm="$3"
    local mem="$4"
    local prod="$5"
    local set_type="$6"
    local target_dir="$7"

    local hpss_path="${base_path}/${yyyy}${init_mm}0100/atmos_product_${prod}_monthly_mem${mem}.tar"
    local work_dir="${target_dir}/.tmp_${prod}"
    local log_file="${target_dir}/extract_${prod}.log"

    mkdir -p "$work_dir"

    echo "[$(date -u +'%H:%M:%S')] Extracting ${set_type} (${yyyy}${init_mm}, mem${mem}, ${prod})..."
    
    local status=0
    (
        cd "$work_dir" || exit 1
        # Dropped -v to avoid heavy metadata/log traffic on Lustre
        if htar -xf "$hpss_path" > "$log_file" 2>&1; then
            # Batched mv (-exec ... +) reduces thousands of forks to 1
            find . -mindepth 2 -type f -name "*.grb2" -exec mv -f -t "$target_dir" {} +
        else
            exit 1
        fi
    ) || status=1

    # Cleanup staging directory
    rm -rf "$work_dir"

    if [ $status -eq 0 ] && compgen -G "${target_dir}/${prod}.monthly.*.grb2" >/dev/null; then
        echo "[$(date -u +'%H:%M:%S')] Finished ${set_type} (${yyyy}${init_mm}, mem${mem}, ${prod})"
        rm -f "$log_file"
    else
        echo "[!] ERROR: Failed extraction for ${set_type} (${yyyy}${init_mm}, mem${mem}, ${prod}). See log: ${log_file}" >&2
        return 1
    fi
}

process_month() {
    local ym="$1"
    local yyyy="${ym:0:4}"
    local init_mm="${ym:4:2}"
    local max_mem base_dir_type base_hpss

    if [ "$yyyy" -le 2025 ]; then
        echo "--> Queueing Hindcast for ${ym} (mem 000-010)..."
        max_mem=10
        base_dir_type="hindcasts"
        base_hpss="$REFC_BASE"
    else
        echo "--> Queueing Real-Time Forecast for ${ym} (mem 000-030)..."
        max_mem=30
        base_dir_type="forecasts"
        base_hpss="$FCST_BASE"
    fi

    for m in $(seq 0 "$max_mem"); do
        printf -v mem "%03d" "$m"
        # Note: Original script wrote both set types to 'forecasts/'. Adjust if hindcasts should be separated.
        local target_dir="${BASE_DIR}/forecasts/${version}/init_${init_mm}/${yyyy}/mem${mem}"

        for prod in "${PRODUCTS[@]}"; do
            # Fast check in main thread: skip without spending worker slots
            if compgen -G "${target_dir}/${prod}.monthly.*.grb2" >/dev/null; then
                echo "[$(date -u +'%H:%M:%S')] [SKIP] ${base_dir_type} (${yyyy}${init_mm}, mem${mem}, ${prod}) already exists"
                continue
            fi

            mkdir -p "$target_dir"
            queue_job extract_single_product "$base_hpss" "$yyyy" "$init_mm" "$mem" "$prod" "$base_dir_type" "$target_dir"
        done
    done
}

echo "======================================================="
echo " Starting SFS HPSS Dual Extraction (inst + acc)"
echo " Start Time: $(date)"
echo " Concurrency: ${MAX_JOBS} parallel HPSS streams"
echo "======================================================="

if [ "$#" -eq 0 ]; then
    TARGET_YM=$(date -d "$(date +%Y-%m-15) -1 month" +%Y%m 2>/dev/null || date -v-1m +%Y%m)
    echo "No dates specified. Defaulting to most recent month (${TARGET_YM})..."
    process_month "$TARGET_YM"

elif [ "$#" -eq 1 ]; then
    process_month "$1"

elif [ "$#" -eq 2 ]; then
    START_YM="$1"
    END_YM="$2"

    curr_y=${START_YM:0:4}
    init_m=${START_YM:4:2}
    end_y=${END_YM:0:4}
    end_m=${END_YM:4:2}

    if [ "$init_m" != "$end_m" ]; then
        echo "Warning: START_YM month ($init_m) != END_YM month ($end_m). Stepping annually using month $init_m." >&2
    fi

    echo "Queueing SFS range from ${START_YM} to ${END_YM} (annual steps for init month ${init_m})..."

    # Continuous dispatch across all years without waiting at year boundaries
    while [ "$curr_y" -le "$end_y" ]; do
        ym_label="${curr_y}${init_m}"
        process_month "$ym_label"
        curr_y=$((curr_y + 1))
    done
else
    echo "Usage:"
    echo "  $0                                # Download most recent month"
    echo "  $0 YYYYMM                         # Download specific month"
    echo "  $0 YYYYMM_START YYYYMM_END        # Download annual range (e.g., $0 199109 202609)"
    exit 1
fi

# Wait for all background workers to finish
wait

echo "======================================================="
echo " Extraction Complete: $(date)"
