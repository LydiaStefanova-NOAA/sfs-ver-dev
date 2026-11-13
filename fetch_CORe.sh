#!/usr/bin/env bash
#
# Usage:
#   ./fetch_CORe.sh [OPTIONS] <VAR1,VAR2,...> [START_YM] [END_YM]
#
# Examples:
#   ./fetch_CORe.sh -v "HGT500 TMP850 UGRD850 VGRD850 UGRD200 VGRD200 MSLP TSKIN T2M" -s 199101 -e 202610
#   ./fetch_CORe.sh PRATE 199101 202610   # Run months later: downloads only PRATE!

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GET_CORE_PY="${SCRIPT_DIR}/get_core.py"
OUT_DIR="${OUT_DIR:-SFS_VERIF_DATA/verifying_truths/CORe/monthly}"

# Lookup known variable metadata: file_type:wgrib2_match_pattern
resolve_var_info() {
    local key="$1"
    case "$key" in
        # Upper air / Pressure level (pgb)
        HGT500)  echo "pgb:HGT:500 mb" ;;
        HGT850)  echo "pgb:HGT:850 mb" ;;
        HGT200)  echo "pgb:HGT:200 mb" ;;
        TMP850)  echo "pgb:TMP:850 mb" ;;
        TMP500)  echo "pgb:TMP:500 mb" ;;
        TMP200)  echo "pgb:TMP:200 mb" ;;
        UGRD850) echo "pgb:UGRD:850 mb" ;;
        VGRD850) echo "pgb:VGRD:850 mb" ;;
        UGRD200) echo "pgb:UGRD:200 mb" ;;
        VGRD200) echo "pgb:VGRD:200 mb" ;;
        MSLP)    echo "pgb:PRES:mean sea level" ;;
        PRES)    echo "pgb:PRES:surface" ;;

        # Surface / Flux / 2m (flx)
        TSKIN)   echo "flx:TMP:surface" ;;
        T2M)     echo "flx:TMP:2 m above" ;;
        PRATE)   echo "flx:PRATE" ;;
        PWAT)    echo "flx:PWAT" ;;

        # Fallback for unknown/custom variables (defaults to checking pgb)
        *)       echo "pgb:$key" ;;
    esac
}

# -----------------------------------------------------------------------------
# Argument Parsing
# -----------------------------------------------------------------------------
RAW_VARS=()
POSITIONAL=()
START_YM=""
END_YM=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--var|--vars) RAW_VARS+=("$2"); shift 2 ;;
        -s|--start)      START_YM="$2"; shift 2 ;;
        -e|--end)        END_YM="$2"; shift 2 ;;
        -o|--outdir)     OUT_DIR="$2"; shift 2 ;;
        *)               POSITIONAL+=("$1"); shift ;;
    esac
done

for arg in "${POSITIONAL[@]}"; do
    if [[ "$arg" =~ ^[0-9]{6}$ ]]; then
        [ -z "$START_YM" ] && START_YM="$arg" || END_YM="$arg"
    else
        RAW_VARS+=("$arg")
    fi
done

# Expand comma- and space-separated lists
VARS=()
for entry in "${RAW_VARS[@]}"; do
    for v in ${entry//,/ }; do
        [ -n "$v" ] && VARS+=("$v")
    done
done

[ ${#VARS[@]} -eq 0 ] && { echo "ERROR: No variables specified."; exit 1; }
[ -z "$START_YM" ] && START_YM=$(date -d "last month" +%Y%m 2>/dev/null || date -v-1m +%Y%m)
[ -z "$END_YM" ] && END_YM="$START_YM"

mkdir -p "$OUT_DIR"

# -----------------------------------------------------------------------------
# Date Processing Loop
# -----------------------------------------------------------------------------
curr_y=${START_YM:0:4}
curr_m=${START_YM:4:2}
end_y=${END_YM:0:4}
end_m=${END_YM:4:2}

echo "=========================================================="
echo "Target Variables : ${VARS[*]}"
echo "Date Range       : ${START_YM} through ${END_YM}"
echo "Output Directory : ${OUT_DIR}"
echo "=========================================================="

while true; do
    printf -v m_pad "%02d" $((10#$curr_m))
    ym="${curr_y}${m_pad}"

    # Buckets for missing variables this month
    missing_pgb_vars=()
    missing_pgb_patterns=()
    missing_flx_vars=()
    missing_flx_patterns=()

    # 1. Inspect existing files on disk
    for var in "${VARS[@]}"; do
        nc_file="${OUT_DIR}/CORe_${var}_${ym}.nc"
        if [ ! -s "$nc_file" ]; then
            info=$(resolve_var_info "$var")
            ftype="${info%%:*}"
            pattern="${info#*:}"

            if [ "$ftype" == "flx" ]; then
                missing_flx_vars+=("$var")
                missing_flx_patterns+=("$pattern")
            else
                missing_pgb_vars+=("$var")
                missing_pgb_patterns+=("$pattern")
            fi
        fi
    done

    # 2. Download missing PGB variables (bundled)
    if [ ${#missing_pgb_vars[@]} -gt 0 ]; then
        # Build dynamic regex: (pattern1|pattern2|...)
        pgb_regex=$(IFS=\|; echo "(${missing_pgb_patterns[*]})")
        echo "[${ym}] Fetching missing PGB (${missing_pgb_vars[*]})..."
        
        python3 "$GET_CORE_PY" pgb "$ym" 1 1 "$pgb_regex" "$OUT_DIR" >/dev/null 2>&1
        
        pgb_grb="${OUT_DIR}/pgb.${ym}.grb"
        [ ! -f "$pgb_grb" ] && [ -f "${OUT_DIR}/pgb.${ym}" ] && pgb_grb="${OUT_DIR}/pgb.${ym}"

        if [ -s "$pgb_grb" ]; then
            for idx in "${!missing_pgb_vars[@]}"; do
                v="${missing_pgb_vars[$idx]}"
                p="${missing_pgb_patterns[$idx]}"
                wgrib2 "$pgb_grb" -match "$p" -netcdf "${OUT_DIR}/CORe_${v}_${ym}.nc" >/dev/null 2>&1
            done
            rm -f "$pgb_grb" "${OUT_DIR}/pgb.${ym}"
        fi
    fi

    # 3. Download missing FLX variables (bundled)
    if [ ${#missing_flx_vars[@]} -gt 0 ]; then
        flx_regex=$(IFS=\|; echo "(${missing_flx_patterns[*]})")
        echo "[${ym}] Fetching missing FLX (${missing_flx_vars[*]})..."
        
        python3 "$GET_CORE_PY" flx "$ym" 1 1 "$flx_regex" "$OUT_DIR" >/dev/null 2>&1
        
        flx_grb="${OUT_DIR}/flx.${ym}.grb"
        [ ! -f "$flx_grb" ] && [ -f "${OUT_DIR}/flx.${ym}" ] && flx_grb="${OUT_DIR}/flx.${ym}"

        if [ -s "$flx_grb" ]; then
            for idx in "${!missing_flx_vars[@]}"; do
                v="${missing_flx_vars[$idx]}"
                p="${missing_flx_patterns[$idx]}"
                wgrib2 "$flx_grb" -match "$p" -netcdf "${OUT_DIR}/CORe_${v}_${ym}.nc" >/dev/null 2>&1
            done
            rm -f "$flx_grb" "${OUT_DIR}/flx.${ym}"
        fi
    fi

    # Advance loop
    [ "$curr_y" -eq "$end_y" ] && [ "$((10#$curr_m))" -eq "$((10#$end_m))" ] && break
    curr_m=$((10#$curr_m + 1))
    [ "$curr_m" -gt 12 ] && { curr_m=1; curr_y=$((curr_y + 1)); }
done

echo "Done."
