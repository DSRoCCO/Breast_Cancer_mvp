# Prueba de humo sin dependencias adicionales.
if (!file.exists(file.path("artifacts", "modelo_breast_cancer.rds"))) {
  stop("No hay artefacto para probar. Ejecute primero: Rscript R/train_model.R")
}
source(file.path("R", "config.R"))
source(file.path("R", "preprocess.R"))
source(file.path("R", "predict.R"))
source(file.path("R", "descriptive.R"))

bundle <- load_model_bundle()
example <- as.data.frame(as.list(bundle$metadata$normalization$media), check.names = FALSE)
names(example) <- bundle$metadata$normalization$variable
prediction <- predict_breast_cancer(example, bundle)

stopifnot(is.finite(prediction$probability_malignant))
stopifnot(prediction$predicted_class %in% c("B", "M"))

missing_field_error <- tryCatch({
  predict_breast_cancer(example[, -1, drop = FALSE], bundle)
  FALSE
}, error = function(e) grepl("Faltan campos", conditionMessage(e)))
stopifnot(missing_field_error)

descriptive <- load_descriptive_summary(mvp_paths()$descriptive)
stopifnot(descriptive$quality$rows == 569L)
stopifnot(sum(descriptive$class_counts$n) == 569L)
stopifnot(all(c("B", "M") %in% descriptive$class_counts$diagnosis))
stopifnot(nrow(descriptive$effects_mean) == 10L)
stopifnot(nrow(descriptive$correlation_mean) == 55L)
stopifnot(nrow(descriptive$pca_input_context$scores) == 569L)
stopifnot(identical(descriptive$pca_input_context$feature_names, bundle$metadata$feature_names))
stopifnot(nrow(prediction$contributions) > 0L)
contrast <- example
contrast$radius_worst <- bundle$metadata$bounds$maximo[bundle$metadata$bounds$variable == "radius_worst"]
contrast_prediction <- predict_breast_cancer(contrast, bundle)
stopifnot(max(abs(contrast_prediction$contributions$contribucion)) > 0)

app_environment <- new.env(parent = globalenv())
source(file.path("app", "app.R"), local = app_environment)
stopifnot(inherits(app_environment$ui, "shiny.tag.list") || inherits(app_environment$ui, "shiny.tag"))
format_environment <- new.env(parent = globalenv())
source(file.path("app", "modules", "predictive_module.R"), local = format_environment)
stopifnot(identical(format_environment$format_example_value(12), "12.00"))
stopifnot(identical(format_environment$format_example_value(0.1), "0.100"))
stopifnot(identical(format_environment$format_example_value(0.01), "0.0100"))
radius_label <- format_environment$feature_input_label("radius_mean", bundle$metadata$bounds)
stopifnot(grepl("Radius Mean \\(rango observado: 6.98 – 28.11\\)", radius_label))
message("Pruebas de humo superadas: contrato predictivo, artefacto descriptivo e inicio de Shiny válidos.")
