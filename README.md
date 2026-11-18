# tools

## check_java.yml
playbook para listar VMs que possuem java e separar em uma lista as VMs que possuem a versão de java igual ou maior que 17.0.6.

### Executar localhost
```ansibleplaybook -i localhost, -c local check_java.yml -K```

### Executar em lista de servidores (inventory)
```ansibleplaybook -i inventory.file -c local check_java.yml -K```

PS: O parâmetro "-K" é para passar a senha de sudo por conta do "become: yes"


## check_java_ocp.sh
bash script para verificar e comparar a versão do java de todos os containers de um cluster openshift e gerar um arquivo csv ao final com o relatório dessa varredura.

```
chmod +x check_java_ocp.sh
oc login -u USER https://api.OCP.domain.example:6443
./check_java_ocp.sh
```

PS: Substituir OCP pelo nome do cluster e "domain.example" pelo domínio onde o cluster está.
