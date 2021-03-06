
clear;
[Imea,args] = genBeamHarden('showImg',false, 'spark',false);

M = 2^12; % length of the sampled signal;
N = 17; % assume roughly there are at most N components;
L = 32; % the length of the annihalating filter
% The relationship are:
%      M/2 + 1 >= L >= N+1

[s, idx] = sort(args.s);
y = Imea(idx);

sameS = (s(1:end-1)-s(2:end))==0;
s(sameS)=[];
y(sameS)=[];

sm = linspace(s(1), s(end), M)';
ym = interp1( s, y, sm,'spline');
figure; plot(s,y); hold on; plot(sm,ym,'r.');
figure;

for L = 3:33
    A = [];
    for i=1:L-1
        A = [A ym(L-i:M-i)];
    end
    b = -ym(L:M);
    h = A\b;
    r = roots([1; h]);
    plot(r,'o'); title(['L= ' num2str(L)]);
    pause();
end


