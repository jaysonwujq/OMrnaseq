# mRNA report KEGG and GO barplot
suppressMessages(library(ggplot2))
suppressMessages(library(dplyr))
suppressMessages(library(argparser))
options(stringsAsFactors = F)
#----set params-----

p <- arg_parser("mRNA report KEGG and GO barplot")
p <- add_argument(p, "--anno", help = "GO or KEGG annotation file")
p <- add_argument(p, "--table", help = "GO or KEGG enrichment table directory")
p <- add_argument(p, "--diff", help = "diff gene list directory")
p <- add_argument(p, "--type", help = "enrichment analysis type, go or kegg")
argv <- parse_args(p)

all_count_file <- argv$anno
enrichment_tables_path <- argv$table
all_lists_path <- argv$diff
enrichment_type <- argv$type
output_path <- enrichment_tables_path

#----theme set-----
enrich_theme <- theme_bw() + theme(legend.key = element_blank(), axis.text.x = element_text(color = "black",
  face = "bold", angle = 90, hjust = 1, vjust = 0.5, size = rel(0.8)), axis.text.y = element_text(color = "black",
  face = "bold", size = rel(0.8)), axis.title.y = element_text(color = "black",
  face = "bold", size = rel(0.8)), panel.grid.minor.x = element_line(colour = "black"),
  panel.grid.major = element_blank(), strip.text = element_blank(), strip.background = element_blank(),
  legend.text = element_text(size = rel(0.8)))
theme_set(enrich_theme)
#-----function-------
find_count <- function(count_data, filter_genes=NULL) {
  if (! is.null(filter_genes)) {
     count_data = count_data[count_data[, 1] %in% filter_genes, ]
  }
  return(length(unique(count_data[, 1])))
}

enrich_data <- function(data, type, label, show_num, max_name_length, all_count,
  term_count) {
  if (type == "kegg" & all(c("X.Term", "Input.number", "Background.number", "P.Value",
    "Corrected.P.Value") %in% names(data))) {
    data <- data[, c("X.Term", "Input.number", "Background.number", "P.Value",
      "Corrected.P.Value")]
  } else if (type == "go" & all(c("over_represented_pvalue", "numDEInCat", "numInCat",
    "term", "ontology") %in% names(data))) {
    data <- data[, c("term", "numDEInCat", "numInCat", "over_represented_pvalue",
      "qvalue", "ontology")]
  } else stop("check your data and rownames!")
  names(data)[1:5] <- c("Term", "Input_number", "Background_number", "P_value",
    "Corrected_P_Value")
  # modified: show top 15 Terms, don't care about it's pvalue
  # TODO add ** to qvlue < 0.05 term, add * to pvalue < 0.05 term
  data <- data[1:show_num, ]
  for (i in 1:dim(data)[1]) {
    if (nchar(data$Term[i]) > max_name_length) {
      data$Term[i] <- paste0(substr(data$Term[i], 1, max_name_length/2), "...",
        substr(data$Term[i], (nchar(data$Term[i]) - max_name_length/2), nchar(data$Term[i])))
    }
  }
  if (length(unique(data$Term)) != length(data$Term)) {
    stop("max name length set too samll!")
  }
  data$label <- label
  data$color <- label
  data$sign <- ""
  data$sign <- ifelse(data$Corrected_P_Value < 0.05, "*", "")
  data$expected <- data$Background_number/all_count * term_count
  data <- data %>% dplyr::filter(Input_number > expected)
  if (dim(data)[1] == 0) {
    stop("data empty!")
  }
  data <- arrange(data, Input_number)
  data
}

enrich_barplot <- function(enrich_merge_data, x_lab = "", y_lab = "Number of genes",
  break_label1, break_label2) {
  p <- ggplot(enrich_merge_data, aes(y = Input_number, x = Term, fill = color)) +
    geom_bar(stat = "identity", width = 0.8) + geom_bar(aes(x = Term, y = expected),
    fill = "black", stat = "identity", width = 0.8) + geom_text(aes(label = sign),
    vjust = 0.5, hjust = 0.5, size = 3) + ylim(c(0, max(enrich_merge_data$Input_number) +
    max(enrich_merge_data$Input_number) * 0.1)) + facet_grid(. ~ label, scales = "free_x",
    space = "free") + scale_fill_manual(values = c(up = "#00A08A", down = "#FF0000",
    all = "#5BBCD6", expected = "black"), breaks = c("all", "down", "up", "expected"),
    labels = c("No. of all diff-expressed genes", paste("No.", break_label2,
      " up-regulated genes", sep = " "), paste("No.", break_label1, " up-regulated genes",
      sep = " "), "Expected no. of genes")) + guides(fill = guide_legend(title = "")) +
    ylab(y_lab) + xlab(x_lab)
  p
}

#----plot out-----
if (enrichment_type == "kegg") {
  kegg_all_term_count <- read.delim(all_count_file, header = F)
  all_enrichment_files <- list.files(enrichment_tables_path)
  for (each_file in all_enrichment_files) {
    if (!grepl("kegg.enrichment.txt", each_file))
      next
    first_level_split <- unlist(strsplit(each_file, split = "\\."))
    if (unlist(strsplit(first_level_split[1], split = "_vs_"))[1] == unlist(strsplit(first_level_split[2],
      split = "-UP"))[1]) {
      up_file <- each_file
      up_data <- read.delim(paste(enrichment_tables_path, up_file, sep = "/"),
        header = T)
      up_file_list <- paste(unlist(strsplit(up_file, split = "\\."))[1], unlist(strsplit(up_file,
        split = "\\."))[2], "edgeR.DE_results.diffgenes.txt", sep = ".")
      up_data_count_list <- read.delim(paste(all_lists_path, up_file_list,
        sep = "/"), header = F)
    } else if (unlist(strsplit(first_level_split[1], split = "_vs_"))[2] == unlist(strsplit(first_level_split[2],
      split = "-UP"))[1]) {
      down_file <- each_file
      down_data <- read.delim(paste(enrichment_tables_path, down_file, sep = "/"),
        header = T)
      down_file_list <- paste(unlist(strsplit(down_file, split = "\\."))[1],
        unlist(strsplit(down_file, split = "\\."))[2], "edgeR.DE_results.diffgenes.txt",
        sep = ".")
      down_data_count_list <- read.delim(paste(all_lists_path, down_file_list,
        sep = "/"), header = F)
    } else if (first_level_split[2] == "ALL") {
      all_file <- each_file
      all_data <- read.delim(paste(enrichment_tables_path, all_file, sep = "/"),
        header = T)
      all_file_list <- paste(unlist(strsplit(all_file, split = "\\."))[1],
        unlist(strsplit(all_file, split = "\\."))[2], "edgeR.DE_results.diffgenes.txt",
        sep = ".")
      all_data_count_list <- read.delim(paste(all_lists_path, all_file_list,
        sep = "/"), header = F)
    }
  }
  up_data_term_count <- find_count(kegg_all_term_count, up_data_count_list$V1)
  down_data_term_count <- find_count(kegg_all_term_count, down_data_count_list$V1)
  all_data_term_count <- find_count(kegg_all_term_count, all_data_count_list$V1)
  kegg_up_data <- enrich_data(up_data, type = "kegg", label = "up", show_num = 15,
    max_name_length = 90, all_count = find_count(kegg_all_term_count), term_count = up_data_term_count)
  kegg_down_data <- enrich_data(down_data, type = "kegg", label = "down", show_num = 15,
    max_name_length = 90, all_count = find_count(kegg_all_term_count), term_count = down_data_term_count)
  kegg_all_data <- enrich_data(all_data, type = "kegg", label = "all", show_num = 15,
    max_name_length = 90, all_count = find_count(kegg_all_term_count), term_count = all_data_term_count)
  kegg_merge_data <- rbind(kegg_all_data, kegg_up_data, kegg_down_data)
  kegg_merge_data$Term <- factor(kegg_merge_data$Term, levels = unique(kegg_merge_data$Term))
  # add expected
  kegg_merge_data[dim(kegg_merge_data)[1] + 1, ] <- kegg_merge_data[dim(kegg_merge_data)[1],
    ]
  kegg_merge_data[dim(kegg_merge_data)[1], c("Input_number", "expected")] <- 0
  kegg_merge_data[dim(kegg_merge_data)[1], "color"] <- "expected"
  ggsave(filename = paste(output_path, paste(first_level_split[1], "kegg.enrichment.barplot.pdf",
    sep = "."), sep = "/"), plot = enrich_barplot(kegg_merge_data, break_label1 = unlist(strsplit(first_level_split[1],
    split = "_vs_"))[1], break_label2 = unlist(strsplit(first_level_split[1],
    split = "_vs_"))[2]), height = 9, width = dim(kegg_merge_data)[1]/4)
  ggsave(filename = paste(output_path, paste(first_level_split[1], "kegg.enrichment.barplot.png",
    sep = "."), sep = "/"), plot = enrich_barplot(kegg_merge_data, break_label1 = unlist(strsplit(first_level_split[1],
    split = "_vs_"))[1], break_label2 = unlist(strsplit(first_level_split[1],
    split = "_vs_"))[2]), height = 9, width = dim(kegg_merge_data)[1]/4, type = "cairo-png")
} else if (enrichment_type == "go") {
  go_all_term_count <- read.delim(all_count_file, sep = "\t")
  go_all_term_count <- go_all_term_count[go_all_term_count[, 2] != "", ]
  all_enrichment_files <- list.files(enrichment_tables_path)
  for (each_file in all_enrichment_files) {
    if (!grepl("go.enrichment.txt", each_file))
      next
    first_level_split <- unlist(strsplit(each_file, split = "\\."))
    if (unlist(strsplit(first_level_split[1], split = "_vs_"))[1] == unlist(strsplit(first_level_split[2],
      split = "-UP"))[1]) {
      up_file <- each_file
      up_data <- read.delim(paste(enrichment_tables_path, up_file, sep = "/"),
        header = T, stringsAsFactors = F)
      up_file_list <- paste(unlist(strsplit(up_file, split = "\\."))[1], unlist(strsplit(up_file,
        split = "\\."))[2], "edgeR.DE_results.diffgenes.txt", sep = ".")
      up_data_count_list <- read.delim(paste(all_lists_path, up_file_list,
        sep = "/"), header = F)
    } else if (unlist(strsplit(first_level_split[1], split = "_vs_"))[2] == unlist(strsplit(first_level_split[2],
      split = "-UP"))[1]) {
      down_file <- each_file
      down_data <- read.delim(paste(enrichment_tables_path, down_file, sep = "/"),
        header = T, stringsAsFactors = F)
      down_file_list <- paste(unlist(strsplit(down_file, split = "\\."))[1],
        unlist(strsplit(down_file, split = "\\."))[2], "edgeR.DE_results.diffgenes.txt",
        sep = ".")
      down_data_count_list <- read.delim(paste(all_lists_path, down_file_list,
        sep = "/"), header = F)
    } else if (first_level_split[2] == "ALL") {
      all_file <- each_file
      all_data <- read.delim(paste(enrichment_tables_path, all_file, sep = "/"),
        header = T, stringsAsFactors = F)
      all_file_list <- paste(unlist(strsplit(all_file, split = "\\."))[1],
        unlist(strsplit(all_file, split = "\\."))[2], "edgeR.DE_results.diffgenes.txt",
        sep = ".")
      all_data_count_list <- read.delim(paste(all_lists_path, all_file_list,
        sep = "/"), header = F)
    }
  }

  up_data_term_count <- find_count(go_all_term_count, up_data_count_list$V1)
  down_data_term_count <- find_count(go_all_term_count, down_data_count_list$V1)
  all_data_term_count <- find_count(go_all_term_count, all_data_count_list$V1)
  go_up_data <- enrich_data(up_data, type = "go", label = "up", show_num = 15,
    max_name_length = 90, all_count = find_count(go_all_term_count), term_count = up_data_term_count)
  go_down_data <- enrich_data(down_data, type = "go", label = "down", show_num = 15,
    max_name_length = 90, all_count = find_count(go_all_term_count), term_count = down_data_term_count)
  go_all_data <- enrich_data(all_data, type = "go", label = "all", show_num = 15,
    max_name_length = 90, all_count = find_count(go_all_term_count), term_count = all_data_term_count)
  go_merge_data <- rbind(go_all_data, go_up_data, go_down_data)
  go_merge_data$Term <- factor(go_merge_data$Term, levels = unique(go_merge_data$Term))
  # add expected
  go_merge_data[dim(go_merge_data)[1] + 1, ] <- go_merge_data[dim(go_merge_data)[1],
    ]
  go_merge_data[dim(go_merge_data)[1], c("Input_number", "expected")] <- 0
  go_merge_data[dim(go_merge_data)[1], "color"] <- "expected"
  ggsave(filename = paste(output_path, paste(first_level_split[1], "go.enrichment.barplot.pdf",
    sep = "."), sep = "/"), plot = enrich_barplot(go_merge_data, break_label1 = unlist(strsplit(first_level_split[1],
    split = "_vs_"))[1], break_label2 = unlist(strsplit(first_level_split[1],
    split = "_vs_"))[2]), height = 9, width = dim(go_merge_data)[1]/4)
  ggsave(filename = paste(output_path, paste(first_level_split[1], "go.enrichment.barplot.png",
    sep = "."), sep = "/"), plot = enrich_barplot(go_merge_data, break_label1 = unlist(strsplit(first_level_split[1],
    split = "_vs_"))[1], break_label2 = unlist(strsplit(first_level_split[1],
    split = "_vs_"))[2]), height = 9, width = dim(go_merge_data)[1]/4, type = "cairo-png")
}
