#!/bin/bash
#PBS -N fetch_sfs
#PBS -j oe 
#PBS -S /bin/bash
#PBS -q "dev_transfer"
#PBS -A VERF-DEV
#PBS -l walltime=06:00:00
#PBS -l place=shared,select=1:ncpus=8:mem=18GB
#PBS -l debug=true

# Ensure job runs in submission directory
cd "${PBS_O_WORKDIR:-$PWD}"

# Ensure HPSS utilities are loaded
module load hpss 2>/dev/null || true

# Explicitly export environment variables for child scripts
export MAX_JOBS=4

export version="sfs_b2"
export REFC_BASE="${REFC_BASE:-/NCEPDEV/emc-global/5year/Yangxing.Zheng/GAEAC6/scratch/SFSbeta2.0_C192mx025_reforecast_Oct01_CPCICS}"
export FCST_BASE="${FCST_BASE:-/NCEPDEV/emc-global/5year/Yangxing.Zheng/GAEAC6/scratch/SFSbeta2.0_C192mx025_NRT_forecast_Oct01_CPCICS}"

export BASE_DIR="/lfs/h2/emc/vpppg/noscrub/lydia.b.stefanova/sfs-ver-dev/SFS_VERIF_DATA"

echo "Running HPSS fetch pipeline from: $(pwd)"
echo "Target Base Directory: ${BASE_DIR}"

#bash fetch_sfs.sh 199110 202610
bash fetch_sfs.sh 202610
