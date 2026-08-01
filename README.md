# OpenWhisk no Kubernetes

Implantacao do Apache OpenWhisk (Serverless) no cluster Kubernetes via Helm.

## Modo de execucao

O deploy utiliza o modo **lean** (`controller.lean: true`), que elimina Kafka e Zookeeper e utiliza message bus em memoria. Isso reduz o consumo de recursos (menos pods, menos volumes) e simplifica a operacao.

### Quando ativar o Kafka

Para ambientes que exigem entrega garantida e persistente de mensagens:

```yaml
controller:
  lean: false

kafka:
  replicaCount: 1
  persistence:
    size: "2Gi"

zookeeper:
  replicaCount: 1
  persistence:
    size: "1Gi"
```

## Pre-requisitos

- Kubernetes cluster com pelo menos 1 worker node (4GB RAM, 2 CPUs)
- Helm 3 (instalado automaticamente pelo pipeline)
- Node labels (para clusters multi-node):

```bash
kubectl label node <NODE> openwhisk-role=invoker
kubectl label node <NODE> openwhisk-role=core
kubectl label node <NODE> openwhisk-role=edge
```

## Pipeline

O deploy é feito via GitHub Actions (`deploy-openwhisk.yaml`), disparado por PR na branch `main` ou manualmente via `workflow_dispatch`.

### Fluxo

1. Renderiza `mycluster.yaml` com variáveis de ambiente (envsubst)
2. Copia o arquivo de valores para a VM via SCP
3. Instala/atualiza o Helm na VM
4. Executa `helm install` ou `helm upgrade` com o chart do OpenWhisk
5. Aguarda todos os pods ficarem prontos
6. Executa `helm test` para validacao basica

### Secrets e Variables (GitHub Environment `production`)

| Nome | Tipo | Descricao |
|------|------|-----------|
| `SSH_HOST` | secret | IP/hostname da VM |
| `SSH_USER` | secret | Usuario SSH |
| `SSH_PRIVATE_KEY` | secret | Chave privada SSH |
| `SSH_PASSPHRASE` | secret | Passphrase da chave SSH |
| `SSH_PORT` | secret | Porta SSH |
| `OPENWHISK_API_HOST` | var | Hostname da API OpenWhisk |
| `OPENWHISK_API_HOST_PORT` | var | Porta da API (ex: 31001) |
| `OPENWHISK_AUTH_SYSTEM_KEY` | secret | Chave de autenticacao do sistema |
| `OPENWHISK_DB_PASSWORD` | secret | Senha do CouchDB |

### Configuracao do `wsk` CLI

Apos o deploy, configure o CLI:

```bash
wsk property set --apihost ${OPENWHISK_API_HOST}:${OPENWHISK_API_HOST_PORT}
wsk property set --auth ${OPENWHISK_AUTH_SYSTEM_KEY}
```

Para certificados autoassinados (padrao), use `wsk -i`.

## Verificacao

```bash
# Status dos pods
kubectl get pods -n openwhisk -o wide

# Helm release
helm list -n openwhisk

# Teste de actions
wsk -i action create hello <(echo 'function main() { return { message: "hello" }; }') --kind nodejs:18
wsk -i action invoke hello --result
```

## Cleanup

```bash
helm uninstall owdev -n openwhisk
```

## Referencias

- [OpenWhisk Deploy Kube](https://github.com/apache/openwhisk-deploy-kube)
- [Configuracao do Helm Chart](https://github.com/apache/openwhisk-deploy-kube/blob/master/docs/configurationChoices.md)
- [Troubleshooting](https://github.com/apache/openwhisk-deploy-kube/blob/master/docs/troubleshooting.md)
