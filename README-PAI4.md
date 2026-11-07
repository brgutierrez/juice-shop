# PAI 4 · Solución de referencia (uso interno del profesorado)

Ficheros que se añaden a un fork de OWASP Juice Shop para tener el pipeline DevSecOps completo.

| Fichero | Para qué sirve |
|---|---|
| `.github/workflows/devsecops.yml` | El pipeline: 9 jobs (secretos, SAST, SCA, IaC, build, imagen, DAST, DefectDojo, publicación) |
| `scripts/defectdojo-upload.sh` | Envía los 6 informes a DefectDojo por la API v2 (`reimport-scan`) |
| `k8s/*.yaml` | Manifiestos de despliegue en Kubernetes, que el gate bloqueante de Checkov comprueba |
| `.semgrepignore` | Rutas que Semgrep no analiza (pruebas y fragmentos de los retos) |
| `.trivyignore` | Riesgos aceptados y falsos positivos de Trivy (vacío; plantilla con formato) |
| `.zap/rules.tsv` | Ajuste de reglas de ZAP (falsos positivos conocidos) |
| `docs/diagramas/` | Diagramas 1.a y 1.b en PNG y en Mermaid |

## Puesta en marcha (resumen)

1. Hacer fork de https://github.com/juice-shop/juice-shop y **borrar** sus workflows de `.github/workflows/`
   (son los del proyecto original: lanzan pruebas en tres sistemas operativos y publicaciones que fallan en un fork).
2. Renombrar la rama `master` del fork a `main` (Settings → General → Default branch → renombrar),
   copiar estos ficheros en la raíz y hacer commit en `main`.
3. Levantar DefectDojo (`docker compose up -d` en su repositorio), sacar la contraseña de `admin`
   (`docker compose logs initializer | grep "Admin password:"`) y la clave de la API v2 (menú de usuario → API v2 Key).
4. Hacer DefectDojo accesible desde GitHub (p. ej. `cloudflared tunnel --url http://localhost:8080`).
5. En el repositorio: *Settings → Secrets and variables → Actions* → secretos `DD_URL` y `DD_API_KEY`;
   variable opcional `DD_PRODUCT_TYPE` (p. ej. `PAI4-ST7`).
6. *Actions → DevSecOps → Run workflow*.

Resultado esperado con Juice Shop: los gates en aviso salen con ⚠, el gate 6 (imagen) **bloquea** porque hay
CVE críticas con parche (p. ej. `jsonwebtoken@0.4.0`), la publicación (job 9) no se ejecuta y los 6 informes
llegan a DefectDojo.

Para demostrar el gate bloqueante 4: en una rama, cambiar `privileged: false` por `privileged: true` en
`k8s/deployment.yaml` y abrir un pull request. El job 4 falla y no se construye la imagen.
