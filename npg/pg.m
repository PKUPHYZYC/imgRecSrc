function out = pg(NLL,proximal,xInit,opt)
%   pg solves a sparse regularized problem
%
%                           NLL(x) + u*r(x)                           (1)
%
%   where NLL(x) is the likelihood function and r(x) is the regularization
%   term with u as the regularization parameter.   For the input, we
%   require NLL to be a function handle that can be used in the following
%   form:
%                       [f,grad,hessian] = NLL(x);
%
%   where f and grad are the value and gradient of NLL at x, respectively.
%   "hessian" is a function handle that can be use to calculate H*x and
%   x'*H*x with hessian(x,1) and hessian(x,2), respectively.  If Hessian
%   matrix is not available, simply return hessian as empty: [];
%   (See npg/sparseProximal.m and utils/Utils.m for examples)
%
%   The "proximal" parameter is served as a structure with "iterative",
%   "op" and "penalty" to solve the following subproblem:
%
%                         0.5*||x-a||_2^2+u*r(x)                      (2)
%
%   1. When proximal.iterative=true, proximal.op is iterative and should be
%   called in the form of
%             [x,itr,p]=proximal.op(a,u,thresh,maxItr,pInit);
%   where
%       pInit           initial value of internal variable (e.g., dual
%                       variable), can be [] if not sure what to give;
%       maxItr          maximum number of iteration to run;
%       x               solution of eq(2);
%       itr             actual number of iteration run when x is returned;
%       p               value of internal variable when terminates, can be
%                       used as the initial value (pInit) for the next run.
%
%   2. When proximal.iterative=false, proximal.op is exact with no
%   iterations, i.e., the proximal operator has analytical solution:
%                           x=proximal.op(a,u);
%   where "u" is optional in case r(x) is an indicator function.
%
%   proximal.penalty(x) returns the value of r(x).
%   (See npg/sparseProximal.m for an example)
%
%   xInit       Initial value for estimation of x
%
%   opt         The optional structure for the configuration of this algorithm (refer to
%               the code for detail)
%       prj_C           A function handle to project signal x to a convex set
%                       C;
%       u               Regularization parameter;
%       initStep        Method for the initial step size, can be one of
%                       "hessian", "bb", and "fixed".  When "fixed" is set,
%                       provide Lipschitz constant of NLL by opt.Lip;
%       debugLevel      An integer value to tune how much debug information
%                       to show during the iterations;
%       outLevel        An integer value to control how many quantities to
%                       put in "out".
%
%   Reference:
%   Author: Renliang Gu (gurenliang@gmail.com)

% default to not use any constraints.
if(~exist('opt','var') || ~isfield(opt,'prj_C') || isempty(opt.prj_C))
    opt.prj_C=@(x) x;
end

if(~isfield(opt,'u')) opt.u=1e-4; end

if(~isfield(opt,'stepIncre')) opt.stepIncre=0.9; end
if(~isfield(opt,'stepShrnk')) opt.stepShrnk=0.5; end
if(~isfield(opt,'preSteps')) opt.preSteps=5; end
if(~isfield(opt,'initStep')) opt.initStep='hessian'; end
% Threshold for relative difference between two consecutive x
if(~isfield(opt,'thresh')) opt.thresh=1e-6; end
if(~isfield(opt,'Lip')) opt.Lip=nan; end
if(~isfield(opt,'maxItr')) opt.maxItr=2e3; end
if(~isfield(opt,'minItr')) opt.minItr=10; end
if(~isfield(opt,'errorType')) opt.errorType=1; end
if(~isfield(opt,'gamma')) gamma=2; else gamma=opt.gamma; end
if(~isfield(opt,'b')) b=0.25; else b=opt.b; end

if(~isfield(opt,'relInnerThresh')) opt.relInnerThresh=1e-2; end
if(~isfield(opt,'cumuTol')) opt.cumuTol=4; end
if(~isfield(opt,'incCumuTol')) opt.incCumuTol=true; end
if(~isfield(opt,'adaptiveStep')) opt.adaptiveStep=true; end
if(~isfield(opt,'maxInnerItr')) opt.maxInnerItr=100; end
if(~isfield(opt,'maxPossibleInnerItr')) opt.maxPossibleInnerItr=1e3; end

% Debug output information
% >=0: no print,
% >=1: only report results,
% >=2: detail output report, 
% >=4: plot real time cost and RMSE,
if(~isfield(opt,'debugLevel')) opt.debugLevel=1; end
% print iterations every opt.verbose lines.
if(~isfield(opt,'verbose')) opt.verbose=100; end

% Output options and debug information
% >=0: minimum output with only results,
% >=1: some cheap output,
% >=2: more detail output and expansive (impairs CPU time, only for debug)
if(~isfield(opt,'outLevel')) opt.outLevel=0; end
if(~isfield(opt,'saveXtrace') || opt.outLevel<2) opt.saveXtrace=false; end
if(~isfield(opt,'collectOtherStepSize') || opt.outLevel<2)
    opt.collectOtherStepSize=false;
end

if(isfield(opt,'trueX'))
    switch opt.errorType
        case 0
            trueX = opt.trueX/pNorm(opt.trueX);
            computError= @(xxx) 1-(realInnerProd(xxx,trueX)^2)/sqrNorm(xxx);
        case 1
            trueXNorm=sqrNorm(opt.trueX);
            if(trueXNorm==0) trueXNorm=eps; end
            computError = @(xxx) sqrNorm(xxx-opt.trueX)/trueXNorm;
        case 2
            trueXNorm=pNorm(opt.trueX);
            if(trueXNorm==0) trueXNorm=eps; end
            computError = @(xxx) pNorm(xxx-opt.trueX)/trueXNorm;
    end
end

debug=Debug(opt.debugLevel);
if(debug.level(4))
    figCostRMSE=1000; figure(figCostRMSE);
end

% In case of projection as proximal
if(nargin(proximal.op)==1)
    proximalOp=proximal.op;
    proximal.op=@(a,u) proximalOp(a);
end

% print start information
if(debug.level(2))
    fprintf('%s\n', repmat( '=', 1, 80 ) );
    str=sprintf('Proximal-Gradient (PG) Method');
    fprintf('%s%s\n',repmat(' ',1,floor(40-length(str)/2)),str);
    fprintf('%s\n', repmat('=',1,80));
    str=sprintf( ' %5s','Itr');
    str=sprintf([str ' %14s'],'Objective');
    if(isfield(opt,'trueX'))
        str=sprintf([str ' %12s'], 'Error');
    end
    str=sprintf([str ' %12s %4s'], '|dx|/|x|', 'αSrh');
    str=sprintf([str ' %12s'], '|d Obj/Obj|');
    str=sprintf([str '\t u=%g'],opt.u);
    fprintf('%s\n%s\n',str,repmat( '-', 1, 80 ) );
end

t=stepSizeInit(opt.initStep,opt.Lip);

tStart=tic;

itr=0; convThresh=0; x=xInit;
NLLVal=NLL(x);
penVal=proximal.penalty(x);
cost=NLLVal+opt.u*penVal;
goodStep=true;
if((opt.outLevel>=1 || debug.level(2)) && isfield(opt,'trueX'))
    RMSE=computError(x);
end

if(opt.outLevel>=1) out.debug={}; end
if(proximal.iterative)
    pInit=[];
    difX=1;
end
if(opt.adaptiveStep) cumu=0; end

while(true)
    itr=itr+1;
    %if(mod(itr,100)==1 && itr>100) save('snapshotFST.mat'); end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %  start of one PG step  %
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%

    numLineSearch=0; goodMM=true; incStep=false;
    [oldCost,grad] = NLL(x);
    if(opt.adaptiveStep && cumu>=opt.cumuTol)
        % adaptively increase the step size
        t=t*opt.stepIncre;
        cumu=0;
        incStep=true;
    end

    % start of line Search
    while(true)
        numLineSearch = numLineSearch+1;

        if(proximal.iterative)
            [newX,innerItr_,pInit_]=proximal.op(x-grad/t,opt.u/t,opt.relInnerThresh*difX,opt.maxInnerItr,...
                pInit);
        else
            newX=proximal.op(x-grad/t,opt.u/t);
        end

        newCost=NLL(newX);
        if(majorizationHolds(newX-x,newCost,oldCost,[],grad,t))
            if(itr<=opt.preSteps && opt.adaptiveStep && goodStep)
                cumu=opt.cumuTol;
            end
            break;
        else
            if(numLineSearch<=20)
                t=t/opt.stepShrnk; goodStep=false;
                % Penalize if there is a step size increase just now
                if(incStep)
                    incStep=false;
                    if(opt.incCumuTol)
                        opt.cumuTol=opt.cumuTol+4;
                    end
                end
            else  % don't know what to do, mark on debug and break
                goodMM=false;
                debug.appendLog('_FalseMM');
                break;
            end
        end
    end
    newPen = proximal.penalty(newX);
    newObj = newCost+opt.u*newPen;

    % using eps reduces numerical issue around the point of convergence
    if((newObj-cost)>eps*max(abs(newCost),abs(cost)))
        if(~goodMM)
            reset(); % both theta and step size;
        end
        if(runMore()) itr=itr-1; continue; end

        % give up and force it to converge
        debug.appendLog('_ForceConverge');
        innerItr=0;
        preX=x; difX=0;
        preCost=cost;
    else
        if(proximal.iterative)
            pInit=pInit_;
            innerItr=innerItr_;
        else
            innerItr=0;
        end
        difX = relativeDif(x,newX);
        preX = x;
        x = newX;
        preCost=cost;
        cost = newObj;
        NLLVal=newCost;
        penVal=newPen;
    end

    if(opt.adaptiveStep)
        if(numLineSearch==1)
            cumu=cumu+1;
        else
            cumu=0;
        end
    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%
    %  end of one PG step  %
    %%%%%%%%%%%%%%%%%%%%%%%%%%

    if(opt.outLevel>=1 || debug.level(2))
        difCost=abs(cost-preCost)/max(1,abs(cost));
        if(isfield(opt,'trueX'))
            preRMSE=RMSE; RMSE=computError(x);
        end
    end
    if(opt.outLevel>=1)
        out.time(itr)=toc(tStart);
        out.cost(itr)=cost;
        out.difX(itr)=difX;
        out.difCost(itr)=difCost;
        out.numLineSearch(itr) = numLineSearch;
        out.stepSize(itr) = 1/t;
        out.NLLVal(itr)=NLLVal;
        out.penVal(itr)=penVal;
        if(proximal.iterative)
            out.innerItr(itr)=innerItr;
        end;
        if(isfield(opt,'trueX'))
            out.RMSE(itr)=RMSE;
        end
        if(~isempty(debug.log()))
            out.debug{size(out.debug,1)+1,1}=itr;
            out.debug{size(out.debug,1),2}=debug.log();
            debug.clearLog();
        end;
    end

    if(opt.outLevel>=2)
        if(opt.saveXtrace) out.xTrace(:,itr)=x; end
        if(opt.collectOtherStepSize)
            out.BB(itr,1)=stepSizeInit('BB');
            out.BB(itr,2)=stepSizeInit('hessian');
        end
    end

    if(debug.level(2))
        debug.print(2,sprintf(' %5d',itr));
        debug.print(2,sprintf(' %14.12g',cost));
        if(isfield(opt,'trueX'))
            debug.print(2,sprintf(' %12g',RMSE));
        end
        debug.print(2,sprintf(' %12g %4d',difX,numLineSearch));
        debug.print(2,sprintf(' %12g', difCost));
        debug.clear_print(2);
        if(mod(itr,opt.verbose)==0) debug.println(2); end
    end

    if(debug.level(4) && itr>1)
        set(0,'CurrentFigure',figCostRMSE);
        if(isfield(opt,'trueX')) subplot(2,1,1); end
        if(cost>0)
            semilogy(itr-1:itr,[preCost,cost],'k'); hold on;
            title(sprintf('cost(%d)=%g',itr,cost));
        end

        if(isfield(opt,'trueX'))
            subplot(2,1,2);
            semilogy(itr-1:itr,[preRMSE, RMSE]); hold on;
            title(sprintf('RMSE(%d)=%g',itr,RMSE));
        end
        drawnow;
    end

    if(itr>1 && difX<=opt.thresh )
        convThresh=convThresh+1;
    end

    if(itr >= opt.maxItr || (convThresh>2 && itr>=opt.minItr))
        break;
    end
end
out.x=x; out.itr=itr; out.opt = opt; out.date=datestr(now);
if(opt.outLevel>=2)
    out.grad=grad;
end
if(debug.level(1))
    fprintf('\nCPU Time: %g, objective=%g',toc(tStart),cost);
    if(isfield(opt,'trueX'))
        if(debug.level(2))
            fprintf(', RMSE=%g\n',RMSE);
        else
            fprintf(', RMSE=%g\n',computError(x));
        end
    else
        fprintf('\n');
    end
end

function reset()
    t=min([t;max(stepSizeInit('hessian'))]);
    debug.appendLog('_Reset');
    debug.printWithoutDel(2,'\t reset');
end
function res=runMore()
    res=false;
    if(~proximal.iterative) return; end
    if(innerItr_<opt.maxInnerItr && opt.relInnerThresh>1e-6)
        opt.relInnerThresh=opt.relInnerThresh/10;
        debug.printWithoutDel(2,...
            sprintf('\n decrease relInnerThresh to %g',...
            opt.relInnerThresh));
        res=true;
    elseif(innerItr_>=opt.maxInnerItr &&...
            opt.maxInnerItr<opt.maxPossibleInnerItr)
        opt.maxInnerItr=opt.maxInnerItr*10;
        debug.printWithoutDel(2,...
            sprintf('\n increase maxInnerItr to %g',opt.maxInnerItr));
        res=true;
    end
end

function t=stepSizeInit(select,Lip,delta)
    switch (lower(select))
        case 'bb'   % use BB method to guess the initial stepSize
            if(~exist('delta','var')) delta=1e-5; end
            [~,grad1] = NLL(x);
            temp = delta*grad1/pNorm(grad1);
            temp = x-opt.prj_C(x-temp);
            [~,grad2] = NLL(x-temp);
            t = abs(realInnerProd(grad1-grad2,temp))/sqrNorm(temp);
        case 'hessian'
            [~,grad1,hessian] = NLL(x);
            if(isempty(hessian))
                if(~exist('delta','var')) delta=1e-5; end
                temp = delta*grad1/pNorm(grad1);
                temp = x-opt.prj_C(x-temp);
                [~,grad2] = NLL(x-temp);
                t = abs(realInnerProd(grad1-grad2,temp))/sqrNorm(temp);
            else
                t = hessian(grad1,2)/sqrNorm(grad1);
            end
        case 'fixed'
            t = Lip;
        otherwise
            error('unkown selection for initial step');
    end
    if(isnan(t) || t<=0)
        error('\n PG is having a negative or NaN step size, do nothing and return!!\n');
    end
end

end

function test = majorizationHolds(x_minus_y,fx,fy,dfx,dfy,L)
    % This function tests whether
    %      f(x) ≤ f(y)+(x-y)'*∇f(y)+ 0.5*L*||x-y||^2
    % holds.

    % if(~isempty(dfx) && abs(fx-fy)/max(max(fx,fy),1) < 1e-10)
    %     % In this case, use stronger condition to avoid numerical issue
    %     test=(realInnerProd(x_minus_y,dfx-dfy) <= L*sqrNorm(x_minus_y)/2);
    % else
        test=((fx-fy)<=realInnerProd(x_minus_y,dfy)+L*sqrNorm(x_minus_y)/2);
    % end
end

