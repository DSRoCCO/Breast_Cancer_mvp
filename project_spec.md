# Contrato del MVP: análisis de masas mamarias

## Propósito y usuarios

Este MVP académico permite a una persona revisora explorar los patrones del conjunto Breast Cancer Wisconsin (Diagnostic) y consultar la salida de un clasificador entrenado. No apoya una decisión clínica real, no sustituye pruebas médicas ni determina tratamiento.

La interfaz responde dos preguntas distintas:

1. **Descriptivo y diagnóstico:** ¿qué calidad, composición, señal individual y redundancia presentan las mediciones de la muestra histórica?
2. **Predictivo y prescriptivo académico:** para un escenario de 20 mediciones, ¿cuál es la probabilidad estimada por el modelo y qué lectura operativa limitada corresponde al lado del umbral fijo?

## Evidencia de origen

- Unidad: una masa mamaria analizada mediante FNA.
- Fuente: Breast Cancer Wisconsin (Diagnostic), `data/data.csv`.
- Población disponible: 569 observaciones; 357 B y 212 M.
- Target: `diagnosis`, donde `M` es la clase positiva.
- Momento: el conjunto no contiene fechas, datos demográficos, seguimiento ni información sobre disponibilidad prospectiva. Se asume sólo para este demostrador que las mediciones están disponibles al momento de la consulta; esta condición debe verificarse antes de cualquier uso real.
- Evidencia: `notebook/analisis_integral.qmd`, secciones 2--9. En particular, las secciones 4--6 respaldan las vistas descriptivas y las secciones 7--8 respaldan el pipeline predictivo.

## Flujo y entradas

El flujo es interactivo y local. El módulo descriptivo carga exclusivamente agregados precomputados. El módulo predictivo recibe las 20 mediciones `mean + worst` usadas por el workflow Elastic Net. Todas son numéricas, obligatorias y deben estar dentro de los rangos observados durante entrenamiento.

La aplicación no acepta ID, target, valores `_se`, fechas ni datos clínicos. Rechaza campos ausentes, no finitos y fuera de rango. El entrenamiento rechaza IDs duplicados, filas duplicadas completas, diagnósticos distintos de B/M, columnas faltantes y mediciones no numéricas/no finitas. La columna final vacía provocada por el delimitador CSV se elimina sólo de la vista de trabajo; el CSV original nunca se sobrescribe.

## Decisión predictiva y límites

El workflow se seleccionó en entrenamiento mediante validación cruzada estratificada repetida; la configuración se fijó antes de la prueba 80/20 reservada. La sensibilidad de M fue el criterio primario y AUROC/balanced accuracy son controles. La regla mayoritaria B es la baseline documentada en el análisis.

El umbral 0.50 es fijo y académico: no fue optimizado en la prueba, no representa costos clínicos y no puede interpretarse como prevalencia, riesgo clínico calibrado o recomendación terapéutica. La lectura prescriptiva se limita a indicar que un resultado a cada lado del umbral requiere evaluación independiente según protocolos profesionales; no confirma ni descarta malignidad.

No-go para uso prospectivo: falta de validación externa y temporal, falta de calibración clínica y definición de costos de error, evidencia de fuga, degradación frente a la baseline, o datos fuera del contrato de entrada.

## Artefactos y trazabilidad

| Artefacto | Productor | Consumidor | Contrato y regeneración |
|---|---|---|---|
| `artifacts/modelo_breast_cancer.rds` | `R/train_model.R` | `R/predict.R`, módulo predictivo | Workflow ajustado (receta + Elastic Net). Regenerar con `Rscript R/train_model.R`. |
| `artifacts/modelo_breast_cancer_metadata.rds` | `R/train_model.R` | `R/predict.R`, módulo predictivo | Variables, umbral, rangos, normalización, parámetros y métricas de prueba. |
| `artifacts/resumen_descriptivo.rds` | `R/train_model.R` + `R/descriptive.R` | módulos descriptivo y predictivo | Agregados sin ID: calidad, clases, Cohen's d, AUROC univariado, correlación `_mean`, varianza PCA y coordenadas PCA anonimizadas para contextualizar un escenario. |
| `data/data.csv` | fuente local | sólo entrenamiento/reproducción | Entrada inmutable; no se carga al iniciar Shiny. |

El esquema de los agregados descriptivos se versiona mediante `mvp_schema_version`. Los `.rds` son generados y no se publican en Git; quien clone el proyecto debe restaurar `renv` y ejecutar el entrenamiento para producirlos.

## Criterios de aceptación

- La aplicación inicia sin notebook ni CSV y carga los tres artefactos compatibles.
- Ambos módulos son visibles y sus cálculos proceden de los artefactos declarados.
- Una entrada válida produce probabilidad, clase, contribuciones y lectura condicionada; una inválida devuelve un error accionable.
- Las pruebas verifican contrato de fuente, artefacto descriptivo, predicción e inicio de la aplicación.
- La documentación permite restaurar dependencias, regenerar artefactos, ejecutar pruebas e iniciar Shiny.

## Exclusiones conocidas

No hay inferencia causal, clusters clínicos, evaluación de equidad, estabilidad temporal, validación externa, autenticación, persistencia de consultas, API ni despliegue. El proyecto incluye Docker y una validación CI del contenedor; eso no equivale a aprobación clínica ni despliegue externo.
