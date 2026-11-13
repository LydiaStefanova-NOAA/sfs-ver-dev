#!/usr/bin/env bash
# ==============================================================================
# Standalone SFS Ensemble Mean Generator (EVS Prep compliant)
# Converts GRIB2 members in parallel to RAM scratch and averages with CDO.
# Output: [prod].monthly.YYYYMM0100.YYYYMM.ensmean.nc
# ==============================================================================
set -euo pipefail

TARGET_YM="${1:-${VDATE:-202509}}"
LEAD_LIST="${LEAD_LIST:-1 2 3 4 5 6}"
BASE_PATH="${BASE_PATH:-/lfs/h2/emc/vpppg/noscrub/lydia.b.stefanova/sfs-ver-dev}"
SFS_DATA="${SFS_DATA:-${BASE_PATH}/SFS_VERIF_DATA}"

SCRATCH="/dev/shm/sfs_prep_$$"
mkdir -p "${SCRATCH}"
trap 'rm -rf "${SCRATCH}"' EXIT

for lead in ${LEAD_LIST}; do
    shift_m=$(( lead - 1 ))
    init_ym=$(date -d "${TARGET_YM}01 - ${shift_m} month" +%Y%m)
    yyyy="${init_ym:0:4}"
    mm="${init_ym:4:2}"

    # Hindcasts <= 2025 vs Real-Time Forecasts >= 2026
    sub_type=$([ "${yyyy}" -le 2025 ] && echo "hindcasts/raw" || echo "forecasts")
    cycle_dir="${SFS_DATA}/${sub_type}/init_${mm}/${yyyy}"
    [ -d "${cycle_dir}" ] || continue

    out_dir="${COMOUT:-${cycle_dir}/memens}"
    mkdir -p "${out_dir}"

    for prod in inst acc; do
        outfile="${out_dir}/${prod}.monthly.${init_ym}0100.${TARGET_YM}.ensmean.nc"
        [ -s "${outfile}" ] && [ "${FORCE:-0}" -ne 1 ] && continue

        # Gather member files
        files=($(find "${cycle_dir}"/mem* -maxdepth 1 -name "${prod}.monthly.${init_ym}0100.${TARGET_YM}*.grb2" 2>/dev/null | sort))
        [ ${#files[@]} -eq 0 ] && continue

        echo "[CALC] Lead ${lead} (${prod}): averaging ${#files[@]} members -> $(basename "${outfile}")"

        # Parallel conversion to RAM scratch
        tmp_ncs=()
        for f in "${files[@]}"; do
            nc="${SCRATCH}/$(basename "$f").nc"
            wgrib2 "$f" -netcdf "$nc" >/dev/null 2>&1 &
            tmp_ncs+=("$nc")
        done
        wait

        # Compute ensemble mean and clean scratch
        cdo -O ensmean "${tmp_ncs[@]}" "${outfile}" >/dev/null 2>&1
        rm -f "${tmp_ncs[@]}"
        echo "[DONE] Wrote ${outfile} ($(stat -c%s "${outfile}") bytes)"
    done
done
