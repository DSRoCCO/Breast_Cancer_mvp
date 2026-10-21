# Configuración central del MVP. No contiene secretos ni lógica de interfaz.

mvp_schema_version <- "1.0.0"

resolve_project_root <- function() {
  if (file.exists(file.path("R", "preprocess.R"))) return(normalizePath("."))
  if (file.exists(file.path("..", "R", "preprocess.R"))) return(normalizePath(".."))
  stop("No se pudo resolver la raíz del proyecto.")
}

mvp_paths <- function(project_root = resolve_project_root()) {
  list(
    data = file.path(project_root, "data", "data.csv"),
    artifacts = file.path(project_root, "artifacts"),
    model = file.path(project_root, "artifacts", "modelo_breast_cancer.rds"),
    model_metadata = file.path(project_root, "artifacts", "modelo_breast_cancer_metadata.rds"),
    descriptive = file.path(project_root, "artifacts", "resumen_descriptivo.rds")
  )
}
