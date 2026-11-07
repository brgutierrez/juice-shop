# Diagramas del pipeline (objetivo 1)

Las imágenes `1a-pipeline.png` y `1b-flujo-vulnerabilidad.png` son las versiones para el informe.
Abajo están las mismas ideas en Mermaid: GitHub las dibuja directamente al abrir este fichero.

## 1.a · Pipeline DevSecOps

```mermaid
flowchart LR
  T([push / pull request a main]) --> S1 & S2 & S3 & S4
  subgraph COMMIT [Commit · en paralelo]
    S1[1 · Gitleaks<br/>gitleaks.json<br/>AVISO: 0 secretos]
    S2[2 · Semgrep SAST<br/>semgrep.json<br/>AVISO: 0 ERROR]
    S3[3 · Trivy fs SCA<br/>trivy-sca.json<br/>AVISO: 0 CRITICAL]
    S4[4 · Checkov IaC<br/>checkov.json<br/>BLOQUEA: controles críticos k8s/ y Dockerfile]
  end
  S1 & S2 & S3 & S4 --> B[5 · docker build<br/>juice-shop.tar]
  subgraph PRUEBAS [Pruebas · en paralelo]
    I[6 · Trivy image<br/>trivy-image.json<br/>BLOQUEA: 0 CRITICAL con parche]
    D[7 · ZAP baseline<br/>zap.xml<br/>AVISO: 0 alertas High]
  end
  B --> I & D
  I & D -->|solo main y si 6 y 7 OK| P[9 · Publicar imagen en GHCR]
  S1 & S2 & S3 & S4 & I & D -. informes .-> DD[(8 · DefectDojo<br/>reimport-scan · if: always)]
  classDef bloq fill:#fdeaea,stroke:#d64545;
  classDef aviso fill:#fff3e6,stroke:#d9822b;
  class S4,I bloq;
  class S1,S2,S3,D aviso;
```

## 1.b · Flujo ante una vulnerabilidad

```mermaid
flowchart TD
  A[Una herramienta detecta un hallazgo y genera su informe] --> U{¿Supera el umbral?}
  U -- no --> V[El job sigue en verde]
  U -- sí --> G{¿Gate bloqueante?}
  G -- no, aviso --> W[Aviso en el job · continue-on-error · el pipeline sigue]
  G -- sí --> F[El job falla · no se ejecutan los jobs dependientes · no se publica]
  F --> N[Aviso al equipo: correo de GitHub, ✗ en el PR, resumen del job]
  V & W & N --> R[Job 8 · reimport-scan en DefectDojo · deduplicación]
  R --> T[Triaje del Security Team: verificar y priorizar por severidad y SLA]
  T --> FP{¿Falso positivo?}
  FP -- sí --> X[False Positive en DefectDojo + exclusión justificada en la herramienta]
  FP -- no --> C{¿Se corrige ahora?}
  C -- no --> RA[Risk Accepted con responsable y caducidad]
  C -- sí --> FIX[Verified · corrección en rama + PR · el pipeline vuelve a analizar]
  FIX --> M[Si ya no aparece: Mitigated · close_old_findings]
```
