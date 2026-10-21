# Breast Cancer: análisis y MVP en R

Proyecto de portafolio que estudia características nucleares de masas mamarias y convierte el flujo analítico validado en un demostrador Shiny. Es un recurso académico: no es un dispositivo médico ni debe utilizarse para diagnóstico o decisiones clínicas.

## Estructura

- `notebook/analisis_integral.qmd`: análisis reproducible y documentación metodológica.
- `report/analisis_integral.pdf`: informe exportado.
- `R/`: configuración, contrato de datos, artefactos descriptivos, entrenamiento y predicción.
- `app/`: interfaz Shiny y módulos de presentación.
- `artifacts/`: workflow, metadatos y resumen descriptivo generados localmente; no se versionan.
- `project_spec.md`: contrato trazable entre análisis, artefactos y MVP.
- `tests/`: pruebas de humo de los dos módulos.

## Ejecución local

Requiere R 4.3+, Quarto para regenerar el informe y las dependencias de `renv.lock`.

En Ubuntu/Debian, una instalación limpia puede requerir las cabeceras de sistema usadas por `igraph` y `httpuv` (Shiny):

```bash
sudo apt install libglpk-dev libuv1-dev
```

El aviso de `renv::restore()` sobre estas librerías no bloquea la ejecución cuando el entorno ya está sincronizado, como ocurrió en la validación local.

```bash
R -e 'renv::restore()'
Rscript R/train_model.R
Rscript tests/run_tests.R
R -e 'shiny::runApp("app", host = "127.0.0.1", port = 3838)'
```

El entrenamiento crea tres archivos locales: `artifacts/modelo_breast_cancer.rds`, `artifacts/modelo_breast_cancer_metadata.rds` y `artifacts/resumen_descriptivo.rds`. Los tres son necesarios para iniciar la aplicación y se excluyen de Git por ser artefactos binarios generados.

## Contrato del MVP

La app carga únicamente `R/` y los artefactos de `artifacts/`; no depende del notebook ni lee el CSV al iniciarse. Tiene dos módulos:

- **Descriptivo:** calidad, distribución B/M, separación estandarizada, AUROC univariado y correlación de las diez mediciones `_mean`, calculados como agregados durante el entrenamiento.
- **Predictivo académico:** escenario de 20 variables `mean + worst`, probabilidad/clase, contribuciones locales, PCA contextual y una lectura condicionada explícitamente no clínica.

El modelo normaliza dentro de su receta y aplica un umbral fijo de 0.50 para la clase M. El formulario valida campos obligatorios, valores numéricos finitos y rangos observados durante entrenamiento.

El resultado presenta probabilidad estimada, clase del modelo y contribuciones lineales locales. Estas contribuciones explican el cálculo del Elastic Net, no relaciones causales ni importancia clínica.

## Reproducción y entrega

`renv.lock` fija el entorno. Para reproducir el análisis:

```bash
quarto render notebook/analisis_integral.qmd --to html
quarto render notebook/analisis_integral.qmd --to pdf
mv notebook/analisis_integral.pdf report/analisis_integral.pdf
```

Antes de contenerizar, el contexto de Docker deberá incluir `app/`, `R/`, `artifacts/`, `renv/`, `.Rprofile` y `renv.lock`; deberá excluir notebooks, reportes, datos crudos, credenciales y cachés. La imagen debe ejecutar como usuario no root y validar que los tres artefactos se cargan durante el arranque. Docker todavía no se ha creado ni validado.

## Datos

La fuente incluida corresponde al Breast Cancer Wisconsin (Diagnostic) dataset. Consulte su procedencia y condiciones de redistribución antes de publicar o redistribuir derivados fuera de este proyecto de portafolio.
