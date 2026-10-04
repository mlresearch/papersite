# CIP-000B Phase 1 scan summary

Generated from local clones under `~/mlresearch` and `~/lawrennd/r*`.

## Corpus

| Source | Titles |
|--------|--------|
| `_posts` YAML `title` | 35 945 |
| Root `*.bib` `title` fields | 1 992 |
| **Total** | **37 937** |

Reports beside this file:

- `candidates_braced_first.md` — `{B}ayesian`-style forms
- `candidates_braced_acronyms.md` / `candidates_braced_words.md`
- `candidates_nameish.md` — mid-title `Capitalised` tokens (noisy)
- `candidates_acronyms.md` / `candidates_def_acronyms.md`

## What works as a signal

**Already braced `{X}rest` forms** are sparse but high precision (only 14
unique stems). Top real ones: Bayesian, Gaussian, Monte, Carlo, Bernoulli,
Markov. Several false braces appear (`{S}ensor`, `{K}ernel`, …) — curation
still required.

**Known eponym seed ∩ corpus** is strong and usable as a YAML core:

| Stem | Approx. hits (posts+bib, mixed) |
|------|----------------------------------|
| Bayesian | 1008 |
| Gaussian | 687 |
| Markov | 385 |
| Wasserstein | 139 |
| Bayes | 110 |
| Langevin / Riemannian / Fourier / Newton / … | tens–hundreds |

**BibTeX-only (1 992 titles):** bracing is rare; most hits are still plain
capitals (`Bayesian` plain 139 vs `{B}ayesian` 7). Many local `.bib` files
are Title Case exports (~80%), so unprotected capitals do not prove the
author omitted braces for sentence-case styles — but the **stem list** is
still the right dictionary for intake lint.

## What does *not* work raw

Mid-title `Capitalised` tokens from `_posts` are dominated by Title Case
English (`Multi`, `Language`, `Reinforcement`, `Diffusion`, …). Frequency
alone must not populate the YAML.

Acronym scans are useful for a **short recurring list** (MCMC, SGD, SVM,
PCA, PAC, POMDP, …) but include ambiguous tokens (`AI`, `ML`, `MAP`, `EM`,
`CT`) that need human exclusion.

Paper-local coinages: keep in scan reports; do not auto-add to YAML.

## YAML readiness verdict

**Yes — ready for a small curated starter YAML**, not for auto-derived dump.

Recommended v1 contents:

1. **Names (high confidence):** Bayes, Bayesian, Markov, Markovian, Gaussian,
   Dirichlet, Poisson, Bernoulli, Laplace, Fourier, Hamiltonian, Langevin,
   Riemannian, Euclidean, Kalman, Gibbs, Metropolis, Hastings, Ising,
   Boltzmann, Wasserstein, Nash, Pareto, Hilbert, Lyapunov, Lipschitz,
   Monte, Carlo (or a combined `Monte Carlo` rule later), Kullback, Leibler
2. **Acronyms (recurring):** MCMC, SGD, SVM, PCA, PAC, POMDP, MDP, GAN,
   VAE, CNN, RNN, GNN, DAG, ODE, PDE, SVD, KL, **AI**, **LLM**, …
   High frequency is not a reason to omit: if the title has capitals, the
   checker should require braces so styles cannot downcase them.
   Short/polysemous stems (`ML`, `MAP`, `EM`, `CT`) still need a quick
   human pass for false friends, but the same capital⇒protect rule applies.

Checker policy can stay: YAML stems only; report unprotected at intake.
