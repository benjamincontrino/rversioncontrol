# rversioncontrol

A tutorial R package demonstrating how R projects, version control, `renv`, and `.env` files work together — with demo functions showing the pattern used for connecting to cloud databases.

---

## Concepts Covered

### 1. R Projects (`.Rproj`)
An `.Rproj` file sets your **working directory** and stores RStudio/Positron settings. It does not isolate package versions — that's `renv`'s job.

### 2. `renv` — Package Version Locking

`renv` creates a **lockfile** (`renv.lock`) that records the exact version of every package your project uses. It operates at the **project level before your R session loads** — meaning you never call `library()` before renv functions. The mental model is:

> `renv` manages **which packages are available** → `library()` loads them **into your session**

#### Core renv Functions

**`renv::init()`** — run once when starting a new project
```r
renv::init()
```
- Creates a project-local library isolated from your global R library
- Scans existing scripts for packages already in use
- Creates `renv.lock` capturing all current versions
- Adds an `.Rprofile` that auto-activates renv every time the project opens

**`renv::snapshot()`** — run whenever you install new packages
```r
install.packages("tidymodels")  # install something new
library(tidymodels)             # use it in your scripts
renv::snapshot()                # lock the new version into renv.lock
```
Think of this like `git commit` — it saves the current state of your package environment.

**`renv::restore()`** — run when cloning a repo or onboarding to a teammate's project
```r
renv::restore()
```
- Reads `renv.lock` and installs the exact versions recorded
- Guarantees reproducibility across machines
- Think of it like `npm install` — rebuilds the environment from the lockfile

**`renv::status()`** — audits whether your lockfile and actual environment match
```r
renv::status()
```
Returns one of three states:
- ✅ Synchronized — lockfile matches installed packages
- ⚠️ Out of sync — you installed something but forgot to `snapshot()`
- ❌ Missing — lockfile references a package not installed (run `restore()`)

**`renv::update()`** — upgrade packages within the renv environment
```r
renv::update("dplyr")   # update one package
renv::update()          # update everything
renv::snapshot()        # always snapshot after updating
```

#### Full renv Lifecycle

```
New project                       Teammate clones your repo
───────────                       ─────────────────────────
renv::init()                      renv::restore()
  ↓                                 ↓
install.packages(...)             library(rversioncontrol)
library(...)                      # exact same versions guaranteed
renv::snapshot()
git push renv.lock
```

#### What Gets Committed to GitHub

```
✅ commit:    renv.lock        ← the version recipe
✅ commit:    .Rprofile        ← auto-activates renv on startup
❌ gitignore: renv/library/   ← actual installed files (too large, teammates rebuild)
```

### 3. `.env` Files — Credential Management
A `.env` file stores **secrets and connection strings** that must never be committed to GitHub. This includes database passwords, API tokens, and storage keys.

```
# .env (never commit this)
DB_SERVER=my-server.database.windows.net
DB_PASSWORD=supersecret
```

In R, load and access them with:

```r
dotenv::load_dot_env(".env")
Sys.getenv("DB_SERVER")

# Or use the helper from this package
get_env_var("DB_SERVER")
```

Always commit `.env.example` (keys only, no values) so teammates know what to fill in.

### 4. R Packages

An R **package** bundles functions with documentation, tests, and dependency declarations. You build one with:

```r
# Document (generates man/ files from roxygen2 comments)
devtools::document()

# Install locally
devtools::install()

# Check for issues
devtools::check()
```

### 5. Using This Package in Another Project

To use `rversioncontrol` (or any custom package) in a different project, you need to install it there — it is not a live link. Installing it once makes it available; if the original package changes you must reinstall to get the updates.

**Install from GitHub (most common):**
```r
devtools::install_github("benjamincontrino/rversioncontrol")
library(rversioncontrol)
```

**Install from a local path:**
```r
devtools::install_local("path/to/rversioncontrol")
```

**When the original package changes:**
```r
# In the original package — after making changes:
devtools::document()
devtools::install()
# bump Version in DESCRIPTION (e.g. 0.1.0 → 0.2.0), then:
# git push

# In the consuming project — to pull the new version:
devtools::install_github("benjamincontrino/rversioncontrol")
```

This is the same pattern as any CRAN package: when `dplyr` releases a new version, you have to update it. Versioning in `DESCRIPTION` matters — bump the version number with every meaningful change so consumers know something changed.

After installing an updated version in a consuming project, run `renv::snapshot()` to record the new version in that project's lockfile.

---

## Cloud Platforms Covered

| Platform | Variables | R Package | Use Case |
|----------|-----------|-----------|----------|
| SQL Server | `DB_*` | `odbc` + `DBI` | Relational queries |
| Azure Blob Storage | `AZURE_*` | `AzureStor` | File storage (CSV, Parquet) |
| Microsoft Fabric | `FABRIC_*` | `odbc` + `DBI` | Lakehouse / warehouse |
| Databricks | `DATABRICKS_*` | `sparklyr` or `odbc` | Spark + Delta Lake |
| Snowflake | `SNOWFLAKE_*` | `odbc` + `DBI` | Cloud data warehouse |

---

## Quick Start

```r
# 1. Clone the repo
# 2. Copy .env.example to .env and fill in your credentials
# 3. Open rversioncontrol.Rproj in RStudio
# 4. Restore packages
renv::restore()

# 5. Load credentials
dotenv::load_dot_env(".env")

# 6. Check what's configured
library(rversioncontrol)
list_env_connections()

# 7. Retrieve a specific variable
get_env_var("DB_SERVER")
```

---

## Example Connection Patterns

### SQL Server
```r
library(DBI); library(odbc)
dotenv::load_dot_env(".env")

con <- dbConnect(odbc(),
  Driver   = get_env_var("DB_DRIVER"),
  Server   = get_env_var("DB_SERVER"),
  Database = get_env_var("DB_NAME"),
  UID      = get_env_var("DB_USER"),
  PWD      = get_env_var("DB_PASSWORD"),
  Port     = get_env_var("DB_PORT", default = "1433")
)
```

### Azure Blob Storage
```r
library(AzureStor)
dotenv::load_dot_env(".env")

endpoint <- blob_endpoint(
  paste0("https://", get_env_var("AZURE_STORAGE_ACCOUNT"), ".blob.core.windows.net"),
  key = get_env_var("AZURE_STORAGE_KEY")
)
container <- storage_container(endpoint, get_env_var("AZURE_CONTAINER"))
```

### Databricks
```r
library(DBI); library(odbc)
dotenv::load_dot_env(".env")

con <- dbConnect(odbc(),
  Driver    = "Simba Spark ODBC Driver",
  Host      = get_env_var("DATABRICKS_HOST"),
  HTTPPath  = get_env_var("DATABRICKS_HTTP_PATH"),
  AuthMech  = 3,
  UID       = "token",
  PWD       = get_env_var("DATABRICKS_TOKEN")
)
```

### Snowflake
```r
library(DBI); library(odbc)
dotenv::load_dot_env(".env")

con <- dbConnect(odbc(),
  Driver    = "SnowflakeDSIIDriver",
  Server    = paste0(get_env_var("SNOWFLAKE_ACCOUNT"), ".snowflakecomputing.com"),
  UID       = get_env_var("SNOWFLAKE_USER"),
  PWD       = get_env_var("SNOWFLAKE_PASSWORD"),
  Database  = get_env_var("SNOWFLAKE_DATABASE"),
  Schema    = get_env_var("SNOWFLAKE_SCHEMA"),
  Warehouse = get_env_var("SNOWFLAKE_WAREHOUSE"),
  Role      = get_env_var("SNOWFLAKE_ROLE")
)
```

---

## Package Development Workflow

```r
# After editing R/ files, regenerate docs
devtools::document()

# Install and test locally
devtools::install()

# Push to GitHub
# git add .
# git commit -m "your message"
# git push
```

## Author
Benjamin Contrino
