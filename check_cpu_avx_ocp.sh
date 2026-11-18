#!/bin/bash

DEBUG_NS="dummy"
OUTPUT_CSV="auditoria_avx512_nodes.csv"
echo "NODE,ARQUITETURA,STATUS,FLAG_CPU" > "$OUTPUT_CSV"

# Garante que o namespace de debug exista com permissão privilegiada (PSA)
#if ! oc get ns "$DEBUG_NS" >/dev/null 2>&1; then
#  echo "Criando namespace '$DEBUG_NS' com perfil privileged para o oc debug..."
#  oc create ns "$DEBUG_NS" >/dev/null
#  oc label ns "$DEBUG_NS" \
#    pod-security.kubernetes.io/enforce=privileged \
#    pod-security.kubernetes.io/audit=privileged \
#    pod-security.kubernetes.io/warn=privileged --overwrite >/dev/null
#fi

echo "Coletando lista de nodes do cluster..."

# Obtém nome e arquitetura de cada node
NODES=$(oc get nodes -o go-template='{{range .items}}{{.metadata.name}} {{.status.nodeInfo.architecture}}{{"\n"}}{{end}}')

TOTAL=$(echo "$NODES" | grep -c .)
ATUAL=0

echo "Iniciando verificação de suporte AVX-512 VBMI em $TOTAL nodes..."
echo "--------------------------------------------------------------------------------"

while read -r node arch; do
  [ -z "$node" ] && continue
  ((ATUAL++))

  # Executa grep com -m1 (para na primeira ocorrência) e diferencia ausência da flag de erro no oc debug
  raw_out=$(oc debug "node/$node" --to-namespace="$DEBUG_NS" -- chroot /host sh -c "grep -m1 -o 'avx512vbmi' /proc/cpuinfo || echo 'NOT_FOUND'" 2>/dev/null)
  clean_out=$(echo "$raw_out" | tr -d '\r\n' | xargs)

  if [[ "$clean_out" == *"avx512vbmi"* ]]; then
    status="AFETADO (AVX-512 VBMI ativo)"
    flag="avx512vbmi"
    echo "[$ATUAL/$TOTAL] [!] $node ($arch) -> $status"
  elif [[ "$clean_out" == *"NOT_FOUND"* ]]; then
    status="NAO SUSCETIVEL (Sem AVX-512 VBMI)"
    flag="ausente"
    echo "[$ATUAL/$TOTAL] [OK] $node ($arch) -> $status"
  else
    status="ERRO (Falha no oc debug)"
    flag="desconhecido"
    echo "[$ATUAL/$TOTAL] [ERRO] $node ($arch) -> $status"
  fi

  echo "$node,$arch,$status,$flag" >> "$OUTPUT_CSV"

done <<< "$NODES"

echo "--------------------------------------------------------------------------------"
echo "Varredura concluída. Relatório completo salvo em: $OUTPUT_CSV"
echo ""
echo "Resumo:"
echo " - Nodes AFETADOS (AVX-512 VBMI ativo): $(grep -c "AFETADO" "$OUTPUT_CSV")"
echo " - Nodes NAO SUSCETIVEL  (Sem AVX-512 VBMI):   $(grep -c "NAO SUSCETIVEL" "$OUTPUT_CSV")"
echo " - Nodes com ERRO na verificação:       $(grep -c "ERRO" "$OUTPUT_CSV")"
