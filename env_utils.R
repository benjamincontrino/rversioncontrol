#' Retrieve an Environment Variable Safely
#'
#' @description
#' Reads a named environment variable loaded from a `.env` file via `dotenv::load_dot_env()`.
#' Returns the value if found, or a helpful error message if missing. This is the
#' core pattern used for all cloud database connectivity in this package — credentials
#' are never hardcoded in scripts; they live in `.env` and are accessed at runtime.
#'
#' @details
#' ## Why .env Files?
#' When connecting to cloud platforms (SQL Server, Azure, Databricks, Snowflake),
#' your credentials must be kept **out of version control**. A `.env` file stores
#' key-value pairs locally on your machine. You add `.env` to `.gitignore` so it
#' is never committed to GitHub. Teammates receive a `.env.example` file showing
#' which keys are needed, without exposing actual secrets.
#'
#' ## Workflow
#' ```r
#' # 1. Load your .env file at the top of any script
#' dotenv::load_dot_env(".env")
#'
#' # 2. Access credentials anywhere in your code
#' host <- get_env_var("DB_SERVER")
#' password <- get_env_var("DB_PASSWORD")
#' ```
#'
#' ## Environment Variable Categories in This Package
#' | Prefix | Platform |
#' |--------|----------|
#' | `DB_` | SQL Server (on-prem or cloud VM) |
#' | `AZURE_` | Azure Blob Storage |
#' | `FABRIC_` | Microsoft Fabric / Synapse |
#' | `DATABRICKS_` | Azure Databricks |
#' | `SNOWFLAKE_` | Snowflake Data Cloud |
#'
#' @param key A character string. The name of the environment variable to retrieve
#'   (e.g., `"DB_PASSWORD"`, `"DATABRICKS_TOKEN"`).
#' @param default A character string or `NULL`. Value returned if the variable is
#'   not set. Defaults to `NULL`, which triggers an error message instead of
#'   returning silently.
#'
#' @return A character string containing the value of the environment variable,
#'   or `NULL` (with a warning) if `default = NULL` and the variable is not found.
#'
#' @examples
#' # Load credentials from .env first
#' # dotenv::load_dot_env(".env")
#'
#' # Retrieve a value (returns NULL with warning if not set)
#' server <- get_env_var("DB_SERVER")
#'
#' # Provide a fallback default
#' port <- get_env_var("DB_PORT", default = "1433")
#'
#' @export
get_env_var <- function(key, default = NULL) {
  val <- Sys.getenv(key, unset = NA)

  if (is.na(val) || val == "") {
    if (is.null(default)) {
      warning(sprintf(
        "Environment variable '%s' is not set. Did you load your .env file with dotenv::load_dot_env()?",
        key
      ))
      return(NULL)
    }
    return(default)
  }

  val
}


#' List All Configured Cloud Connection Variables
#'
#' @description
#' Scans your loaded environment variables and returns a summary table showing
#' which cloud platforms have credentials configured. Values are masked for
#' security — only the variable names and whether they are set are shown.
#' This is useful for quickly auditing your `.env` setup before attempting
#' database connections.
#'
#' @details
#' ## Supported Platforms
#' This function checks for environment variables associated with four cloud
#' platforms used in this tutorial:
#'
#' - **SQL Server** (`DB_*`): Traditional ODBC connection to SQL Server,
#'   typically on a cloud VM or Azure SQL. Uses `odbc` + `DBI` in R.
#'
#' - **Azure Blob Storage** (`AZURE_*`): Object/file storage on Azure.
#'   Used for reading/writing flat files (CSV, Parquet) at scale.
#'   Uses the `AzureStor` package in R.
#'
#' - **Microsoft Fabric / Databricks** (`FABRIC_*`, `DATABRICKS_*`):
#'   Cloud-native analytics platforms with lakehouse architecture.
#'   Fabric uses ODBC; Databricks uses `sparklyr` or `odbc`.
#'
#' - **Snowflake** (`SNOWFLAKE_*`): Cloud data warehouse. Uses the
#'   `odbc` package with the Snowflake ODBC driver.
#'
#' @return A `data.frame` with columns:
#'   \describe{
#'     \item{platform}{The cloud platform name}
#'     \item{variable}{The environment variable name}
#'     \item{is_set}{Logical — `TRUE` if the variable has a non-empty value}
#'   }
#'
#' @examples
#' # dotenv::load_dot_env(".env")
#' list_env_connections()
#'
#' @export
list_env_connections <- function() {
  vars <- c(
    # SQL Server
    "DB_DRIVER", "DB_SERVER", "DB_NAME", "DB_USER", "DB_PASSWORD", "DB_PORT",
    # Azure Blob Storage
    "AZURE_STORAGE_ACCOUNT", "AZURE_STORAGE_KEY", "AZURE_CONTAINER",
    # Microsoft Fabric
    "FABRIC_DB_DRIVER", "FABRIC_DB_SERVER", "FABRIC_DB_NAME",
    # Databricks
    "DATABRICKS_HOST", "DATABRICKS_TOKEN", "DATABRICKS_HTTP_PATH",
    "DATABRICKS_CATALOG", "DATABRICKS_SCHEMA",
    # Snowflake
    "SNOWFLAKE_ACCOUNT", "SNOWFLAKE_USER", "SNOWFLAKE_PASSWORD",
    "SNOWFLAKE_WAREHOUSE", "SNOWFLAKE_DATABASE", "SNOWFLAKE_SCHEMA"
  )

  platform_map <- c(
    DB_DRIVER = "SQL Server", DB_SERVER = "SQL Server", DB_NAME = "SQL Server",
    DB_USER = "SQL Server", DB_PASSWORD = "SQL Server", DB_PORT = "SQL Server",
    AZURE_STORAGE_ACCOUNT = "Azure Blob Storage", AZURE_STORAGE_KEY = "Azure Blob Storage",
    AZURE_CONTAINER = "Azure Blob Storage",
    FABRIC_DB_DRIVER = "Microsoft Fabric", FABRIC_DB_SERVER = "Microsoft Fabric",
    FABRIC_DB_NAME = "Microsoft Fabric",
    DATABRICKS_HOST = "Databricks", DATABRICKS_TOKEN = "Databricks",
    DATABRICKS_HTTP_PATH = "Databricks", DATABRICKS_CATALOG = "Databricks",
    DATABRICKS_SCHEMA = "Databricks",
    SNOWFLAKE_ACCOUNT = "Snowflake", SNOWFLAKE_USER = "Snowflake",
    SNOWFLAKE_PASSWORD = "Snowflake", SNOWFLAKE_WAREHOUSE = "Snowflake",
    SNOWFLAKE_DATABASE = "Snowflake", SNOWFLAKE_SCHEMA = "Snowflake"
  )

  results <- data.frame(
    platform = platform_map[vars],
    variable = vars,
    is_set   = vapply(vars, function(v) {
      val <- Sys.getenv(v, unset = "")
      nzchar(val)
    }, logical(1)),
    row.names = NULL,
    stringsAsFactors = FALSE
  )

  results
}
