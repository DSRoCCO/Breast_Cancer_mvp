# Contrato de datos compartido por entrenamiento y aplicación.

all_measurements <- c(
  "radius", "texture", "perimeter", "area", "smoothness", "compactness",
  "concavity", "concave points", "symmetry", "fractal_dimension"
)

model_features <- c(paste0(all_measurements, "_mean"), paste0(all_measurements, "_worst"))
all_features <- unlist(lapply(c("mean", "se", "worst"), function(summary) {
  paste0(all_measurements, "_", summary)
}), use.names = FALSE)

validate_breast_data <- function(data) {
  required <- c("id", "diagnosis", all_features)
  missing <- setdiff(required, names(data))
  if (length(missing) > 0) stop("Faltan columnas requeridas: ", paste(missing, collapse = ", "))
  if (!all(data$diagnosis %in% c("M", "B"))) stop("diagnosis sólo admite M o B.")
  if (anyDuplicated(data$id)) stop("El identificador id debe ser único.")
  if (anyDuplicated(data)) stop("Se detectaron filas completamente duplicadas.")
  non_numeric <- all_features[!vapply(data[all_features], is.numeric, logical(1))]
  if (length(non_numeric) > 0) stop("Mediciones no numéricas: ", paste(non_numeric, collapse = ", "))
  if (any(!is.finite(as.matrix(data[all_features])))) stop("Las mediciones deben ser finitas y no faltantes.")
  invisible(data)
}

read_breast_data <- function(path = file.path("data", "data.csv")) {
  if (!file.exists(path)) stop("No se encontró la fuente de entrenamiento: ", path)
  raw <- read.csv(path, check.names = FALSE, stringsAsFactors = FALSE)
  empty <- names(raw)[vapply(raw, function(x) all(is.na(x) | x == ""), logical(1))]
  data <- raw[, !(names(raw) %in% empty), drop = FALSE]

  validate_breast_data(data)
  data |> dplyr::mutate(diagnosis = factor(diagnosis, levels = c("M", "B")))
}

build_model_recipe <- function(data) {
  model_data <- data |> dplyr::select(id, diagnosis, dplyr::all_of(model_features))
  recipes::recipe(diagnosis ~ ., data = model_data) |>
    recipes::update_role(id, new_role = "id") |>
    recipes::step_normalize(recipes::all_numeric_predictors())
}

validate_input <- function(new_data, metadata, strict_bounds = TRUE) {
  missing <- setdiff(metadata$feature_names, names(new_data))
  if (length(missing) > 0) stop("Faltan campos obligatorios: ", paste(missing, collapse = ", "))

  values <- new_data[1, metadata$feature_names, drop = FALSE]
  for (feature in metadata$feature_names) values[[feature]] <- suppressWarnings(as.numeric(values[[feature]]))
  invalid <- names(values)[!vapply(values, function(x) length(x) == 1 && is.finite(x), logical(1))]
  if (length(invalid) > 0) stop("Campos numéricos inválidos: ", paste(invalid, collapse = ", "))

  if (strict_bounds) {
    bounds <- metadata$bounds
    outside <- vapply(seq_len(nrow(bounds)), function(i) {
      value <- values[[bounds$variable[[i]]]][[1]]
      value < bounds$minimo[[i]] || value > bounds$maximo[[i]]
    }, logical(1))
    out_of_range <- bounds$variable[outside]
    if (length(out_of_range) > 0) {
      stop("Valores fuera del rango observado en entrenamiento: ", paste(out_of_range, collapse = ", "))
    }
  }
  values
}
