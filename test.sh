#!/usr/bin/env bash
# ==============================================================================
# Script: prep_seasonal_ensmean.sh
# Purpose: Compute SFS ensemble mean using standard wgrib2 and CDO on WCOSS2.
#          Converts members to NetCDF in parallel using $DATA, averages with CDO,
#          and outputs [prod].monthly.YYYYMM0100.YYYYMM.ensmean.nc.
# Usage:
#   ./prep_seasonal_ensmean.sh 202509
# ==============================================================================
set -euo pipefail

TARGET_YM="${1:-${VDATE:-202509}}"
LEAD_LIST="${LEAD_LIST:-1 2 3 4 5 6}"
BASE_PATH="${BASE_PATH:-/lfs/h2/emc/vpppg/noscrub/lydia.b.stefanova/sfs-ver-dev}"
SFS_DATA="${SFS_DATA:-${BASE_PATH}/SFS_VERIF_DATA}"

# NWS-compliant scratch location: uses $DATA or falls back to local workspace
SCRATCH="${DATA:-${BASE_PATH}/tmp_sfs_prep_$$}"
mkdir -p "${SCRATCH}"
trap 'rm -rf "${SCRATCH}"' EXIT

for lead in ${LEAD_LIST}; do
    shift_m=$(( lead - 1 ))
    init_ym=$(date -d "${TARGET_YM}01 - ${shift_m} month" +%Y%m)
    yyyy="${init_ym:0:4}"
    mm="${init_ym:4:2}"

    # Hindcasts (<=2025, 11 mem) vs Forecasts (>=2026, 31 mem)
    if [ "${yyyy}" -le 2025 ]; then
        cycle_dir="${SFS_DATA}/hindcasts/raw/init_${mm}/${yyyy}"
        num_expected=11
    else
        cycle_dir="${SFS_DATA}/forecasts/init_${mm}/${yyyy}"
        num_expected=31
    fi
    [ -d "${cycle_dir}" ] || continue

    out_dir="${COMOUT:-${cycle_dir}/memens}"
    mkdir -p "${out_dir}"

    for prod in inst acc; do
        outfile="${out_dir}/${prod}.monthly.${init_ym}0100.${TARGET_YM}.ensmean.nc"
        [ -s "${outfile}" ] && [ "${FORCE:-0}" -ne 1 ] && continue

        # Gather member files valid only for target month
        mapfile -t files < <(find "${cycle_dir}"/mem* -maxdepth 1 -type f -name "${prod}.monthly.${init_ym}0100.${TARGET_YM}*.grb2" ! -name "*.idx" 2>/dev/null | sort)
        [ ${#files[@]} -eq 0 ] && continue

        if [ "${#files[@]}" -ne "${num_expected}" ]; then
            echo "[WARN] Lead ${lead} (${prod}): found ${#files[@]}/${num_expected} members. Skipping."
            continue
        fi

        echo "[CALC] Lead ${lead} (${prod}, Init ${init_ym} -> Valid ${TARGET_YM}) across ${#files[@]} members"

        # 1. Parallel conversion of member GRIB2 files to NetCDF in $DATA
        tmp_ncs=()
        for f in "${files[@]}"; do
            nc="${SCRATCH}/$(basename "$f").nc"
            wgrib2 "$f" -netcdf "$nc" >/dev/null 2>&1 &
            tmp_ncs+=("$nc")
        done
        wait

        # 2. CDO averages members into final NetCDF
        cdo -O ensmean "${tmp_ncs[@]}" "${outfile}" >/dev/null 2>&1
        rm -f "${tmp_ncs[@]}"

        echo "[DONE] Created ${outfile} ($(stat -c%s "${outfile}") bytes)"
    done
done
