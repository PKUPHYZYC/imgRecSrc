%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%      Beam Hardening correction of CT Imaging via Mass attenuation 
%                        coefficient discretizati
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%   Author: Renliang Gu (renliang@iastate.edu)
%   $Revision: 0.1 $ $Date: Fri 07 Feb 2014 03:03:48 AM CST

clear;
setupPath
filename = [mfilename '.mat'];
if(~exist(filename)) save(filename,''); end

conf = ConfigCT();
conf.maskType='CircleMask'; %'cvxHull'; %'TightMask'; %
conf.imageName='castSim'; %'phantom' %'twoMaterials'; %'realct'; %'pellet'; %
conf.PhiPhitMode='basic'; %'filtered'; %'weighted'; %
conf.spark=0;

opt.rInit=5000;
opt.spectBasis = 'dis';
opt.saveImg=0;
opt.thresh=1e-12;
opt.maxItr=2e3;
%opt.muRange=[0.03 30];
opt.logspan=3;
opt.sampleMode='logspan'; %'assigned'; %'exponential'; %
opt.K=2;
opt.E=17;
opt.useSparse=0;
opt.showImg=1;
opt.visible=1;
opt.skipAlpha=0;
opt.maxIeSteps = 1;
%opt.t3=0;       % set t3 to ignore value of opt.a
opt.numCall=1;
opt.muLustig=1e-13; % logspace(-15,-6,5);
opt.skipIe=0;
opt.a=-6.5;  % aArray=-6.8:0.2:-6.2;

runList=[25,26];

%%%%%%%%%%%%%%%%%%%%%%%%
if(any(runList==3)) %solve by Back Projection
    j=0;
    prefix='BackProj';
    j=j+1;
    fprintf('%s, i=%d, j=%d\n',prefix,i,j);
    opt=conf.setup(opt);
    out3.x_BackProj=conf.FBP(conf.y);
    out3.res_BackProj=norm(conf.y-Phi(x_BackProj))/normy;
    out3.Img2D_BackProj=reshape(x_BackProj,[my mx]);
    out3.PSNR_BackProj(i,j,1)=psnr(Img2D(maskIdx),Img2D_BackProj(maskIdx),scaleM);
    out3.PSNR_BackProj(i,j,2)=psnr(Img2D,Img2D_BackProj,scale);
    save(filename,'out3','-append');
end

if(any(runList==20)) % dis, single AS step,
    temp = conf.theta;
    intval = 6:-1:1
    i=1;
    for i=1:length(intval)
        conf.theta = (0:intval(i):179)';
        opt=conf.setup(opt);
        prefix='BeamHard';
        fprintf('%s, i=%d, j=%d\n',prefix,i,0);
        initSig=conf.FBP(conf.y);
        initSig = initSig(opt.mask~=0);
        out20{i}=beamhardenSpline(conf.Phi,conf.Phit,...
            conf.Psi,conf.Psit,conf.y,initSig,opt);
    end
    conf.theta = temp;
    save(filename,'out20','-append');
end
if(any(runList==22)) % dis, max AS step,
    temp = conf.theta;
    temp1 = opt.maxIeSteps;
    opt.maxIeSteps = 100;
    intval = 6:-1:1
    i=1;
    for i=1:length(intval)
        conf.theta = (0:intval(i):179)';
        opt=conf.setup(opt);
        prefix='BeamHard';
        fprintf('%s, i=%d, j=%d\n',prefix,i,0);
        initSig=conf.FBP(conf.y);
        initSig = initSig(opt.mask~=0);
        out22{i}=beamhardenSpline(conf.Phi,conf.Phit,...
            conf.Psi,conf.Psit,conf.y,initSig,opt);
    end
    conf.theta = temp;
    opt.maxIeSteps = temp1;
    save(filename,'out22','-append');
end
if(any(runList==23)) % b0, single AS step,
    temp = conf.theta;
    opt.spectBasis = 'b0';
    intval = 6:-1:1
    i=1;
    for i=1:length(intval)
        conf.theta = (0:intval(i):179)';
        opt=conf.setup(opt);
        prefix='BeamHard';
        fprintf('%s, i=%d, j=%d\n',prefix,i,0);
        initSig=conf.FBP(conf.y);
        initSig = initSig(opt.mask~=0);
        out23{i}=beamhardenSpline(conf.Phi,conf.Phit,...
            conf.Psi,conf.Psit,conf.y,initSig,opt);
    end
    conf.theta = temp;
    opt.spectBasis = 'dis';
    save(filename,'out23','-append');
end
if(any(runList==24)) % b0, max AS step,
    opt.spectBasis = 'b0';
    temp = conf.theta;
    temp1 = opt.maxIeSteps;
    opt.maxIeSteps = 100;
    intval = 6:-1:1
    i=1;
    for i=1:length(intval)
        conf.theta = (0:intval(i):179)';
        opt=conf.setup(opt);
        prefix='BeamHard';
        fprintf('%s, i=%d, j=%d\n',prefix,i,0);
        initSig=conf.FBP(conf.y);
        initSig = initSig(opt.mask~=0);
        out24{i}=beamhardenSpline(conf.Phi,conf.Phit,...
            conf.Psi,conf.Psit,conf.y,initSig,opt);
    end
    conf.theta = temp;
    opt.maxIeSteps = temp1;
    opt.spectBasis = 'dis';
    save(filename,'out24','-append');
end
if(any(runList==25)) % b1, single AS step,
    temp = conf.theta;
    opt.spectBasis = 'b1';
    intval = 6:-1:1
    i=1;
    for i=1:length(intval)
        conf.theta = (0:intval(i):179)';
        opt=conf.setup(opt);
        prefix='BeamHard';
        fprintf('%s, i=%d, j=%d\n',prefix,i,0);
        initSig=conf.FBP(conf.y);
        initSig = initSig(opt.mask~=0);
        out25{i}=beamhardenSpline(conf.Phi,conf.Phit,...
            conf.Psi,conf.Psit,conf.y,initSig,opt);
    end
    conf.theta = temp;
    opt.spectBasis = 'dis';
    save(filename,'out25','-append');
end
if(any(runList==26)) % b1, max AS step,
    opt.spectBasis = 'b1';
    temp = conf.theta;
    temp1 = opt.maxIeSteps;
    opt.maxIeSteps = 100;
    intval = 6:-1:1
    i=1;
    for i=1:length(intval)
        conf.theta = (0:intval(i):179)';
        opt=conf.setup(opt);
        prefix='BeamHard';
        fprintf('%s, i=%d, j=%d\n',prefix,i,0);
        initSig=conf.FBP(conf.y);
        initSig = initSig(opt.mask~=0);
        out26{i}=beamhardenSpline(conf.Phi,conf.Phit,...
            conf.Psi,conf.Psit,conf.y,initSig,opt);
    end
    conf.theta = temp;
    opt.maxIeSteps = temp1;
    opt.spectBasis = 'dis';
    save(filename,'out26','-append');
end


% ADD SPARSE RECONSRUCTION 


if(any(runList==21)) % beamhardening with refinement
    j=0;
    prefix='BeamHard';
    x_BackProj=conf.FBP(conf.y);
    for jj=7 %[5:6] %1:length(rCoeff)
        j=j+1;
        fprintf('%s, i=%d, j=%d\n',prefix,i,j);
        initSig=x_BackProj(:)*1+0*Mask(:)/2; %Img2D; %

        aArray=-6.8:0.2:-6.2;
        muLustigArray=logspace(-15,-6,5);
        j=3;
        opt.muLustig=muLustigArray(j);

        aArray=-6.5;
        for i=1:length(aArray)
            opt.a=aArray(i);
            out{i}=beamhardenASSparseResampleMu(conf.Phi,conf.Phit,...
                conf.Psi,conf.Psit,conf.y,initSig,opt);
            RMSE(i)=1-(out{i}(end).alpha'*opt.trueAlpha/norm(out{i}(end).alpha))^2;
        end
        save(filename,'out21','-append');
    end
end
