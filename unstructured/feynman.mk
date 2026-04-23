# M3D-C1 build profile for feynman.ap.columbia.edu
#
# Target environment:
#   - Ubuntu 22.04 LTS, single SMP node (50 cores, ~900 GB RAM)
#   - System GCC 11.4, system OpenMPI 4.1.2 (from apt, on $PATH by default)
#   - CMake 3.22, SLURM 21.08 (partition: LocalQ)
#   - No PPPL / site-shared filesystems; all deps built under $(M3DC1_DEPS)
#
# Build deps (see README/readme.feynman):
#   PETSc + bundled MUMPS/SuperLU_DIST/ScaLAPACK/ParMETIS/Metis/Zoltan/FFTW/HDF5/NetCDF/BLAS
#   SCOREC/core (PUMI)
#   GSL (built locally)
#
# Invocation:
#   make ARCH=feynman OPT=1                      # 2D real
#   make ARCH=feynman OPT=1 COM=1                # 2D complex
#   make ARCH=feynman OPT=1 3D=1 MAX_PTS=60      # 3D real

FOPTS  = -c -fdefault-real-8 -fdefault-double-8 -fallow-argument-mismatch -cpp \
         -DPETSC_VERSION=313 -DUSEBLAS $(OPTS) -ffree-line-length-0
CCOPTS = -c -O -DPETSC_VERSION=313 -DDEBUG
R8OPTS = -fdefault-real-8 -fdefault-double-8

ifeq ($(OPT), 1)
  FOPTS  := $(FOPTS) -w -O2 -ffree-line-length-none
  CCOPTS := $(CCOPTS) -O
else
  FOPTS := $(FOPTS) -g
endif

ifeq ($(PAR), 1)
  FOPTS := $(FOPTS) -DUSEPARTICLES
endif

ifeq ($(OMP), 1)
  LDOPTS := $(LDOPTS) -fopenmp
  FOPTS  := $(FOPTS)  -fopenmp
  CCOPTS := $(CCOPTS) -fopenmp
endif

CC     = mpicc
CPP    = mpicxx
F90    = mpif90
F77    = mpif90
LOADER = mpif90

F90OPTS = $(F90FLAGS) $(FOPTS)
F77OPTS = $(F77FLAGS) $(FOPTS)

# Install prefix for locally-built deps; override via env if desired.
M3DC1_DEPS     ?= $(HOME)/M3DC1_deps
PETSC_DIR      ?= $(M3DC1_DEPS)/petsc
SCOREC_BASE_DIR?= $(M3DC1_DEPS)/core
GSL_DIR        ?= $(M3DC1_DEPS)/gsl

ifeq ($(COM), 1)
  PETSC_ARCH       = feynman-gcc-ompi-cplx
  M3DC1_SCOREC_LIB = -lm3dc1_scorec_complex
else
  PETSC_ARCH       = feynman-gcc-ompi
  M3DC1_SCOREC_LIB = -lm3dc1_scorec
endif

# Ubuntu's gcc/openmpi live in standard system paths, so no hardcoded -L needed
# beyond $(PETSC_DIR)/$(PETSC_ARCH)/lib (for PETSc + its downloaded deps).
PETSC_WITH_EXTERNAL_LIB = \
    -Wl,-rpath,$(PETSC_DIR)/$(PETSC_ARCH)/lib \
    -L$(PETSC_DIR)/$(PETSC_ARCH)/lib \
    -lpetsc \
    -lcmumps -ldmumps -lsmumps -lzmumps -lmumps_common -lpord \
    -lscalapack -lsuperlu -lsuperlu_dist \
    -lfftw3_mpi -lfftw3 \
    -lflapack -lfblas \
    -lzoltan -lparmetis -lmetis \
    -lhdf5hl_fortran -lhdf5_fortran -lhdf5_hl -lhdf5 \
    -lnetcdf \
    -lz -ldl -lstdc++ -lquadmath \
    -lmpi_usempif08 -lmpi_usempi_ignore_tkr -lmpi_mpifh -lmpi \
    -lgfortran -lm -lgcc_s -lpthread

SCOREC_UTIL_DIR   = $(SCOREC_BASE_DIR)/bin
PUMI_DIR          = $(SCOREC_BASE_DIR)
PUMI_LIB          = -lpumi -lapf -lapf_zoltan -lcrv -lsam -lspr -lmth \
                    -lgmi -lma -lmds -lparma -lpcu -lph -llion
M3DC1_SCOREC_DIR  = $(SCOREC_BASE_DIR)

ifdef SCORECVER
  SCOREC_DIR = $(M3DC1_SCOREC_DIR)/$(SCORECVER)
else
  SCOREC_DIR = $(M3DC1_SCOREC_DIR)
endif

SCOREC_LIB = -L$(SCOREC_DIR)/lib $(M3DC1_SCOREC_LIB) \
             -Wl,--start-group,-rpath,$(PUMI_DIR)/lib -L$(PUMI_DIR)/lib \
             $(PUMI_LIB) -Wl,--end-group

GSL_LIB = -Wl,-rpath,$(GSL_DIR)/lib -L$(GSL_DIR)/lib -lgsl -lgslcblas

LIBS = $(SCOREC_LIB) \
       $(PETSC_WITH_EXTERNAL_LIB) \
       $(GSL_LIB)

INCLUDE = -I$(PETSC_DIR)/include \
          -I$(PETSC_DIR)/$(PETSC_ARCH)/include \
          -I$(SCOREC_DIR)/include \
          -I$(GSL_DIR)/include

ifeq ($(ST), 1)
  NETCDF_DIR = $(PETSC_DIR)/$(PETSC_ARCH)
  LIBS += -Wl,--start-group -L$(NETCDF_DIR)/lib -Wl,-rpath,$(NETCDF_DIR)/lib \
          -lnetcdff -lnetcdf -Wl,--end-group
  INCLUDE += -I$(NETCDF_DIR)/include
endif


%.o : %.c
	$(CC)  $(CCOPTS) $(INCLUDE) $< -o $@

%.o : %.cpp
	$(CPP) $(CCOPTS) $(INCLUDE) $< -o $@

%.o: %.f
	$(F77) $(F77OPTS) $(INCLUDE) $< -o $@

%.o: %.F
	$(F77) $(F77OPTS) $(INCLUDE) $< -o $@

%.o: %.f90
	$(F90) $(F90OPTS) $(INCLUDE) $< -o $@
