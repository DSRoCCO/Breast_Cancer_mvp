# Entrena el artefacto de servicio. Ejecutar desde la raíz del proyecto:
# Rscript R/train_model.R

source(file.path("R", "config.R"))
source(file.path("R", "preprocess.R"))
source(file.path("R", "descriptive.R"))

required <- c("dplyr", "tidyr", "rsample", "recipes", "parsnip", "workflows", "tune", "dials", "yardstick", "glmnet")
missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing) > 0) stop("Paquetes requeridos: ", paste(missing, collapse = ", "))

set.seed(20261017)
paths <- mvp_paths()
data <- read_breast_data(paths$data)
split <- rsample::initial_split(data, prop = .80, strata = diagnosis)
train <- rsample::training(split)
test <- rsample::testing(split)

metrics <- yardstick::metric_set(yardstick::sens, yardstick::spec, yardstick::ppv,
                                 yardstick::bal_accuracy, yardstick::accuracy, yardstick::roc_auc)
resamples <- rsample::vfold_cv(train, v = 5, repeats = 3, strata = diagnosis)

workflow_tunable <- workflows::workflow() |>
  workflows::add_recipe(build_model_recipe(train)) |>
  workflows::add_model(parsnip::logistic_reg(penalty = tune::tune(), mixture = tune::tune()) |>
                         parsnip::set_engine("glmnet"))

set.seed(20261022)
tuned <- tune::tune_grid(
  workflow_tunable, resamples = resamples,
  grid = dials::grid_regular(dials::penalty(range = c(-5, -1)), dials::mixture(), levels = 4),
  metrics = metrics
)
best <- tune::select_best(tuned, metric = "sens")
selected_workflow <- tune::finalize_workflow(workflow_tunable, best)

# La prueba se evalúa una sola vez para dejar constancia de la evaluación
# académica. El artefacto de servicio se refita con toda la fuente después de
# fijar configuración y parámetros exclusivamente con entrenamiento.
held_out <- tune::last_fit(selected_workflow, split = split, metrics = metrics)
held_out_metrics <- tune::collect_metrics(held_out)
final_workflow <- workflows::fit(selected_workflow, data = data)

engine <- workflows::extract_fit_engine(final_workflow)
# glmnet binomial expresa el recorrido respecto de la segunda clase (B cuando
# los niveles son M, B). Se invierte para que contribuciones positivas indiquen
# aumento de la probabilidad reportada de M.
coef_matrix <- as.matrix(glmnet::coef.glmnet(engine, s = as.numeric(best$penalty)))
coefficient_sign <- if (identical(engine$classnames[[1]], "M")) -1 else 1
coefficients <- data.frame(
  variable = rownames(coef_matrix), coeficiente = coefficient_sign * as.numeric(coef_matrix[, 1]),
  row.names = NULL, check.names = FALSE
)
normalization <- data |>
  dplyr::summarise(dplyr::across(dplyr::all_of(model_features), list(media = mean, sd = sd))) |>
  tidyr::pivot_longer(dplyr::everything(), names_to = c("variable", ".value"),
                      names_pattern = "(.*)_(media|sd)$")
bounds <- data |>
  dplyr::summarise(dplyr::across(dplyr::all_of(model_features), list(minimo = min, maximo = max))) |>
  tidyr::pivot_longer(dplyr::everything(), names_to = c("variable", ".value"),
                      names_pattern = "(.*)_(minimo|maximo)$")

metadata <- list(
  schema_version = mvp_schema_version,
  model_name = "Elastic Net",
  model_version = format(Sys.Date(), "%Y-%m-%d"),
  target = "diagnosis",
  positive_class = "M",
  threshold = 0.50,
  representation = "mean + worst",
  feature_names = model_features,
  training_rows = nrow(data),
  source = "Breast Cancer Wisconsin (Diagnostic), data/data.csv",
  selected_parameters = best,
  held_out_metrics = held_out_metrics,
  coefficients = coefficients,
  normalization = normalization,
  bounds = bounds,
  disclaimer = "Demostrador académico; no usar para diagnóstico ni decisiones clínicas."
)

dir.create(paths$artifacts, showWarnings = FALSE, recursive = TRUE)
saveRDS(final_workflow, paths$model)
saveRDS(metadata, paths$model_metadata)
save_descriptive_summary(data, paths$descriptive)
message("Artefactos creados en artifacts/. Modelo: Elastic Net con ", length(model_features), " predictores y resumen descriptivo.")
