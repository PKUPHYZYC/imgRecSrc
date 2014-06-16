classdef FISTA_ADMM_NNL1 < Methods
    properties
        stepShrnk = 0.5;
        preAlpha=0;
        preG=[];
        preY=[];
        thresh=1e-4;
        maxItr=1e3;
        theta = 0;
        admmAbsTol=1e-9;
        admmTol=1e-3;   % abs value should be 1e-8
        cumu=0;
        cumuTol=4;
        grad;

        debug = false;

        restart=0;   % make this value negative to disable restart
    end
    methods
        function obj = FISTA_ADMM_NNL1(n,alpha,maxAlphaSteps,stepShrnk,Psi,Psit)
            fprintf('use FISTA_ADMM_NNL1 method\n');
            obj = obj@Methods(n,alpha);
            obj.maxItr = maxAlphaSteps;
            obj.stepShrnk = stepShrnk;
            obj.Psi = Psi; obj.Psit = Psit;
            obj.preAlpha=alpha;
        end
        % solves l(α) + I(α>=0) + u*||Ψ'*α||_1
        % method No.4 with ADMM inside FISTA for NNL1
        % the order of 2nd and 3rd terms is determined by the ADMM subroutine
        function out = main(obj)
            obj.p = obj.p+1; obj.warned = false;
            if(obj.restart>=0) obj.restart=0; end
            pp=0; opt=[];
            while(pp<obj.maxItr)
                pp=pp+1;
                temp=(1+sqrt(1+4*obj.theta^2))/2;
                y=obj.alpha+(obj.theta -1)/temp*(obj.alpha-obj.preAlpha);
                obj.theta = temp;

                % y=obj.alpha+(obj.p-1)/(obj.p+2)*(obj.alpha-obj.preAlpha);
                % y=obj.alpha;
                obj.preAlpha = obj.alpha;

                % [oldCost,obj.grad] = obj.func(y);
                % obj.t = abs(innerProd(obj.grad-obj.preG, y-obj.preY))/...
                %     sqrNorm(y-obj.preY);
                % obj.preG = obj.grad; obj.preY = y;
                [oldCost,obj.grad] = obj.func(y);

                % start of line Search
                obj.ppp=0;
                while(true)
                    obj.ppp = obj.ppp+1;
                    newX = y - (obj.grad)/(obj.t);
                    % newX = obj.innerADMM_v5(newX,obj.t,obj.u,...
                    %     max(obj.admmTol*obj.difAlpha,obj.admmAbsTol),opt);
                    newX = obj.innerADMM_v5(newX,obj.t,obj.u,...
                        obj.admmTol*obj.difAlpha,opt);
                    newCost=obj.func(newX);
                    if(obj.ppp>20 || newCost<=oldCost+innerProd(obj.grad, newX-y)+sqrNorm(newX-y)*obj.t/2)
                        break;
                    else obj.t=obj.t/obj.stepShrnk;
                    end
                end
                obj.fVal(3) = pNorm(obj.Psit(newX),1);
                temp = newCost+obj.u*obj.fVal(3);

                % restart
                if(obj.restart==0 && (~isempty(obj.cost)) && temp>obj.cost)
                    obj.theta=0; pp=pp-1;
                    obj.restart= 1;
                    opt.oldCost = oldCost; opt.y=y;
                    continue;
                end
                obj.cost = temp;
                obj.stepSize = 1/obj.t;
                obj.difAlpha = relativeDif(obj.alpha,newX);
                obj.alpha = newX;
                if(obj.ppp==1)
                    obj.cumu=obj.cumu+1;
                    if(obj.cumu>=obj.cumuTol)
                        obj.t=obj.t*obj.stepShrnk;
                        obj.cumu=0;
                    end
                else obj.cumu=0;
                end
                %set(0,'CurrentFigure',123);
                %subplot(2,1,1); semilogy(obj.p,newCost,'.'); hold on;
                %subplot(2,1,2); semilogy(obj.p,obj.difAlpha,'.'); hold on;
                if(obj.difAlpha<=obj.thresh) break; end
            end
            out = obj.alpha;
        end
        function alpha = innerADMM_v4(obj,newX,t,u,absTol,opt)
            % solve 0.5*t*||α-α_0||_2 + I(α>=0) + u*||Ψ'*α||_1
            % which is equivalent to 0.5*||α-α_0||_2 + I(α>=0) + u/t*||Ψ'*α||_1
            % α_0 is newX;
            % start an ADMM inside the FISTA
            if(nargin < 6) opt=[]; end
            alpha=newX; Psi_s=alpha; y1=0; rho=1; pppp=0;
            while(true)
                pppp=pppp+1;

                s = Utils.softThresh(obj.Psit(alpha+y1),u/(rho*t));
                temp=Psi_s; Psi_s = obj.Psi(s);
                difPsi_s=relativeDif(temp,Psi_s);

                temp = alpha;
                alpha = (newX+rho*(Psi_s-y1))/(1+rho);
                alpha(alpha<0)=0;
                difAlpha = relativeDif(temp,alpha);

                y1 = y1 - (Psi_s-alpha);

                %set(0,'CurrentFigure',123);
                %semilogy(pppp,difAlpha,'r.',pppp,difPsi_s,'g.'); hold on;
                %drawnow;

                if(pppp>1e4) keyboard; end

                if(difAlpha<=absTol && difPsi_s<=absTol)
                    if(isempty(opt)) break;
                    else
                        newCost=obj.func(p);
                        if(newCost<=opt.oldCost+innerProd(obj.grad, p-opt.y)+sqrNorm(p-opt.y)*obj.t/2)
                            temp = newCost+obj.u*pNorm(obj.Psit(p),1);
                            if(temp<obj.cost) break; else continue; end
                        else
                            break;
                        end
                    end
                end
            end
            % end of the ADMM inside the FISTA
        end
        function p = innerADMM_v5(obj,newX,t,u,absTol,opt)
            % solve 0.5*t*||α-α_0||_2 + u*||Ψ'*α||_1 + I(α>=0) 
            % which is equivalent to 0.5*||α-α_0||_2 + u/t*||Ψ'*α||_1 + I(α>=0) 
            % α_0 is newX;
            % start an ADMM inside the FISTA
            if(nargin < 6) opt=[]; end
            alpha=newX; p=alpha; p(p<0)=0; y1=alpha-p;
            rho=1; pppp=0;
            %if(obj.debug) absTol=1e-16; end
            %while(pppp<1)
            while(true)
                pppp=pppp+1;
                temp = alpha;
                alpha = (newX+rho*(p-y1));
                alpha = obj.Psi(Utils.softThresh(obj.Psit(alpha),u/t))/(1+rho);
                difAlpha = relativeDif(temp,alpha);

                temp=p; p=alpha+y1; p(p<0)=0;
                difP=relativeDif(temp,p);

                y1 = y1 +alpha-p;

                if(obj.debug)
                    da(pppp)=difAlpha;
                    dp(pppp)=difP;
                    dap(pppp)=pNorm(alpha-p);
                    ny(pppp) = pNorm(y1);
                    co(pppp) = 0.5*sqrNorm(newX-p)+u/t*pNorm(obj.Psit(p),1);
                end

                if(pppp>1e5) keyboard; end

                if(difAlpha<=absTol && difP<=absTol)
                    if(isempty(opt)) break;
                    else
                        newCost=obj.func(p);
                        if(newCost<=opt.oldCost+innerProd(obj.grad, p-opt.y)+sqrNorm(p-opt.y)*obj.t/2)
                            temp = newCost+obj.u*pNorm(obj.Psit(p),1);
                            if(temp<obj.cost) break; else continue; end
                        else
                            break;
                        end
                    end
                end
            end
            if(obj.debug && false)
                semilogy(da,'r'); hold on;
                semilogy(dp,'g'); semilogy(dap,'b'); semilogy(ny,'k');
                semilogy(co,'c');
            end
            % end of the ADMM inside the FISTA
        end
        function newX = innerProjection2(obj,newX,t,u)
            s=obj.Psit(newX);
            s=Utils.softThresh(s,u/t);
            newX=obj.Psi(s);
            newX(newX<0)=0;
        end
        function co = evaluate(obj,newX,x)
            co=sqrNorm(newX-x)/2*obj.t;
            co=co+obj.u*pNorm(obj.Psit(x),1);
            if(any(x<0)) co=inf; end
        end
    end
end

