#!/bin/bash

MIN_VERSION="17.0.6"
OUTPUT_CSV="auditoria_java_ocp.csv"
echo "NAMESPACE,POD,CONTAINER,STATUS,VERSAO_JAVA" > "$OUTPUT_CSV"

# Retorna 0 (verdadeiro) se $1 >= $2 (ex: 17.0.10 >= 17.0.6)
version_ge() {
  local v1="$1" v2="$2"
  # Remove sufixos de build como -LTS, +10, _345
  v1="${v1%%[-_+]*}"
  v2="${v2%%[-_+]*}"

  # Valida se a string possui formato numérico válido
  [[ "$v1" =~ ^[0-9]+(\.[0-9]+)*$ ]] || return 1

  IFS='.' read -r -a a1 <<< "$v1"
  IFS='.' read -r -a a2 <<< "$v2"

  local len=${#a1[@]}
  [ ${#a2[@]} -gt "$len" ] && len=${#a2[@]}

  for ((i=0; i<len; i++)); do
    local n1=${a1[i]:-0}
    local n2=${a2[i]:-0}
    if ((10#$n1 > 10#$n2)); then
      return 0
    elif ((10#$n1 < 10#$n2)); then
      return 1
    fi
  done
  return 0
}

echo "Coletando lista de containers em execução no cluster..."

CONTAINERS=$(oc get pods -A --field-selector=status.phase=Running -o go-template='{{range .items}}{{$ns := .metadata.namespace}}{{$pod := .metadata.name}}{{range .spec.containers}}{{$ns}} {{$pod}} {{.name}}{{"\n"}}{{end}}{{end}}')

TOTAL=$(echo "$CONTAINERS" | grep -c .)
ATUAL=0

echo "Iniciando verificação (alvo: Java >= $MIN_VERSION) em $TOTAL containers..."
echo "--------------------------------------------------------------------------------"

while read -r ns pod container; do
  [ -z "$ns" ] && continue
  ((ATUAL++))

  # Executa java -version diretamente no container (sem depender de /bin/sh)
  raw_out=$(oc exec -n "$ns" "$pod" -c "$container" -- java -version 2>&1)
  rc=$?

  if [ $rc -eq 0 ]; then
    version=$(echo "$raw_out" | awk -F '"' '/version/ {print $2}' | head -n1)

    if version_ge "$version" "$MIN_VERSION"; then
      status="AFETADO (Java >= $MIN_VERSION)"
      echo "[$ATUAL/$TOTAL] [!] $ns / $pod ($container) -> $status [$version]"
    else
      status="SEGURO (Java < $MIN_VERSION)"
      echo "[$ATUAL/$TOTAL] [OK] $ns / $pod ($container) -> $status [$version]"
    fi
    echo "$ns,$pod,$container,$status,$version" >> "$OUTPUT_CSV"
  else
    status="SEM JAVA"
    echo "$ns,$pod,$container,$status,N/A" >> "$OUTPUT_CSV"
  fi

done <<< "$CONTAINERS"

echo "--------------------------------------------------------------------------------"
echo "Varredura concluída. Relatório completo salvo em: $OUTPUT_CSV"
echo ""
echo "Resumo:"
echo " - Containers AFETADOS (Java >= $MIN_VERSION): $(grep -c "AFETADO" "$OUTPUT_CSV")"
echo " - Containers SEGUROS  (Java < $MIN_VERSION):  $(grep -c "SEGURO" "$OUTPUT_CSV")"
echo " - Containers SEM JAVA:                        $(grep -c "SEM JAVA" "$OUTPUT_CSV")"
