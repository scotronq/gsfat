function [features,score] = sfAnalysis(hic,rnaSeq,binNames,norm,binInfo,graphWeighted,dimReduc,topEllipseFrac)
%sfAnalysis analyzes Hi-C and RNA-seq through centrality and PCA
%   sfAnalysis extracts centrality features from Hi-C, concatenates these
%   features with RNA-seq, then determines a low dimensional projection to
%   extract regions that change significantly
%
%   Input
%   hic:            Hi-C matrix, typically normalized (NxNxM double;
%                   default: N/A)
%   rnaSeq:         Rna-seq values, (NxM double; default: N/A)
%   binNames:       Names associated with Hi-C and RNA-seq bins (string or
%                   cell array; default: empty cell)
%   norm:           Normalize Hi-C flag, observed over expected ([0,1]; default: 0)
%   binInfo:        Bin chr information necessary for normalization (array;
%                   default: [])
%   graphWeighted:  Use graph weighted centrality analysis ([0,1]; default: 1)
%   dimReduc:       Type of dimension reduction (PCA, LapEigen)
%   topEllipseFrac: The top fraction of bins that are fit with an ellipse
%
%   Output
%   features:       Concatenated feature array (Nx3 double)
%   score:          Location of bin in low dimensional projection (Nx3 double)
%
%   Version 1.1 (4/26/19)
%   Written by: Scott Ronquist
%   Contact:    scotronq@umich.edu
%   Created:    1/23/19
%   
%   Revision History:
%   v1.0 (1/23/19)
%   * sfAnalysis.m created
%   v1.1 (4/26/19)
%   * code commenting
%   * fixed ellipse fitting
%   * added dimReduc option

%% Set default parameters
if ~exist('dimReduc','var')||isempty(dimReduc);dimReduc='pca';end
if ~exist('graphWeighted','var')||isempty(graphWeighted);graphWeighted=1;end
if ~exist('binInfo','var')||isempty(binInfo);binInfo=[];end
if ~exist('norm','var')||isempty(norm);norm=0;end
if ~exist('binNames','var')||isempty(binNames);binNames=cellstr(num2str([1:length(rnaSeq)]'));end
if ~exist('topEllipseFrac','var')||isempty(topEllipseFrac);topEllipseFrac=.1;end

%% Normalize, remove centromere and extract centrality (depreciated)
if norm
    error(['norm = 1 is currently a deprecated option, normalize Hi-C',...
        'matrices prior to input'])
    hic = norm_hic_bins(hic,binInfo);
end

%% Extract Features
% extract centrality
for tp  = 1:size(hic,3)
    G = graph(hic(:,:,tp),'OmitSelfLoops');
    
    % Inverse weights for closeness and betweeness (MATLAB weight definition)
    HtRoot = nthroot(hic(:,:,tp),2);
    Ct = 1./HtRoot;
    Ct(isnan(Ct)) = 0;  Ct(isinf(Ct)) = 0;
    GInv = graph(Ct,'OmitSelfLoops');
    
    % Extract features
    if graphWeighted % centrality measure cost/importance is edge weighted
        features(:,:,tp) = [centrality(G,'degree','Importance',double(G.Edges.Weight)),...
            centrality(G,'closeness','Cost',double(GInv.Edges.Weight)),...
            centrality(G,'betweenness','Cost',double(GInv.Edges.Weight)),...
            centrality(G,'eigenvector','Importance',double(G.Edges.Weight))];
    else
        features(:,:,tp) = [centrality(G,'degree'),centrality(G,'closeness'),...
            centrality(G,'betweenness'),centrality(G,'eigenvector')];
    end
end

% add RNA-seq
features = cat(2,features,reshape(rnaSeq,size(rnaSeq,1),1,size(rnaSeq,2)));

% normalize features
Xnorm = FeatureNorm2(features);

% stack time points to project to same low dimensional space
XnormStacked = [];
for i = 1:size(Xnorm,3)
    XnormStacked = [XnormStacked;Xnorm(:,:,i)];
end

%% Dimension reduction
dimReduc = lower(dimReduc);
switch dimReduc
    case 'pca'
        [~,score,~] = pca(XnormStacked);
    case 'lapeigen'
        knn = 30*size(hic,3);%30*size(hic,3);
        sigma = 100;
        score = laplacian_eigen(XnormStacked, 3, knn, sigma);
    case 'tsne'
        score = tsne(XnormStacked,[],3);
    otherwise
        error('please select a valid dimension reduction method: pca, lapeigen, tsne')
end

%% Figure output
% figure('units','normalized','position',[.1 .1 .8 .8]), hold on
% figure, hold on
figure('position',[50 50 750 550]), hold on
if size(Xnorm,3) == 1
    % plot features in low dimensional space
    colorScale = jet(length(binNames));
    scatter3(score(:,1), score(:,2), score(:,3), 10, colorScale,'filled');
    
    % label top 10% or top 10 (min) furthest pts
    numPts = min([round(size(score,1)*topEllipseFrac) 10]);
    distMat = squareform(pdist(score(:,1:3)));
    [~,labelLocs] = sort(sum(distMat),'descend');
    text(score(labelLocs(1:numPts),1), score(labelLocs(1:numPts),2),...
        score(labelLocs(1:numPts),3), binNames(labelLocs(1:numPts)))
    
else
    % reshape data, take first 3 dimensions
    numSamples = size(Xnorm,3);
    numBins = size(Xnorm,1);
    scoreReshape = zeros(numBins,3,numSamples);
    for iS = 1:numSamples
        scoreReshape(:,:,iS) = score(numBins*(iS-1)+1:numBins*iS,1:3);
    end
    
    % plot features in low dimensional space
    colorScale = jet(numSamples);
    for iS = 1:numSamples
        scatter3(scoreReshape(:,1,iS), scoreReshape(:,2,iS),...
            scoreReshape(:,3,iS), 20,colorScale(iS,:),'filled');
    end
    
    % add lines btw pts
    if 1==1%~strcmp(dimReduc,'lapeigen')
    for iS = 1:numSamples-1
        plot3([scoreReshape(:,1,iS),scoreReshape(:,1,iS+1)]',...
            [scoreReshape(:,2,iS),scoreReshape(:,2,iS+1)]',...
            [scoreReshape(:,3,iS),scoreReshape(:,3,iS+1)]','k-')
    end
    end
    
    % get dist btw pts
    allDist = zeros(numBins,numSamples-1);
    for iS = 1:numSamples-1
        allDist(:,iS) = diag(pdist2(scoreReshape(:,1:3,iS), scoreReshape(:,1:3,iS+1)));
    end
    
    % label top 10% or top 20 (min) of genes to label and draw line
    numPts = min([round(size(scoreReshape,1)*topEllipseFrac) 10]);
    [~,labelLocs] = sort(sum(allDist,2),'descend');
    meanLoc = mean(scoreReshape,3);
    text(meanLoc(labelLocs(1:numPts),1), meanLoc(labelLocs(1:numPts),2),...
        meanLoc(labelLocs(1:numPts),3), binNames(labelLocs(1:numPts)));
    
    % fit ellipse to points if = 3 pts available
    if numSamples == 3
        binArea = zeros(numBins,1);
        
        for iBin = 1:numBins
            % fit ellipse
            fprintf('Fitting ellipse to pts: %.2f%%\n',(iBin/numBins*100))
            
            % plot large distance pts
            if ismember(iBin,labelLocs(1:numPts))
                [X, binArea(iBin)] = fitEllipse3d(squeeze(scoreReshape(iBin,1:3,:))');
                plot3(X(:,1),X(:,2),X(:,3),'r-')
            end
        end
        
        % fit ellipsoid to points if > 3 pts available
    elseif numSamples > 3
        binVol = zeros(numBins,1);
        
        for iBin = 1:numBins
            fprintf('Fitting ellipsoid to pts: %.2f\n',(iBin/numBins*100))
            
            % plot large distance pts
            if ismember(iBin,labelLocs(1:numPts))
                % fit ellipse
                [A,C] = MinVolEllipse(squeeze(scoreReshape(iBin,1:3,:)),.01);
                
                [~,D,~] = svd(A);
                a = 1/sqrt(D(1,1));
                b = 1/sqrt(D(2,2));
                c = 1/sqrt(D(3,3));
                binVol(iBin) = (4/3)*pi*a*b*c;
                Ellipse_plot(A,C,[.5 0 0]);
            end
        end
    end
    
    %custom legend
    h = zeros(numSamples, 1);
    for iS = 1:numSamples
        h(iS) = plot(NaN,NaN,'.','color',colorScale(iS,:),'markersize',30);
        sampleName{iS} = ['Sample',num2str(iS)];
    end
    legend(h,sampleName);
    
end

% format output
box on
title(sprintf('Structure-Function Feature Space - %s',dimReduc))

switch dimReduc
    case 'pca'
        xlabel('PC 1'), ylabel('PC 2'), zlabel('PC 3')
    otherwise
        xlabel('Component 1'), ylabel('Component 2'), zlabel('Component 3')
end
view(2)
set(gca,'linewidth',2,'fontsize',15)
end

