function [gp_array, P_TH, Ef, Varf, x, fx] = gp_ina(opt, gp, xx, yy, tx, param, tstindex)
% GP_INA explores the hypeparameters around the mode and returns a
% list of GPs with different hyperparameters and corresponding weights
%
%       Description [GP_ARRAY, P_TH, EF, VARF, X, FX] = GP_INA(OPT,
%       GP, XX, YY, TX, PARAM, TSTINDEX) takes a gp data structure GP
%       with covariates XX and observations YY and returns an array of
%       GPs GP_ARRAY and corresponding weights P_TH. Iff test
%       covariates TX is included, GP_INA also returns corresponding
%       mean EF and variance VARF (FX is PDF evaluated at X). TSTINDEX
%       is for FIC. (will be explained better ...)
%
%       OPT.FMINUNC consists of the options for fminunc
%       OPT.INT_METHOD is the method used for integration
%                      'grid_based' for grid search
%                      'normal' for sampling from gaussian appr
%                      'quasi_mc' for quasi monte carlo samples

% Copyright (c) 2009 Ville Pietil�inen

% This software is distributed under the GNU General Public 
% Licence (version 2 or later); please refer to the file 
% Licence.txt, included with the software, for details.


% ===========================
% Which latent method is used
% ===========================
if isfield(gp, 'latent_method')
    switch gp.latent_method
      case 'EP'
        fh_e = @gpep_e;
        fh_g = @gpep_g;
        fh_p = @ep_pred;
      case 'Laplace'
        fh_e = @gpla_e;
        fh_g = @gpla_g;
        fh_p = @la_pred;
    end
else 
    fh_e = @gp_e;
    fh_g = @gp_g;
    fh_p = @gp_pred;
    
end

if nargin < 6
    param = 'hyper';
end

if ~isfield(opt, 'fminunc')
    opt.fminunc=optimset(opt.fminunc,'GradObj','on');
    opt.fminunc=optimset(opt.fminunc,'LargeScale', 'off');
    opt.fminunc=optimset(opt.fminunc,'Display', 'iter');
end

if ~isfield(opt,'int_method')
    opt.int_method = 'quasi_mc';
end

if ~isfield(opt,'threshold')
    opt.threshold = 2.5;
end

if ~isfield(opt,'step_size')
    opt.stepsize = 1;
end


% ====================================
% Find the mode of the hyperparameters
% ====================================

w0 = gp_pak(gp, param);
% $$$ gradcheck(w0, fh_e, fh_g, gp, xx, yy, param)
mydeal = @(varargin)varargin{1:nargout};

% The mode and hessian at it 
[w,fval,exitflag,output,grad,H] = fminunc(@(ww) mydeal(feval(fh_e,ww, gp, xx, yy, param), feval(fh_g, ww, gp, xx, yy, param)), w0, opt.fminunc);
gp = gp_unpak(gp,w,param);

% Number of parameters
nParam = size(H,1);


switch opt.int_method
  case 'grid_based'
    
    % ===============================
    % New variable z for exploration
    % ===============================

    Sigma = inv(H);
    
    % Some jitter may be needed to get positive semi-definite covariance
    if any(eig(Sigma)<0)
        jitter = 0;
        while any(eig(Sigma)<0)
            jitter = jitter + eye(size(H,1))*0.0001;
            Sigma = Sigma + jitter;
        end
        warning('gp_ina -> singular Hessian. Jitter of %.4f added.', jitter)
    end
    
    [V,D] = eig(full(Sigma));
    z = (V*sqrt(D))';

    % =======================================
    % Exploration of possible hyperparameters
    % =======================================
    
    checked = zeros(1,nParam); % List of locations already visited
    candidates = zeros(1,nParam); % List of locations with enough density
    gp_array={}; % Array of gp-models with different hyperparameters
    Ef_grid = []; % Predicted means with different hyperparameters
    Varf_grid = []; % Variance of predictions with different hyperparameters
    p_th=[]; % List of the weights of different hyperparameters (un-normalized)
    th=[]; % List of hyperparameters
    
    
    % Make the predictions in the mode if needed and estimate the density of the mode
    if exist('tx')
        if exist('tstindex')
            p_th(1) = -feval(fh_e,w,gp,xx,yy,param);
            [Ef_grid(end+1,:), Varf_grid(end+1,:)]=feval(fh_p,gp,xx,yy,tx,param,[],tstindex);
        else   
            p_th(1) = -feval(fh_e,w,gp,xx,yy,param);
            [Ef_grid(end+1,:),Varf_grid(end+1,:)] = feval(fh_p,gp,xx,yy,tx,param);
        end
    else 
        p_th(1) = -feval(fh_e,w,gp,xx,yy,param);
    end
            
    % Put the mode to th-array and gp-model in the mode to gp_array
    th(1,:) = w;
    gp = gp_unpak(gp,w,param);
    gp_array{end+1} = gp;

    
    while ~isempty(candidates) % Repeat until there are no hyperparameters
                               % with enough density that are not
                               % checked yet
        for i1 = 1 : nParam % Loop through the dimensions
            pos = zeros(1,nParam); pos(i1)=1; % One step to the positive direction
                                              % of dimension i1
                                              
            % Check if the neighbour in the direction of pos is already checked
            if ~any(sum(abs(repmat(candidates(1,:)+pos,size(checked,1),1)-checked),2)==0) 
                w_p = w + candidates(1,:)*z + z(i1,:); % The parameters in the neighbour
                %p_th(end+1) = -feval(fh_e,w_p,gp,xx,yy,param);
                th(end+1,:) = w_p; 
                
                gp = gp_unpak(gp,w_p,param);
                gp_array{end+1} = gp;
                
                % Make the predictions (if needed) and save the density of the hyperparameters
                if exist('tx')
                    if exist('tstindex')
                        p_th(end+1) = -feval(fh_e,w_p,gp,xx,yy,param);
                        [Ef_grid(end+1,:), Varf_grid(end+1,:)]=feval(fh_p,gp,xx,yy,tx,param,[],tstindex);
                    else   
                        p_th(end+1) = -feval(fh_e,w_p,gp,xx,yy,param);
                        [Ef_grid(end+1,:),Varf_grid(end+1,:)] = feval(fh_p,gp,xx,yy,tx,param);
                    end
                else
                    p_th(end+1) = -feval(fh_e,w_p,gp,xx,yy,param);
                end
                
                % If the density is large enough, put the location in to the
                % candidates list. The neighbours of that location
                % will be studied lated
                if (p_th(1)-p_th(end))<opt.threshold
                    candidates(end+1,:) = candidates(1,:)+pos;
                end

                % Put the recently studied point to the checked list
                checked(end+1,:) = candidates(1,:)+pos;    
            end
            
            neg = zeros(1,nParam); neg(i1)=-1;
            if ~any(sum(abs(repmat(candidates(1,:)+neg,size(checked,1),1)-checked),2)==0)
                w_n = w + candidates(1,:)*z - z(i1,:);
                %p_th(end+1) = -feval(fh_e,w_n,gp,xx,yy,param);
                th(end+1,:) = w_n;
                
                gp = gp_unpak(gp,w_n,param);
                gp_array{end+1} = gp;
                
                if exist('tx')
                    if exist('tstindex')
                        p_th(end+1) = -feval(fh_e,w_n,gp,xx,yy,param);
                        [Ef_grid(end+1,:), Varf_grid(end+1,:)]=feval(fh_p,gp,xx,yy,tx,param,[],tstindex);
                    else   
                        p_th(end+1) = -feval(fh_e,w_n,gp,xx,yy,param);
                        [Ef_grid(end+1,:),Varf_grid(end+1,:)] = feval(fh_p,gp,xx,yy,tx,param);
                    end
                else
                    p_th(end+1) = -feval(fh_e,w_n,gp,xx,yy,param);
                end
                
                if (p_th(1)-p_th(end))<opt.threshold
                    candidates(end+1,:) = candidates(1,:)+neg;
                end
                checked(end+1,:) = candidates(1,:)+neg;
            end
        end
        candidates(1,:)=[];
    end    
    
    % Convert densities from the log-space and normalize them
    p_th = p_th(:)-min(p_th);
    P_TH = exp(p_th)/sum(exp(p_th));
    

  case 'normal'
    
    % Covariance of the gaussian approximation
    H = full(H);
    Sigma = inv(H);
    
    % Some jitter may be needed to get positive semi-definite covariance
    if any(eig(Sigma)<0)
        jitter = 0;
        while any(eig(Sigma)<0)
            jitter = jitter + eye(size(H,1))*0.0001;
            Sigma = Sigma + jitter;
        end
        warning('gp_ina -> singular Hessian. Jitter of %.4f added.', jitter)
    end
    % Number of samples 
    N = 20;
    
    
    gp_array=cell(N,1);
    th = mvnrnd(w,Sigma,N);
    
    % Densities of the samples in the approximation of the target distribution
    p_th_appr = mvnpdf(th, w, Sigma);
    p_th_appr = p_th_appr/sum(p_th_appr);

    
    % Densities of the samples in target distribution and predictions, if needed.
    for j = 1 : N
        gp_array{j}=gp_unpak(gp,th(j,:),param);
        if exist('tx')
            if exist('tstindex')
                p_th(j) = -feval(fh_e,th(j,:),gp_array{j},xx,yy,param);
                [Ef_grid(j,:), Varf_grid(j,:)]=feval(fh_p,gp_array{j},xx,yy,tx,param,[],tstindex);
            else
                p_th(j) = -feval(fh_e,th(j,:),gp_array{j},xx,yy,param);
                [Ef_grid(j,:),Varf_grid(j,:)] = feval(fh_p,gp_array{j},xx,yy,tx,param);
            end
        else
            p_th(j) = -feval(fh_e,th(j,:),gp_array{j},xx,yy,param);
        end
    end

    p_th = exp(p_th-min(p_th));
    p_th = p_th/sum(p_th);
    
    % Importance weights for the samples
    iw = p_th(:)./p_th_appr(:);
    iw = iw/sum(iw);
    
    % Return the importance weights
    P_TH = iw;
    

  case 'quasi_mc'

    % Covariance of the gaussian approximation
    H = full(H);
    Sigma = inv(H);

    % Some jitter may be needed to get positive semi-definite covariance
    if any(eig(Sigma)<0)
        jitter = 0;
        while any(eig(Sigma)<0)
            jitter = jitter + eye(size(H,1))*0.0001;
            Sigma = Sigma + jitter;
        end
        warning('gp_ina -> singular Hessian. Jitter of %.4f added.', jitter)
    end
    
    % Number of samples
    if ~isfield(opt, 'nsamples')
        N = 20;
    else
        N = opt.nsamples;
    end
    
    gp_array=cell(N,1);
    
    % Quasi MC samples
    th  = repmat(w,N,1)+(chol(Sigma)*(sqrt(2).*erfinv(2.*hammersley(size(Sigma,1),N) - 1)))';

    % Density of the samples in the approximation
    p_th_appr = mvnpdf(th, w, Sigma);
    p_th_appr = p_th_appr/sum(p_th_appr);
    
    % Densities of the samples in target distribution and corresponding predictions, if needed.
    for j = 1 : N
        gp_array{j}=gp_unpak(gp,th(j,:),param);
        if exist('tx')
            if exist('tstindex')
                p_th(j) = -feval(fh_e,th(j,:),gp_array{j},xx,yy,param);
                [Ef_grid(j,:), Varf_grid(j,:)]=feval(fh_p,gp_array{j},xx,yy,tx,param,[],tstindex);
            else
                p_th(j) = -feval(fh_e,th(j,:),gp_array{j},xx,yy,param);
                [Ef_grid(j,:),Varf_grid(j,:)] = feval(fh_p,gp_array{j},xx,yy,tx,param);
            end
        else
            p_th(j) = -feval(fh_e,th(j,:),gp_array{j},xx,yy,param);
        end
    end

    p_th = exp(p_th-min(p_th));
    p_th = p_th/sum(p_th);

    
    % Importance weights for samples
    iw = p_th(:)./p_th_appr(:);
    iw = iw/sum(iw);
    
    % Return importance weights 
    P_TH = iw;


end    

% =================================================================
% If targets are given as imputs, make predictions to those targets
% =================================================================

if exist('tx')
    
    % ====================================================================
    % Grid of 501 points around 10 stds to both directions around the mode
    % ====================================================================
    x = zeros(size(Ef_grid,2),501);
    for j = 1 : size(Ef_grid,2);
        x(j,:) = Ef_grid(1,j)-10*sqrt(Varf_grid(1,j)) : 20*sqrt(Varf_grid(1,j))/500 : Ef_grid(1,j)+10*sqrt(Varf_grid(1,j));  
    end

    % Calculate the density in each grid point by integrating over
    % different models
    fx = zeros(size(Ef_grid,2),501);
    for j = 1 : size(Ef_grid,2)
        fx(j,:) = sum(normpdf(repmat(x(j,:),size(Ef_grid,1),1), repmat(Ef_grid(:,j),1,size(x,2)), repmat(sqrt(Varf_grid(:,j)),1,size(x,2))).*repmat(P_TH,1,size(x,2))); 
    end

    % Normalize distributions
    fx = fx./repmat(sum(fx,2),1,size(fx,2));

    % Widths of each grid point
    dx = diff(x,1,2);
    dx(:,end+1)=dx(:,end);

    % Calculate mean and variance of the disrtibutions
    Ef = sum(x.*fx,2)./sum(fx,2);
    Varf = sum(fx.*(repmat(Ef,1,size(x,2))-x).^2,2)./sum(fx,2);

end

% $$$ if ~exist('idx'), idx=size(th,1)+1; end;
% $$$     
% $$$     Ef_grid(idx:end,:)=[];
% $$$     Varf_grid(idx:end,:)=[];
% $$$     th(idx:end,:)=[];
% $$$     P_TH=exp(p_th-min(p_th))./sum(exp(p_th-min(p_th)));
% $$$     
% $$$     clear PPP PP
% $$$     x = -2.5 : 0.01 : 2.5;
% $$$     px = zeros(size(Ef_grid,2),numel(x));
% $$$     for j = 1 : numel(x);
% $$$         px(:,j)= (sum(normpdf(x(j), Ef_grid, sqrt(Varf_grid)).*repmat(P_TH(:),1,size(Ef_grid,2))))';
% $$$     end
% $$$ 
% $$$     clear diff;
% $$$ 
% $$$     px = px./repmat(sum(px,2),1,size(px,2));
% $$$     PPP = px;
% $$$     dx = diff(repmat(x,size(PPP,1),1),1,2);
% $$$     dx(:,end+1)=dx(:,end);
% $$$ 
% $$$     px = px./repmat(sum(px,2),1,size(px,2));
% $$$ 
% $$$     Ef = sum(repmat(x,size(px,1),1).*PPP,2)./sum(PPP,2);
% $$$     Varf = sum(PPP.*(repmat(Ef,1,size(x,2))-repmat(x,size(Ef,1),1)).^2,2)./sum(PPP,2);
% $$$ 
% $$$     fx = PPP; 

% $$$ % =========================================================
% $$$ % Check potential hyperparameter combinations (to be explained)
% $$$ % =========================================================
% $$$ 
% $$$ % Possible steps from the mode
% $$$ pot_dirs = (unique(nchoosek(repmat(1:steps,1,nParam), nParam),'rows')-floor(steps/2)-1);
% $$$ % Corresponding possible hyperparameters
% $$$ pot = (unique(nchoosek(repmat(1:steps,1,nParam),nParam),'rows')-floor(steps/2)-1)*z+repmat(w,size(pot_dirs,1),1);
% $$$ 
% $$$ if nParam == 2
% $$$     dirs = [1 0 ; 0 1 ; -1 0 ; 0 -1 ; 1 1 ; -1 -1 ; 1 -1 ; -1 1];
% $$$ elseif nParam == 3
% $$$     dirs = [1 0 0 ; 0 1 0 ; 0 0 1 ; -1 0 0 ; 0 -1 0 ; 0 0 -1 ; ...
% $$$             1 1 0 ; 1 0 1 ; 0 1 1 ; 1 -1 0 ; -1 1 0 ; -1 0 1 ; 1 0 -1; ...
% $$$             0 -1 1 ; 0 1 -1; -1 -1 0 ; -1 0 -1 ; 0 -1 -1 ;  1 1 1 ; -1 1 1 ; ...
% $$$             1 -1 1 ; 1 1 -1 ; -1 -1 1 ; -1 1 -1 ; 1 -1 -1 ; -1 -1 -1];
% $$$ end
% $$$ 
% $$$ candidates = w;
% $$$ idx = 1;
% $$$ loc = zeros(1,nParam);
% $$$ ind = zeros(1,nParam);
% $$$ checked=candidates;
% $$$ while ~isempty(candidates)
% $$$     wd = candidates(1,:);
% $$$     th(idx,:) = wd;
% $$$     loc = ind(1,:);
% $$$     
% $$$     pot(all(repmat(loc,size(pot_dirs,1),1)==pot_dirs,2),:)=[];
% $$$     pot_dirs(all(repmat(loc,size(pot_dirs,1),1)==pot_dirs,2),:)=[];
% $$$     
% $$$     gp = gp_unpak(gp,wd,param);
% $$$     gp_array{idx} = gp;
% $$$     
% $$$     p_th(idx) = -feval(fh_e,wd,gp,xx,yy,param);
% $$$     
% $$$     if exist('tx')
% $$$         if exist('tstindex')
% $$$             [Ef_grid(idx,:), Varf_grid(idx,:)]=feval(fh_p,gp,xx,yy,tx,param,[],tstindex);
% $$$         else   
% $$$             [Ef_grid(idx,:),Varf_grid(idx,:)] = feval(fh_p,gp,xx,yy,tx,param);
% $$$         end
% $$$     end
% $$$     
% $$$     
% $$$     [I,II]=sort(sum((repmat(loc,size(pot_dirs,1),1)-pot_dirs).^2,2));
% $$$     neigh = pot(II(1:3^nParam-1),:);
% $$$     
% $$$     for j = 1 : size(neigh,1)
% $$$         tmp = neigh(j,:);
% $$$         if ~any(sum(abs(repmat(tmp,size(checked,1),1)-checked),2)==0),
% $$$             error = -feval(fh_e,tmp,gp,xx,yy,param);
% $$$             if -feval(fh_e,w,gp,xx,yy,param) - error < 2.5, 
% $$$                 candidates(end+1,:) = tmp;
% $$$                 ind(end+1,:) = loc+dirs(j,:);
% $$$             end
% $$$             checked(end+1,:) = tmp;
% $$$         end
% $$$     end    
% $$$     candidates(1,:)=[];
% $$$     idx = idx+1;
% $$$     ind(1,:) = [];
% $$$     if isP,candidates,end
% $$$ end

% $$$     P_TH=ones(N,1)/N;
% $$$     p_th = P_TH;
% $$$     
% $$$     if exist('tx')
% $$$         if exist('tstindex')
% $$$             for j = 1 : N
% $$$                 p_th(j) = -feval(fh_e,th(j,:),gp,xx,yy,param);
% $$$                 [Ef_grid(j,:), Varf_grid(j,:)]=feval(fh_p,gp_array{j},xx,yy,tx,param,[],tstindex);
% $$$             end
% $$$         else
% $$$             for j = 1 : N
% $$$                 p_th(j) = -feval(fh_e,th(j,:),gp,xx,yy,param);
% $$$                 [Ef_grid(j,:),Varf_grid(j,:)] = feval(fh_p,gp_array{j},xx,yy,tx,param);
% $$$             end
% $$$         end
% $$$     else
% $$$         p_th(j) = -feval(fh_e,th(j,:),gp,xx,yy,param);
% $$$     end


% $$$     P_TH=ones(N,1)/N;
% $$$     p_th = P_TH;
% $$$     
% $$$     if exist('tx')
% $$$         if exist('tstindex')
% $$$             for j = 1 : N
% $$$                 if isP, j, end;
% $$$                 [Ef_grid(j,:), Varf_grid(j,:)]=feval(fh_p,gp_array{j},xx,yy,tx,param,[],tstindex);
% $$$             end
% $$$         else
% $$$             for j = 1 : N
% $$$                 if isP, j, end;
% $$$                 [Ef_grid(j,:),Varf_grid(j,:)] = feval(fh_p,gp_array{j},xx,yy,tx,param);
% $$$             end
% $$$         end
% $$$     end

% $$$ % ===================
% $$$     % Positive direction
% $$$     % ===================
% $$$ 
% $$$     for dim = 1 : nParam
% $$$         diffe = 0;
% $$$         iter = 1;
% $$$         while diffe < 2.5
% $$$             diffe = -feval(fh_e,w,gp,xx,yy,param) + feval(fh_e,w+z(dim,:)*iter,gp,xx,yy,param);
% $$$             iter = iter + 1;
% $$$             if isP, diffe, end
% $$$         end
% $$$         delta_pos(dim) = iter;
% $$$     end
% $$$     % ==================
% $$$     % Negative direction
% $$$     % ==================
% $$$ 
% $$$     for dim = 1 : nParam
% $$$         diffe = 0;
% $$$         iter = 1;
% $$$         while diffe < 2.5
% $$$             diffe = -feval(fh_e,w,gp,xx,yy,param) + feval(fh_e,w-z(dim,:)*iter, ...
% $$$                                                           gp,xx,yy,param);
% $$$             iter = iter + 1;
% $$$             if isP, diffe, end
% $$$         end
% $$$         delta_neg(dim) = iter;
% $$$     end
% $$$ 
% $$$ 
% $$$ 
% $$$     for j = 1 : nParam
% $$$         delta{j} = -delta_neg(j):1:delta_pos(j);
% $$$         temp(j) = numel(delta{j});
% $$$     end
% $$$     comb = prod(temp);
% $$$ 
% $$$     steps = max(delta_pos+delta_neg+1);
% $$$     p_th = zeros(comb,1);
% $$$     Ef_grid = zeros(comb, numel(yy));
% $$$     Varf_grid = zeros(comb, numel(yy));
% $$$     th = zeros(comb,nParam);
% $$$     pot_dirs = zeros(comb, nParam);
% $$$     pot = zeros(comb, nParam);
% $$$ 
% $$$     % =========================================================
% $$$     % Check potential hyperparameter combinations (to be explained)
% $$$     % =========================================================
% $$$     idx = ones(1,nParam);
% $$$     stepss = delta_pos+delta_neg+1;
% $$$     ind = 1;
% $$$     while any(idx~=stepss)
% $$$         for j = 1 : nParam
% $$$             pot_dirs(ind,j)=delta{j}(idx(j)); 
% $$$         end
% $$$         
% $$$         ind=ind+1;
% $$$         idx(end)=idx(end)+1;
% $$$         while any(idx>stepss)
% $$$             t = find(idx>stepss);
% $$$             idx(t)=1;
% $$$             idx(t-1)=idx(t-1)+1;
% $$$         end
% $$$     end
% $$$ 
% $$$     for j = 1 : nParam
% $$$         pot_dirs(ind,j)=delta{j}(idx(j)); 
% $$$     end
% $$$ 
% $$$     
% $$$     
% $$$     
% $$$     
% $$$     % Possible steps from the mode
% $$$     % pot_dirs = (unique(nchoosek(repmat(1:steps,1,nParam), nParam),'rows')-floor(steps/2)-1);
% $$$     % Corresponding possible hyperparameters
% $$$     pot = pot_dirs*z+repmat(w,size(pot_dirs,1),1);
% $$$ 
% $$$     candidates = w;
% $$$     idx = 1;
% $$$     candit=[];
% $$$     loc = zeros(1,nParam);
% $$$     ind = zeros(1,nParam);
% $$$     checked=candidates;
% $$$     while ~isempty(candidates)
% $$$         wd = candidates(1,:);
% $$$         th(idx,:) = wd;
% $$$         loc = ind(1,:);
% $$$         
% $$$         pot(all(repmat(loc,size(pot_dirs,1),1)==pot_dirs,2),:)=[];
% $$$         pot_dirs(all(repmat(loc,size(pot_dirs,1),1)==pot_dirs,2),:)=[];
% $$$         
% $$$         gp = gp_unpak(gp,wd,param);
% $$$         gp_array{idx} = gp;
% $$$         
% $$$         p_th(idx) = -feval(fh_e,wd,gp,xx,yy,param);
% $$$         
% $$$         if exist('tx')
% $$$             if exist('tstindex')
% $$$                 [Ef_grid(idx,:), Varf_grid(idx,:)]=feval(fh_p,gp,xx,yy,tx,param,[],tstindex);
% $$$             else   
% $$$                 [Ef_grid(idx,:),Varf_grid(idx,:)] = feval(fh_p,gp,xx,yy,tx,param);
% $$$             end
% $$$         end
% $$$         
% $$$         
% $$$         [I,II]=sort(sum((repmat(loc,size(pot_dirs,1),1)-pot_dirs).^2,2));
% $$$         neigh = pot(II(1:3^nParam-1),:);
% $$$         
% $$$         for j = 1 : size(neigh,1)
% $$$             tmp = neigh(j,:);
% $$$             if ~any(sum(abs(repmat(tmp,size(checked,1),1)-checked),2)==0),
% $$$                 error = -feval(fh_e,tmp,gp,xx,yy,param);
% $$$                 if -feval(fh_e,w,gp,xx,yy,param) - error < 2.5, 
% $$$                     candidates(end+1,:) = tmp;
% $$$                     candit(end+1,:)=tmp;
% $$$                     %ind(end+1,:) = loc+dirs(j,:);
% $$$                     ind(end+1,:) = pot_dirs(II(j),:);
% $$$                 end
% $$$                 checked(end+1,:) = tmp;
% $$$             end
% $$$         end    
% $$$         candidates(1,:)=[];
% $$$         idx = idx+1;
% $$$         ind(1,:) = [];
% $$$         if isP,candidates,end
% $$$     end
% $$$ 
% $$$ 
% $$$     p_th(idx:end)=[];
% $$$     P_TH=exp(p_th-min(p_th))./sum(exp(p_th-min(p_th)));