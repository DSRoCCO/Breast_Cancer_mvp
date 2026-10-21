# Artefacto descriptivo agregado para el módulo de diagnóstico de Shiny.
# No contiene identificadores ni sustituye el análisis completo de Quarto.

feature_label <- function(x) tools::toTitleCase(gsub("_", " ", x))

cohens_d_summary <- function(data, variables) {
  n_m <- sum(data$diagnosis == "M")
  n_b <- sum(data$diagnosis == "B")
  do.call(rbind, lapply(variables, function(variable) {
    x_m <- data[data$diagnosis == "M", variable]
    x_b <- data[data$diagnosis == "B", variable]
    pooled_sd <- sqrt(((n_m - 1) * stats::var(x_m) + (n_b - 1) * stats::var(x_b)) / (n_m + n_b - 2))
    d <- (mean(x_m) - mean(x_b)) / pooled_sd
    se <- sqrt((n_m + n_b) / (n_m * n_b) + d^2 / (2 * (n_m + n_b - 2)))
    data.frame(
      variable = variable,
      etiqueta = feature_label(variable),
      cohens_d = d,
      inferior = d - 1.96 * se,
      superior = d + 1.96 * se,
      stringsAsFactors = FALSE
    )
  }))
}

univariate_auc <- function(data, variables) {
  n_m <- sum(data$diagnosis == "M")
  n_b <- sum(data$diagnosis == "B")
  do.call(rbind, lapply(variables, function(variable) {
    ranks <- rank(data[[variable]], ties.method = "average")
    auc <- (sum(ranks[data$diagnosis == "M"]) - n_m * (n_m + 1) / 2) / (n_m * n_b)
    data.frame(variable = variable, etiqueta = feature_label(variable), auroc = auc,
               stringsAsFactors = FALSE)
  }))
}

build_descriptive_summary <- function(data) {
  mean_features <- grep("_mean$", names(data), value = TRUE)
  all_features <- c(
    grep("_mean$", names(data), value = TRUE),
    grep("_se$", names(data), value = TRUE),
    grep("_worst$", names(data), value = TRUE)
  )
  effects <- cohens_d_summary(data, mean_features)
  effects <- effects[order(effects$cohens_d, decreasing = TRUE), , drop = FALSE]
  aucs <- univariate_auc(data, mean_features)
  aucs <- aucs[order(aucs$auroc, decreasing = TRUE), , drop = FALSE]

  correlation <- stats::cor(data[, mean_features, drop = FALSE])
  corr_long <- as.data.frame(as.table(correlation), stringsAsFactors = FALSE)
  names(corr_long) <- c("variable_1", "variable_2", "correlacion")
  corr_long$i <- match(corr_long$variable_1, mean_features)
  corr_long$j <- match(corr_long$variable_2, mean_features)
  corr_long <- corr_long[corr_long$i >= corr_long$j, , drop = FALSE]
  corr_long$etiqueta_r <- sprintf("%.2f", corr_long$correlacion)

  pairs <- corr_long[corr_long$i > corr_long$j, c("variable_1", "variable_2", "correlacion")]
  pairs$abs_correlacion <- abs(pairs$correlacion)
  pairs <- pairs[order(pairs$abs_correlacion, decreasing = TRUE), , drop = FALSE]

  pca <- stats::prcomp(data[, all_features, drop = FALSE], center = TRUE, scale. = TRUE)
  variance <- pca$sdev^2 / sum(pca$sdev^2)
  # PCA específico de las 20 entradas disponibles en la interfaz. Permite
  # ubicar un escenario sin inventar los diez valores _se que la app no pide.
  pca_inputs <- stats::prcomp(data[, model_features, drop = FALSE], center = TRUE, scale. = TRUE)
  class_counts <- as.data.frame(table(data$diagnosis), stringsAsFactors = FALSE)
  names(class_counts) <- c("diagnosis", "n")
  class_counts$diagnosis <- as.character(class_counts$diagnosis)
  class_counts$proporcion <- class_counts$n / sum(class_counts$n)

  list(
    schema_version = mvp_schema_version,
    generated_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
    source = "Breast Cancer Wisconsin (Diagnostic), data/data.csv",
    unit = "Una observación por masa mamaria analizada mediante FNA",
    quality = list(
      rows = nrow(data),
      ids_unique = length(unique(data$id)) == nrow(data),
      complete_duplicates = sum(duplicated(data)),
      missing_values = sum(is.na(data)),
      raw_measurements = length(all_features),
      empty_trailing_column_removed = TRUE
    ),
    class_counts = class_counts,
    effects_mean = effects,
    auroc_mean = aucs,
    correlation_mean = corr_long,
    strongest_correlation = pairs[1, , drop = FALSE],
    pca_variance = data.frame(component = seq_along(variance), variance = variance,
                              cumulative_variance = cumsum(variance)),
    pca_input_context = list(
      feature_names = model_features,
      center = pca_inputs$center,
      scale = pca_inputs$scale,
      rotation = pca_inputs$rotation[, 1:2, drop = FALSE],
      scores = data.frame(PC1 = pca_inputs$x[, 1], PC2 = pca_inputs$x[, 2],
                          diagnosis = as.character(data$diagnosis))
    ),
    disclaimer = "Evidencia descriptiva de esta muestra histórica; no establece causalidad, diagnóstico ni validez clínica externa."
  )
}

save_descriptive_summary <- function(data, path) {
  saveRDS(build_descriptive_summary(data), path)
}

load_descriptive_summary <- function(path) {
  if (!file.exists(path)) {
    stop("No existe el resumen descriptivo. Ejecute primero: Rscript R/train_model.R")
  }
  summary <- readRDS(path)
  if (!identical(summary$schema_version, mvp_schema_version)) {
    stop("La versión del resumen descriptivo no es compatible. Regenere los artefactos.")
  }
  summary
}
