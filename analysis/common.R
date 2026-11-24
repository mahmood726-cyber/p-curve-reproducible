# Shared helpers for the archive's R scripts.
# Library: R_LIBS / R_LIBS_USER as set by the caller; additionally P25_RLIB (if set) is put first.
local({
  extra <- Sys.getenv("P25_RLIB", unset = "")
  if (nzchar(extra)) .libPaths(c(extra, .libPaths()))
})
# Write text with LF line endings on every platform (byte-reproducible files).
write_lf <- function(lines, path) {
  con <- file(path, open = "wb"); on.exit(close(con))
  writeLines(enc2utf8(lines), con, sep = "\n", useBytes = TRUE)
}
write_csv_lf <- function(df, path) {
  con <- file(path, open = "wb"); on.exit(close(con))
  utils::write.csv(df, con, row.names = FALSE, fileEncoding = "", eol = "\n")
}
# 17 significant digits: every double round-trips exactly through the JSON text.
write_json_lf <- function(x, path, ...) write_lf(jsonlite::toJSON(x, auto_unbox = TRUE, pretty = TRUE, digits = I(17), na = "null", ...), path)
