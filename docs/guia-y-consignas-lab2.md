# Guía y consignas – Lab 2: Introducción a Kubernetes y Helm

**Destinatarios:** Alumnos de las materias vinculadas al Proyecto Integrador (ej. Ingeniería de Software, Gestión de la Calidad de Software).  
**Objetivo:** Desplegar la aplicación del Lab 1 en Kubernetes (Minikube), primero con manifiestos planos y luego con Helm; exponer la app mediante Services e Ingress; configurar HPA con metrics-server; y validar el escalado con una prueba de estrés JMeter ejecutada como Job en el clúster.

---

## 1. Guía para el alumno

### 1.1 Contexto

En el Lab 1 construiste imágenes Docker y las publicaste en **Amazon ECR**. En este laboratorio esas mismas imágenes se convierten en **cargas de trabajo** de Kubernetes: Pods gestionados por Deployments, accesibles mediante Services y, opcionalmente, Ingress. Aprenderás a:

- Escribir y aplicar **manifiestos YAML** (Deployment, Service, HPA).
- Empaquetar despliegues con **Helm** y parametrizar entornos sin duplicar plantillas.
- Instalar **metrics-server** para que el **HPA** pueda leer uso de CPU.
- Generar carga con **JMeter** dentro del clúster (Job + ConfigMap) y observar escalado y desescalado.

### 1.2 Requisitos previos

- Lab 1 completado: imágenes `tp1-backend` y `tp1-frontend` (o equivalentes) en ECR.
- [kubectl](https://kubernetes.io/docs/tasks/tools/) instalado.
- [Helm 3](https://helm.sh/docs/intro/install/) instalado.
- [Minikube](https://minikube.sigs.k8s.io/docs/start/) instalado.
- Conocimientos básicos de YAML y de la línea de comandos.

### 1.3 Recursos recomendados

- [Kubernetes – Concepts](https://kubernetes.io/docs/concepts/)
- [Helm – Quickstart](https://helm.sh/docs/intro/quickstart/)
- [Horizontal Pod Autoscaling](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [metrics-server](https://github.com/kubernetes-sigs/metrics-server)
- [Apache JMeter](https://jmeter.apache.org/usermanual/index.html)

### 1.4 Orden sugerido de trabajo

#### Paso 1 – Clonar el repositorio y levantar Minikube

```bash
git clone <url-del-repo-lab2>
cd ICOMP-UNC-pi-2025-Infra-lab2
minikube start
kubectl cluster-info
kubectl get nodes
```

Opcional: asignar más recursos si vas a escalar muchas réplicas:

```bash
minikube stop
minikube start --cpus=4 --memory=8192
```

#### Paso 2 – Instalar metrics-server

Sin metrics-server, el HPA no obtiene métricas de CPU de los Pods.

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

En Minikube, si `kubectl top pods` falla por certificados, aplicar el parche recomendado en la documentación de metrics-server para entornos locales (kubelet insecure TLS) o usar:

```bash
minikube addons enable metrics-server
```

Verificar (puede tardar 1–2 minutos):

```bash
kubectl get deployment metrics-server -n kube-system
kubectl top nodes
kubectl top pods -A
```

#### Paso 3 – Despliegue con manifiestos planos

Aplicar backend (Deployment + Service NodePort + HPA) y frontend:

```bash
kubectl apply -f Kubernetes/backend.yaml
kubectl apply -f Kubernetes/frontend.yaml
```

Verificar:

```bash
kubectl get pods
kubectl get svc
kubectl get hpa
```

Servicios esperados en los manifiestos de referencia:

| Servicio | Tipo | Puerto |
|----------|------|--------|
| `tp1-backend-service` | NodePort | 8080 → nodePort **30081** |
| `tp1-frontend-service` | NodePort | 80 → nodePort **30080** |

Probar acceso:

```bash
minikube service tp1-backend-service --url
minikube service tp1-frontend-service --url
```

El frontend en manifiestos usa `VITE_API_BASE_URL` apuntando al NodePort del backend (ajustar IP de Minikube si cambia).

#### Paso 4 – Despliegue con Helm

Si los manifiestos planos ya desplegaron recursos con los mismos nombres, eliminarlos o usar otro namespace antes de instalar Helm para evitar conflictos:

```bash
kubectl delete -f Kubernetes/backend.yaml
kubectl delete -f Kubernetes/frontend.yaml
```

Instalar backend (entorno dev):

```bash
helm upgrade --install tp1-backend ./Helm/backend -f ./Helm/dev/backend.yaml
```

Instalar frontend (Ingress habilitado):

```bash
minikube addons enable ingress
helm upgrade --install tp1-frontend ./Helm/frontend -f ./Helm/dev/frontend.yaml
```

Verificar releases:

```bash
helm list
helm get values tp1-backend
helm get values tp1-frontend
kubectl get pods,svc,hpa,ingress
```

**Parametrizar NodePort en Helm (backend):** el template de Service admite `type: NodePort`. Ejemplo de fragmento en un archivo de valores (ej. `Helm/dev/backend-nodeport.yaml`):

```yaml
service:
  type: NodePort
  port: 8080
  targetPort: 8080
  nodePort: 30081
```

Aplicar con:

```bash
helm upgrade --install tp1-backend ./Helm/backend -f ./Helm/dev/backend.yaml -f ./Helm/dev/backend-nodeport.yaml
```

#### Paso 5 – Exponer la aplicación con Ingress

En `Helm/dev/frontend.yaml` el Ingress usa el host `app.local` y enruta `/api` al Service `tp1-backend-service` y `/` al frontend.

1. Obtener IP de Minikube: `minikube ip`
2. Agregar en el archivo hosts del sistema: `<minikube-ip> app.local`
3. Abrir `http://app.local` en el navegador.

Comprobar la API:

```bash
curl http://app.local/api/devices
```

#### Paso 6 – Prueba de estrés con JMeter (Job + ConfigMap)

Crear namespace y recursos:

```bash
kubectl create namespace jmeter
kubectl apply -f Kubernetes/configmap.yaml
kubectl apply -f Kubernetes/jmeter-job.yaml
```

Seguir el Job y el HPA en paralelo (otra terminal):

```bash
kubectl get jobs -n jmeter -w
kubectl get hpa -w
kubectl top pods
```

Logs del Job:

```bash
kubectl logs -n jmeter job/jmeter
```

Copiar resultados (ajustar nombre del Pod si el Job ya terminó):

```bash
POD=$(kubectl get pods -n jmeter -l job-name=jmeter -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n jmeter $POD -- find / -name results.jtl 2>/dev/null
kubectl cp jmeter/$POD:/outputs/results.jtl ./results.jtl
```

**Fuente del plan de prueba:** para reproducibilidad en evaluación, la configuración aplicada al clúster es la de `Kubernetes/configmap.yaml` (100 hilos, 600 s, timer de throughput). El archivo `config/test-plan.jmx` sirve para editar en JMeter GUI y regenerar el ConfigMap.

#### Paso 7 – Variar escenarios de escalado (opcional avanzado)

Editar en values o en el manifiesto HPA:

- `autoscaling.maxReplicas` (5, 15, 20)
- `resources.requests.cpu` (ej. 200m)
- `autoscaling.targetCPUUtilizationPercentage` (70)

Reaplicar Helm, relanzar el Job de JMeter y registrar en una tabla: réplicas máximas alcanzadas, CPU reportada por HPA, errores OOM o Pods Pending.

#### Paso 8 – Documentar y entregar

Completar el informe según `entregables-lab2.md` y las consignas C1–C6 de esta guía.

---

## 2. Consignas (qué debe cumplir el alumno)

Cada ítem puede evaluarse de forma independiente; el docente definirá criterios de corrección (revisión de YAML, ejecución en Minikube, informe).

### C1. Documentación de Kubernetes, Minikube y Helm

- **C1.1** Incluir en el README del repo o en el informe una explicación clara de: Pod, Deployment, Service, HPA, ConfigMap y Job.
- **C1.2** Explicar el rol de Minikube como clúster local y sus limitaciones de recursos.
- **C1.3** Explicar qué es un chart Helm, `values.yaml`, templates y release; diferenciar manifiestos planos vs Helm.

### C2. Manifiestos Kubernetes (Services y HPA)

- **C2.1** Proveer manifiestos para backend y frontend: Deployment + Service cada uno.
- **C2.2** Incluir HPA v2 para el backend con métrica de CPU y umbrales configurables (`minReplicas`, `maxReplicas`, `targetCPUUtilizationPercentage`).
- **C2.3** Los manifiestos deben aplicarse con `kubectl apply -f` sin errores y los Pods deben llegar a `Running`.

### C3. Helm – charts parametrizados

- **C3.1** Chart Helm para backend y para frontend con templates de Deployment y Service (y HPA en backend).
- **C3.2** Parametrizar al menos: puerto, tipo de Service, resources (requests/limits), flag y parámetros de autoscaling (`enabled`, min/max réplicas, target CPU).
- **C3.3** Overrides por entorno en `Helm/dev/` (y opcional `Helm/prd/`) sin modificar templates para cambiar imagen o recursos.

### C4. Exponer la aplicación

- **C4.1** La API del backend debe ser alcanzable desde fuera del clúster (NodePort en manifiestos o Ingress `/api` en Helm).
- **C4.2** El frontend debe ser accesible (NodePort o Ingress en `/`).
- **C4.3** Documentar URLs, hosts (`app.local`) o comandos `minikube service` usados.

### C5. Escalado – HPA y metrics-server

- **C5.1** metrics-server instalado y funcional (`kubectl top pods`).
- **C5.2** Demostrar escalado del backend bajo carga (capturas o tabla réplicas vs tiempo).
- **C5.3** Documentar en el informe el análisis **HPA vs VPA** y justificar el uso de HPA en este lab.

### C6. Prueba de estrés con JMeter

- **C6.1** Plan JMeter montado vía **ConfigMap**; ejecución mediante **Job** de Kubernetes (no un Pod interactivo permanente como entrega final).
- **C6.2** El Job debe generar `results.jtl` (ruta documentada, ej. `/outputs/results.jtl`).
- **C6.3** El informe describe la carga configurada (hilos, duración, endpoint) y el efecto observado en el HPA.

---

## 2.1 Buenas prácticas (resumen)

| Área | Práctica |
|------|----------|
| **Imágenes** | Usar tags inmutables (SHA o versión) en producción; `latest` solo en dev local. |
| **Recursos** | Definir `requests` y `limits` para que el HPA y el planificador comporten de forma predecible. |
| **Namespaces** | Aislar JMeter en namespace `jmeter`. |
| **Helm** | `helm upgrade --install` idempotente; versionar values por entorno. |
| **Carga** | Empezar con poca carga; subir gradualmente para no tumbar Minikube sin documentar el límite. |
| **Limpieza** | `kubectl delete job jmeter -n jmeter` entre pruebas; ajustar `maxReplicas` según RAM del host. |

---

## 3. Escenarios de prueba de escalado (referencia docente)

Tabla basada en las pruebas realizadas durante el desarrollo del laboratorio:

| Prueba | maxReplicas | Carga / resources | Resultado a documentar |
|--------|-------------|-------------------|-------------------------|
| 1 | 5 | CPU request 200m, target 70 %, carga del ConfigMap | HPA crea Pods hasta el máximo (5) por CPU elevada |
| 2 | 15 | Igual que prueba 1 | Escala progresivamente (ej. hasta 12, luego 15); CPU ~76 % al estabilizar |
| 3 | 20 | Carga alta, poca RAM en Minikube | Al ~18 réplicas, Pods Pending o OOM por memoria del nodo |
| 4 | 20 | Resources y carga reducidos | Escala 1→11; tras fin de carga, desescalado tras ~5 min |

---

## 4. Entregables para los alumnos (definición formal)

Para la definición **completa** de entregables, consultar **`entregables-lab2.md`** en esta misma carpeta.

| Entregable | Descripción | Formato sugerido |
|------------|-------------|-------------------|
| **Repositorio Lab 2** | Manifiestos, Helm, JMeter. | Repo Git. |
| **Evidencia de despliegue** | `kubectl` / `helm` + capturas. | Informe o README. |
| **Informe breve** | Paso a paso, HPA bajo carga, decisiones Helm/Ingress/Job. | PDF o Markdown. |

**Criterios de aceptación mínimos** (detalle en `entregables-lab2.md`)

- Manifiestos y Helm despliegan backend y frontend desde ECR.
- App expuesta (NodePort o Ingress).
- metrics-server + HPA demostrado bajo carga.
- JMeter como Job con ConfigMap y resultados recuperables.

---

*Documento alineado con la Solicitud de Proyecto Integrador (Lab 2) y con el repositorio `ICOMP-UNC-pi-2025-Infra-lab2`.*
