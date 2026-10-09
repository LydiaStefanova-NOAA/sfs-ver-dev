# 1991–2020 Climatology & Empirical Tercile Generation Pipeline

This repository contains data ingestion (`fetch_core.sh`) and statistical processing (`make_clim` scripts) for NOAA's Environmental Verification System (EVS) / METplus pipeline. The scripts generate monthly reference climatologies for the **1991–2020 base period**, including both mean fields and non-parametric empirical terciles (33.3rd and 66.7th percentiles) for categorical skill evaluation.

## Setup

module load intel-oneapi-compilers/2025.1.1
module use /contrib/METplus/modulefiles
module load metplus/13.0.0-beta2

---

## Data Pipeline Architecture

The pipeline follows a modular two-stage structure:

1. **Fetch & Conversion Stage:** Ingests raw monthly data, extracts specific 2D slices, converts GRIB2 formats to NetCDF where applicable, and purges intermediate raw files to minimize HPC disk footprint.
2. **Climatology & Quantile Stage:** Concatenates 30-year monthly datasets (1991–2020), computes non-parametric mean and quantile fields, cleans encoding metadata, and exports standard NetCDF files.

---

## File Summary

### Data Acquisition Scripts

* **`fetch_ghcncams.sh`**: Retrieves GHCN-CAMS 2m T data for preceding month (default), or specified YYYYMM, or range.
* **`fetch_cmap.sh`**: Retrieves CMAP precipitation data for preceding month (default), or specified YYYYMM, or range.
* **`fetch_core.sh`**: Shell wrapper that retrieves CORE reanalysis data, calls `get_core.py` to download monthly GRIB2 files, extracts specified variables (such as 500 hPa Height or 850 hPa Temperature) via `wgrib2`, converts them to 2D NetCDF files, and purges the raw GRIB2 files upon completion.
* **`get_core.py`**: Python download helper utility used by `fetch_core.sh` to pull CORE datasets.
* **`submit_fetch_sfs_inst_hpss.sh`**: Self-cointained shell script (to be submitted via sbatch) that retrieves acc grib2 files from HPSS (`HGT500`, `TMP850`, `UGRD200`).
* **`submit_fetch_sfs_acc_hpss.sh`**: Self-cointained shell script (to be submitted via sbatch) that retrieves inst grib2 files from HPSS (`APCP`).

### Climatology & Tercile Scripts

* **`make_clim_cmap.py`**: Generates 1991–2020 monthly precipitation climatology from monthly CMAP NetCDF files.
* **`make_clim_ghcncams.py`**: Generates 1991–2020 monthly surface air temperature climatology from monthly GHCN-CAMS NetCDF files.
* **`make_clim_core.py`**: Parameterized script that computes 1991–2020 monthly climatology and empirical terciles for any CORE variable key (`HGT500`, `TMP850`, `UGRD200`).
* **`calc_sfs_climatology_unified.py`**: Parameterized script that computes 1991–2020 monthly climatology and empirical terciles for the following variabels (`HGT500`, `TMP850`, `UGRD200`, `APCP`). Submitted via **`submit_calc_sfs_climatology_unified.sh`**


---

## Quick Start & Usage

### 1. CORE Reanalysis Pipeline

```bash
# Fetch and convert 1991-2020 CORE 500 hPa Geopotential Height
./fetch_core.sh HGT500 "HGT:500 mb" 199101 202012

# Compute 1991-2020 monthly means and empirical terciles
python make_clim_core.py HGT500

# Example: Process 850 hPa Temperature
./fetch_core.sh TMP850 "TMP:850 mb" 199101 202012
python make_clim_core.py TMP850
```

### 2. CMAP Precipitation Pipeline

```bash
# Generate CMAP monthly climatology
python make_clim_cmap.py
```

### 3. GHCN-CAMS Surface Air Temperature Pipeline

```bash
# Generate GHCN-CAMS monthly climatology
python make_clim_ghcncams.py
```

---

## Output Dataset Specification

Each resulting file in `DATA/[DATASET]/climatology/[dataset]_clim_[MM].nc` contains three 2D spatial fields (lat x lon):

| Variable Name | Description | EVS / METplus Config Usage |
| :--- | :--- | :--- |
| `[var]` | 1991–2020 Climatological Mean | `CLIMO_MEAN_VAR1_NAME = [var]` |
| `[var]_p33` | 33.3rd Empirical Percentile Boundary | `OBS_VAR1_THRESH = <=climo_p33` |
| `[var]_p67` | 66.7th Empirical Percentile Boundary | `OBS_VAR1_THRESH = >climo_p67` |

### METplus Technical Compatibility Notes

* **Clean Encoding:** All output datasets undergo encoding cleanup prior to export (`out_ds.encoding = {}`). This eliminates residual `unlimited_dims {'time'}` metadata warnings during METplus ingestion.
* **2D Slice Notation:** Because time dimensions are collapsed into static monthly reference files, set 2D array wildcard levels in METplus configuration files: `CLIMO_MEAN_VAR1_LEVELS = "(*,*)"`.
