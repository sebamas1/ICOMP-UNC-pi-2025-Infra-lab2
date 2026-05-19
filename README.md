# ICOMP-UNC-pi-2025-Infra-lab2

Repositorio del **Laboratorio 2** del Proyecto Integrador: despliegue de la aplicación Device Manager (imágenes del Lab 1 en Amazon ECR) en **Kubernetes**, con **Helm**, **HPA** y pruebas de estrés con **JMeter**.

## Estructura del repositorio

| Carpeta / archivo | Contenido |
|-------------------|-----------|
| [`docs/`](docs/) | Documentación pedagógica: README introductorio, guía y consignas, entregables e informe final. |
| [`Kubernetes/`](Kubernetes/) | Manifiestos planos: Deployments, Services, HPA, Job de JMeter y ConfigMap del plan de prueba. |
| [`Helm/`](Helm/) | Charts Helm para backend y frontend; overrides por entorno en `Helm/dev/` y `Helm/prd/`. |
| [`config/`](config/) | Plan de prueba JMeter (`test-plan.jmx`) de referencia para edición local. |

## Documentación

- [README del Lab 2](docs/README-lab2.md) — Introducción a los temas (Kubernetes, Minikube, Helm, HPA, JMeter).
- [Guía y consignas](docs/guia-y-consignas-lab2.md) — Pasos operativos para el alumno y criterios de evaluación.
- [Entregables](docs/entregables-lab2.md) — Qué debe entregar el alumno para aprobar el lab.
- [Informe final](docs/informe-final-lab2.md) — Descripción paso a paso del trabajo realizado (referencia de la tesis).

## Inicio rápido

Requisitos: Lab 1 completado (imágenes en ECR), `kubectl`, `helm`, Minikube.

```bash
minikube start
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl apply -f Kubernetes/backend.yaml
kubectl apply -f Kubernetes/frontend.yaml
```

Para el flujo completo (Helm, Ingress, JMeter, HPA bajo carga), seguir la [guía y consignas](docs/guia-y-consignas-lab2.md).
