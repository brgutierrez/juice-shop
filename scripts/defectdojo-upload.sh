#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Envía los informes de las herramientas a DefectDojo mediante la API v2.
#
# Usa /api/v2/reimport-scan/ con auto_create_context=true:
#   - la primera vez crea el tipo de producto, el producto, el engagement y el test;
#   - las siguientes vuelve a importar sobre el MISMO test, de modo que DefectDojo
#     deduplica: un hallazgo que ya existía no se duplica, uno nuevo se añade y uno
#     que ya no aparece se marca como mitigado (close_old_findings=true).
#
# Variables de entorno:
#   DD_URL, DD_API_KEY       (obligatorias, vienen de los secretos del repositorio)
#   DD_PRODUCT_TYPE          (opcional, por defecto PAI4)   → «Organization» en la UI
#   DD_PRODUCT               (opcional, por defecto juice-shop) → «Asset» en la UI
#
# Uso:  bash scripts/defectdojo-upload.sh <carpeta-de-informes>
# -----------------------------------------------------------------------------
set -uo pipefail

REPORT_DIR="${1:-reports}"
: "${DD_URL:?Falta DD_URL (secreto del repositorio)}"
: "${DD_API_KEY:?Falta DD_API_KEY (secreto del repositorio)}"
PRODUCT_TYPE="${DD_PRODUCT_TYPE:-PAI4}"
PRODUCT="${DD_PRODUCT:-juice-shop}"
BRANCH="${GITHUB_HEAD_REF:-${GITHUB_REF_NAME:-local}}"
ENGAGEMENT="CI/CD ${BRANCH}"
API="${DD_URL%/}/api/v2/reimport-scan/"
errors=0

# fichero_del_informe | scan_type exacto de DefectDojo | título del test
REPORTS=(
  "gitleaks.json|Gitleaks Scan|Gitleaks (secretos)"
  "semgrep.json|Semgrep JSON Report|Semgrep (SAST)"
  "trivy-sca.json|Trivy Scan|Trivy fs (SCA)"
  "checkov.json|Checkov Scan|Checkov (IaC)"
  "trivy-image.json|Trivy Scan|Trivy image (contenedor)"
  "zap.xml|ZAP Scan|ZAP baseline (DAST)"
)

echo "| Informe | Test en DefectDojo | Resultado |" >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
echo "|---|---|---|" >> "${GITHUB_STEP_SUMMARY:-/dev/null}"

for entry in "${REPORTS[@]}"; do
  IFS='|' read -r file scan_type title <<< "$entry"
  path="$REPORT_DIR/$file"

  if [ ! -s "$path" ]; then
    # El job que lo genera no llegó a ejecutarse (p. ej. un gate bloqueó el build).
    echo "::warning title=DefectDojo::$file no existe; se omite"
    echo "| $file | $title | omitido (no generado) |" >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
    continue
  fi

  args=(
    -F "scan_type=$scan_type"
    -F "file=@$path"
    -F "product_type_name=$PRODUCT_TYPE"
    -F "product_name=$PRODUCT"
    -F "engagement_name=$ENGAGEMENT"
    -F "test_title=$title"
    -F "auto_create_context=true"
    -F "deduplication_on_engagement=true"
    -F "close_old_findings=true"
    -F "minimum_severity=Info"
    -F "verified=false"
    -F "scan_date=$(date +%F)"
    -F "branch_tag=$BRANCH"
  )
  [ -n "${GITHUB_RUN_ID:-}" ] && args+=(-F "build_id=$GITHUB_RUN_ID")
  [ -n "${GITHUB_SHA:-}" ]    && args+=(-F "commit_hash=$GITHUB_SHA")
  [ -n "${GITHUB_REPOSITORY:-}" ] && \
    args+=(-F "source_code_management_uri=${GITHUB_SERVER_URL:-https://github.com}/$GITHUB_REPOSITORY")

  code=$(curl -sS -o /tmp/dd-response.json -w '%{http_code}' --max-time 300 \
           -H "Authorization: Token $DD_API_KEY" "${args[@]}" "$API") || code="000"

  if [[ "$code" == 2* ]]; then
    test_id=$(jq -r '.test_id // "?"' /tmp/dd-response.json 2>/dev/null)
    echo "OK  $file → test $test_id ($scan_type)"
    echo "| $file | $title (test $test_id) | importado |" >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
  else
    echo "::error title=DefectDojo::Error HTTP $code al importar $file"
    head -c 800 /tmp/dd-response.json 2>/dev/null; echo
    echo "| $file | $title | ERROR HTTP $code |" >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
    errors=$((errors + 1))
  fi
done

# Si algún informe no se pudo importar, el job falla: así el equipo se entera.
exit $(( errors > 0 ? 1 : 0 ))
