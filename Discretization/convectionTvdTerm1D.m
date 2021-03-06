function [M, RHS] = convectionTvdTerm1D(MeshStructure, u, phi, FL)
% This function uses the upwind scheme to discretize a 1D
% convection term in the form \grad (u \phi) where u is a face vactor
% It also returns the x and y parts of the matrix of coefficient.
% 
% SYNOPSIS:
%   
% 
% PARAMETERS:
%   
% 
% RETURNS:
%   
% 
% EXAMPLE:
% 
% SEE ALSO:
%     

%{
Copyright (c) 2012, 2013, Ali Akbar Eftekhari
All rights reserved.

Redistribution and use in source and binary forms, with or 
without modification, are permitted provided that the following 
conditions are met:

    *   Redistributions of source code must retain the above copyright notice, 
        this list of conditions and the following disclaimer.
    *   Redistributions in binary form must reproduce the above 
        copyright notice, this list of conditions and the following 
        disclaimer in the documentation and/or other materials provided 
        with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, 
THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR 
PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR 
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, 
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, 
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, 
OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF 
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING 
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS 
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
%}

% extract data from the mesh structure
G = MeshStructure.numbering;
Nx = MeshStructure.numberofcells;
dx = MeshStructure.cellsize;
RHS = zeros(Nx+2, 1);
psi_p = zeros(Nx+1,1);
psi_m = zeros(Nx+1,1);

% define the vectors to store the sparse matrix data
iix = zeros(3*(Nx+2),1);
jjx = zeros(3*(Nx+2),1);
sx = zeros(3*(Nx+2),1);

% extract the velocity data 
% note: size(ux) = [1:m+1, 1:n] and size(uy) = [1:m, 1:n+1]
ux = u.xvalue;

% calculate the upstream to downstream gradient ratios for u>0 (+ ratio)
% P is 3:Nx+2
% W is 2:Nx+1
% WW is 1:Nx
dphi_p = phi(2:Nx+2)-phi(1:Nx+1);
rp = dphi_p(1:end-1)./fsign(dphi_p(2:end));
psi_p(2:Nx+1) = 0.5*FL(rp).*(phi(3:Nx+2)-phi(2:Nx+1));
psi_p(1) = 0; % left boundary will be handled explicitly

% calculate the upstream to downstream gradient ratios for u<0 (- ratio)
% P is 3:Nx+2
% W is 2:Nx+1
% WW is 1:Nx
rm = dphi_p(2:end)./fsign(dphi_p(1:end-1));
psi_m(1:Nx) = 0.5*FL(rm).*(phi(1:Nx)-phi(2:Nx+1));
psi_m(Nx+1) = 0; % right boundary will be handled explicitly

% reassign the east, west, north, and south velocity vectors for the 
% code readability
ue = ux(2:Nx+1);		uw = ux(1:Nx);

% find the velocity direction for the upwind scheme
ue_min = min(ue,0);	ue_max = max(ue,0);
uw_min = min(uw,0);	uw_max = max(uw,0);

% calculate the TVD correction term
RHS(2:Nx+1) = -(1/dx)*((ue_max.*psi_p(2:Nx+1)+ue_min.*psi_m(2:Nx+1))- ...
              (uw_max.*psi_p(1:Nx)+uw_min.*psi_m(1:Nx)));

% calculate the coefficients for the internal cells
AE = reshape(ue_min/dx,Nx,1);
AW = reshape(-uw_max/dx,Nx,1);
APx = reshape((ue_max-uw_min)/dx,Nx,1);

% correct for the cells next to the boundary
% Left boundary:
APx(1) = APx(1)-uw_max(1)/(2*dx);   AW(1) = AW(1)/2;
% Right boundary:
AE(end) = AE(end)/2;    APx(end) = APx(end) + ue_min(end)/(2*dx);

% build the sparse matrix based on the numbering system
rowx_index = reshape(G(2:Nx+1),Nx,1); % main diagonal x
iix(1:3*Nx) = repmat(rowx_index,3,1);
jjx(1:3*Nx) = [reshape(G(1:Nx),Nx,1); reshape(G(2:Nx+1),Nx,1); reshape(G(3:Nx+2),Nx,1)];
sx(1:3*Nx) = [AW; APx; AE];

% build the sparse matrix
kx = 3*Nx;
M = sparse(iix(1:kx), jjx(1:kx), sx(1:kx), Nx+2, Nx+2);
end

function phi_out = fsign(phi_in)
% This function checks the value of phi_in and assigns an eps value to the
% elements that are less than or equal to zero, while keeping the signs of
% the nonzero elements
    phi_out = (abs(phi_in)>=eps).*phi_in+eps*(phi_in==0)+eps*(abs(phi_in)<eps).*sign(phi_in);
end