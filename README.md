# OpenWhisk no Kubernetes

Implantacao do Apache OpenWhisk (Serverless) no cluster Kubernetes via Terraform + kubectl.

## Estrutura

```
open-whisk/
├── main.tf                        # Terraform: renderiza manifests com variaveis
├── variables.tf                   # Inputs (api_host, auth_key, db_password)
├── terraform.tfvars.template      # Template de valores (copia para terraform.tfvars)
├── manifests/                     # Manifests Kubernetes com placeholders ${VAR}
│   ├── 00-namespace.yaml
│   ├── 01-secrets.yaml
│   ├── 02-serviceaccounts.yaml
│   ├── 03-rbac.yaml
│   ├── 04-configmaps.yaml
│   ├── 05-persistentvolumeclaims.yaml
│   ├── 06-services.yaml
│   ├── 07-statefulsets.yaml
│   ├── 08-couchdb-deployment.yaml
│   ├── 09-jobs.yaml
│   ├── 10-pods.yaml
│   ├── 11-networkpolicies.yaml
│   └── 12-nginx-deployment.yaml
├── deploy/                        # Renderizado pelo Terraform (gitignored)
├── .github/workflows/
│   └── deploy-openwhisk.yaml      # Pipeline CI/CD
├── .gitignore
└── README.md
```

## Modo Lean

O deploy utiliza o modo **lean** (`controller.lean: true`), sem Kafka/Zookeeper. O estado e mensageria ficam em memoria.

### Quando usar Kafka

Para ambientes que exigem entrega garantida de mensagens, gere novamente os manifests:

```bash
helm template owdev openwhisk/openwhisk -f mycluster.yaml > manifests/all.yaml
```

E adicione os recursos de Kafka/Zookeeper ao diretorio `manifests/`.

## Pre-requisitos

- Kubernetes cluster com pelo menos 1 worker node (4GB RAM, 2 CPUs)
- kubectl configurado na VM de deploy
- `envsubst` disponivel na VM
- Node labels (apenas para multi-node):

```bash
kubectl label node <NODE> openwhisk-role=invoker
kubectl label node <NODE> openwhisk-role=core
kubectl label node <NODE> openwhisk-role=edge
kubectl label node <NODE> openwhisk-role=provider
```

## Pipeline

O deploy e feito via GitHub Actions, disparado por PR na branch `main` ou manualmente via `workflow_dispatch`.

### Fluxo

| Evento | Job | Descricao |
|--------|-----|-----------|
| PR aberta/atualizada | `plan` | `terraform plan` — preview do que sera alterado |
| merge na `main` ou `workflow_dispatch` | `apply` | Renderiza + SCP + `kubectl apply` + verify |

### Etapas do job `apply`

1. **Terraform Init** — baixa provider `null`
2. **Terraform Apply** — renderiza manifests com `envsubst` para `deploy/`
3. **SSH** — cria diretorio `/opt/cys/openwhisk` na VM
4. **SCP** — copia `deploy/` para a VM
5. **SSH** — `kubectl apply -f` em ordem numerica
6. **SSH** — `kubectl wait` para deployments/jobs
7. **SSH** — verificacao final (pods, services, logs de falhas)
8. **Limpeza** — remove `/opt/cys/openwhisk` da VM

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
| `OPENWHISK_AUTH_SYSTEM_KEY` | secret | Chave de autenticacao do sistema (uuid:secret) |
| `OPENWHISK_AUTH_GUEST_KEY` | secret | Chave de autenticacao guest (deve ser diferente da system) |
| `OPENWHISK_DB_PASSWORD` | secret | Senha do CouchDB |

## Uso local

```bash
# Copie o template e preencha os valores
cp terraform.tfvars.template terraform.tfvars

# Preview do que sera gerado
terraform init
terraform plan

# Renderizar e aplicar (precisa de kubectl configurado)
terraform apply -auto-approve
```

## Configuracao do `wsk` CLI

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

# Teste de actions
wsk -i action create hello <(echo 'function main() { return { message: "hello" }; }') --kind nodejs:18
wsk -i action invoke hello --result
```

## Cleanup

```bash
kubectl delete namespace openwhisk
```
