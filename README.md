# PMLR Repository

[![Tests](https://github.com/mlresearch/papersite/workflows/Test%20Scripts/badge.svg)](https://github.com/mlresearch/papersite/actions)

This repository contains tools and scripts for managing and publishing proceedings for the Proceedings of Machine Learning Research (PMLR).

*I've archived an old version of this code at <https://github.com/mlresearch/old_papersite>. On 2025-05-26 that repo was cloned to start this one and restructure with aim of creating a better automated pipeline.*

## Overview

The repository is structured as follows:

- **lib/**: Contains Ruby scripts for managing the Jekyll site and processing BibTeX files.
- **bin/**: Contains shell scripts for various tasks related to the repository.


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

