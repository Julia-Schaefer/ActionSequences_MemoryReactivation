# Action Sequences Structure Human Memory Reactivation

Analysis code, derived data and results for:

> Schaefer, J. K., Chowdhury, A., & Staudigl, T. (2026). Action Sequences Structure Human Memory Reactivation. *bioRxiv*. https://doi.org/10.64898/2026.08.08.742825 (preprint)

Participants learned action sequences by pairing images with real-world gaze shifts (head turns) while EEG and motion tracking were recorded. We use 2nd-order representational similarity analysis (RSA) to test whether the reactivation of image memories is timed to recalled gaze shifts during retrieval.

## Repository structure

```
.
├── code/                   analysis scripts
│   └── functions/          functions called by the scripts
├── data/
│   ├── accuracy/           decoding accuracy, all participants
│   └── behaviour/          behavioural data
│   └── example_data/       full data of two subjects
└── results/
    ├── stats/              statistics of all analyses
    └── figures/            figures, one subfolder per analysis
```

## Analysis pipeline

```
RSA_computation.m ──► Accuracy_computation.m ──► data/accuracy/ ──┬──► Accuracy_Plots.m
(2nd-order RSA)       (decoding accuracy)                          └──► Control_analyses.m

data/behaviour/ ──┬──► Memory_performance.m
                  └──► Head_motion_traces.m
```

All figures and statistics in `results/` are reproduced from the data in `data/`.

| Script | Content |
|---|---|
| `RSA_computation.m` | 2nd-order RSA |
| `Accuracy_computation.m` | Decoding accuracy and head velocity: learning task, retrieval task (remembered vs. forgotten segments); each with and without head-direction control |
| `Head_motion_traces.m` | Example trace of head angle and velocity with detected movement onsets; Fig. 1a, b |
| `Memory_performance.m` | Head-turn performance by position in the sequence; image-sorting performance for forgotten vs. remembered head turns; Fig. 1c, d |
| `Accuracy_Plots.m` | 2D and 1D accuracy per class and class mean, comparison with head-direction control (paired contrast), remembered vs. forgotten; cluster-based permutation tests; Fig. 2, 3, 4, S4, S5 |
| `Control_analyses.m` | Control analyses; Fig. S1, S2, S3 |

**Inputs and outputs**

- `RSA_computation.m`
    Available upon request.
- `Accuracy_computation.m`
  - Input: `data/example_data/` Data for exemplary accuracy computation of two subjects.
  - Output: `data/example_data/` Decoding accuracy for two exemplary subjects.
- `Head_motion_traces.m`
  - Input: `data/behaviour/RSA_info_pp-01.mat`
  - Output: `results/figures/head_motion/`
- `Memory_performance.m`
  - Input: `data/behaviour/desc-behaviour_RSA_info.mat`, `data/behaviour/Perf_Image_sorting_task.mat`
  - Output: `results/figures/behaviour/`, `results/stats/task-retrieval_desc-behaviour_stats.mat`
- `Accuracy_Plots.m` (run time 286 min)
  - Input: `data/accuracy/`
  - Output: `results/figures/accuracy/`, `results/stats/desc-accuracy_stats.mat`
- `Control_analyses.m`
  - Input: `data/accuracy/`
  - Output: `results/figures/bias_check/`, `results/stats/task-retrieval_desc-biascheck_stats.mat`

## Requirements

- MATLAB R2019b (9.7), Update 9, Mathworks, https://www.mathworks.com; 
- Signal Processing Toolbox (8.3)
- Statistics and Machine Learning Toolbox (11.6)
- [FieldTrip](https://www.fieldtriptoolbox.org/) (version 20230118)
- Image Processing Toolbox (11.0)
- Bioinformatics Toolbox (4.13)

## Functions (`code/functions/`)

| Function | Purpose |
|---|---|
| `HD_segment_data` | segments RSA data and head velocity around each head turn |
| `check_for_four_headturns` | selects trials with all four head turns |
| `bring2Dto1D_Accuracy` | 2D accuracy (test × training time) → 1D time course |
| `ClusBasedPermTest1D`, `ClusBasedPermTest2D` | cluster-based permutation tests (use FieldTrip) |
| `rsquaredLME` | R² of a mixed-effects model |
| `plotRepeatedMeasuresBoxplot` | boxplot with repeated-measures ANOVA, post-hoc tests and t-tests against zero |
| `plot1D`, `plot1D_simple`, `plot1D_RSA`, `plot2D_RSA`, `plot_contour` | plotting |
| `keep_line_alpha` | keeps line transparency in saved `.fig` files |
| `slice_data` | slices the data into time windows (used by `RSA_computation.m`) |
| `ranked_z_data` | rank-transforms and z-scores the sliced data(used by `RSA_computation.m`) |
| `get_Rval` | correlation (R values) between training and test data (used by `RSA_computation.m`) |
| `savePlotAsPdf` | saves a figure as a PDF file (used by `RSA_computation.m`) |

## Data availability

Behavioural data, full decoding results and exemplary data for decoding accuracy computation are included in `data/`. Participants are identified by number only. Data for 2nd-order RSA available upon reasonable request.

## Citation

If you use this code or data, please cite the paper above.

## Authors

Julia K. Schaefer ([ORCID](https://orcid.org/0000-0002-9246-267X)), Aditya Chowdhury ([ORCID](https://orcid.org/0000-0002-5795-517X)), Tobias Staudigl ([ORCID](https://orcid.org/0000-0003-2885-1280)), Ludwig-Maximilians-Universität München.

## Contact

Tobias Staudigl (corresponding author), tobias.staudigl@psy.lmu.de

## Acknowledgements

Funded by the European Research Council (ERC), grant 802681.

