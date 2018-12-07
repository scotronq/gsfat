function [pvalue,padj] = matlabNegbinDE(sampleCounts1,sampleCounts2,varLink,lowCountThreshold)
%matlabNegbinDE Summary of this function goes here
%   Detailed explanation goes here

%% Identifying Differentially Expressed Genes from RNA-Seq Data
% https://www.mathworks.com/help/bioinfo/examples/identifying-differentially...
% -expressed-genes-from-rna-seq-data.html
% This example shows how to test RNA-Seq data for differentially expressed
% genes using a negative binomial model.

% Copyright 2010-2016 The MathWorks, Inc.

%% default parameters
if nargin<4; lowCountThreshold=10; end
if nargin<3; varLink='LocalRegression'; end

countAll = [sampleCounts1, sampleCounts2];

%% Inferring Differential Expression with a Negative Bionomial Model
% neg bin Regression
tRegression = nbintest(sampleCounts1,sampleCounts2,'VarianceLink',varLink);
% % % % % h = plotVarianceLink(tRegression);
% % % % % 
% % % % % % set custom title
% % % % % h(1).Title.String = 'Variance Link on Treated Samples';
% % % % % h(2).Title.String = 'Variance Link on Untreated Samples';
% % % % % 
% % % % % % comparison
% % % % % h = plotVarianceLink(tRegression,'compare',true);
% % % % % 
% % % % % % set custom title
% % % % % h(1).Title.String = 'Variance Link on Treated Samples';
% % % % % h(2).Title.String = 'Variance Link on Untreated Samples';
  
%% histogram of P-values
% % % % % figure;
% % % % % histogram(tRegression.pValue,100)
% % % % % xlabel('P-value')
% % % % % ylabel('Frequency')
% % % % % title('P-value enrichment')

%% Multiple Testing and Adjusted P-values
% compute the adjusted P-values (BH correction)
padj = mafdr(tRegression.pValue,'BHFDR',true);
pvalue = tRegression.pValue;

%% Filter low counts
lowCountGenes = all(countAll < lowCountThreshold, 2);
% % % % % % histogram(tRegression.pValue(~lowCountGenes),100)
% % % % % % xlabel('P-value')
% % % % % % ylabel('Frequency')
% % % % % % title('P-value enrichment without low count genes')

padj(lowCountGenes) = NaN;
pvalue(lowCountGenes) = NaN;

end

