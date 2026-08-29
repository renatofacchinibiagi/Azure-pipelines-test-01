# Azure-pipelines-test-01

Infraestrutura Azure com Terraform e GitHub Actions.

Este repositorio cria:

- Resource group: `rg-azure-pipelines-test-01`
- Virtual network: `vnet-azure-pipelines-test-01`
- Subnet: `snet-azure-pipelines-test-01`
- Storage Account e container Blob para backend remoto do Terraform state
- Pipeline GitHub Actions com autenticacao OIDC na Azure
- Azure Container Registry (ACR) para guardar imagens Docker
- Managed Identity dedicada para o Container Instance puxar imagens do ACR sem senha
- Azure Container Instance (ACI) rodando uma aplicacao HTML simples empacotada em Docker

## Como O Projeto Esta Organizado

```text
.
├── .github/workflows/terraform.yml  # Pipeline GitHub Actions para Terraform
├── app/index.html                   # Aplicacao HTML simples usada no container
├── Dockerfile                       # Empacota app/index.html com nginx
├── bootstrap/                       # Cria RG, Storage Account e container do tfstate
├── backend.tf.example               # Modelo local de backend remoto
├── main.tf                          # Cria VNet, subnet, ACR, identity e Container Instance
├── outputs.tf                       # Outputs da infraestrutura principal
├── providers.tf                     # Provider AzureRM
├── variables.tf                     # Variaveis da infraestrutura principal
└── versions.tf                      # Versoes do Terraform e providers
```

## Conceitos Principais

**Terraform state** é o arquivo que registra o que o Terraform gerencia. Ele nao deve ser versionado no Git. Neste projeto, o state principal fica em um container Blob no Azure Storage.

**Bootstrap** é a primeira etapa que cria a base necessaria para o Terraform trabalhar com backend remoto: resource group, Storage Account e container `tfstate`.

**GitHub Actions** é a ferramenta de automacao do GitHub. O arquivo `.github/workflows/terraform.yml` define a pipeline.

**Pipeline CI/CD** é o fluxo automatizado que valida, planeja e, quando autorizado, aplica mudancas na Azure.

**OIDC** permite que o GitHub Actions autentique na Azure sem client secret. O GitHub emite um token temporario, e a Azure confia nele apenas quando o workflow vem do repositorio e branch configurados.

## Pre-requisitos Locais

- Azure CLI autenticado com `az login`
- Terraform instalado
- Permissao na subscription para criar resource group, storage account, container Blob, VNet e subnet

Confira a subscription ativa:

```powershell
az account show
```

Se precisar trocar:

```powershell
az account set --subscription "<subscription-id-ou-nome>"
```

## 1. Criar O Bootstrap Do State

O bootstrap cria:

- `rg-azure-pipelines-test-01`
- Storage Account para guardar o state remoto
- Container Blob `tfstate`

Execute a partir da raiz do repositorio:

```powershell
terraform -chdir=bootstrap init
terraform -chdir=bootstrap fmt -recursive
terraform -chdir=bootstrap validate
terraform -chdir=bootstrap plan -out=tfplan
terraform -chdir=bootstrap apply tfplan
```

Depois do apply, consulte os outputs:

```powershell
terraform -chdir=bootstrap output
```

Guarde o valor de `storage_account_name`. Ele sera usado no backend remoto e nas variables do GitHub.

## 2. Configurar O Backend Remoto Local

Copie o exemplo:

```powershell
Copy-Item backend.tf.example backend.tf
```

Edite `backend.tf` e substitua `<storage_account_name_do_output_do_bootstrap>` pelo output `storage_account_name` do bootstrap.

Exemplo:

```hcl
terraform {
	backend "azurerm" {
		resource_group_name  = "rg-azure-pipelines-test-01"
		storage_account_name = "stazpipe01abc123"
		container_name       = "tfstate"
		key                  = "network/terraform.tfstate"
	}
}
```

O arquivo `backend.tf` fica no `.gitignore` porque ele e uma configuracao local. O arquivo versionado e apenas o `backend.tf.example`.

## 3. Criar A Infraestrutura Principal Localmente

Depois do backend configurado, rode na raiz:

```powershell
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

Isso cria ou atualiza a VNet e a subnet dentro do resource group criado pelo bootstrap.

## 4. Criar A Managed Identity Para O GitHub Actions

A Managed Identity representa a pipeline dentro da Azure. Ela e a identidade que o GitHub Actions usa para executar Terraform.

No Portal Azure:

1. Pesquise por **Managed Identities**
2. Clique em **Create**
3. Preencha:
	 - **Subscription**: sua subscription
	 - **Resource group**: `rg-azure-pipelines-test-01`
	 - **Region**: a mesma regiao do resource group
	 - **Name**: `id-github-actions-azure-pipelines-test-01`
4. Clique em **Review + create**
5. Clique em **Create**

Depois de criada, abra a Managed Identity e anote:

- **Client ID**: usado como `AZURE_CLIENT_ID` no GitHub
- **Tenant ID**: usado como `AZURE_TENANT_ID` no GitHub

O **Object ID** nao é o Tenant ID. Ele identifica internamente a identidade no Entra ID, mas nao é usado na variavel `AZURE_TENANT_ID`.

Tambem é possivel obter estes valores pelo terminal:

```powershell
az account show --query tenantId -o tsv
az account show --query id -o tsv
```

## 5. Configurar Permissoes IAM Da Managed Identity

A Managed Identity precisa de permissao no resource group para criar e alterar recursos, e permissao na Storage Account para ler e gravar o Terraform state.

No resource group `rg-azure-pipelines-test-01`:

1. Abra **Access control (IAM)**
2. Clique em **Add > Add role assignment**
3. Escolha a role **Contributor**
4. Em **Assign access to**, selecione **Managed identity**
5. Selecione `id-github-actions-azure-pipelines-test-01`
6. Clique em **Review + assign**

Na Storage Account criada pelo bootstrap:

1. Abra **Access control (IAM)**
2. Clique em **Add > Add role assignment**
3. Escolha a role **Storage Blob Data Contributor**
4. Em **Assign access to**, selecione **Managed identity**
5. Selecione `id-github-actions-azure-pipelines-test-01`
6. Clique em **Review + assign**

A role **Contributor** permite gerenciar recursos no resource group. A role **Storage Blob Data Contributor** permite que o backend remoto do Terraform leia e grave o state no Blob Storage usando Azure AD/OIDC.

## 6. Criar A Federated Credential OIDC

A Federated Credential cria a relacao de confianca entre GitHub Actions e Azure. Ela deve apontar para este repositorio e para a branch `main`.

No Portal Azure:

1. Abra a Managed Identity `id-github-actions-azure-pipelines-test-01`
2. Acesse **Settings > Federated credentials**
3. Clique em **Add Credential**
4. Selecione o cenario **GitHub Actions deploying Azure resources**
5. Preencha:
	 - **Organization**: `renatofacchinibiagi`
	 - **Repository**: `Azure-pipelines-test-01`
	 - **Entity**: `Branch`
	 - **Branch**: `main`
	 - **Name**: `github-main`
6. Clique em **Add**

Se o Portal pedir IDs numericos do GitHub, use:

```powershell
gh api users/renatofacchinibiagi --jq ".id"
gh api repos/renatofacchinibiagi/Azure-pipelines-test-01 --jq ".id"
```

Se preferir criar via Azure CLI, o comando equivalente e:

```powershell
az identity federated-credential create `
	--name "github-main" `
	--identity-name "id-github-actions-azure-pipelines-test-01" `
	--resource-group "rg-azure-pipelines-test-01" `
	--issuer "https://token.actions.githubusercontent.com" `
	--subject "repo:renatofacchinibiagi/Azure-pipelines-test-01:ref:refs/heads/main" `
	--audiences "api://AzureADTokenExchange"
```

Nao crie `AZURE_CLIENT_SECRET`. Com OIDC, nao existe senha fixa salva no GitHub.

## 7. Criar Variables No GitHub

No GitHub, acesse:

```text
Repository > Settings > Secrets and variables > Actions > Variables
```

Crie uma repository variable por vez:

| Variable | Valor |
| --- | --- |
| `AZURE_CLIENT_ID` | Client ID da managed identity usada pelo GitHub Actions |
| `AZURE_TENANT_ID` | Tenant ID retornado por `az account show --query tenantId -o tsv` |
| `AZURE_SUBSCRIPTION_ID` | Subscription ID retornado por `az account show --query id -o tsv` |
| `TF_STATE_RESOURCE_GROUP_NAME` | `rg-azure-pipelines-test-01` |
| `TF_STATE_STORAGE_ACCOUNT_NAME` | Output `storage_account_name` do bootstrap |
| `TF_STATE_CONTAINER_NAME` | `tfstate` |
| `TF_STATE_KEY` | `network/terraform.tfstate` |

Para pegar o nome da Storage Account do state:

```powershell
terraform -chdir=bootstrap output -raw storage_account_name
```

Esses valores podem ficar em **Variables**, porque nao sao senhas. Nao use **Secrets** para `AZURE_CLIENT_SECRET`, porque esse projeto nao usa secret.

## 8. Como A Pipeline Funciona

O workflow fica em `.github/workflows/terraform.yml`.

Ele possui permissao:

```yaml
permissions:
	contents: read
	id-token: write
```

`id-token: write` permite que o GitHub Actions solicite um token OIDC para autenticar na Azure.

O workflow executa automaticamente em:

- Pull requests para `main`
- Pushes para `main`

Nesses casos, ele roda:

- `terraform fmt -check -recursive`
- Criacao temporaria de um `backend.tf` no runner
- `terraform init` com backend remoto no Azure Storage
- `terraform validate`
- `terraform plan -out=tfplan`

O `terraform apply` nao roda automaticamente em push. Ele so roda quando o workflow e executado manualmente com `apply` marcado como `true`.

## 9. Como Rodar Pelo GitHub Actions

Para validar uma mudanca:

1. Altere o codigo Terraform localmente
2. Rode `terraform fmt -recursive` e `terraform validate`
3. Faca commit e push para `main`
4. Abra **Actions > Terraform** no GitHub
5. Confira se o workflow passou e veja o resultado do `terraform plan`

Para aplicar uma mudanca na Azure pela pipeline:

1. Abra **Actions > Terraform**
2. Clique em **Run workflow**
3. Selecione a branch `main`
4. Marque **Run terraform apply after plan**
5. Clique em **Run workflow**

Se a infraestrutura ja estiver igual ao codigo, o plan/apply deve mostrar que nao ha mudancas. Se houver alteracao no codigo, o plan mostra o que sera criado, alterado ou removido antes do apply.

## 10. Docker Local: Build E Execucao Da Aplicacao

A aplicacao deste lab e uma pagina HTML simples em `app/index.html`, empacotada com nginx via `Dockerfile`.

Pre-requisito: Docker Desktop instalado e com o Engine rodando (`Engine running` no proprio app).

Build da imagem:

```powershell
docker build -t azure-pipelines-test-01:v1 .
```

Execucao local:

```powershell
docker run -d -p 8080:80 azure-pipelines-test-01:v1
```

Abra `http://localhost:8080` no navegador. Para parar:

```powershell
docker ps
docker stop <CONTAINER_ID>
```

Nesse ponto, a aplicacao roda 100% local. A Azure ainda nao esta envolvida.

## 11. Azure Container Registry E Azure Container Instance

Alem de VNet e subnet, o `main.tf` cria mais 4 recursos para rodar essa aplicacao na Azure:

- `azurerm_container_registry.main`: o ACR, com `admin_enabled = false` (sem senha de admin)
- `azurerm_user_assigned_identity.aci`: uma Managed Identity dedicada, usada apenas para o Container Instance autenticar no ACR
- `azurerm_role_assignment.aci_acr_pull`: da a role `AcrPull` para essa identity, escopada no ACR
- `azurerm_container_group.main`: o Azure Container Instance (ACI), que roda o container publicamente na porta 80, usando a identity acima para puxar a imagem sem senha

Esse padrao repete o mesmo principio usado no GitHub Actions com OIDC: nenhum servico usa senha fixa, cada um tem uma identidade dedicada com a role minima necessaria.

Como o Container Instance depende de uma imagem que ainda nao existe no primeiro apply, a criacao e feita em duas etapas, explicadas abaixo.

## 12. Aplicar Apenas ACR, Identity E Role Assignment

Na raiz do projeto:

```powershell
terraform plan -target azurerm_container_registry.main -target azurerm_user_assigned_identity.aci -target azurerm_role_assignment.aci_acr_pull -out=tfplan
terraform apply tfplan
```

Isso cria o ACR e a identity, sem tentar criar o Container Instance ainda.

## 13. Dar A Voce Mesmo Permissao De Push No ACR

Como o ACR nao tem admin/senha, seu proprio usuario tambem precisa de uma role de dados para enviar imagens.

Pelo Azure CLI:

```powershell
$USER_OBJECT_ID = az ad signed-in-user show --query id -o tsv
$ACR_RESOURCE_ID = az acr show --name (terraform output -raw acr_name) --query id -o tsv

az role assignment create --assignee $USER_OBJECT_ID --role AcrPush --scope $ACR_RESOURCE_ID
```

Ou pelo Portal Azure: abra o ACR, va em **Access control (IAM)**, **Add role assignment**, escolha a role `AcrPush`, selecione seu proprio usuario em **Select members** e confirme em **Review + assign**.

## 14. Build, Tag E Push Da Imagem Para O ACR

Login no ACR usando sua propria conta Azure:

```powershell
az acr login --name (terraform output -raw acr_name)
```

Criar a tag apontando para o ACR e enviar a imagem:

```powershell
$ACR_LOGIN_SERVER = terraform output -raw acr_login_server
docker tag azure-pipelines-test-01:v1 "$ACR_LOGIN_SERVER/azure-pipelines-test-01:v1"
docker push "$ACR_LOGIN_SERVER/azure-pipelines-test-01:v1"
```

Esse nome final precisa bater com as variaveis `container_image_name` e `container_image_tag` usadas no `main.tf`.

## 15. Aplicar O Container Instance

Com a imagem ja no ACR, aplique o restante:

```powershell
terraform plan -out=tfplan
terraform apply tfplan
```

Isso cria o `azurerm_container_group.main`. Para ver a URL publica:

```powershell
terraform output aci_fqdn
```

Abra essa URL no navegador. A pagina passa a ser servida pela Azure, nao mais pelo seu computador. Para confirmar isso, pare o container local (`docker stop`) e recarregue a URL: ela deve continuar respondendo.

## 16. Atualizando A Aplicacao Para Uma Nova Versao

Fluxo para publicar uma nova versao da aplicacao:

1. Edite `app/index.html`
2. Gere uma nova imagem local, com tag nova:

```powershell
docker build -t azure-pipelines-test-01:v2 .
```

3. Teste local antes de enviar (boa pratica):

```powershell
docker run -d -p 8081:80 azure-pipelines-test-01:v2
```

4. Login, tag e push da nova versao:

```powershell
az acr login --name (terraform output -raw acr_name)
docker tag azure-pipelines-test-01:v2 "$(terraform output -raw acr_login_server)/azure-pipelines-test-01:v2"
docker push "$(terraform output -raw acr_login_server)/azure-pipelines-test-01:v2"
```

5. Atualize `variables.tf`, mudando o default de `container_image_tag` para `"v2"`

6. Aplique novamente:

```powershell
terraform plan -out=tfplan
terraform apply tfplan
```

O Terraform substitui o Container Instance (Container Instance nao suporta troca de imagem em tempo real), recriando-o ja com a nova imagem.

## 17. Encerrar Recursos Para Nao Gerar Custo

O Azure Container Instance cobra por segundo enquanto estiver rodando. O ACR e a Storage Account do state tem custo baixo, porem fixo, enquanto existirem.

Para pausar sem perder o trabalho feito no ACR:

```powershell
terraform destroy -target azurerm_container_group.main
```

Isso remove somente o Container Instance. VNet, subnet, ACR, identities e as imagens ja enviadas continuam intactos. Para recriar o container depois:

```powershell
terraform plan -out=tfplan
terraform apply tfplan
```

Para remover tudo criado neste diretorio (exceto o bootstrap):

```powershell
terraform destroy
```

O `bootstrap/` (resource group + Storage Account do state) e gerenciado separadamente:

```powershell
terraform -chdir=bootstrap destroy
```

## 18. Proximo Passo: Build E Push Dentro Do GitHub Actions

Hoje o build/push da imagem Docker e feito manualmente. O proximo passo natural e mover isso para dentro do workflow `.github/workflows/terraform.yml`, ainda nao implementado neste repositorio.

Ideia geral da pipeline com Docker:

```text
1. Push no GitHub
2. GitHub Actions autentica na Azure via OIDC (ja configurado)
3. Workflow faz docker build da imagem
4. Workflow faz login no ACR usando a mesma identidade OIDC
5. Workflow faz docker tag usando o SHA do commit, em vez de v1/v2 manuais
6. Workflow faz docker push para o ACR
7. Terraform aplica, recebendo a tag da imagem via variavel dinamica:
   terraform apply -var="container_image_tag=<sha-do-commit>" tfplan
```

Para isso funcionar, a Managed Identity do GitHub Actions (`id-github-actions-azure-pipelines-test-01`) tambem precisaria da role `AcrPush`, escopada no ACR, do mesmo jeito que foi dada ao usuario no passo 13.

## 19. Variaveis Terraform

Na raiz:

- `resource_group_name`: padrao `rg-azure-pipelines-test-01`
- `virtual_network_name`: padrao `vnet-azure-pipelines-test-01`
- `vnet_address_space`: padrao `["10.10.0.0/16"]`
- `subnet_name`: padrao `snet-azure-pipelines-test-01`
- `subnet_address_prefixes`: padrao `["10.10.1.0/24"]`
- `acr_name`: opcional; se nao informar, o Terraform gera um nome valido com sufixo aleatorio
- `acr_sku`: padrao `Basic`
- `container_image_name`: padrao `azure-pipelines-test-01`
- `container_image_tag`: padrao `v2`
- `container_cpu`: padrao `0.5`
- `container_memory_gb`: padrao `1`
- `aci_dns_name_label`: opcional; se nao informar, o Terraform gera um prefixo unico com sufixo aleatorio
- `tags`: tags aplicadas aos recursos

No bootstrap:

- `resource_group_name`: padrao `rg-azure-pipelines-test-01`
- `location`: padrao `brazilsouth`
- `storage_account_name`: opcional; se nao informar, o Terraform gera um nome valido com sufixo aleatorio
- `state_container_name`: padrao `tfstate`

## 20. Boas Praticas De Git

O `.gitignore` foi configurado para ignorar:

- Diretorios `.terraform/`
- Arquivos de state `*.tfstate`
- Variaveis locais `*.tfvars` e `*.tfvars.json`
- Planos `*.tfplan`, `tfplan` e `planout`
- Configuracao local `backend.tf`

O arquivo `.terraform.lock.hcl` nao foi ignorado de proposito. Depois do `terraform init`, ele deve ser versionado para manter versoes de providers reproduziveis no time e em pipelines.

Antes de fazer commit, confira:

```powershell
git status --short
```

Devem ir para o Git arquivos como `.tf`, `.terraform.lock.hcl`, `.github/workflows/terraform.yml`, `backend.tf.example`, `Dockerfile`, `app/index.html` e `README.md`.

Nao devem ir para o Git arquivos como `backend.tf`, `terraform.tfstate`, `*.tfplan` e diretorios `.terraform/`.

## 21. Proximos Estudos: Kubernetes E Escala Maior

Este lab hoje cobre o fluxo completo de container em um unico recurso:

```text
GitHub -> Docker build/push manual -> ACR -> Azure Container Instance -> URL publica
```

Para uma aplicacao real, com multiplas replicas, autoscaling e alta disponibilidade, os proximos passos comuns sao:

**Azure Container Apps**: roda containers com multiplas replicas e autoscaling gerenciado (baseado em CPU, memoria ou numero de requisicoes HTTP), sem precisar administrar um cluster Kubernetes diretamente. E o proximo passo mais natural depois do Container Instance.

**AKS (Azure Kubernetes Service)**: cluster Kubernetes gerenciado pela Azure. Da controle total via recursos nativos do Kubernetes, como o Horizontal Pod Autoscaler (HPA), mas exige gerenciar nos, deployments, services e ingress.

Com Terraform, evoluir para Container Apps envolveria criar um `Container Apps Environment` e um `Container App` reaproveitando a mesma VNet/subnet e o mesmo ACR ja criados neste lab. Evoluir para AKS envolveria criar um cluster (`azurerm_kubernetes_cluster`) e node pools, tambem reaproveitando VNet, subnet e ACR.

Ordem recomendada de estudo a partir daqui:

1. Automatizar build/push no GitHub Actions (secao 18)
2. Migrar do Container Instance para Azure Container Apps
3. Adicionar dominio proprio e HTTPS
4. Estudar Kubernetes e AKS
