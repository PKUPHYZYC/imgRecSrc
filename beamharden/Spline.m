classdef Spline < handle
    % Find the case when active set wanders
    properties
        func
        funcz
        funcp
        funcpz
        funcpp
        funcppz
    end 

    methods
        function obj = Spline(sType,kappa)
            % Method help here
            if(nargin>0)
                if(nargin<2)
                    kappa = logspace(log10(0.03),log10(30),100);
                end
                switch lower(sType)
                    case 'dis'
                    case 'b0'
                        syms k s k1 k2
                        obj.func = int(exp(-k*s),k,k1,k2);
                        obj.funcz = subs(diff(obj.func*s,s),s,0);
                        obj.funcp = -diff(obj.func,s);
                        obj.funcpz = subs(diff(simple(obj.funcp*s^2),s,2),s,0)/2;
                        obj.funcpp = diff(obj.func,s,2);
                        obj.funcppz = subs(diff(simple(obj.funcpp*s^3),s,3),s,0)/6;
                    case 'b1'
                end
            end
        end

        function [BL,sBL,ssBL] = iout(ss, I)
            % kappa is a column vector, representing the nodes
            % for b0-spline, length(I)=length(kappa)-1;
            % B-0 spline with nodes be kappa

            if(nargin==0)       % start to test
                kappa = logspace(log10(0.03),log10(30),100);
                s = -0.1:0.001:10;
                [BL, sBL, ssBL] = b0Iout1(kappa,s);
                return;
            end

            kappa = kappa(:); s = s(:);
            idx = find(abs(s)<=eps);
            if(nargin>=3)
                BL = zeros(length(s),1);
            else
                BL = zeros(length(s),length(kappa)-1);
            end
            if(nargout>1) sBL = BL; end
            if(nargout>2) ssBL = BL; end
            expksR = exp(-kappa(1)*s);
            for i=1:length(kappa)-1
                expksL = expksR;
                expksR = exp(-kappa(i+1)*s);
                temp = (expksL-expksR)./s;
                temp(idx) = kappa(i+1)-kappa(i);
                if(nargin>=3) BL = BL + temp*I(i);
                else BL(:,i) = temp; end

                if(nargout>1)
                    temp = ((s*kappa(i)+1).*expksL-(s*kappa(i+1)+1).*expksR)./s./s;
                    temp(idx) = (kappa(i+1)^2-kappa(i)^2)/2;
                    if(nargin>=3) sBL = sBL + temp*I(i);
                    else sBL(:,i) = temp; end
                end
                if(nargout>2)
                    temp = ( ((kappa(i)*s+2)*kappa(i).*s+2).*expksL ...
                        -((kappa(i+1)*s+2)*kappa(i+1).*s + 2).*expksR )./s./s./s;
                    temp(idx) = (kappa(i+1)^3-kappa(i)^3)/3;
                    if(nargin>=3) ssBL = ssBL + temp*I(i);
                    else ssBL(:,i) = temp; end
                end
            end
        end
    end

    methods (Static)
        function num = getEmpNumber
            num = queryDB('LastEmpNumber') + 1;
        end
    end
end
