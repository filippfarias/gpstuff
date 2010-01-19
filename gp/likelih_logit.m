function likelih = likelih_logit(do, varargin)
%likelih_logit	Create a Logit likelihood structure for Gaussian Process
%
%	Description
%
%	LIKELIH = LIKELIH_LOGIT('INIT', Y) Create and initialize Logit likelihood. 
%       The input argument Y contains class labels {0,1}.
%
%	The fields in LIKELIH are:
%	  type                     = 'likelih_logit'
%         likelih.fh_pak           = function handle to pak
%         likelih.fh_unpak         = function handle to unpak
%         likelih.fh_permute       = function handle to permutation
%         likelih.fh_e             = function handle to energy of likelihood
%         likelih.fh_g             = function handle to gradient of energy
%         likelih.fh_g2            = function handle to second derivatives of energy
%         likelih.fh_g3            = function handle to third (diagonal) gradient of energy 
%         likelih.fh_tiltedMoments = function handle to evaluate tilted moments for EP
%         likelih.fh_mcmc          = function handle to MCMC sampling of latent values
%         likelih.fh_predy         = function handle to evaluate predictive density of y
%         likelih.fh_recappend     = function handle to record append
%
%	LIKELIH = LIKELIH_LOGIT('SET', LIKELIH, 'FIELD1', VALUE1, 'FIELD2', VALUE2, ...)
%       Set the values of fields FIELD1... to the values VALUE1... in LIKELIH.
%
%	See also
%       LIKELIH_POISSON, LIKELIH_PROBIT, LIKELIH_NEGBIN


%       Copyright (c) 1998-2000 Aki Vehtari
%       Copyright (c) 2008 Jarno Vanhatalo

% This software is distributed under the GNU General Public
% License (version 2 or later); please refer to the file
% License.txt, included with the software, for details.

    if nargin < 2
        error('Not enough arguments')
    end

    % Initialize the covariance function
    if strcmp(do, 'init')
        likelih.type = 'logit';
        y = varargin{1};
        if ~isempty(find(y~=1 & y~=-1))
            error('The class labels have to be {-1,1}')
        end
        likelih.t = (y+1)/2;
        
        % Set the function handles to the nested functions
        likelih.fh_pak = @likelih_logit_pak;
        likelih.fh_unpak = @likelih_logit_unpak;
        likelih.fh_permute = @likelih_logit_permute;
        likelih.fh_e = @likelih_logit_e;
        likelih.fh_g = @likelih_logit_g;    
        likelih.fh_g2 = @likelih_logit_g2;
        likelih.fh_g3 = @likelih_logit_g3;
        likelih.fh_tiltedMoments = @likelih_logit_tiltedMoments;
        likelih.fh_mcmc = @likelih_logit_mcmc;
        likelih.fh_predy = @likelih_logit_predy;
        likelih.fh_recappend = @likelih_logit_recappend;

        if length(varargin) > 2
            if mod(nargin,2) ~=1
                error('Wrong number of arguments')
            end
            % Loop through all the parameter values that are changed
            for i=2:2:length(varargin)-1
                switch varargin{i}
                  otherwise
                    error('Wrong parameter name!')
                end
            end
        end
    end

    % Set the parameter values of covariance function
    if strcmp(do, 'set')
        if mod(nargin,2) ~=0
            error('Wrong number of arguments')
        end
        gpcf = varargin{1};
        % Loop through all the parameter values that are changed
        for i=2:2:length(varargin)-1
            switch varargin{i}
              otherwise
                error('Wrong parameter name!')
            end
        end
    end



    function w = likelih_logit_pak(likelih, w)
    %LIKELIH_LOGIT_PAK      Combine likelihood parameters into one vector.
    %
    %   NOT IMPLEMENTED!
    %
    %	Description
    %	W = LIKELIH_LOGIT_PAK(GPCF, W) takes a likelihood data structure LIKELIH and
    %	combines the parameters into a single row vector W.
    %	  
    %
    %	See also
    %	LIKELIH_LOGIT_UNPAK
    end


    function w = likelih_logit_unpak(likelih, w)
    %LIKELIH_LOGIT_UNPAK      Combine likelihood parameters into one vector.
    %
    %   NOT IMPLEMENTED!
    %
    %	Description
    %	W = LIKELIH_LOGIT_UNPAK(GPCF, W) takes a likelihood data structure LIKELIH and
    %	combines the parameter vector W and sets the parameters in LIKELIH.
    %	  
    %
    %	See also
    %	LIKELIH_LOGIT_PAK
    end



    function likelih = likelih_logit_permute(likelih, p)
    %LIKELIH_LOGIT_PERMUTE    A function to permute the ordering of parameters 
    %                           in likelihood structure
    %   
    %   NOT IMPLEMENTED!
    %
    %   Description
    %	LIKELIH = LIKELIH_LOGIT_UNPAK(LIKELIH, P) takes a likelihood data structure
    %   LIKELIH and permutation vector P and returns LIKELIH with its parameters permuted
    %   according to P.
    %
    %   See also 
    %   GPLA_E, GPLA_G, GPEP_E, GPEP_G with CS+FIC model
    end


    function logLikelih = likelih_logit_e(likelih, y, f)
    %LIKELIH_LOGIT_E    (Likelihood) Energy function
    %
    %   
    %   NOT IMPLEMENTED!
    %
    %   Description
    %   E = LIKELIH_LOGIT_E(LIKELIH, Y, F) takes a likelihood data structure
    %   LIKELIH, incedence counts Y and latent values F and returns the log likelihood.
    %
    %   See also
    %   LIKELIH_LOGIT_G, LIKELIH_LOGIT_G3, LIKELIH_LOGIT_G2, GPLA_E

        logLikelih = sum(-log(1+exp(-y.*f)));
    end


    function deriv = likelih_logit_g(likelih, y, f, param)
    %LIKELIH_LOGIT_G    Gradient of (likelihood) energy function
    %
    %   
    %   NOT IMPLEMENTED!
    %
    %   Description
    %   G = LIKELIH_LOGIT_G(LIKELIH, Y, F, PARAM) takes a likelihood data structure
    %   LIKELIH, incedence counts Y and latent values F and returns the gradient of 
    %   log likelihood with respect to PARAM. At the moment PARAM can be only 'latent'.
    %
    %   See also
    %   LIKELIH_LOGIT_E, LIKELIH_LOGIT_G2, LIKELIH_LOGIT_G3, GPLA_E
        
        t  = likelih.t;
        PI = 1./(1+exp(-f));
        deriv = t - PI;
        %deriv = (y+1)/2 - 1./(1+exp(-f));      
    end


    function g2 = likelih_logit_g2(likelih, y, f, param)
    %LIKELIH_LOGIT_G2    Third gradients of (likelihood) energy function
    %
    %   
    %   NOT IMPLEMENTED!
    %
    %   Description
    %   G2 = LIKELIH_LOGIT_G2(LIKELIH, Y, F, PARAM) takes a likelihood data 
    %   structure LIKELIH, incedence counts Y and latent values F and returns the 
    %   hessian of log likelihood with respect to PARAM. At the moment PARAM can 
    %   be only 'latent'. HESSIAN is a vector with diagonal elements of the hessian 
    %   matrix (off diagonals are zero).
    %
    %   See also
    %   LIKELIH_LOGIT_E, LIKELIH_LOGIT_G, LIKELIH_LOGIT_G3, GPLA_E
        PI = 1./(1+exp(-f));
        g2 = -PI.*(1-PI);        
    end    
    
    function third_grad = likelih_logit_g3(likelih, y, f, param)
    %LIKELIH_LOGIT_G3    Gradient of (likelihood) Energy function
    %
    %   
    %   NOT IMPLEMENTED!
    %
    %   Description
    %   G3 = LIKELIH_LOGIT_G3(LIKELIH, Y, F, PARAM) takes a likelihood data 
    %   structure LIKELIH, incedence counts Y and latent values F and returns the 
    %   third gradients of log likelihood with respect to PARAM. At the moment PARAM can 
    %   be only 'latent'. G3 is a vector with third gradients.
    %
    %   See also
    %   LIKELIH_LOGIT_E, LIKELIH_LOGIT_G, LIKELIH_LOGIT_G2, GPLA_E, GPLA_G
        t  = (y+1)/2;
        PI = 1./(1+exp(-f));
        third_grad = -PI.*(1-PI).*(1-2*PI);        
    end


    function [m_0, m_1, sigm2hati1] = likelih_logit_tiltedMoments(likelih, y, i1, sigm2_i, myy_i)
    %LIKELIH_LOGIT_TILTEDMOMENTS    Returns the moments of the tilted distribution
    %
    %   Description
    %   [M_0, M_1, M2] = LIKELIH_LOGIT_TILTEDMOMENTS(LIKELIH, Y, I, S2, MYY) takes a 
    %   likelihood data structure LIKELIH, incedence counts Y, index I and cavity variance 
    %   S2 and mean MYY. Returns the zeroth moment M_0, firtst moment M_1 and second moment 
    %   M_2 of the tilted distribution
    %
    %   See also
    %   GPEP_E
       
        yy = y(i1);
        % Create function handle for the function to be integrated (likelihood * cavity). 
        zm = @(f)exp(-log(1+exp(-yy.*f)) - 0.5 * (f-myy_i).^2./sigm2_i - log(sigm2_i)/2 - log(2*pi)/2); 
        
        % Set the integration limits (in this case based only on the prior).
        mean_app = myy_i;
        sigm_app = sqrt(sigm2_i);
        
        lambdaconf(1) = mean_app - 6.*sigm_app; lambdaconf(2) = mean_app + 6.*sigm_app;
        test1 = zm((lambdaconf(2)+lambdaconf(1))/2)>zm(lambdaconf(1));
        test2 = zm((lambdaconf(2)+lambdaconf(1))/2)>zm(lambdaconf(2));
        testiter = 1;
        if test1 == 0 
            lambdaconf(1) = lambdaconf(1) - 3*sigm_app;
            test1 = zm((lambdaconf(2)+lambdaconf(1))/2)>zm(lambdaconf(1));
            if test1 == 0
                go=true;
                while testiter<10 & go
                    lambdaconf(1) = lambdaconf(1) - 2*sigm_app;
                    lambdaconf(2) = lambdaconf(2) - 2*sigm_app;
                    test1 = zm((lambdaconf(2)+lambdaconf(1))/2)>zm(lambdaconf(1));
                    test2 = zm((lambdaconf(2)+lambdaconf(1))/2)>zm(lambdaconf(2));
                    if test1==1&test2==1
                        go=false;
                    end
                    testiter=testiter+1;
                end
            end
            mean_app = (lambdaconf(2)+lambdaconf(1))/2;
        elseif test2 == 0
            lambdaconf(2) = lambdaconf(2) + 3*sigm_app;
            test2 = zm((lambdaconf(2)+lambdaconf(1))/2)>zm(lambdaconf(2));
            if test2 == 0
                go=true;
                while testiter<10 & go
                    lambdaconf(1) = lambdaconf(1) + 2*sigm_app;
                    lambdaconf(2) = lambdaconf(2) + 2*sigm_app;
                    test1 = zm((lambdaconf(2)+lambdaconf(1))/2)>zm(lambdaconf(1));
                    test2 = zm((lambdaconf(2)+lambdaconf(1))/2)>zm(lambdaconf(2));
                    if test1==1&test2==1
                        go=false;
                    end
                    testiter=testiter+1;
                end
            end
            mean_app = (lambdaconf(2)+lambdaconf(1))/2;
        end  
        RTOL = 1.e-6;
        ATOL = 1.e-10;
                        
        % Integrate with quadrature
        [m_0, m_1, m_2] = quad_moments(zm,lambdaconf(1), lambdaconf(2), RTOL, ATOL);        
        
        sigm2hati1 = m_2 - m_1.^2;
                
        % If the second central moment is less than cavity variance integrate more
        % precisely. Theoretically should be sigm2hati1 < sigm2_i.
        if sigm2hati1 >= sigm2_i
            ATOL = ATOL.^2;
            RTOL = RTOL.^2;
            [m_0, m_1, m_2] = moments(zm, lambdaconf(1), lambdaconf(2), RTOL, ATOL);
            sigm2hati1 = m_2 - m_1.^2;
            if sigm2hati1 >= sigm2_i
                error('likelih_logit_tilted_moments: sigm2hati1 >= sigm2_i');
            end
        end
    end
        

    function [z, energ, diagn] = likelih_logit_mcmc(z, opt, varargin)
    %LIKELIH_LOGIT_MCMC        Conducts the MCMC sampling of latent values
    %
    %   Description
    %   [F, ENERG, DIAG] = LIKELIH_LOGIT_MCMC(F, OPT, GP, X, Y) takes the current latent 
    %   values F, options structure OPT, Gaussian process data structure GP, inputs X and
    %   incedence counts Y. Samples new latent values and returns also energies ENERG and 
    %   diagnostics DIAG. 
    % 
    %   See Neal (1996) for the technical discussion of the sampler.
    %
    %   See also
    %   GP_MC

        gp = varargin{1};
        p = varargin{2};
        t = varargin{3};
        
        switch gp.type
          case 'FULL'            
            maxcut = -log(eps);
            mincut = -log(1/realmin - 1);
            lvs=opt.sample_latent_scale;
            a = max(min(z, maxcut),mincut);
            [K,C]=gp_trcov(gp, p);
            L=chol(C)';
            n=length(t);
            likelih_e = @logistic;
            e = feval(likelih_e, gp, z, t);
            
            % Adaptive control algorithm to find such a value for lvs 
            % that the rejection rate of Metropolis is optimal. 
            slrej = 0;
            for li=1:100
                zt=sqrt(1-lvs.^2).*z+lvs.*L*randn(n,1);
                at = max(min(zt, maxcut),mincut);
                ed = feval(likelih_e, gp, zt, t);
                a=e-ed;
                if exp(a) > rand(1)
                    z=zt;
                    e=ed;
                    lvs=min(1,lvs*1.1);
                else
                    lvs=max(1e-8,lvs/1.05);
                end
            end
            opt.sample_latent_scale=lvs;
            % Do the actual sampling 
            for li=1:(opt.repeat)
                zt=sqrt(1-lvs.^2).*z+lvs.*L*randn(n,1);
                at = max(min(zt, maxcut),mincut);
                ed = feval(likelih_e, gp, zt, t);
                a=e-ed;
                if exp(a) > rand(1)
                    z=zt;
                    e=ed;
                else
                    slrej=slrej+1;
                end
            end
            diagn.rej = slrej/opt.repeat;
            diagn.lvs = lvs;
            diagn.opt=opt;
            energ=[];
            z = z';
          case {'FIC', 'PIC', 'CS+FIC'}
            error('likelih_logit: MCMC sampler implemented only for full GP!')
        end


        function e = logistic(gp, z, t)
        % LH_2CLASS     Minus log likelihood function for 2 class classification.
        %               A logistic likelihod
        %
        %       E = H_LOGIT(GP, P, T, Z) takes.... and returns minus log from 
            
        % If class prior is defined use it
            if isfield(gp,'classprior');
                cp=gp.classprior;     % THIS IS NOT YET IMPLEMENTED
            else
                cp=1;
            end
            
% $$$             y = 1./(1 + exp(-z));
% $$$             e = -sum(sum(cp.*t.*log(y) + (1 - t).*log(1 - y)));
            e = sum(1 + exp(-y.*z));
        end

    end 
    
    function [Ey, Vary, py] = likelih_logit_predy(gp, Ef, Varf, y)
    % Return the predictive probability of ty given the posterior mean Ef 
    % and variance Varf
        py1 = zeros(1,length(Ef));
        for i1=1:length(Ef)
            ci = sqrt(Varf(i1));
            F  = @(x)1./(1+exp(-x)).*normpdf(x,Ef(i1),sqrt(Varf(i1)));
            py1(i1) = quadgk(F,Ef(i1)-6*ci,Ef(i1)+6*ci);                             
        end
        Ey = 2*py1-1;
        Vary = 1-(2*py1-1).^2;        
        if nargin > 3
            % NOTE: This is only approximation since \int logit(y|f) N(f|Ef,Varf) df
            % has no analytic solution.
            
            % Quadrature integration                                    
            py = zeros(1,length(Ef));
            for i1 = 1:length(Ef)
                ci = sqrt(Varf(i1));
                F = @(x)1./(1+exp(-y(i1).*x)).*normpdf(x,Ef(i1),sqrt(Varf(i1)));
                py(i1,1)=quadgk(F,Ef(i1)-6*ci,Ef(i1)+6*ci);                     
            end
            
            % Monte Carlo alternative
            % for i = 1:length(Ef)
            %     samp = normrnd(Ef(i1),sqrt(Varf(i1)),10000,1);
            %     p1(i1,1) = mean(1./(1+exp(-samp)));           
            % end    
            end
        end
    end

    
    function reclikelih = likelih_logit_recappend(reclikelih, ri, likelih)
    % RECAPPEND - Record append
    %          Description
    %          RECCF = GPCF_SEXP_RECAPPEND(RECCF, RI, GPCF) takes old covariance
    %          function record RECCF, record index RI, RECAPPEND returns a
    %          structure RECCF containing following record fields:
    %          lengthHyper    =
    %          lengthHyperNu  =
    %          lengthScale    =
    %          magnSigma2     =


    end
end


