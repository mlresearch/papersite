# PMLR Repository

[![Tests](https://github.com/mlresearch/papersite/workflows/Test%20BibTeX%20Cleaner/badge.svg)](https://github.com/mlresearch/papersite/actions)

This repository contains tools and scripts for managing and publishing proceedings for the Proceedings of Machine Learning Research (PMLR).

*I've archived an old version of this code at <https://github.com/mlresearch/old_papersite>. On 2025-05-26 that repo was cloned to start this one and restructure with aim of creating a better automated pipeline.*

## Overview

The repository is structured as follows:

- **lib/**: Contains Ruby scripts for managing the Jekyll site and processing BibTeX files.
- **bin/**: Contains shell scripts for various tasks related to the repository.
- **backlog/**: Task management system for tracking improvements and features.
- **cip/**: Code Improvement Plans for documenting architectural changes.

## Volume Processing Workflow

The modern workflow for processing PMLR volumes includes:

1. **BibTeX Cleaning**: Use `tidy_bibtex.rb` to fix common issues like unescaped % characters
2. **Volume Creation**: Use `create_volume.rb` to generate Jekyll posts and organize assets
3. **Deployment**: Use `deploy_volume.sh` for proper branch separation (assets on main, Jekyll on gh-pages)

### BibTeX Cleaning

Before processing a volume, clean the BibTeX file to fix common issues:

```bash
# Clean BibTeX file (fixes unescaped % characters and other issues)
ruby lib/tidy_bibtex.rb --fix-all input.bib output_cleaned.bib
```

### Volume Creation

Create the Jekyll site and organize assets:

```bash
# Create volume with cleaned BibTeX
ruby lib/create_volume.rb -v VOLUME_NUMBER -b cleaned.bib

# If PDFs are in a separate branch, skip PDF checks
ruby lib/create_volume.rb -v VOLUME_NUMBER -b cleaned.bib --skip-pdf-check
```

### Deployment

Deploy the volume with proper branch separation:

```bash
# Deploy with new script (recommended)
./bin/deploy_volume.sh VOLUME_NUMBER
```

This creates:
- **main branch**: Contains assets (PDFs) and README.md
- **gh-pages branch**: Contains Jekyll site files for GitHub Pages


## Ruby Code

The Ruby code is used for creating Jekyll sites for hosting PMLR on GitHub Pages. The main code is found in `lib/mlresearch.rb`.

### Requirements

The Ruby scripts depend on the following packages:

- ActiveRecord
- bibtex-ruby
- facets
- pandoc-ruby

You can install these packages using:

```bash
gem install bibtex-ruby facets pandoc-ruby activerecord
```

Alternatively, you can use the provided `Gemfile` with:

```bash
bundle install
```

### Usage

For detailed usage instructions, refer to the `lib/README.md` file.

## Contributing

To suggest fixes or improvements, please make a pull request containing the changes requested and a justification for the changes.

For details on how to publish in PMLR, please check [PMLR FAQ](https://proceedings.mlr.press/faq.html).

For details on what is required to submit a proceedings, please check [PMLR Specification](https://proceedings.mlr.press/spec.html).

