# Entregables – Lab 2: Introducción a Kubernetes y Helm

**Proyecto Integrador** – Desarrollo de Laboratorios y Prácticas Iterativas e Incrementales en un Cloud Provider (Alianza AWS-UNC).

Este documento define de forma explícita **qué debe entregar el alumno** para aprobar el Lab 2. Los entregables están alineados con la propuesta del PI (Solicitud de Proyecto Integrador) y con las consignas detalladas en la **Guía y consignas del Lab 2**.

---

## Marco del Lab 2 según la propuesta del PI

Según la Solicitud de Proyecto Integrador:

> *"Laboratorio 2 – Introducción a Kubernetes y Helm. Se desplegará la aplicación en un clúster de Kubernetes. Primero usando manifiestos básicos y luego utilizando Helm, mostrando cómo simplificar y parametrizar los despliegues."*

El alumno debe demostrar que es capaz de:

1. Desplegar las **imágenes del Lab 1** (backend y frontend en ECR) en un clúster Kubernetes local (Minikube).
2. Definir **manifiestos** de Deployment, Service y HPA para exponer y escalar el backend.
3. Empaquetar los despliegues en **charts Helm** parametrizables (puertos, tipo de Service, recursos, réplicas, autoscaling).
4. Configurar **metrics-server** y demostrar que el **HPA** escala y desescala bajo carga.
5. Ejecutar una **prueba de estrés** con JMeter dentro del clúster (Job + ConfigMap) y documentar los resultados.

---

## Prerrequisitos (Lab 1)

| Requisito | Descripción |
|-----------|-------------|
| **Imágenes en ECR** | Backend (`tp1-backend` o equivalente) y frontend (`tp1-frontend`) publicados desde el pipeline del Lab 1. |
| **Aplicación funcional** | API REST (.NET) y app web (React) que se comunican; mismos artefactos que en Docker Compose. |
| **Herramientas locales** | `kubectl`, `helm` (v3), Minikube (o clúster acordado con el docente). |

---

## Estructura del repositorio Lab 2

| Requisito | Descripción |
|-----------|-------------|
| **Carpeta `Kubernetes/`** | Manifiestos planos: backend (Deployment, Service, HPA), frontend, Job de JMeter, ConfigMap del plan de prueba. |
| **Carpeta `Helm/`** | Charts `backend` y `frontend`; overrides en `Helm/dev/` y opcionalmente `Helm/prd/`. |
| **Plan JMeter** | Archivo `.jmx` en `config/` y/o embebido en ConfigMap aplicable al clúster. |
| **Documentación** | Carpeta `docs/` con guía, entregables e informe según indicación del docente. |

---

## Listado de entregables obligatorios

| # | Entregable | Descripción | Formato | Relación con consignas |
|---|------------|-------------|---------|------------------------|
| **1** | **Repositorio Lab 2** | Código de manifiestos, charts Helm y configuración JMeter. Accesible para el corrector. | Repo Git (GitHub u otro) | C2, C3, C6 |
| **2** | **Despliegue con manifiestos** | Backend y frontend aplicados con `kubectl apply`; Services operativos; HPA definido para el backend. | YAML en `Kubernetes/` + evidencia (`kubectl get pods,svc,hpa`) | C2, C4, C5 |
| **3** | **Despliegue con Helm** | Instalación de charts backend y frontend con valores por entorno (`-f Helm/dev/...`). Parámetros documentados en README o informe. | Charts en `Helm/` + evidencia (`helm list`, valores usados) | C3, C4 |
| **4** | **Exposición de la aplicación** | App accesible desde fuera del clúster: NodePort (manifiestos) y/o Ingress (Helm). | Capturas o URL de acceso (`minikube service`, `app.local`, etc.) | C4 |
| **5** | **HPA y metrics-server** | metrics-server instalado; HPA reacciona a carga (tabla o capturas de réplicas vs tiempo). Al menos un escenario de escalado documentado. | Evidencia en informe + `kubectl describe hpa` | C5 |
| **6** | **Prueba de estrés JMeter** | Job de Kubernetes + ConfigMap; ejecución contra el Service del backend; archivo `results.jtl` localizable (ej. `/outputs/results.jtl`). | YAML del Job + logs o `kubectl cp` | C6 |
| **7** | **Informe breve** | Paso a paso de lo realizado: Minikube, manifiestos, Helm, parametrización, HPA, JMeter y conclusiones de las pruebas de escalado. | PDF o Markdown según indicación del docente | C1, C5, C6 |

---

## Parametrización Helm exigida (backend y frontend)

El chart del **backend** debe permitir configurar al menos (vía `values.yaml` o overrides), sin editar templates:

| Parámetro | Ejemplo en este repo |
|-----------|----------------------|
| Puerto del contenedor | `containerPort: 8080` |
| Tipo de Service | `service.type` (ClusterIP, NodePort) |
| Puerto del Service | `service.port`, `service.targetPort` |
| NodePort (si aplica) | `service.nodePort` (template condicional) |
| Resources | `resources.requests` / `resources.limits` (CPU, memoria) |
| Réplicas estáticas | `replicaCount` (cuando HPA deshabilitado) |
| Autoscaling | `autoscaling.enabled`, `minReplicas`, `maxReplicas`, `targetCPUUtilizationPercentage` |

El chart del **frontend** debe parametrizar imagen, Service, Ingress (host, paths, backend de `/api`) y variables de entorno relevantes (`VITE_API_BASE_URL`).

---

## Criterios de aceptación mínimos

Para considerar el Lab 2 **aprobado**, debe cumplirse lo siguiente:

| Criterio | Verificación |
|----------|--------------|
| **Imágenes del Lab 1** | Deployments usan imágenes de ECR del backend y frontend; Pods en estado `Running`. |
| **Manifiestos planos** | `kubectl apply -f Kubernetes/backend.yaml` y `frontend.yaml` sin error; Services responden. |
| **Helm** | `helm upgrade --install` de ambos charts con archivo de valores; cambiar un parámetro en values y reaplicar sin tocar templates. |
| **Service / Ingress** | Corrector puede alcanzar la API o la UI según lo documentado (NodePort o Ingress). |
| **metrics-server** | `kubectl top pods` devuelve métricas; HPA no permanece en `<unknown>`. |
| **Escalado bajo carga** | Durante JMeter (u otra carga), `kubectl get hpa` muestra aumento de réplicas; tras la carga, desescalado observable (puede tardar varios minutos). |
| **JMeter como Job** | Manifiesto `Job` (no Pod manual permanente); ConfigMap montado; resultados inspeccionables. |
| **Análisis HPA vs VPA** | Informe menciona por qué se usó HPA (escala horizontal) y qué haría un VPA (escala vertical). No es obligatorio implementar VPA. |

---

## Escenarios de prueba de escalado (referencia)

El docente puede pedir que el informe documente variaciones como las siguientes (realizadas en el desarrollo del lab):

| Prueba | maxReplicas | Configuración destacada | Resultado esperado a documentar |
|--------|-------------|-------------------------|-------------------------------|
| 1 | 5 | CPU request 200m, target HPA 70 %, carga sostenida | HPA alcanza 5 réplicas por CPU sobre el umbral |
| 2 | 15 | Misma carga | Escala hasta 15; CPU se estabiliza cerca del target |
| 3 | 20 | Carga alta, clúster con poca RAM | OOM o Pods pendientes al acercarse al límite del nodo (~18 réplicas) |
| 4 | 20 | Resources y carga reducidos | Escala de 1 a ~11 réplicas; desescalado ~5 min después de la carga |

La carga reproducible en el repositorio está definida en `Kubernetes/configmap.yaml` (100 hilos, 600 s, timer de throughput). El informe debe describir la configuración **real** del JMX aplicado, no solo valores aproximados.

---

## Resumen por consigna (referencia cruzada)

- **C1 (Conceptos K8s, Minikube, Helm):** README + sección de marco teórico en informe → entregables **7**.
- **C2 (Manifiestos):** Deployment, Service, HPA en `Kubernetes/` → entregables **1**, **2**.
- **C3 (Helm parametrizado):** Charts backend y frontend → entregables **1**, **3**.
- **C4 (Exponer la app):** NodePort y/o Ingress → entregables **2**, **3**, **4**.
- **C5 (HPA + metrics-server):** Escalado demostrado → entregables **5**, **7**.
- **C6 (JMeter Job + ConfigMap):** Prueba de estrés → entregables **6**, **7**.

---

## Notas para el docente

- **Plazos y formato:** El docente puede fijar plazos y formato del informe (PDF, extensión máxima, entrega por campus).
- **Clúster:** Se asume Minikube; si se usa kind, k3d o EKS de práctica, debe documentarse en la guía del curso.
- **Fuente del plan JMeter:** Para reproducibilidad, indicar si la verdad operativa es `Kubernetes/configmap.yaml` o `config/test-plan.jmx` (pueden diferir; alinear antes de evaluar).
- **Evaluación:** Cada consigna C1–C6 puede evaluarse de forma independiente; este documento unifica qué entregar.

---

*Documento basado en la Solicitud de Proyecto Integrador y en la Guía y consignas del Lab 2. Para el detalle de cada consigna y los comandos paso a paso, consultar `guia-y-consignas-lab2.md`.*
