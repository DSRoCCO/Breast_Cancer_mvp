load_model_bundle <- function(artifacts_dir = "artifacts") {
  model_path <- file.path(artifacts_dir, "modelo_breast_cancer.rds")
  metadata_path <- file.path(artifacts_dir, "modelo_breast_cancer_metadata.rds")
  if (!file.exists(model_path) || !file.exists(metadata_path)) {
    stop("No existe el artefacto del modelo. Ejecute primero: Rscript R/train_model.R")
  }
  metadata <- readRDS(metadata_path)
  if (exists("mvp_schema_version", inherits = TRUE) && !identical(metadata$schema_version, mvp_schema_version)) {
    stop("La versión de metadatos del modelo no es compatible. Regenere los artefactos.")
  }
  list(model = readRDS(model_path), metadata = metadata)
}

predict_breast_cancer <- function(new_data, bundle, strict_bounds = TRUE) {
  values <- validate_input(new_data, bundle$metadata, strict_bounds = strict_bounds)
  # El ID pertenece al rol técnico de la receta, no al formulario ni al modelo.
  values$id <- 0L
  probabilities <- predict(bundle$model, values, type = "prob")
  p_maligno <- probabilities$.pred_M[[1]]
  predicted <- if (p_maligno >= bundle$metadata$threshold) "M" else "B"

  coefficients <- bundle$metadata$coefficients |>
    dplyr::filter(variable %in% bundle$metadata$feature_names, coeficiente != 0) |>
    dplyr::left_join(bundle$metadata$normalization, by = "variable") |>
    dplyr::mutate(
      valor = vapply(variable, function(x) values[[x]][[1]], numeric(1)),
      contribucion = ((valor - media) / sd) * coeficiente,
      magnitud = abs(contribucion)
    ) |>
    dplyr::arrange(dplyr::desc(magnitud)) |>
    dplyr::slice_head(n = 8)

  list(probability_malignant = p_maligno, predicted_class = predicted,
       contributions = coefficients, input_values = values, metadata = bundle$metadata)
}
