#!/usr/bin/env bash
#SBATCH --job-name=sfs_clim
#SBATCH --account=fv3-cpu                    # Replace with your HPC account name
#SBATCH --partition=u1-service
#SBATCH --qos=batch
#SBATCH --time=01:30:00                   # 1.5 hours is plenty
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8                 # Matches max_workers=8 in Python script
#SBATCH --mem=32G                         # 32GB RAM for smooth xarray concatenation
#SBATCH --output=sfs_clim_%j.log
#SBATCH --error=sfs_clim_%j.err

module load intel-oneapi-compilers/2025.1.1
module use /contrib/METplus/modulefiles
module load metplus/13.0.0-beta2

echo "Starting SFS Climatology Calculation at $(date)"

python make_clim_sfs.py --init_month 10

echo "Finished at $(date)"
