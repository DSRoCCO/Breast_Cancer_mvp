library(shiny)
library(ggplot2)
library(scales)

# shiny::runApp("app") ejecuta desde app/; el origen también funciona desde raíz.
project_root <- if (file.exists(file.path("R", "config.R"))) normalizePath(".") else normalizePath("..")
source(file.path(project_root, "R", "config.R"))
source(file.path(project_root, "R", "preprocess.R"))
source(file.path(project_root, "R", "predict.R"))
source(file.path(project_root, "R", "descriptive.R"))
source(file.path(project_root, "app", "modules", "descriptive_module.R"))
source(file.path(project_root, "app", "modules", "predictive_module.R"))

paths <- mvp_paths(project_root)
bundle <- load_model_bundle(paths$artifacts)
descriptive <- load_descriptive_summary(paths$descriptive)

ui <- navbarPage(
  title = "Breast Cancer MVP · R/Shiny",
  tabPanel("Descriptivo", descriptive_ui("descriptive")),
  tabPanel("Predictivo", predictive_ui("predictive")),
  footer = tags$div(class = "container text-muted", style = "padding: 14px 0 20px;",
    "MVP académico basado en Breast Cancer Wisconsin (Diagnostic). No usar para diagnóstico ni decisiones clínicas.")
)

server <- function(input, output, session) {
  descriptive_server("descriptive", descriptive)
  predictive_server("predictive", bundle, descriptive)
}

shinyApp(ui, server)
