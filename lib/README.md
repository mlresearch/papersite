# Ruby Code

This code is for creating `jekyll` sites for hosting PMLR on `GitHub pages`

From the shell there are various ruby scripts to run. The main code
that does the work is found in `mlresearch.rb`.

## Requirements

The `papersite` script depends on the following packages, which will need to
be install before the scripts here can run:

 - ActiveRecord
 - bibtex-ruby
 - facets
 - pandoc-ruby

You can install all the above with:
```
gem install bibtex-ruby facets pandoc-ruby activerecord
```

Alternatively, you can use the provided `Gemfile` with:
```
bundle install
```

## At First Request

When the volume was first requested, a new repo should be set up under

https://github.com/mlresearch/

with the name vNN where NN is the number of the proceedings.

Use this link:

https://github.com/organizations/mlresearch/repositories/new

To set up the proceedings.

Do *not* initialize with a README. Simply "Create Repository" and *then*
add relevant people to the edit/write permissions.

The "Description" field for the repo should be of the form "AISTATS 2017
Proceedings" or equivalent. This will populate the front page when the
proceedings are available (see http://proceedings.mlr.press/).

## When the Proceedings are Ready

The proceedings editor will submit a pull request to the repo. That pull request
contains the PDFs and supplemental information, as well as a bib file
containing information about the volume. The specification for all
this is given here:

http://proceedings.mlr.press/spec.html

### Modern Workflow (Recommended)

1. **Setup Directory Structure**:
```bash
# Create volume directory
cd ~/mlresearch/
git clone git@github.com:mlresearch/vNN.git
```
which will clone the repo including the bib file.

Add today's date to the bib file in the `published`-field in the @Proceedings entry in the `FILE.bib`.

2. **Clean BibTeX File**:
```bash
# Fix common BibTeX issues (unescaped % characters, etc.)
ruby ../papersite/lib/tidy_bibtex.rb --fix-all FILE.bib FILE_cleaned.bib
```
Add today's date to the `published`-field in the `@Proceedings` entry in `FILE.bib`.

3. **Create Volume**:
```bash
# Generate Jekyll site and organize assets
ruby ../papersite/lib/create_volume.rb -v NN -b FILE_cleaned.bib

# If PDFs are in separate branch, skip PDF checks
ruby ../papersite/lib/create_volume.rb -v NN -b FILE_cleaned.bib --skip-pdf-check
```

4. **Deploy with Proper Branch Separation**:
```bash
# Use new deployment script (recommended)
../papersite/bin/deploy_volume.sh NN
```

This initially updates the main branch with the created files. Then creates a gh-pages branch. Then it deletes files to leave you with:

- **main branch**: Contains assets (PDFs) and README.md
- **gh-pages branch**: Contains Jekyll site files for GitHub Pages

### Legacy Workflow (Deprecated)

The site is created using Jekyll. There is a customised remote-theme for formating the proceedings which is referenced in the `_config.yml` file.

Now, assuming you have already created the stub git repo on github,
you can run the script

### BibTeX Cleaning

The `tidy_bibtex.rb` script fixes or flags common issues:
- Unescaped % characters in abstract fields
- Missing commas in author fields
- Unicode character handling

Usage:
```bash
ruby lib/tidy_bibtex.rb --fix-all input.bib output.bib
```

### Unicode Handling

The system automatically handles Unicode characters using `unicode_replacements.yml`. Common characters are automatically converted to LaTeX equivalents.



