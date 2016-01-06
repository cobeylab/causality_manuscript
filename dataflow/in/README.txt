This directory should contain everything necessary to replicate all results in the
manuscript.

Each subdirectory contains a file named "pyembedding-commit.txt", which indicates the git
commit (version) of the pyembedding repository used to run that analysis.

The repository can be retrieved via git from

git clone git@bitbucket.org:cobeylab/pyembedding.git

and a particular commit can be checked out using

cd pyembedding
git checkout <commit-name>

Sub-directories include:

simulations/
    Scripts used to generate every-10-day (using a 360-day year for convenience) incidence
    and prevalence data across a range of parameter values.

ccm-analyses/
    Scripts to generate each CCM analysis performed from simulation data. Contains
    subdirectories named
    
    <duration>-<sampling period>-<data transformation>/
    
    with sub-subdirectories named
    
    <identification-method>/<embedding-type>
    
    where <identification-method> is either "self", meaning that the embedding was
    identified by testing state-space-reconstruction correlation from one-step-ahead
    self-prediction in the "effect" time series, or "cross", meaning that the embedding
    was identified by testing CCM cross-correlation from the "effect" to the "cause" time
    series (with no offset).
