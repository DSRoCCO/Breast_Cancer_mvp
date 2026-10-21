# Breast Cancer: análisis y MVP en R

Proyecto de portafolio que estudia características nucleares de masas mamarias y convierte el flujo analítico validado en un demostrador Shiny reproducible. Es un recurso académico: no es un dispositivo médico, no confirma diagnósticos y no debe utilizarse para decisiones clínicas.

El contenedor es la forma recomendada de ejecutar el MVP: fija R 4.3.3, restaura las dependencias bloqueadas y genera los artefactos del modelo desde los datos incluidos durante su construcción.

## Estructura

- `notebook/analisis_integral.qmd`: análisis reproducible y documentación metodológica.
- `report/analisis_integral.pdf`: informe exportado.
- `R/`: configuración, contrato de datos, artefactos descriptivos, entrenamiento y predicción.
- `app/`: interfaz Shiny y módulos de presentación.
- `artifacts/`: workflow, metadatos y resumen descriptivo generados localmente; no se versionan.
- `project_spec.md`: contrato trazable entre análisis, artefactos y MVP.
- `tests/`: pruebas de humo de los dos módulos.
- `Dockerfile`: construcción multi-etapa, prueba y ejecución de la aplicación.
- `.github/workflows/container.yml`: validación automática del contenedor en cada push y pull request.

## Ejecutar con Docker (recomendado)

### Requisitos

- Docker Engine 24+ o Docker Desktop. No se requiere tener R, Quarto ni paquetes de R instalados en el equipo anfitrión.
- Conexión a internet durante el primer `docker build`, para descargar la imagen base y restaurar los paquetes fijados en `renv.lock`.
- Puerto local `3838` disponible.

### Paso a paso

1. Clone el repositorio y entre en su raíz:

   ```bash
   git clone <URL-DEL-REPOSITORIO>
   cd Breast_Cancer_mvp
   ```

2. Construya la imagen. En esta etapa se restauran las versiones bloqueadas, se entrena Elastic Net con `data/data.csv`, se generan los artefactos y se ejecutan las pruebas de humo. La primera ejecución tarda más porque descarga dependencias.

   ```bash
   docker build --tag breast-cancer-mvp:local .
   ```

   La construcción termina correctamente sólo si aparece la prueba de humo superada. Si falla, la imagen no se genera.

3. Inicie el contenedor y publique el puerto sólo en la interfaz local:

   ```bash
   docker run --rm --name breast-cancer-mvp \
     --publish 127.0.0.1:3838:3838 \
     breast-cancer-mvp:local
   ```

4. Abra [http://127.0.0.1:3838](http://127.0.0.1:3838) en el navegador. La interfaz ofrece los módulos **Descriptivo** y **Predictivo**.

5. Detenga la aplicación con `Ctrl+C`. La opción `--rm` elimina el contenedor detenido; la imagen queda disponible para volver a iniciarla sin reconstruirla.

### Comprobaciones opcionales

En otra terminal, compruebe que Shiny responde y que el contenedor está saludable:

```bash
curl --fail http://127.0.0.1:3838/
docker inspect --format '{{.State.Health.Status}}' breast-cancer-mvp
```

El resultado esperado del segundo comando es `healthy` tras el periodo inicial de arranque. Para detener un contenedor iniciado sin `--rm`:

```bash
docker stop breast-cancer-mvp
docker rm breast-cancer-mvp
```

### Qué incluye la imagen

La construcción multi-etapa usa el CSV exclusivamente en la fase de entrenamiento. La imagen final contiene la aplicación Shiny, las dependencias restauradas y estos artefactos generados:

- `artifacts/modelo_breast_cancer.rds`
- `artifacts/modelo_breast_cancer_metadata.rds`
- `artifacts/resumen_descriptivo.rds`

No incluye el CSV, los tests, notebooks, informes, credenciales ni archivos de configuración local. Además, se ejecuta con un usuario sin privilegios (`shiny`).

## Ejecución local sin Docker

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

## Reproducir el análisis Quarto

`renv.lock` fija el entorno. Para reproducir el análisis:

```bash
quarto render notebook/analisis_integral.qmd --to html
quarto render notebook/analisis_integral.qmd --to pdf
mv notebook/analisis_integral.pdf report/analisis_integral.pdf
```

## Reproducibilidad y automatización

- `renv.lock` fija las versiones de los paquetes de R. No se instalan dependencias automáticamente desde el código de la aplicación.
- El `Dockerfile` usa R 4.3.3, entrena y prueba antes de publicar la imagen de ejecución.
- `.github/workflows/container.yml` reconstruye la imagen e inicia Shiny en cada push y pull request. Se conserva en Git precisamente para que GitHub pueda ejecutar esa validación, pero se excluye del contexto Docker porque no se necesita dentro de la imagen.
- `.gitignore` y `.dockerignore` excluyen secretos, configuración local de agentes/editores, cachés, artefactos locales, informes y datos innecesarios en tiempo de ejecución.

Para actualizar las dependencias de manera deliberada, ejecute el entrenamiento y las pruebas, después revise el cambio de `renv.lock` antes de versionarlo:

```bash
R -e 'renv::restore()'
Rscript R/train_model.R
Rscript tests/run_tests.R
```

## Datos

La fuente incluida corresponde al Breast Cancer Wisconsin (Diagnostic) dataset. Consulte su procedencia y condiciones de redistribución antes de publicar o redistribuir derivados fuera de este proyecto de portafolio.

## Licencia y uso responsable

El código se distribuye bajo la [licencia MIT](LICENSE). Se publica con fines académicos y de portafolio; la licencia permite reutilización bajo sus términos, pero no elimina las restricciones clínicas, éticas o de datos que correspondan a cada uso. No use esta aplicación para diagnóstico, triaje o decisiones sobre pacientes.
