#!/usr/bin/env bash

# Usage:
#   ./fetch_core.sh <VAR_KEY> [GRIB_MATCH] [YYYYMM_START] [YYYYMM_END]
#
# Examples:
#   ./fetch_core.sh HGT500
#   ./fetch_core.sh TMP850 "TMP:850 mb" 199101 202012
#   ./fetch_core.sh UGRD200 "UGRD:200 mb" 199101 202012


VAR_KEY="${1:-HGT500}"
OUT_DIR="${OUT_DIR:-SFS_VERIF_DATA/verifying_truths/CORE/${VAR_KEY}/monthly}"
GRIB_MATCH="$2"

# Auto-set GRIB_MATCH for common shortcuts if not explicitly passed
if [ -z "$GRIB_MATCH" ]; then
    case "$VAR_KEY" in
        HGT500)  GRIB_MATCH="HGT:500 mb" ;;
        TMP850)  GRIB_MATCH="TMP:850 mb" ;;
        UGRD200) GRIB_MATCH="UGRD:200 mb" ;;
        VGRD200) GRIB_MATCH="VGRD:200 mb" ;;
        MSLP) GRIB_MATCH="MSLP" ;;
        *)
            echo "ERROR: Unknown VAR_KEY shortcut '$VAR_KEY'. Please provide GRIB_MATCH pattern explicitly."
            echo "Usage: $0 $VAR_KEY \"MATCH_PATTERN\" [YYYYMM_START] [YYYYMM_END]"
            exit 1
            ;;
    esac
fi

# Determine date arguments
SHIFT_ARGS=2
if [ -n "$2" ] && [[ "$2" =~ ^[0-9]{6}$ ]]; then
    # If 2nd arg is a YYYYMM date rather than a match string:
    START_YM="$2"
    END_YM="$3"
    SHIFT_ARGS=1
    # Fallback match lookup
    case "$VAR_KEY" in
        HGT500)  GRIB_MATCH="HGT:500 mb" ;;
        TMP850)  GRIB_MATCH="TMP:850 mb" ;;
        UGRD200) GRIB_MATCH="UGRD:200 mb" ;;
        VGRD200) GRIB_MATCH="VGRD:200 mb" ;;
    esac
else
    START_YM="$3"
    END_YM="$4"
fi

VAR_LOWER=$(echo "$VAR_KEY" | tr '[:upper:]' '[:lower:]')


download_month() {
    local ym="$1"
    local nc_file="${OUT_DIR}/core_${VAR_LOWER}_${ym}.nc"

    if [ -f "$nc_file" ]; then
        echo "NetCDF file already exists: ${nc_file}. Skipping."
        return 0
    fi

    echo "Fetching CORe ${VAR_KEY} ('${GRIB_MATCH}') for ${ym}..."

    python get_core.py pgb "$ym" 1 1 "$GRIB_MATCH" "$OUT_DIR"

    if [ $? -eq 0 ]; then
        local grb_file=""
        if [ -f "${OUT_DIR}/pgb.${ym}" ]; then
            grb_file="${OUT_DIR}/pgb.${ym}"
        elif [ -f "${OUT_DIR}/pgb.${ym}.grb" ]; then
            grb_file="${OUT_DIR}/pgb.${ym}.grb"
        fi

        if [ -n "$grb_file" ]; then
            echo "Converting ${grb_file} -> ${nc_file}..."
            wgrib2 "$grb_file" -netcdf "$nc_file" > /dev/null

            if [ $? -eq 0 ] && [ -f "$nc_file" ]; then
                rm -f "$grb_file"
                echo "Successfully created: ${nc_file} (GRIB purged)"
            else
                echo "ERROR: wgrib2 conversion failed for ${ym}"
            fi
        else
            echo "ERROR: Downloaded GRIB2 file not found for ${ym}"
        fi
    else
        echo "Error downloading CORe data for ${ym}."
    fi
}

# Run execution modes
if [ -z "$START_YM" ]; then
    TARGET_YM=$(date -d "last month" +%Y%m 2>/dev/null || date -v-1m +%Y%m)
    echo "No date range given. Defaulting to most recent month (${TARGET_YM})..."
    download_month "$TARGET_YM"
elif [ -z "$END_YM" ]; then
    download_month "$START_YM"
else
    curr_y=${START_YM:0:4}
    curr_m=${START_YM:4:2}
    end_y=${END_YM:0:4}
    end_m=${END_YM:4:2}

    echo "Downloading CORe ${VAR_KEY} range ${START_YM} to ${END_YM}..."

    while true; do
        printf -v m_padded "%02d" $((10#$curr_m))
        ym_label="${curr_y}${m_padded}"

        download_month "$ym_label"

        if [ "$curr_y" -eq "$end_y" ] && [ "$((10#$curr_m))" -eq "$((10#$end_m))" ]; then
            break
        fi

        curr_m=$((10#$curr_m + 1))
        if [ "$curr_m" -gt 12 ]; then
            curr_m=1
            curr_y=$((curr_y + 1))
        fi
    done
fi
