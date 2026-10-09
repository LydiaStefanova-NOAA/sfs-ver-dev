import os
import numpy as np
import xarray as xr

m_dir = "/scratch4/NCEPDEV/ovp/Lydia.B.Stefanova/REPOS/sfs-ver-dev/SFS_VERIF_DATA/verifying_truths/CMAP/monthly"
c_dir = "/scratch4/NCEPDEV/ovp/Lydia.B.Stefanova/REPOS/sfs-ver-dev/SFS_VERIF_DATA/verifying_truths/CMAP/climatology"
os.makedirs(c_dir, exist_ok=True)

for mm in range(1, 13):
    mm_str = f"{mm:02d}"
    files = [
        f"{m_dir}/cmap_{yyyy}{mm_str}.nc"
        for yyyy in range(1991, 2021)
        if os.path.exists(f"{m_dir}/cmap_{yyyy}{mm_str}.nc")
    ]

    if not files:
        print(f"No files found for month {mm_str}. Skipping.")
        continue

    # Open datasets directly without dask dependency
    ds_list = [xr.open_dataset(f) for f in files]
    
    # Concatenate along time dimension across the 1991-2020 base period
    ds_combined = xr.concat(ds_list, dim="time")

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

        # Main Climatological Mean
        out_ds[f"{var}_mean"] = ds_mean[var].astype(np.float32)
        out_ds[f"{var}_mean"].attrs["long_name"] = f"{orig_long_name} (1991-2020 Mean)"

        # Standard Deviation
        out_ds[f"{var}_std"] = ds_std[var].astype(np.float32)
        out_ds[f"{var}_std"].attrs["long_name"] = f"{orig_long_name} (1991-2020 Standard Deviation)"

        # Empirical Tercile Bounds
        out_ds[f"{var}_p33"] = ds_p33[var].astype(np.float32)
        out_ds[f"{var}_p33"].attrs["long_name"] = f"{orig_long_name} (1991-2020 33.3rd Empirical Percentile)"

        out_ds[f"{var}_p67"] = ds_p67[var].astype(np.float32)
        out_ds[f"{var}_p67"].attrs["long_name"] = f"{orig_long_name} (1991-2020 66.7th Empirical Percentile)"

    # 4. Wipe stale dataset and variable encoding to prevent "unlimited_dims {'time'}" warnings
    out_ds.encoding = {}
    for var in out_ds.data_vars:
        out_ds[var].encoding = {}

    # Save climatology NetCDF file
    out_file = f"{c_dir}/cmap_clim_{mm_str}.nc"
    out_ds.to_netcdf(out_file)

    # Clean up open file handles
    for ds in ds_list:
        ds.close()

    print(f"Saved: {out_file}")
