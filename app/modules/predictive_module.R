predictive_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::fluidPage(
    shiny::fluidRow(
      shiny::column(12,
        shiny::h3("Análisis prescriptivo académico"),
        shiny::p("Evalúe un escenario de mediciones. La salida es una estimación del modelo, no un diagnóstico ni una indicación médica."),
        shiny::tags$p(class = "text-muted", shiny::textOutput(ns("disclaimer")))
      )
    ),
    shiny::sidebarLayout(
      shiny::sidebarPanel(
        shiny::h4("Escenario de entrada"),
        shiny::tags$p("Se precargan valores de ejemplo: medias observadas durante entrenamiento. Reemplácelos por un escenario válido; se validan tipo numérico y rango observado."),
        shiny::uiOutput(ns("feature_inputs")),
        shiny::fluidRow(
          shiny::column(7, shiny::actionButton(ns("evaluate"), "Evaluar escenario", class = "btn-primary", width = "100%")),
          shiny::column(5, shiny::actionButton(ns("reset"), "Restablecer ejemplo", width = "100%"))
        )
      ),
      shiny::mainPanel(
        shiny::h4("Resultado del escenario"), shiny::uiOutput(ns("result")),
        shiny::h4("Lectura operativa condicionada"), shiny::uiOutput(ns("guidance")),
        shiny::h4("Explicación local del modelo"),
        shiny::tags$p("Las barras muestran las contribuciones lineales más grandes para este escenario. Describen el cálculo del Elastic Net; no prueban causalidad ni importancia clínica independiente."),
        shiny::plotOutput(ns("contributions"), height = 330),
        shiny::h4("Ubicación exploratoria del escenario"),
        shiny::tags$p("PCA proyecta el escenario junto a casos históricos usando las mismas 20 entradas. Muestra similitud geométrica, no una explicación del modelo, un diagnóstico ni grupos clínicos definidos."),
        shiny::plotOutput(ns("pca_context"), height = 380),
        shiny::h4("Contrato del modelo"), shiny::tableOutput(ns("model_info"))
      )
    )
  )
}

format_example_value <- function(value) {
  if (!is.finite(value) || value == 0) return(formatC(value, format = "f", digits = 2))
  digits <- as.integer(2 + max(0, ceiling(-log10(abs(value)))))
  formatC(value, format = "f", digits = digits)
}

feature_input_label <- function(feature, bounds) {
  range <- bounds[bounds$variable == feature, , drop = FALSE]
  if (nrow(range) != 1) stop("No existe un rango de entrenamiento para: ", feature)
  sprintf(
    "%s (rango observado: %s – %s)",
    feature_label(feature),
    format_example_value(range$minimo[[1]]),
    format_example_value(range$maximo[[1]])
  )
}

predictive_server <- function(id, bundle, descriptive) {
  shiny::moduleServer(id, function(input, output, session) {
    # Mantiene una precisión legible según la escala: 12 -> 12.00,
    # 0.1 -> 0.100, 0.01 -> 0.0100. El texto se conserva en el input
    # numérico para que los ceros finales sean visibles en la interfaz.
    example_values <- stats::setNames(vapply(
      bundle$metadata$normalization$media,
      format_example_value,
      character(1)
    ), bundle$metadata$normalization$variable)
    output$disclaimer <- shiny::renderText(bundle$metadata$disclaimer)
    output$feature_inputs <- shiny::renderUI({
      shiny::tagList(lapply(c("_mean", "_worst"), function(suffix) {
        vars <- bundle$metadata$feature_names[endsWith(bundle$metadata$feature_names, suffix)]
        shiny::tagList(shiny::h5(ifelse(suffix == "_mean", "Mediciones promedio (mean)", "Peor valor (worst)")),
          lapply(vars, function(feature) shiny::numericInput(
            session$ns(feature), feature_input_label(feature, bundle$metadata$bounds), value = example_values[[feature]]
          )))
      }))
    })
    shiny::observeEvent(input$reset, lapply(bundle$metadata$feature_names, function(feature) shiny::updateNumericInput(session, feature, value = example_values[[feature]])), ignoreInit = TRUE)
    submitted <- shiny::eventReactive(input$evaluate, {
      values <- as.data.frame(as.list(lapply(bundle$metadata$feature_names, function(x) input[[x]])), check.names = FALSE)
      names(values) <- bundle$metadata$feature_names
      tryCatch(predict_breast_cancer(values, bundle), error = function(e) e)
    })
    output$result <- shiny::renderUI({
      result <- submitted()
      if (is.null(result)) return(shiny::tags$p("Complete las mediciones y presione “Evaluar escenario”."))
      if (inherits(result, "error")) return(shiny::div(class = "alert alert-danger", conditionMessage(result)))
      label <- if (result$predicted_class == "M") "Salida del modelo: M (maligno)" else "Salida del modelo: B (benigno)"
      color <- if (result$predicted_class == "M") "alert-warning" else "alert-info"
      shiny::div(class = paste("alert", color), shiny::tags$strong(label), shiny::tags$br(),
        paste0("Probabilidad estimada de clase M: ", scales::percent(result$probability_malignant, accuracy = .1)), shiny::tags$br(),
        paste0("Umbral fijo predefinido: ", result$metadata$threshold))
    })
    output$guidance <- shiny::renderUI({
      result <- submitted()
      if (is.null(result) || inherits(result, "error")) return(shiny::tags$p("La guía se mostrará cuando exista un escenario válido."))
      if (result$predicted_class == "M") shiny::div(class = "alert alert-warning", "El escenario supera el umbral académico del modelo. No confirma malignidad: cualquier evaluación clínica debe seguir protocolos, profesionales y pruebas diagnósticas independientes.") else shiny::div(class = "alert alert-info", "El escenario no supera el umbral académico. No descarta malignidad ni sustituye evaluación clínica; no debe usarse para modificar atención médica.")
    })
    output$contributions <- shiny::renderPlot({
      result <- submitted()
      shiny::req(!is.null(result), !inherits(result, "error"))
      d <- result$contributions
      d$variable <- factor(feature_label(d$variable), levels = rev(feature_label(d$variable)))
      d$direccion <- ifelse(d$contribucion >= 0, "Hacia M", "Hacia B")
      ggplot2::ggplot(d, ggplot2::aes(contribucion, variable, fill = direccion)) +
        ggplot2::geom_col() + ggplot2::geom_vline(xintercept = 0, linetype = "dashed") +
        ggplot2::scale_fill_manual(values = c("Hacia M" = "#D55E00", "Hacia B" = "#0072B2")) +
        ggplot2::labs(x = "Contribución lineal local", y = NULL, fill = NULL) + ggplot2::theme_minimal(base_size = 11)
    })
    output$pca_context <- shiny::renderPlot({
      result <- submitted()
      shiny::req(!is.null(result), !inherits(result, "error"))
      pca <- descriptive$pca_input_context
      ordered_values <- vapply(pca$feature_names, function(feature) result$input_values[[feature]][[1]], numeric(1))
      standardized <- (ordered_values - pca$center) / pca$scale
      coordinates <- as.numeric(standardized %*% pca$rotation)
      point <- data.frame(PC1 = coordinates[[1]], PC2 = coordinates[[2]])
      ggplot2::ggplot(pca$scores, ggplot2::aes(PC1, PC2, colour = diagnosis)) +
        ggplot2::geom_point(alpha = .35, size = 1.7) +
        ggplot2::geom_point(data = point, shape = 21, fill = "#FFFFFF", colour = "#000000", stroke = 1.2, size = 4) +
        ggplot2::scale_colour_manual(values = c("B" = "#0072B2", "M" = "#D55E00"), name = "Histórico") +
        ggplot2::labs(x = "Componente principal 1", y = "Componente principal 2") +
        ggplot2::theme_minimal(base_size = 11)
    })
    output$model_info <- shiny::renderTable({
      data.frame(Elemento = c("Modelo", "Representación", "Predictores", "Umbral", "Observaciones de entrenamiento"),
        Valor = c(bundle$metadata$model_name, bundle$metadata$representation, length(bundle$metadata$feature_names), bundle$metadata$threshold, bundle$metadata$training_rows))
    }, striped = TRUE, bordered = TRUE)
  })
}
