# Writes SOURCE_SHA256.json (every archived file except git/work/node_modules folders and the inventory itself).
source("analysis/common.R")
skip <- "^(\\.git|\\.validate-work|\\.plant-work|\\.edge-profile|harness/node_modules)(/|$)|^results/shards/.*\\.(checkpoints|partial)\\.jsonl$|^figures/dump_dom\\.err$"
files <- sort(list.files(".", recursive = TRUE, all.files = TRUE, no.. = TRUE))
files <- files[!grepl(skip, files) & files != "SOURCE_SHA256.json"]
h <- tools::sha256sum(files)
write_json_lf(as.list(setNames(unname(h), files)), "SOURCE_SHA256.json")
cat(sprintf("INVENTORY: %d files\n", length(files)))
