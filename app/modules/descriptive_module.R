descriptive_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::fluidRow(
      shiny::column(12,
        shiny::h3("Análisis descriptivo"),
        shiny::p("Resume la calidad, composición y patrones observados en la muestra usada para construir el MVP."),
        shiny::tags$p(class = "text-muted", shiny::textOutput(ns("disclaimer")))
      )
    ),
    shiny::fluidRow(
      shiny::column(3, shiny::wellPanel(shiny::h5("Observaciones"), shiny::textOutput(ns("rows")))),
      shiny::column(3, shiny::wellPanel(shiny::h5("Mediciones"), shiny::textOutput(ns("measurements")))),
      shiny::column(3, shiny::wellPanel(shiny::h5("IDs únicos"), shiny::textOutput(ns("ids")))),
      shiny::column(3, shiny::wellPanel(shiny::h5("Valores faltantes"), shiny::textOutput(ns("missing"))))
    ),
    shiny::hr(),
    shiny::fluidRow(
      shiny::column(5, shiny::h4("Distribución del diagnóstico"), shiny::plotOutput(ns("diagnosis_plot"), height = 320)),
      shiny::column(7, shiny::h4("Qué muestra esta vista"), shiny::uiOutput(ns("context")))
    ),
    shiny::hr(),
    shiny::h4("Señal descriptiva de las mediciones promedio"),
    shiny::p("Cohen's d compara la media de malignos menos benignos en unidades de desviación estándar. El intervalo es una medida de incertidumbre de la estimación; no es una probabilidad individual."),
    shiny::plotOutput(ns("effects_plot"), height = 430),
    shiny::hr(),
    shiny::fluidRow(
      shiny::column(6,
        shiny::h4("Capacidad individual de ordenamiento"),
        shiny::p("AUROC univariado evalúa cada medición por separado: 0.50 equivale a azar; valores mayores indican mejor ordenamiento de M frente a B en esta muestra."),
        shiny::plotOutput(ns("auroc_plot"), height = 360)
      ),
      shiny::column(6,
        shiny::h4("Relaciones entre mediciones promedio"),
        shiny::p("La matriz muestra correlaciones lineales. Bloques intensos indican información compartida, no importancia clínica ni causalidad."),
        shiny::plotOutput(ns("correlation_plot"), height = 360)
      )
    )
  )
}

descriptive_server <- function(id, descriptive) {
  shiny::moduleServer(id, function(input, output, session) {
    output$disclaimer <- shiny::renderText(descriptive$disclaimer)
    output$rows <- shiny::renderText(format(descriptive$quality$rows, big.mark = ","))
    output$measurements <- shiny::renderText(descriptive$quality$raw_measurements)
    output$ids <- shiny::renderText(if (isTRUE(descriptive$quality$ids_unique)) "Sí" else "No")
    output$missing <- shiny::renderText(descriptive$quality$missing_values)

    output$diagnosis_plot <- shiny::renderPlot({
      d <- descriptive$class_counts
      d$label <- ifelse(d$diagnosis == "M", "Maligno (M)", "Benigno (B)")
      ggplot2::ggplot(d, ggplot2::aes(label, n, fill = diagnosis)) +
        ggplot2::geom_col(width = .62) +
        ggplot2::geom_text(ggplot2::aes(label = paste0(n, " (", scales::percent(proporcion, accuracy = .1), ")")), vjust = -0.35, size = 4) +
        ggplot2::scale_fill_manual(values = c("B" = "#0072B2", "M" = "#D55E00"), guide = "none") +
        ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(0, .15))) +
        ggplot2::labs(x = NULL, y = "Número de masas") + ggplot2::theme_minimal(base_size = 12)
    })

    output$context <- shiny::renderUI({
      counts <- descriptive$class_counts
      m <- counts$n[counts$diagnosis == "M"]
      b <- counts$n[counts$diagnosis == "B"]
      top_effect <- descriptive$effects_mean[1, ]
      top_auc <- descriptive$auroc_mean[1, ]
      strongest <- descriptive$strongest_correlation
      shiny::tagList(
        shiny::tags$p(sprintf("La evidencia corresponde a %s: %d benignas y %d malignas.", descriptive$unit, b, m)),
        shiny::tags$p(sprintf("Entre las medidas promedio, %s presenta la mayor separación estandarizada observada (Cohen's d = %.2f).", top_effect$etiqueta, top_effect$cohens_d)),
        shiny::tags$p(sprintf("Como señal aislada, %s obtiene AUROC = %.3f. El par promedio más correlacionado es %s y %s (r = %.3f).", top_auc$etiqueta, top_auc$auroc, feature_label(strongest$variable_1), feature_label(strongest$variable_2), strongest$correlacion)),
        shiny::tags$p(class = "text-muted", "Estos hallazgos describen la muestra; la decisión predictiva se consulta en el segundo módulo.")
      )
    })

    output$effects_plot <- shiny::renderPlot({
      d <- descriptive$effects_mean
      d$etiqueta <- factor(d$etiqueta, levels = rev(d$etiqueta))
      ggplot2::ggplot(d, ggplot2::aes(cohens_d, etiqueta)) +
        ggplot2::geom_vline(xintercept = 0, linetype = "dashed", colour = "#666666") +
        ggplot2::geom_errorbar(ggplot2::aes(xmin = inferior, xmax = superior), orientation = "y", width = .16, colour = "#6B6B6B") +
        ggplot2::geom_point(size = 3, colour = "#D55E00") +
        ggplot2::labs(x = "Cohen's d (M − B)", y = NULL) + ggplot2::theme_minimal(base_size = 12)
    })

    output$auroc_plot <- shiny::renderPlot({
      d <- descriptive$auroc_mean
      d$etiqueta <- factor(d$etiqueta, levels = rev(d$etiqueta))
      ggplot2::ggplot(d, ggplot2::aes(auroc, etiqueta)) +
        ggplot2::geom_vline(xintercept = .5, linetype = "dashed", colour = "#666666") +
        ggplot2::geom_col(fill = "#D55E00", width = .68) +
        # coord_cartesian amplía la región visible sin eliminar barras cuyo
        # origen geométrico está en cero.
        ggplot2::scale_x_continuous(labels = scales::label_percent(accuracy = 1)) +
        ggplot2::coord_cartesian(xlim = c(.45, 1)) +
        ggplot2::labs(x = "AUROC univariado", y = NULL) + ggplot2::theme_minimal(base_size = 11)
    })

    output$correlation_plot <- shiny::renderPlot({
      d <- descriptive$correlation_mean
      order <- unique(d$variable_1)
      d$variable_1 <- factor(feature_label(d$variable_1), levels = feature_label(order))
      d$variable_2 <- factor(feature_label(d$variable_2), levels = rev(feature_label(order)))
      ggplot2::ggplot(d, ggplot2::aes(variable_1, variable_2, fill = correlacion)) +
        ggplot2::geom_tile(colour = "white", linewidth = .35) +
        ggplot2::geom_text(ggplot2::aes(label = etiqueta_r), size = 2.35) +
        ggplot2::scale_fill_gradient2(low = "#2166AC", mid = "white", high = "#B2182B", midpoint = 0, limits = c(-1, 1)) +
        ggplot2::labs(x = NULL, y = NULL, fill = "r") +
        ggplot2::theme_minimal(base_size = 9) +
        ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 55, hjust = 1), panel.grid = ggplot2::element_blank())
    })
  })
}
