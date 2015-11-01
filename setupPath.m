function setupPath
%
% Author: Renliang Gu (renliang@iastate.edu)
% $Revision: 0.3 $ $Date: Sat 31 Oct 2015 09:50:39 PM CDT
%
% 0.4: add variable cleaning statements
% 0.3: add the current path
% 0.2: implement by dbstack, so that it can be called from any location

[a,~]=dbstack('-completenames');
a=a(1);
[pathstr,~,~]=fileparts(a.file);
addpath([pathstr filesep 'beamharden' filesep 'subfunctions']);
addpath([pathstr filesep 'beamharden']);
addpath([pathstr filesep 'tomography']);
addpath([pathstr filesep 'rwt']);
addpath([pathstr filesep 'npg']);
addpath([pathstr filesep 'bhc']);
addpath([pathstr filesep 'prj']);
addpath([pathstr filesep 'utils']);
addpath([pathstr filesep 'utils' filesep 'L-BFGS-B-C' filesep 'Matlab']);
addpath([pathstr filesep 'irt' filesep 'nufft']);
addpath([pathstr filesep 'irt' filesep 'systems']);
addpath([pathstr filesep 'irt']);
addpath([pathstr filesep 'irt' filesep 'emission']);
addpath([pathstr filesep 'irt' filesep 'transmission']);
addpath([pathstr filesep 'irt' filesep 'fbp']);
addpath([pathstr filesep 'irt' filesep 'data']);
addpath([pathstr filesep 'irt' filesep 'utilities']);
addpath([pathstr filesep 'others']);
addpath([pathstr filesep 'others' filesep 'FPC_AS']);
addpath([pathstr filesep 'others' filesep 'FPC_AS' filesep 'src']);
addpath([pathstr filesep 'others' filesep 'FPC_AS' filesep 'prob_gen']);
addpath([pathstr filesep 'others' filesep 'FPC_AS' filesep 'prob_gen' filesep 'classes']);
addpath([pathstr filesep 'others' filesep 'glmnet_matlab']);
addpath([pathstr filesep 'others' filesep 'fpc' filesep 'solvers']);
addpath([pathstr filesep 'others' filesep 'fpc' filesep 'solvers' filesep 'utilities']);

cd 'prj'
if(isunix)
    !make cpu
    if(gpuDeviceCount>0)
        !make gpu 
    end
elseif(ispc)
    if (~exist(['solveTridiag.' mexext],'file'))
        mex solveTridiag.c
    end
    if ~exist(['parPrj.' mexext],'file')
        mex -output parPrj mParPrj.c parPrj.c
    end
    if ~exist(['cpuPrj.' mexext],'file')
        mex -output cpuPrj cpuPrj.c mPrj.c common/kiss_fft.c -DCPU=1
    end
    if(gpuDeviceCount>0  && ~exist(['gpuPrj.' mexext],'file'))
        link='"-LC:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v7.0\lib\x64"';
        mex('-DGPU=1','-output','gpuPrj', link,'-lcudart','gpuPrj.obj','mPrj.c','common/kiss_fft.c');
    end
end
cd(pathstr)

cd('rwt')
tgt=['mdwt.' mexext];
if(~exist(tgt,'file')...
        || isOlder(tgt,{'mdwt.c','mdwt_r.c'}))
    mex mdwt.c mdwt_r.c
end
tgt=['midwt.' mexext];
if(~exist(tgt,'file')...
        || isOlder(tgt,{'midwt.c','midwt_r.c'}))
    mex midwt.c midwt_r.c
end
cd(pathstr)

cd(['utils' filesep 'L-BFGS-B-C' filesep 'Matlab'])
if(~exist(['lbfgsb_wrapper.' mexext],'file'))
    if(isunix)
        !make
    elseif(ispc)
        mex -largeArrayDims -O -g -UDEBUG -I../src ...
            lbfgsb_wrapper.c ../src/lbfgsb.c ../src/linesearch.c ../src/subalgorithms.c ...
            ../src/print.c ../src/linpack.c ../src/miniCBLAS.c ../src/timer.c
    end
end
cd(pathstr)
end

function o = isOlder(f1, f2)
    if(~iscell(f2))
        dependence{1}=f2;
    else
        dependence=f2;
    end
    file=dir(dependence{1});
    time=datenum(file.date);
    for i=2:length(dependence)
        file=dir(dependence{i});
        time=max(time,datenum(file.date));
    end
    file=dir(f1);
    o=datenum(file.date)<time;
end

