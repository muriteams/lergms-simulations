library(ggplot2)
library(magrittr)
library(data.table)

source("simulations/interval_tags.R")
intervals_effect <- c(.1, .5, 1, 2)

experiments <- c(
  # "Distribution of Empirical Bias (mutual)" = "02-various-sizes-4-5-mutual",
  "Distribution of Empirical Bias (ttriad)" = "02-various-sizes-4-5-ttriad"
)

e <- experiments[1]
term_name <- c("edges", gsub(".+[-](?=[a-zA-Z]+$)", "", e, perl = TRUE))

# Reading data
res  <- readRDS(sprintf("simulations/%s.rds", e))
dgp  <- readRDS(sprintf("simulations/%s-dat.rds", e))
pars <- lapply(dgp, "[[", "par")

# Fail to compute (Error) ------------------------------------------------------

# Listing failed ones
failed_ergm <- lapply(res, "[[", "ergm")
failed_ergm <- sapply(failed_ergm, inherits, what = "error")

failed_ergmito <- lapply(res, "[[", "ergmito")
failed_ergmito <- sapply(failed_ergmito, inherits, what = "error")

overall <- table(failed_ergm, failed_ergmito)

# (ergm, ergmito): (Not OK, OK) ------------------------------------------------
idx <- which(failed_ergm & !failed_ergmito)
dat <- lapply(res[idx], "[[", "ergmito")

covered <- Map(function(a,b) {
  if (any(!is.finite(a$ci)))
    return(FALSE)
  all(
    # Condition 1: Is within the CI
    (a$ci[, 1] < b) & (a$ci[, 2] > b) &
    # Condition 2: Is significant
      (sign(a$ci[,1])*sign(a$ci[,2]) > 0)
    )
}, a = dat, b = lapply(dgp[idx], "[[", "par"))
covered <- unlist(covered)

lapply(dat[which(covered)], "[[", "ci")

ergmito_given_ergm_failed <- table(covered)

# (ergm, ergmito): (OK, not OK) ------------------------------------------------
idx <- which(!failed_ergm & failed_ergmito)
dat <- lapply(res[idx], "[[", "ergm")

covered <- Map(function(a,b) {
  if (any(!is.finite(a$ci)))
    return(FALSE)
  all(
    # Condition 1: Is within the CI
    (a$ci[, 1] < b) & (a$ci[, 2] > b) &
      # Condition 2: Is significant
      (sign(a$ci[,1])*sign(a$ci[,2]) > 0)
  )
}, a = dat, b = lapply(dgp[idx], "[[", "par"))
covered <- unlist(covered)

lapply(dat[which(covered)], "[[", "ci")

ergm_given_ergmito_failed <- table(covered)

# Creating the data ------------------------------------------------------------
library(igraph)
tree <- matrix(c(
  1, 2,
  1, 3,
  3, 4,
  3, 5,
  4, 6,
  4, 7,
  5, 8,
  5, 9
  ), byrow=TRUE, ncol=2)

tree <- data.frame(tree)
tree$label <- c(
  "No",
  "Yes",
  "MC-MLE",
  "MLE",
  "Yes",
  "No",
  "Yes",
  "No"
)

tree <- graph_from_data_frame(
  tree, vertices = data.frame(
    idx  = 1:9,
    name = c(
      "Either failed",             # 1 All
      overall["FALSE", "FALSE"],   # 2 All jointly OK
      "Which failed",              # 3 Not OK
      "MLE\nsignificant",          # 4 MC-MLE
      "MC-MLE\nsignificant",       # 5 MLE
      ergmito_given_ergm_failed["TRUE"],
      ergmito_given_ergm_failed["FALSE"],
      ergm_given_ergmito_failed["TRUE"],
      ergm_given_ergmito_failed["FALSE"]
      )             
  ))

graphics.off()
pdf("analysis/failed-tree.pdf", width = 4, height = 4)
op <- par(mai = rep(0, 4))
plot(
  tree, layout = layout_as_tree, vertex.color="transparent",
  vertex.frame.color="transparent",
  edge.arrow.size = 0,
  vertex.size = 35,
  vertex.label.color = "black",
  vertex.label.family = "serif",
  edge.label.color = "black",
  edge.label.family = "serif"
  )
par(op)
dev.off()


# Distribution of sufficient statistics ----------------------------------------

# Failed cases
idx <- which(failed_ergm & !failed_ergmito)

failed_nets <- lapply(dgp[idx], "[[", "nets")
library(ergmito)
mat4 <- matrix(1, ncol = 4, nrow = 4)
diag(mat4) <- 0
mat5 <- matrix(1, ncol = 5, nrow = 5)
diag(mat5) <- 0

maxref <- matrix(ncol=2, nrow=5)
maxref[4,] <- count_stats(mat4 ~ edges + ttriad)
maxref[5,] <- count_stats(mat5 ~ edges + ttriad)


stats_failed <- lapply(failed_nets, count_stats, terms = c("edges", "ttriad"))
sizes_failed <- lapply(failed_nets, nvertex)
stats_failed <- Map(function(x, s) {
  
  # Normalizing to the size
  colMeans(x/maxref[s,])
  
}, x = stats_failed, s = sizes_failed)
stats_failed <- do.call(rbind, stats_failed)
stats_failed_df <- data.frame(
  count = as.vector(stats_failed),
  term  = c(rep("edges", nrow(stats_failed)), rep("ttriad", nrow(stats_failed)))
)

# Success cases
idx <- which(!failed_ergm & !failed_ergmito)

success_nets <- lapply(dgp[idx], "[[", "nets")

stats_success <- lapply(success_nets, count_stats, terms = c("edges", "ttriad"))
sizes_success <- lapply(success_nets, nvertex)
stats_success <- Map(function(x, s) {
  
  # Normalizing to the size
  colMeans(x/maxref[s,])
  
}, x = stats_success, s = sizes_success)
stats_success <- do.call(rbind, stats_success)
stats_success_df <- data.frame(
  count = as.vector(stats_success),
  term  = c(rep("edges", nrow(stats_success)), rep("ttriad", nrow(stats_success)))
)

dat <- rbind(
  cbind(stats_failed_df, failed = "yes"),
  cbind(stats_success_df, failed = "no")
) 


ggplot(dat, aes(y = count, x=term)) +
  geom_violin() + 
  facet_wrap(
    ~ failed,
    labeller = labeller(
      failed = c(yes = "Failed", no = "Did not failed")
    )) +
  labs(x = "Term", y = "Suf. Stats. as %\nof upper bound") +
  lims(y = c(0,1)) +
  theme(text = element_text(family = "AvantGarde")) #+
  # ggsave("analysis/failed.pdf", width = 8, height = 6)


non_existance <- rbind(
  data.table(stats_failed, failed = "yes"),
  data.table(stats_success, failed = "no")
  )

colnames(non_existance)[1:2] <- c("edges", "ttriad")
  
ggplot(non_existance, aes(x = edges, y = ttriad)) +
  geom_hex() +
  facet_grid(~failed, labeller = labeller(
    failed = c(yes = "Failed", no = "Did not failed")
  )) +
  labs(fill = "# of cases") +
  scale_fill_viridis_c() +
  theme(text = element_text(family = "AvantGarde")) +
  ggsave("analysis/failed.pdf", width = 7, height = 4)