#!/bin/sh
#SBATCH --job-name=03-various-sizes-4-5
#SBATCH --output=logs/03-various-sizes-4-5.out
#SBATCH --time=12:00:00
#SBATCH --mem-per-cpu=16G
#SBATCH --partition=thomas
#SBATCH --account=lc_pdt
#SBATCH --mail-type=ALL
#SBATCH --mail-user=g.vegayon@gmail.com

library(ergmito)
library(ergm)
library(parallel)
library(slurmR)

# Loading simulation function and data
source("data/fitter.R")

# Transitive model -------------------------------------------------------------
dat <- readRDS("simulations/dgp_4_5_null-larger.rds")

# Creating cluster
opts_slurmR$set_tmp_path("/staging/ggv/")
opts_slurmR$set_job_name("03-various-sizes-4-5-null")
opts_slurmR$set_opts(
  account       = "lc_ggv",
  partition     = "scavenge",
  time          = "08:00:00",
  `mem-per-cpu` = "2G"
)

# Checking veb
opts_slurmR$verbose_on()

job2 <- Slurm_lapply(
   dat,
   fitter,
   njobs    = 400,
   mc.cores = 1L,
   plan     = "wait",
   model    = ~ edges + ttriad
   )

cat("~~ THE END ttriad ... COLLECTING ~~\n")

# Waiting just in case
Sys.sleep(60*2)

# ans1 <- Slurm_collect(job1)
ans2 <- Slurm_collect(job2)
# saveRDS(ans1, "simulations/02-various-sizes-4-5-mutual.rds", compress = FALSE)
saveRDS(ans2, "simulations/03-various-sizes-4-5-null-larger.rds", compress = FALSE)

cat("~~ THE END ALL ~~\n")

