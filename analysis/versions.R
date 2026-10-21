# Fail-closed version checks for validate.R.
required <- c(puniform = "0.2.8", metadat = "1.6.0", metafor = "5.2.1", jsonlite = "2.0.0")
optional <- c(stringr = "1.6.0", poibin = "1.6")       # only for the non-gating dmetar cross-check
installed_versions <- function(pk = c(names(required), names(optional)))
  vapply(pk, function(p) tryCatch(as.character(packageVersion(p)), error = function(e) NA_character_), "")
check_versions <- function(actual) {
  if (!identical(paste(R.version$major, R.version$minor, sep = "."), "4.6.0"))
    stop("R 4.6.0 required; found ", R.version.string)
  bad <- names(required)[is.na(actual[names(required)]) | actual[names(required)] != required]
  if (length(bad)) stop("Package version mismatch (refusing to run): ",
                        paste(sprintf("%s %s (need %s)", bad, actual[bad], required[bad]), collapse = "; "))
  invisible(TRUE)
}
