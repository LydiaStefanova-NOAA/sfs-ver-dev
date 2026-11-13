#!/bin/bash
#PBS -N stage_sfs
#PBS -j oe 
#PBS -S /bin/bash
#PBS -q "dev_transfer"
#PBS -A VERF-DEV
#PBS -l walltime=06:00:00
#PBS -l place=shared,select=1:ncpus=1:mem=2GB
#PBS -l debug=true

# Ensure job runs in submission directory
cd "${PBS_O_WORKDIR:-$PWD}"

# Ensure HPSS utilities are loaded
module load hpss 2>/dev/null || true

# Explicitly export environment variables for child scripts
export MAX_JOBS=1

export version="sfs_b2"
export REFC_BASE="${REFC_BASE:-/NCEPDEV/emc-global/5year/Yangxing.Zheng/GAEAC6/scratch/SFSbeta2.0_C192mx025_reforecast_Oct01_CPCICS}"
export FCST_BASE="${FCST_BASE:-/NCEPDEV/emc-global/5year/Yangxing.Zheng/GAEAC6/scratch/SFSbeta2.0_C192mx025_NRT_forecast_Oct01_CPCICS}"


hsi stage $REFC_BASE/*201[4-9]100100/atmos*monthly*.tar
hsi stage $REFC_BASE/*202[0-5]100100/atmos*monthly*.tar
hsi stage $FCST_BASE/*2026100100/atmos*monthly*.tar
