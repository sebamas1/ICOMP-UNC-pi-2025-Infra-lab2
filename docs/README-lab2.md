# Lab 2: Introducción a Kubernetes y Helm

## Introducción a los temas del laboratorio

Este laboratorio continúa el ciclo iniciado en el Lab 1: las imágenes Docker del backend y del frontend ya están en **Amazon ECR**; ahora hay que **orquestarlas** en un clúster de **Kubernetes**, parametrizar los despliegues con **Helm**, exponer la aplicación mediante **Services** (y opcionalmente **Ingress**), escalar horizontalmente con el **Horizontal Pod Autoscaler (HPA)** y validar el comportamiento bajo carga con **JMeter** ejecutado dentro del clúster.

Es el puente entre la containerización y el pipeline del Lab 1 y los laboratorios siguientes (Terraform, EKS, monitoreo con Prometheus/Grafana, etc.).

---

## Kubernetes

- **Kubernetes (K8s)** es una plataforma de orquestación de contenedores. Agrupa contenedores en **Pods**, los mantiene con **Deployments** (réplicas, actualizaciones, reinicios) y los conecta con la red mediante **Services**.

- **Objetos principales en este lab:**
  - **Deployment**: define cuántas réplicas de una aplicación corren y qué imagen usan.
  - **Service**: expone un conjunto de Pods con una IP/DNS estable dentro del clúster (y, según el tipo, hacia fuera).
  - **HorizontalPodAutoscaler (HPA)**: aumenta o reduce réplicas según métricas (aquí, uso de CPU respecto al *request*).
  - **ConfigMap**: almacena configuración o archivos (por ejemplo, un plan `.jmx` de JMeter).
  - **Job**: ejecuta uno o más Pods hasta completar una tarea y terminar (ideal para pruebas de carga puntuales).

- **Por qué Kubernetes después de Docker:** la misma imagen del Lab 1 puede ejecutarse en varias réplicas, recuperarse ante fallos y escalarse según demanda, sin reconfigurar manualmente cada contenedor.

---

## Minikube

- **Minikube** levanta un clúster de Kubernetes de un solo nodo en la máquina local. Permite practicar `kubectl`, Helm, HPA e Ingress sin costo de nube.

- **Limitaciones relevantes para este lab:** CPU y RAM del host son finitas. En pruebas de estrés con muchas réplicas del backend, el nodo puede quedarse sin memoria (comportamiento observado al escalar hacia 18–20 Pods en Minikube). Eso es útil pedagógicamente: muestra que el autoscaling no es infinito y depende de la capacidad del clúster.

---

## Helm

- **Helm** es el gestor de paquetes de Kubernetes. Un **chart** empaqueta plantillas YAML (`templates/`) y valores por defecto (`values.yaml`). Un **release** es una instalación concreta del chart en el clúster.

- **Ventajas frente a manifiestos planos:** parametrizar puertos, tipo de Service, recursos, réplicas y HPA sin duplicar YAML; separar entornos con archivos `-f Helm/dev/backend.yaml` o `Helm/prd/backend.yaml`.

- En este repositorio hay charts para **backend** y **frontend**, con overrides **dev** (integración) y **prd** (imágenes y recursos de producción en ECR).

---

## Exposición de la aplicación

| Enfoque | Dónde | Cómo accede el usuario |
|---------|--------|-------------------------|
| **NodePort** | Manifiestos en `Kubernetes/` | El Service publica puertos en el nodo (ej. 30081 backend, 30080 frontend). Útil para pruebas rápidas con `minikube service`. |
| **ClusterIP + Ingress** | Chart Helm del frontend | El frontend y el backend se exponen bajo un host (`app.local`) con rutas `/` (UI) y `/api` (API). Requiere Ingress Controller (nginx en Minikube). |

Ambos enfoques cumplen el objetivo de **exponer la app como Service**; Helm añade Ingress como capa HTTP unificada.

---

## Escalado: HPA y metrics-server

- El **Horizontal Pod Autoscaler (HPA)** observa métricas (típicamente CPU) y ajusta `replicas` del Deployment entre `minReplicas` y `maxReplicas` cuando el uso supera o baja del umbral configurado (ej. 70 % del CPU *request*).

- **metrics-server** es un componente del clúster que agrega uso de CPU/memoria de los Pods. Sin él, `kubectl get hpa` puede mostrar `<unknown>` y el HPA no escala.

- **VPA (Vertical Pod Autoscaler):** ajusta *requests/limits* por Pod, no el número de réplicas. En el sprint se **analizó** HPA frente a VPA; para este lab se implementó **HPA** porque el objetivo pedagógico es escalar réplicas bajo carga HTTP.

---

## Pruebas de estrés con JMeter

- **JMeter** genera tráfico HTTP contra el backend (en este lab, `GET` a `/api/devices`).

- El plan se monta con un **ConfigMap** y se ejecuta en un **Job** de Kubernetes (imagen `justb4/jmeter:5.5`), no en un Pod suelto indefinido: el Job termina al finalizar el test y permite inspeccionar logs y el archivo `results.jtl` en `/outputs/results.jtl`.

- La carga configurada en el ConfigMap del repositorio usa 100 hilos, duración 600 s (10 min) y un **Constant Throughput Timer** para acotar la tasa de peticiones (ver comentarios en `Kubernetes/configmap.yaml`).

---

## Relación con el Proyecto Integrador

Según la Solicitud de Proyecto Integrador:

> *"Laboratorio 2 – Introducción a Kubernetes y Helm. Se desplegará la aplicación en un clúster de Kubernetes. Primero usando manifiestos básicos y luego utilizando Helm, mostrando cómo simplificar y parametrizar los despliegues."*

Las imágenes provienen del Lab 1 (`tp1-backend`, `tp1-frontend` en ECR). Este lab demuestra orquestación, parametrización, exposición, autoscaling y prueba de carga.

---

## Documentación y artefactos en este repositorio

| Documento | Uso |
|-----------|-----|
| [Guía y consignas](guia-y-consignas-lab2.md) | Pasos para el alumno y consignas C1–C6. |
| [Entregables](entregables-lab2.md) | Definición formal de qué entregar. |
| [Informe final](informe-final-lab2.md) | Trabajo realizado paso a paso (referencia tesis). |

**Código:** [`Kubernetes/`](../Kubernetes/), [`Helm/`](../Helm/), [`config/`](../config/).

---

## Próximos pasos (Labs 3–6)

- **Lab 3:** Infraestructura como código con Terraform en AWS.
- **Lab 4:** Clúster EKS y monitoreo (Prometheus, Grafana).
- **Lab 5:** Feature flags (Split) y despliegues canary.
- **Lab 6:** Pipeline CI/CD completo (build, IaC, Helm, monitoreo).
