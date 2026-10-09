import os
import sys
import argparse
import subprocess
import concurrent.futures
import numpy as np
import xarray as xr

VAR_CONFIGS = {
    "inst": {
        "regex": "(HGT:500 mb|TMP:2 m above ground|TMP:surface)",
        "prefix": "inst"
    },
    "acc": {
        "regex": "(APCP|PRATE):surface",
        "prefix": "acc"
    }
}

def parse_args():
    parser = argparse.ArgumentParser(description="Compute SFS Climatology & Terciles")
    parser.add_argument("--init_month", type=int, default=10, help="Initialization month (1-12, default: 10)")
    parser.add_argument("--base_dir", type=str, default="SFS_VERIF_DATA", help="Base verification data directory")
    return parser.parse_args()

def get_target_yyyymm(init_year, init_month, lead_offset):
    total_months = (init_month - 1) + lead_offset
    target_year = init_year + (total_months // 12)
    target_month = (total_months % 12) + 1
    return f"{target_year}{target_month:02d}"

def convert_grb_to_nc(task):
    grb_path, tmp_nc_path, regex = task
    if os.path.exists(tmp_nc_path) and os.path.getsize(tmp_nc_path) > 0:
        return tmp_nc_path

    cmd = ["wgrib2", grb_path, "-match", regex, "-netcdf", tmp_nc_path]
    try:
        res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        if res.returncode != 0 or not os.path.exists(tmp_nc_path) or os.path.getsize(tmp_nc_path) == 0:
            return None
        return tmp_nc_path
    except Exception:
        return None

if __name__ == "__main__":
    args = parse_args()
    
    init_m = args.init_month
    init_str = f"{init_m:02d}"
    
    data_dir = os.path.join(args.base_dir, "hindcasts", "raw", f"init_{init_str}")
    clim_dir = os.path.join(args.base_dir, "hindcasts", "climatology_1991-2020", f"init_{init_str}")
    tmp_nc_dir = os.path.join(args.base_dir, "tmp", f"subsets_init_{init_str}")

    os.makedirs(clim_dir, exist_ok=True)
    os.makedirs(tmp_nc_dir, exist_ok=True)

    print("==================================================================")
    print(f"  Calculating 1991-2020 SFS Init Month {init_str} Climatology & Terciles")
    print(f"  Input Directory : {data_dir}")
    print(f"  Output Directory: {clim_dir}")
    print("==================================================================")

    for lead_idx in range(12):
        lead_num = lead_idx + 1
        print(f"\n[+] Processing Lead Month {lead_num:02d}/12...")

        conversion_tasks = []

        for yyyy in range(1991, 2021):
            target_yyyymm = get_target_yyyymm(yyyy, init_m, lead_idx)
            init_date_str = f"{yyyy}{init_str}0100"
            
            for m in range(11):
                mem_str = f"{m:03d}"
                for file_type, cfg in VAR_CONFIGS.items():
                    grb_file = f"{data_dir}/{yyyy}/mem{mem_str}/{file_type}.monthly.{init_date_str}.{target_yyyymm}.grib.t00z.grb2"
                    
                    if os.path.exists(grb_file):
                        tmp_nc = f"{tmp_nc_dir}/sub_{file_type}_{yyyy}_mem{mem_str}_lead{lead_num:02d}.nc"
                        conversion_tasks.append((grb_file, tmp_nc, cfg["regex"]))

        print(f"    Found {len(conversion_tasks)} GRIB2 targets. Subsetting via wgrib2...")

        with concurrent.futures.ProcessPoolExecutor(max_workers=8) as executor:
            converted_files = list(executor.map(convert_grb_to_nc, conversion_tasks))

        valid_files = [f for f in converted_files if f and os.path.exists(f) and os.path.getsize(f) > 0]

        if not valid_files:
            print(f"    [!] No valid files created for Lead {lead_num:02d}. Skipping.")
            continue

        sample_datasets = []
        for yyyy in range(1991, 2021):
            for m in range(11):
                mem_str = f"{m:03d}"
                inst_tmp = f"{tmp_nc_dir}/sub_inst_{yyyy}_mem{mem_str}_lead{lead_num:02d}.nc"
                acc_tmp  = f"{tmp_nc_dir}/sub_acc_{yyyy}_mem{mem_str}_lead{lead_num:02d}.nc"
                
                opened = []
                for tmp_file in [inst_tmp, acc_tmp]:
                    if os.path.exists(tmp_file):
                        ds = xr.open_dataset(tmp_file)
                        vars_to_drop = [c for c in ds.coords if c not in ["latitude", "longitude", "lat", "lon", "x", "y"]]
                        ds = ds.drop_vars(vars_to_drop, errors="ignore")
                        opened.append(ds)

                if opened:
                    ds_sample = xr.merge(opened, combine_attrs="override")
                    sample_datasets.append(ds_sample)

        ds_pooled = xr.concat(sample_datasets, dim="sample", coords="minimal", compat="override", combine_attrs="override")

        print("    Computing 1991-2020 Means and Empirical Terciles (P33.33 & P66.67)...")
        clim_ds = xr.Dataset()

        for var in ds_pooled.data_vars:
            data = ds_pooled[var]
            clim_ds[f"{var}_mean"] = data.mean(dim="sample", keep_attrs=True).astype(np.float32)
            clim_ds[f"{var}_std"]  = data.std(dim="sample", keep_attrs=True).astype(np.float32)
            clim_ds[f"{var}_tercile_p33"] = data.quantile(1.0/3.0, dim="sample", keep_attrs=True).drop_vars("quantile", errors="ignore").astype(np.float32)
            clim_ds[f"{var}_tercile_p67"] = data.quantile(2.0/3.0, dim="sample", keep_attrs=True).drop_vars("quantile", errors="ignore").astype(np.float32)

        clim_ds.attrs["description"] = f"SFS Init Month {init_str} Reforecast 1991-2020 Base Climatology for Lead Month {lead_num:02d}"
        clim_ds.attrs["sample_size"] = len(sample_datasets)

        out_nc = f"{clim_dir}/sfs_init{init_str}_clim_1991-2020_lead{lead_num:02d}.nc"
        clim_ds.to_netcdf(out_nc)
        print(f"    [✔] Saved Complete Climatology: {out_nc}")

        for ds in sample_datasets:
            ds.close()
        for f in valid_files:
            if os.path.exists(f):
                os.remove(f)

    if os.path.exists(tmp_nc_dir):
        os.rmdir(tmp_nc_dir)
