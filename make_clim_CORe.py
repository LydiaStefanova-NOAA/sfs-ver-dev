import os
import sys

# MUST be set before importing xarray/netCDF4 to prevent Lustre file-locking hangs
os.environ["HDF5_USE_FILE_LOCKING"] = "FALSE"

import numpy as np
import xarray as xr

# Paths dynamically resolved via environment variables
m_dir = os.environ.get("MONTHLY_DIR", "SFS_VERIF_DATA/verifying_truths/CORe/monthly")
c_dir = os.environ.get("CLIM_DIR", os.environ.get("OUT_DIR", "SFS_VERIF_DATA/verifying_truths/CORe/climatology"))

os.makedirs(c_dir, exist_ok=True)

# Variables supplied via command line arguments or environment variable
if len(sys.argv) > 1:
    var_keys = sys.argv[1:]
elif "VAR_KEY" in os.environ:
    var_keys = os.environ["VAR_KEY"].split()
else:
    print(f"Usage: python {sys.argv[0]} <VAR_KEY> [VAR_KEY2 ...]", file=sys.stderr, flush=True)
    sys.exit(1)

# Baseline climatology period (1991-2020 inclusive)
CLIMO_YEARS = range(1991, 2021)

for var_key in var_keys:
    print(f"\n>>> Processing climatology for {var_key}...", flush=True)
    for mm in range(1, 13):
        mm_str = f"{mm:02d}"
        out_file = f"{c_dir}/CORe_{var_key}_clim_{mm_str}.nc"

        # Skip if already calculated
        if os.path.exists(out_file) and os.path.getsize(out_file) > 0:
            print(f"[{var_key}] Month {mm_str} already exists ({out_file}). Skipping.", flush=True)
            continue

        # Expected files for full 1991-2020 baseline
        expected_files = [
            f"{m_dir}/CORe_{var_key}_{yyyy}{mm_str}.nc"
            for yyyy in CLIMO_YEARS
        ]

        # Verify all expected files exist and are not empty
        missing_files = [
            f for f in expected_files 
            if not (os.path.exists(f) and os.path.getsize(f) > 0)
        ]

        if missing_files:
            print(
                f"\n[ERROR] Incomplete dataset for {var_key} (month {mm_str}). "
                f"Missing {len(missing_files)} of {len(expected_files)} files required for 1991-2020 baseline:\n"
                + "\n".join(f"  - {f}" for f in missing_files),
                file=sys.stderr,
                flush=True,
            )
            sys.exit(1)

        print(f"[{var_key}] Month {mm_str}: Loading {len(expected_files)} files into memory...", end="", flush=True)

        # Open and pull directly into memory
        ds_list = [xr.open_dataset(f) for f in expected_files]
        ds_combined = xr.concat(ds_list, dim="time").load()

        for ds in ds_list:
            ds.close()

        print(" computing stats...", end="", flush=True)

        # 1. Compute 1991-2020 Mean Climatology & Standard Deviation
        ds_mean = ds_combined.mean(dim="time", keep_attrs=True)
        ds_std  = ds_combined.std(dim="time", keep_attrs=True)

        # 2. Compute Empirical Terciles (33.3rd and 66.7th percentiles)
        ds_p33 = ds_combined.quantile(1/3, dim="time", keep_attrs=True).drop_vars("quantile", errors="ignore")
        ds_p67 = ds_combined.quantile(2/3, dim="time", keep_attrs=True).drop_vars("quantile", errors="ignore")

        # 3. Assemble unified output dataset for EVS/METplus
        out_ds = xr.Dataset()

        for var in ds_combined.data_vars:
            orig_long_name = ds_combined[var].attrs.get("long_name", var)

            out_ds[f"{var}_mean"] = ds_mean[var].astype(np.float32)
            out_ds[f"{var}_mean"].attrs["long_name"] = f"{orig_long_name} (1991-2020 Mean)"

            out_ds[f"{var}_std"] = ds_std[var].astype(np.float32)
            out_ds[f"{var}_std"].attrs["long_name"] = f"{orig_long_name} (1991-2020 Standard Deviation)"

            out_ds[f"{var}_p33"] = ds_p33[var].astype(np.float32)
            out_ds[f"{var}_p33"].attrs["long_name"] = f"{orig_long_name} (1991-2020 33.3rd Empirical Percentile)"

            out_ds[f"{var}_p67"] = ds_p67[var].astype(np.float32)
            out_ds[f"{var}_p67"].attrs["long_name"] = f"{orig_long_name} (1991-2020 66.7th Empirical Percentile)"

        # 4. Clean encoding and write to disk
        out_ds.encoding = {}
        for var in out_ds.data_vars:
            out_ds[var].encoding = {}

        out_ds.to_netcdf(out_file)
        out_ds.close()

        print(f" done -> Saved {out_file}", flush=True)
