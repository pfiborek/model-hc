function [shapeFunction_P,ownerElement,w_p,expNodes] = ...
    spectral2meshgrid(Eps, n_x,n_y,nodeCoordinates_main,elementNodes_main,...
    nodeCoordinates_interface,alpha_rot,case_name)
% Eps = 1e-5;, n_x = 6; n_y = 6; 
% nodeCoordinates_main = nodeCoordinates_k1; elementNodes_main = elementNodes_k1; 
% nodeCoordinates_interface = nodeCoordinates_interface; 
% alpha_rot = structure(k2).rotation_angle;
x_p = nodeCoordinates_interface(:,1);
y_p = nodeCoordinates_interface(:,2);
z_p = nodeCoordinates_interface(:,3);
 


ownerElement = findOwnerElement(x_p,y_p,z_p,nodeCoordinates_main,elementNodes_main,...
    n_x,n_y,case_name);

expNodes =[];
if any(ownerElement==0)
    xx = repmat(nodeCoordinates_main(:,1)',length(find(ownerElement==0)),1);
    yy = repmat(nodeCoordinates_main(:,2)',length(find(ownerElement==0)),1);
    zz = repmat(nodeCoordinates_main(:,3)',length(find(ownerElement==0)),1);
    [valPoint,point_no] = min(sqrt(bsxfun(@minus, x_p(ownerElement==0),xx).^2 + ...
        bsxfun(@minus, y_p(ownerElement==0),yy).^2+ ...
        bsxfun(@minus, z_p(ownerElement==0),zz).^2),[],2);
    aa = find(ownerElement==0);
    expNodes = aa(valPoint>=Eps);
    nrNodes = aa(valPoint<Eps);
    point_no = point_no(valPoint<Eps);
    xx = zeros(length(nrNodes),1);
    for ii = 1: length(nrNodes)
        [row,~] = find(elementNodes_main==point_no(ii));
        xx(ii) = row(1); 
    end
    ownerElement(nrNodes) = xx;
    ownerElement(expNodes) = [];
    x_p(expNodes) = [];
    y_p(expNodes) = [];
end



if n_y>1
    [ksi,wi_x]=gll(n_x);
    [eta,wi_y]=gll(n_y);

    [Ksi, Eta] = meshgrid(ksi,eta);
    Ksi = repmat(reshape(Ksi',1,[]),length(x_p),1);
    Eta = repmat(reshape(Eta',1,[]),length(x_p),1);

    elementNodes_owner = elementNodes_main(ownerElement,:);
    x_0 = nodeCoordinates_main(elementNodes_owner,1);
    x_0 = reshape(x_0,[],n_x*n_y);
    y_0 = nodeCoordinates_main(elementNodes_owner,2);
    y_0 = reshape(y_0,[],n_x*n_y);

    [~,point_no] = min(sqrt(bsxfun(@minus, x_p,x_0).^2+bsxfun(@minus, y_p,y_0).^2),[],2);
    x_0 = x_0(sub2ind(size(x_0),(1:length(point_no))',point_no));
    y_0 = y_0(sub2ind(size(y_0),(1:length(point_no))',point_no));
    x_0((sqrt((x_p - x_0).^2 + (y_p - y_0).^2))<Eps) = x_p((sqrt((x_p - x_0).^2 + (y_p - y_0).^2))<Eps);
    y_0((sqrt((x_p - x_0).^2 + (y_p - y_0).^2))<Eps) = y_p((sqrt((x_p - x_0).^2 + (y_p - y_0).^2))<Eps);
    
    ksi_0 = Ksi(sub2ind(size(Ksi),ones(length(point_no),1),point_no));
    eta_0 = Eta(sub2ind(size(Eta),ones(length(point_no),1),point_no));

    n1 = (ownerElement-1)*n_x*n_y + point_no;
    [~,Jacob_P11inv,Jacob_P12inv,Jacob_P21inv,Jacob_P22inv,~,~,~,~,~,~,...
        ~,~,~,~] = Jacob_NbN(5,n_x,n_y,1,elementNodes_main,nodeCoordinates_main,[]);
    ksi_p = ksi_0 + Jacob_P11inv(n1).*(x_p - x_0) + Jacob_P21inv(n1).*(y_p - y_0);
    eta_p = eta_0 + Jacob_P12inv(n1).*(x_p - x_0) + Jacob_P22inv(n1).*(y_p - y_0);
    [ksi_i,~] = gll(n_x);
    [eta_i,~] = gll(n_y);
    [Q_ksi] = Vandermonde_v2(ksi_i,n_x);
    [Q_eta] = Vandermonde_v2(eta_i,n_y);

    [shapeFunction_P,~,~] = shapeFunction_2D(Q_ksi,Q_eta,ksi_p,eta_p,'s');
    % coordinates of element nodes
    nodes_order = reshape(elementNodes_owner',[],1);

    x_e = nodeCoordinates_main(nodes_order,1);
    y_e = nodeCoordinates_main(nodes_order,2);
    
    x_k = shapeFunction_P*x_e;% interpolated values
    y_k = shapeFunction_P*y_e;% interpolated values

    A = (sqrt((x_p-x_k).^2+(y_p-y_k).^2));
    k=0;
    while any(A > Eps)
    
        ksi_0(A > Eps) = ksi_p(A > Eps);
        eta_0(A > Eps) = eta_p(A > Eps);
        x_0(A > Eps) = x_k(A > Eps);
        y_0(A > Eps) = y_k(A > Eps);
        % shape function derivatives
        [~,naturalDerivativesX_P,naturalDerivativesY_P] = ...
            shapeFunction_2D(Q_ksi,Q_eta,ksi_0,eta_0,'d');

        % jacobians
        J11 = naturalDerivativesX_P*x_e;
        J12 = naturalDerivativesX_P*y_e;
        J21 = naturalDerivativesY_P*x_e;
        J22 = naturalDerivativesY_P*y_e;
        [Jacob_P11inv,Jacob_P12inv,Jacob_P21inv,Jacob_P22inv] =...
            Jacob_inv(J11,J12,J21,J22);
        % next iteration
        ksi_p(A > Eps) = ksi_0(A > Eps) + Jacob_P11inv(A > Eps).*(x_p(A > Eps)-x_0(A > Eps)) + ...
            Jacob_P21inv(A > Eps).*(y_p(A > Eps)-y_0(A > Eps));
        eta_p(A > Eps) = eta_0(A > Eps) + Jacob_P12inv(A > Eps).*(x_p(A > Eps)-x_0(A > Eps)) + ...
            Jacob_P22inv(A > Eps).*(y_p(A > Eps)-y_0(A > Eps));
    
        [shapeFunction_P,~,~] = shapeFunction_2D(Q_ksi,Q_eta,ksi_p,eta_p,'s');
        x_k = shapeFunction_P*x_e;% interpolated values
        y_k = shapeFunction_P*y_e;% interpolated values
    
        A = (sqrt((x_p-x_k).^2+(y_p-y_k).^2));
        clc;    k = k +1; disp(k); disp([length(A(A > Eps)) max(A(A > Eps))/Eps]);
    end
    disp([min(A) max(A)]/Eps)
    [~,naturalDerivativesX_P,naturalDerivativesY_P] = ...
        shapeFunction_2D(Q_ksi,Q_eta,ksi_p,eta_p,'d');
    J11 = naturalDerivativesX_P*x_e;
    J12 = naturalDerivativesX_P*y_e;
    J21 = naturalDerivativesY_P*x_e;
    J22 = naturalDerivativesY_P*y_e;
    det_J = round((J11.*J22-J12.*J21)*1e8)*1e-8;
    w_p = kron(wi_y,wi_x);
    w_p = repmat(w_p,length(x_p),1);
    w_p = w_p(sub2ind(size(w_p),ones(length(point_no),1),point_no)).*det_J;
elseif n_y==1
   
    [ksi,wi_x]=gll(n_x);
    
    Ksi = repmat(ksi,length(x_p),1);
    elementNodes_owner = elementNodes_main(ownerElement,:);
    x_0 = nodeCoordinates_main(elementNodes_owner,1);
    x_0 = reshape(x_0,[],n_x);
    y_0 = nodeCoordinates_main(elementNodes_owner,2);
    y_0 = reshape(y_0,[],n_x);
    
    [~,point_no] = min(sqrt(bsxfun(@minus, x_p,x_0).^2+bsxfun(@minus, y_p,y_0).^2),[],2);
    x_0 = x_0(sub2ind(size(x_0),(1:length(point_no))',point_no));
    y_0 = y_0(sub2ind(size(y_0),(1:length(point_no))',point_no));

    ksi_0 = Ksi(sub2ind(size(Ksi),ones(length(point_no),1),point_no));
    %%%%%%%%%%%%%%%%%%%%%%%%%
    if ~isempty(alpha_rot)
            alpha = num2cell(alpha_rot(ownerElement,1));
            beta = num2cell(alpha_rot(ownerElement,2));
            gamma = num2cell(alpha_rot(ownerElement,3));
            nC = cellfun(@(x) nodeCoordinates_main(x,:),num2cell(elementNodes_owner,2), 'uni',0);
            e_nodesTrans = cellfun(@(x) x(1,:),nC, 'uni',0);
            XYZ_0 = [x_0,y_0 z_p];
            XYZ_0 = cellfun(@(x,y) bsxfun(@minus, x,y),num2cell(XYZ_0,2), e_nodesTrans, 'uni',0);
            R_xyz = cellfun(@global2local, alpha, beta, gamma, 'uni',0);
            XYZ_0 = cellfun(@(x,y) transpose(round(x*y'*1e6)*1e-6), R_xyz,XYZ_0, 'uni',0);
            XYZ_0 = cell2mat(cellfun(@(x,y) bsxfun(@plus, x,y),XYZ_0,e_nodesTrans, 'uni',0));
            X_0 = XYZ_0(:,1);
            Y_0 = XYZ_0(:,2);
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%
    
    %%%%%%%%%%%%%%%%%%%%%%%%%
    if ~isempty(alpha_rot)
            alpha = num2cell(alpha_rot(ownerElement,1));
            beta = num2cell(alpha_rot(ownerElement,2));
            gamma = num2cell(alpha_rot(ownerElement,3));
            nC = cellfun(@(x) nodeCoordinates_main(x,:),num2cell(elementNodes_owner,2), 'uni',0);
            e_nodesTrans = cellfun(@(x) x(1,:),nC, 'uni',0);
            XYZ_P = [x_p,y_p, z_p];
            XYZ_P = cellfun(@(x,y) bsxfun(@minus, x,y),num2cell(XYZ_P,2), e_nodesTrans, 'uni',0);
            R_xyz = cellfun(@global2local, alpha, beta, gamma, 'uni',0);
            XYZ_P = cellfun(@(x,y) transpose(round(x*y'*1e6)*1e-6), R_xyz,XYZ_P, 'uni',0);
            XYZ_P = cell2mat(cellfun(@(x,y) bsxfun(@plus, x,y),XYZ_P,e_nodesTrans, 'uni',0));
            X_P = XYZ_P(:,1);
            Y_P = XYZ_P(:,2);
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%
    
    
    
    n1 = (ownerElement-1)*n_x + point_no;
    [~,Jacob_P11inv,~,~,~,~,~,~,~,~,~,~,~,~,~] = ...
        Jacob_NbN(1,n_x,1,1,elementNodes_main,nodeCoordinates_main,alpha_rot);
    ksi_p = ksi_0 + Jacob_P11inv(n1).*(X_P-X_0);
    
    [ksi_i,~] = gll(n_x);
    [Q_ksi] = Vandermonde_v2(ksi_i,n_x);
    
    [shapeFunction_P,~] = shapeFunction_1D(Q_ksi,ksi_p,'s');
    % coordinates of element nodes
    nodes_order = reshape(elementNodes_owner',[],1);

    x_e = nodeCoordinates_main(nodes_order,1);
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%
    if ~isempty(alpha_rot)
            alpha = num2cell(alpha_rot(ownerElement,1));
            beta = num2cell(alpha_rot(ownerElement,2));
            gamma = num2cell(alpha_rot(ownerElement,3));
            nC = cellfun(@(x) nodeCoordinates_main(x,:),num2cell(elementNodes_owner,2), 'uni',0);
            e_nodesTrans = cellfun(@(x) x(1,:),nC, 'uni',0);
            nC = cellfun(@(x,y) bsxfun(@minus, x,y),nC, e_nodesTrans, 'uni',0);
            R_xyz = cellfun(@global2local, alpha, beta, gamma, 'uni',0);
            nC = cellfun(@(x,y) transpose(round(x*y'*1e6)*1e-6), R_xyz,nC, 'uni',0);
            nC = cell2mat(cellfun(@(x,y) bsxfun(@plus, x,y),nC,e_nodesTrans, 'uni',0));
            X_E = nC(:,1);
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%
    
    
    X_K = shapeFunction_P*X_E;% interpolated values
    

    A = sqrt((X_P-X_K).^2);
    k = 0;
    while any(A > Eps)
    
        ksi_0(A > Eps) = ksi_p(A > Eps);
        
        X_0(A > Eps) = X_K(A > Eps);
        % shape function derivatives
        [~,naturalDerivativesX_P] = ...
            shapeFunction_1D(Q_ksi,ksi_0,'d');

        % jacobians
        J11 = naturalDerivativesX_P*x_e;
        
        Jacob_P11inv = 1./J11;
        % next iteration
        ksi_p(A > Eps) = ksi_0(A > Eps) + Jacob_P11inv(A > Eps).*(X_P(A > Eps)-X_0(A > Eps));
    
        [shapeFunction_P,~] = shapeFunction_1D(Q_ksi,ksi_p,'s');
        X_K = shapeFunction_P*X_E;% interpolated values
        A = sqrt((X_P-X_K).^2);
        clc;    k = k +1; disp(k); disp([length(A(A > Eps)) max(A(A > Eps))/Eps]);
    end
    disp([min(A) max(A)]/Eps)
    [~,naturalDerivativesX_P] = ...
        shapeFunction_1D(Q_ksi,ksi_p,'d');
    J11 = naturalDerivativesX_P*X_E;
    det_J = round((J11)*1e8)*1e-8;
    w_p = wi_x;
    w_p = repmat(w_p,length(X_P),1);
    w_p = w_p(sub2ind(size(w_p),ones(length(point_no),1),point_no)).*det_J;
    
end

shapeFunction_P = round(shapeFunction_P*1e10)*1e-10;