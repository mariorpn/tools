# tools

## check_java.yml

playbook para listar VMs que possuem java e separar em uma lista as VMs que possuem a versão de java igual ou maior que 17.0.6.

---

### Executar localhost
```ansibleplaybook -i localhost, -c local check_java.yml -K```

### Executar em lista de servidores (inventory)
```ansibleplaybook -i inventory.file -c local check_java.yml -K```

PS: O parâmetro "-K" é para passar a senha de sudo por conta do "become: yes"


## check_java_ocp.sh

bash script para verificar e comparar a versão do java de todos os containers de um cluster openshift e gerar um arquivo csv ao final com o relatório dessa varredura.

---

### Pré-requisitos
**CLI `oc` instalada** e autenticada no cluster com permissão de `cluster-admin` (necessária para executar pods privilegiados nos nodes).

### Comandos
```
$ chmod +x check_java_ocp.sh
$ oc login -u USER https://api.OCP_NAME.domain.example:6443
$ ./check_java_ocp.sh
```
PS: Substituir "USER" pelo usuário do cluster openshift, "OCP_NAME" pelo nome do cluster e "domain.example" pelo domínio onde o cluster está.



## check_cpu_avx_ocp.sh

Este procedimento executa uma varredura **somente leitura** em todos os nodes do cluster OpenShift para identificar quais hosts possuem a instrução de CPU `avx512vbmi` habilitada (requisito de hardware conhecido para exploração do **CVE-2026-114938**).

---

### Pré-requisitos

1. **CLI `oc` instalada** e autenticada no cluster com permissão de `cluster-admin` (necessária para executar pods privilegiados nos nodes).
2. **Namespace `dummy` configurado para debug:**
   * A partir do OpenShift 4.12, o *Pod Security Admission (PSA)* bloqueia ou restringe pods privilegiados em namespaces comuns. Como o comando `oc debug` precisa acessar o sistema de arquivos do host (`chroot /host`), o cluster **precisa possuir o namespace `dummy`** criado e configurado com o perfil `privileged`.
   * Caso o cluster ainda não possua esse namespace, crie-o antes de rodar o script:

```bash
oc create namespace dummy
oc label namespace dummy \
  pod-security.kubernetes.io/enforce=privileged \
  pod-security.kubernetes.io/audit=privileged \
  pod-security.kubernetes.io/warn=privileged --overwrite
```

> **Referências oficiais da Red Hat:**
> * [Red Hat Openshift KCS Solution — Debug node fail](https://access.redhat.com/kb/4976641)
> * [Red Hat OpenShift Documentation — Investigating node issues (`oc debug`)](https://docs.openshift.com/container-platform/latest/support/troubleshooting/investigating-node-issues.html)
> * [Red Hat OpenShift Documentation — Understanding and managing Pod Security Admission](https://docs.openshift.com/container-platform/latest/authentication/understanding-and-managing-pod-security-admission.html)

---

### Como utilizar

### 1. Valide se o namespace `dummy` existe
```bash
oc get ns dummy
```
*(Se retornar `NotFound`, execute os comandos da seção de **Pré-requisitos** antes de prosseguir).*

### 2. Salve e execute o script de auditoria

Baixe o arquivo `check_cpu_avx_ocp.sh` e execute os comandos

```
chmod +x check_avx512_nodes.sh
$ oc login -u USER https://api.OCP_NAME.domain.example:6443
./check_avx512_nodes.sh
```
PS: Substituir "USER" pelo usuário do cluster openshift, "OCP_NAME" pelo nome do cluster e "domain.example" pelo domínio onde o cluster está.

### 3. Analise o relatório e realize a limpeza (opcional)

* Os resultados detalhados ficam disponíveis no arquivo **`auditoria_avx512_nodes.csv`**.
* Para listar apenas os nodes com a flag ativa:
  ```bash
  grep "AFETADO" auditoria_avx512_nodes.csv
  ```
* Caso a política interna do ambiente exija a remoção do namespace temporário após o diagnóstico:
  ```bash
  oc delete namespace dummy
  ```
