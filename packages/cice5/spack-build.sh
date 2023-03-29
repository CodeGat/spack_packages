#! /bin/csh -f

set echo on

if ( $#argv < 4 ) then
  echo '*** Please issue the command like ***'
  echo '> ./bld/build.sh <driver> <grid> <blocks> <ntask> [<debug>]'
  echo 'e.g. bld/build.sh auscom 1440x1080 48x40 480'
  echo 'driver: which driver to use.'
  echo 'grid: grid resolution longitude by latitude.'
  echo 'blocks: grid split into the number of blocks longitude by latitude.'
  echo 'ntask: number of tasks.'
  exit
else
  set driver = $1
  set grid = $2
  set blocks = $3
  set ntask = $4
endif

# Location of this model
setenv SRCDIR $cwd
setenv CBLD   $SRCDIR/bld

### The version of an executable can be found with the following
### command: strings <executable> | grep 'CICE_VERSION='
set version='202301'
sed -e "s/{CICE_VERSION}/$version/g" $SRCDIR/drivers/$driver/version.F90.template > $SRCDIR/drivers/$driver/version_mod.F90

### Where this model is compiled
setenv OBJDIR $SRCDIR/build_${driver}_${grid}_${blocks}_${ntask}p
if !(-d $OBJDIR) mkdir -p $OBJDIR

setenv NTASK $ntask
setenv RES $grid
set NXGLOB = `echo $RES | sed s/x.\*//`
set NYGLOB = `echo $RES | sed s/.\*x//`
set NXBLOCK = `echo $blocks | sed s/x.\*//`
set NYBLOCK = `echo $blocks | sed s/.\*x//`
setenv BLCKX `expr $NXGLOB / $NXBLOCK` # x-dimension of blocks ( not including )
setenv BLCKY `expr $NYGLOB / $NYBLOCK` # y-dimension of blocks (  ghost cells  )

@ a = $NXGLOB * $NYGLOB ; @ b = $BLCKX * $BLCKY * $NTASK
@ m = $a / $b ; setenv MXBLCKS $m ; if ($MXBLCKS == 0) setenv MXBLCKS 1
echo Autimatically generated: MXBLCKS = $MXBLCKS

cp -f $CBLD/Makefile.std $CBLD/Makefile

cd $OBJDIR

### List of source code directories (in order of importance).
cat >! Filepath << EOF
$SRCDIR/drivers/$driver
$SRCDIR/source
$SRCDIR/mpi
$SRCDIR/io_pio
$SRCDIR/csm_share
EOF

cc -o makdep $CBLD/makdep.c || exit 2

make VPFILE=Filepath EXEC=cice_${driver}_${grid}_${blocks}_${ntask}p.exe \
           NXGLOB=$NXGLOB NYGLOB=$NYGLOB \
           BLCKX=$BLCKX BLCKY=$BLCKY MXBLCKS=$MXBLCKS \
           -f  $CBLD/Makefile MACFILE=$CBLD/Macros.spack || exit 2

cd ..
pwd
echo NTASK = $NTASK
echo "global N, block_size"
echo "x    $NXGLOB,    $BLCKX"
echo "y    $NYGLOB,    $BLCKY"
echo max_blocks = $MXBLCKS
