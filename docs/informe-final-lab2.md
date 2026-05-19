# Informe final – Lab 2: Introducción a Kubernetes y Helm

**Proyecto Integrador – Desarrollo de Laboratorios y Prácticas Iterativas en un Cloud Provider (AWS-UNC)**  
Referencia: Solicitud de Proyecto Integrador (Laboratorio 2).

---

## 1. Objetivo del laboratorio

Desplegar la aplicación Device Manager (backend .NET y frontend React, imágenes publicadas en el Lab 1 en **Amazon ECR**) en un clúster de **Kubernetes** local (**Minikube**), siguiendo el enfoque del PI:

1. Primero con **manifiestos YAML** planos (Deployment, Service, HPA).
2. Luego con **Helm**, parametrizando puertos, tipo de Service, recursos, réplicas y autoscaling.
3. **Exponer** la aplicación hacia fuera del clúster (NodePort e Ingress).
4. Configurar **escalado horizontal** (HPA) apoyado en **metrics-server**.
5. Validar el comportamiento con **pruebas de estrés** usando **JMeter** ejecutado como **Job** dentro del clúster.

---

## 2. Tecnologías utilizadas

| Área | Tecnología | Uso en el Lab 2 |
|------|------------|------------------|
| Orquestación | Kubernetes | Deployments, Services, HPA, ConfigMap, Job |
| Clúster local | Minikube | Entorno de desarrollo y pruebas de escalado |
| Empaquetado K8s | Helm 3 | Charts `tp1-backend` y `tp1-frontend`; overrides dev/prd |
| Métricas | metrics-server | CPU de Pods para HPA y `kubectl top` |
| Autoscaling | HPA (autoscaling/v2) | Escala réplicas del backend por CPU (target 70 %) |
| Exposición HTTP | Ingress (nginx) | Host `app.local`, rutas `/` y `/api` |
| Registro | Amazon ECR | Imágenes del Lab 1 (`tp1-backend`, `tp1-frontend`, `tp1-backend-prd`) |
| Pruebas de carga | Apache JMeter 5.5/5.6 | Imagen `justb4/jmeter`; plan en ConfigMap |
| CLI | kubectl, helm | Aplicación de manifiestos e instalación de releases |

---

## 3. Descripción de las tareas realizadas (paso a paso)

### 3.1 Preparación del clúster con Minikube

**Qué se hizo:** Se instaló y arrancó Minikube en la máquina de desarrollo para disponer de un clúster Kubernetes de un nodo compatible con `kubectl` y Helm.

**Pasos:**

1. Ejecutar `minikube start` (opcionalmente con más CPU/RAM si se prevén muchas réplicas).
2. Verificar conectividad: `kubectl cluster-info`, `kubectl get nodes`.
3. Confirmar que el contexto de `kubectl` apunta al clúster de Minikube.

**Resultado:** Clúster operativo listo para aplicar manifiestos y releases Helm.

---

### 3.2 Instalación y verificación de metrics-server

**Qué se hizo:** Se instaló **metrics-server**, componente necesario para que el API server de Kubernetes exponga métricas de uso de CPU y memoria de Pods y nodos. Sin él, el HPA no puede calcular el porcentaje de CPU respecto al *request* y permanece en estado `<unknown>`.

**Pasos:**

1. Aplicar el manifiesto oficial de metrics-server o habilitar el addon en Minikube (`minikube addons enable metrics-server`).
2. Esperar a que el Deployment en `kube-system` esté `Ready`.
3. Verificar con `kubectl top nodes` y `kubectl top pods`.

**Resultado:** Métricas disponibles para el controlador del HPA y para observación manual durante las pruebas de carga.

---

### 3.3 Despliegue con manifiestos planos (backend)

**Qué se hizo:** Se creó el archivo `Kubernetes/backend.yaml` con tres recursos en cadena: **Deployment**, **Service** y **HorizontalPodAutoscaler**.

**Deployment `tp1-backend`:**

- Imagen desde ECR: `public.ecr.aws/b4c0c6w7/tesis/tp1-backend` con tag por commit.
- Puerto del contenedor: **8080**.
- **Resources:** `requests` CPU **200m**, memoria 256Mi; `limits` CPU 500m, memoria 512Mi.
- **replicas:** 1 (el HPA modifica este valor dinámicamente).

**Service `tp1-backend-service`:**

- Tipo **NodePort** para exponer la API fuera del clúster.
- Puerto del Service 8080 → `targetPort` 8080 → **nodePort 30081**.

**HPA `tp1-backend-hpa`:**

- Escala el Deployment `tp1-backend`.
- `minReplicas: 1`, `maxReplicas: 20`.
- Métrica: CPU con `averageUtilization: 70` (70 % del CPU *request* de cada Pod).

**Pasos de aplicación:**

```bash
kubectl apply -f Kubernetes/backend.yaml
kubectl get deploy,svc,hpa
```

**Resultado:** Backend accesible en el NodePort del nodo Minikube; HPA asociado y listo para recibir métricas.

---

### 3.4 Despliegue con manifiestos planos (frontend)

**Qué se hizo:** Se aplicó `Kubernetes/frontend.yaml` con Deployment y Service NodePort para el frontend.

- Imagen ECR `tp1-frontend` con tag fijo por commit.
- Variable de entorno `VITE_API_BASE_URL` apuntando al backend vía IP de Minikube y NodePort **30081** (patrón usado antes de centralizar tráfico en Ingress).
- Service **NodePort 30080** → puerto 80 del Service → puerto 3000 del contenedor.

**Pasos:**

```bash
kubectl apply -f Kubernetes/frontend.yaml
minikube service tp1-frontend-service --url
```

**Resultado:** UI accesible externamente; comunicación con la API documentada por URL del backend.

---

### 3.5 Creación de la infraestructura Helm (charts, values, templates)

**Qué se hizo:** Se migró la lógica de los manifiestos planos a dos **charts Helm** bajo `Helm/backend` y `Helm/frontend`, con plantillas Go template y valores por defecto en `values.yaml`.

**Estructura backend:**

| Archivo | Función |
|---------|---------|
| `Chart.yaml` | Metadatos del chart `tp1-backend` |
| `values.yaml` | Valores por defecto (imagen, resources, service, autoscaling) |
| `templates/deployment.yaml` | Deployment parametrizado |
| `templates/service.yaml` | Service con soporte ClusterIP/NodePort |
| `templates/hpa.yaml` | HPA condicionado a `autoscaling.enabled` |
| `templates/_helpers.tpl` | Nombres consistentes del release |

**Estructura frontend:**

| Archivo | Función |
|---------|---------|
| `values.yaml` / `Helm/dev/frontend.yaml` | Imagen, Service, Ingress |
| `templates/deployment.yaml` | Deployment con `env` |
| `templates/service.yaml` | Service ClusterIP |
| `templates/ingress.yaml` | Reglas HTTP para `app.local` |

**Overrides por entorno:**

- `Helm/dev/backend.yaml` y `Helm/dev/frontend.yaml`: imágenes de integración (`tp1-backend`, `tp1-frontend`), recursos moderados, Ingress activo en frontend.
- `Helm/prd/backend.yaml` y `Helm/prd/frontend.yaml`: imagen `tp1-backend-prd`, más CPU/memoria, `replicaCount` base 2, mismos parámetros de HPA.

**Pasos de instalación:**

```bash
helm upgrade --install tp1-backend ./Helm/backend -f ./Helm/dev/backend.yaml
helm upgrade --install tp1-frontend ./Helm/frontend -f ./Helm/dev/frontend.yaml
```

**Resultado:** Despliegues reproducibles y parametrizables sin editar YAML de plantilla.

---

### 3.6 Parametrización de Services y autoscaling (Helm)

**Qué se hizo:** Se parametrizaron en `values.yaml` (y overrides) los aspectos requeridos en el sprint:

| Parámetro | Clave Helm | Ejemplo (dev backend) |
|-----------|------------|------------------------|
| Puerto contenedor | `containerPort` | 8080 |
| Tipo de Service | `service.type` | ClusterIP (dev) / NodePort en manifiestos planos |
| Puertos Service | `service.port`, `service.targetPort` | 8080 |
| NodePort opcional | `service.nodePort` | 30081 (si `type: NodePort`) |
| Resources | `resources.requests/limits` | CPU 200m, mem 256Mi |
| Réplicas estáticas | `replicaCount` | 1 (dev) / 2 (prd) |
| HPA activo | `autoscaling.enabled` | true |
| Mín / máx réplicas | `minReplicas`, `maxReplicas` | 1 / 20 |
| Target CPU | `targetCPUUtilizationPercentage` | 70 |

El template del HPA renderiza solo si `autoscaling.enabled` es true:

```1:20:Helm/backend/templates/hpa.yaml
{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "tp1-backend.fullname" . }}-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "tp1-backend.fullname" . }}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
{{- end }}
```

**Resultado:** Un mismo chart sirve para distintos entornos cambiando solo archivos `-f`.

---

### 3.7 Ingress – exposición unificada de frontend y API

**Qué se hizo:** Se habilitó **Ingress** en el chart del frontend (`ingress.enabled: true`, clase `nginx`) con host **`app.local`**:

- Ruta **`/api`** → Service `tp1-backend-service`, puerto 8080 (API sin prefijo adicional en el backend; el path se envía tal cual según configuración del Ingress).
- Ruta **`/`** → Service del frontend (UI).

**Pasos:**

1. `minikube addons enable ingress`
2. Entrada en archivo hosts: `<minikube-ip> app.local`
3. `helm upgrade` del frontend con `Helm/dev/frontend.yaml`
4. Verificación: `curl http://app.local/api/devices` y navegador en `http://app.local`

**Resultado:** Un solo punto de entrada HTTP para alumnos y correctores; el frontend usa `VITE_API_BASE_URL: ""` para llamar a la API en el mismo origen.

---

### 3.8 Pruebas de estrés con JMeter (ConfigMap + Job)

**Qué se hizo:** Se implementó la generación de carga contra el backend dentro del clúster.

**Evolución Pod → Job:** En iteraciones tempranas se ejecutó JMeter en un Pod; la versión final usa un **Job** (`Kubernetes/jmeter-job.yaml`) con `restartPolicy: Never` y `backoffLimit: 0`, de modo que el trabajo termina al finalizar el test y queda trazable como unidad de trabajo de Kubernetes.

**ConfigMap `jmeter-testplan` (namespace `jmeter`):**

- Contiene el archivo `test-plan.jmx` embebido.
- Configuración operativa: **100 hilos**, **duración 600 s** (10 minutos), scheduler activo.
- Petición HTTP: `GET http://tp1-backend-service.default:8080/api/devices`.
- **Constant Throughput Timer** para limitar la tasa agregada de muestras (ver comentario en el XML del ConfigMap sobre throughput por minuto).

**Job `jmeter`:**

- Imagen: `justb4/jmeter:5.5`.
- Montaje del ConfigMap en `/tests` (solo lectura).
- Volumen `emptyDir` en `/outputs` para `results.jtl`.
- Comando:

```bash
jmeter -n -t /tests/test-plan.jmx -JtargetUrl=http://tp1-backend-service.default:8080 -l /outputs/results.jtl
```

**Inspección de resultados:** Tras la ejecución, se localizó el archivo con:

```bash
find / -name results.jtl 2>/dev/null
```

Ruta confirmada: **`/outputs/results.jtl`**.

**Nota sobre fuentes del plan:** El archivo `config/test-plan.jmx` en el repositorio tiene parámetros distintos (ej. 1000 hilos) y sirve como borrador editable en JMeter GUI; la fuente de verdad para pruebas en el clúster es **`Kubernetes/configmap.yaml`**.

**Pasos de ejecución:**

```bash
kubectl create namespace jmeter
kubectl apply -f Kubernetes/configmap.yaml
kubectl apply -f Kubernetes/jmeter-job.yaml
kubectl get hpa -w
kubectl logs -n jmeter job/jmeter
```

**Resultado:** Carga sostenida contra el Service del backend en `default`; HPA observable en tiempo real.

---

### 3.9 Calibración del HPA y cuatro pruebas de escalado

**Umbrales configurados:**

- CPU **request** del backend: **200m** (manifiestos y Helm dev).
- HPA: target **70 %** de utilización respecto al request.
- Métrica provista por **metrics-server**.

**Pruebas realizadas:**

| # | maxReplicas | Configuración de carga / recursos | Observación |
|---|-------------|-----------------------------------|-------------|
| **1** | 5 | Carga del ConfigMap; CPU del backend muy por encima del 70 % | El HPA creó réplicas hasta el **máximo configurado (5)**. El límite fue el techo del HPA, no la saturación del nodo. |
| **2** | 15 | Misma carga | Escalado progresivo (primero ~12 réplicas); al seguir alta la CPU (~160 % agregada reportada en observaciones), continuó hasta **15** réplicas; CPU del deployment cercana a **76 %** al estabilizar. |
| **3** | 20 | Carga alta; clúster Minikube con RAM limitada | El HPA escaló, pero al llegar aproximadamente a **18 réplicas** el nodo comenzó a quedarse **sin memoria** (Pods `Pending` o reinicios por OOM). Demuestra que el autoscaling horizontal no sustituye la capacidad física del clúster. |
| **4** | 20 | Se **redujeron** resources del backend y la **intensidad** del stress test | Escalado de **1 a 11** réplicas de forma estable; al finalizar las peticiones, el HPA **desescaló** gradualmente tras aproximadamente **5 minutos** (comportamiento por defecto del controlador para evitar flapping). |

**Interpretación pedagógica:**

- Con **maxReplicas** bajo (5), se observa el tope artificial del HPA.
- Con **maxReplicas** alto y carga fuerte, el HPA intenta compensar hasta encontrar límites del nodo (prueba 3).
- Ajustando carga y requests, se logra un ciclo completo **escalar → sostener → desescalar** (prueba 4), alineado con el objetivo del lab.

---

### 3.10 Análisis HPA frente a VPA

**HPA (implementado):** Aumenta o disminuye el **número de Pods** según métricas (CPU). Adecuado para tráfico HTTP variable y stateless replicas del backend.

**VPA (analizado, no implementado):** Ajustaría automáticamente **requests y limits** de CPU/memoria por Pod. Útil cuando el problema es dimensionar cada instancia, no la cantidad. En este lab la carga se resolvió horizontalmente; además, combinar VPA y HPA en el mismo Deployment requiere cuidado para evitar conflictos.

**Decisión:** Usar **HPA + metrics-server** por alineación con el objetivo del PI (orquestación y despliegues escalables) y con las pruebas JMeter del sprint.

---

## 4. Justificación y decisiones de diseño

| Decisión | Justificación |
|----------|----------------|
| **Manifiestos antes que Helm** | El PI pide mostrar primero YAML explícito y luego la abstracción Helm; facilita la enseñanza de objetos Kubernetes. |
| **NodePort en manifiestos, ClusterIP + Ingress en Helm dev** | NodePort simplifica pruebas rápidas sin DNS; Ingress modela un entorno más cercano a producción con un solo host. |
| **CPU como única métrica del HPA** | Suficiente para el backend CPU-bound bajo JMeter; evita dependencias de Prometheus adapter en Minikube. |
| **Request CPU 200m** | Valor bajo hace que el porcentaje de HPA suba rápido bajo carga, haciendo visible el escalado en tiempo de laboratorio. |
| **Job en lugar de Pod suelto para JMeter** | Semántica de “trabajo terminable”, reintentos controlados (`backoffLimit: 0`) y mejor alineación con buenas prácticas Kubernetes. |
| **Namespace `jmeter` aislado** | Separación de la carga de prueba de los workloads de la aplicación. |
| **Imágenes dev vs prd en Helm** | `tp1-backend` vs `tp1-backend-prd` continúan la estrategia del Lab 1 (integración vs producción en ECR). |

---

## 5. Marco teórico – conceptos cloud y DevOps utilizados

### 5.1 Orquestación con Kubernetes

**Kubernetes** automatiza el despliegue, escalado y operación de contenedores. Un **Pod** es la unidad mínima de ejecución (uno o más contenedores compartiendo red). Un **Deployment** declara el estado deseado (imagen, réplicas, recursos) y el controlador mantiene ese estado (recrea Pods fallidos, aplica rolling updates).

**Problema que resuelve:** Pasar de “ejecutar un contenedor en una VM” a gestionar decenas de réplicas, salud y actualizaciones sin intervención manual.

### 5.2 Services y tipos de exposición

Un **Service** es un endpoint estable que selecciona Pods por labels.

- **ClusterIP:** IP interna; solo accesible dentro del clúster.
- **NodePort:** Abre un puerto en cada nodo (rango 30000–32767) que redirige al Service.
- **Ingress:** Reglas HTTP/HTTPS hacia Services; requiere un **Ingress Controller** (nginx en Minikube).

En este lab, NodePort demuestra exposición directa; Ingress demuestra enrutamiento por path y host virtual.

### 5.3 Horizontal Pod Autoscaler y metrics-server

El **HPA** consulta métricas (típicamente CPU/memoria vía API de métricas) y calcula el número deseado de réplicas:

\[
\text{réplicas deseadas} \approx \text{réplicas actuales} \times \frac{\text{métrica actual}}{\text{métrica objetivo}}
\]

**metrics-server** agrega uso de recursos de kubelet y lo expone al API server. Sin componentes de métricas, el autoscaler no tiene señal.

El **tiempo de enfriamiento** (scale-down delay) evita oscilaciones: tras bajar la carga, las réplicas no desaparecen instantáneamente (observado ~5 min en la prueba 4).

### 5.4 Helm – charts, values y releases

**Helm** separa **plantillas** (con placeholders) de **valores** (configuración por entorno). Un **release** nombra una instalación (`tp1-backend`) en un namespace. Comandos como `helm upgrade --install` son idempotentes y aptos para pipelines CI/CD futuros (Lab 6).

**Problema que resuelve:** Evitar copiar y divergir decenas de YAML entre dev, staging y producción.

### 5.5 Pruebas de carga en el clúster (JMeter, Job, ConfigMap)

**JMeter** simula usuarios concurrentes contra endpoints HTTP. Ejecutarlo **dentro** del clúster (Job + ConfigMap) tiene ventajas:

- Tráfico entra por la red de Services como un cliente interno real.
- No depende de la conectividad desde la laptop del alumno hacia NodePort.
- El plan de prueba se versiona como código (ConfigMap generado desde `.jmx`).

Un **Job** de Kubernetes garantiza que el contenedor de prueba ejecute hasta completar y termine, liberando recursos.

**JTL:** archivo de resultados de JMeter (latencias, códigos HTTP, throughput) para análisis offline.

### 5.6 Relación con el Lab 1 y el Lab 3

- **Lab 1:** produce el artefacto inmutable (imagen en ECR).
- **Lab 2:** consume ese artefacto y define *cómo* corre en Kubernetes (réplicas, red, escalado).
- **Lab 3 (siguiente):** provisionará infraestructura en AWS con Terraform; el clúster dejará de ser solo Minikube local.

---

## 6. Conclusión

El Lab 2 cumple con la Solicitud del PI: la aplicación del Lab 1 se desplegó en Kubernetes **primero con manifiestos básicos** y **luego con Helm**, demostrando parametrización de Services, recursos y autoscaling. Se instaló **metrics-server**, se configuró el **HPA** sobre CPU (request 200m, target 70 %) y se validó con **JMeter** empaquetado en **ConfigMap** y ejecutado como **Job**, documentando cuatro escenarios de escalado que muestran límites del HPA, del clúster y el desescalado tras la carga.

Este laboratorio prepara el terreno para **infraestructura como código** (Lab 3) y para un clúster gestionado **EKS** (Lab 4), donde los mismos charts Helm podrán instalarse sobre infraestructura provisionada en AWS.

---

## 7. Anexos – comandos de verificación

```bash
# Estado general
kubectl get pods,svc,hpa,ingress
helm list

# Métricas
kubectl top pods
kubectl describe hpa tp1-backend-hpa

# JMeter
kubectl get jobs -n jmeter
kubectl logs -n jmeter job/jmeter

# Acceso local
minikube service tp1-backend-service --url
minikube ip   # para app.local en /etc/hosts
```

**Artefactos de referencia en el repositorio:**

- Manifiestos: `Kubernetes/backend.yaml`, `Kubernetes/frontend.yaml`
- Helm: `Helm/backend/`, `Helm/frontend/`, `Helm/dev/`, `Helm/prd/`
- Estrés: `Kubernetes/jmeter-job.yaml`, `Kubernetes/configmap.yaml`, `config/test-plan.jmx`

*Fin del informe – Lab 2.*
