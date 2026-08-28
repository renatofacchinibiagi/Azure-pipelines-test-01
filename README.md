# Azure-pipelines-test-01

Infraestrutura Azure com Terraform e GitHub Actions.

Este repositorio cria:

- Resource group: `rg-azure-pipelines-test-01`
- Virtual network: `vnet-azure-pipelines-test-01`
- Subnet: `snet-azure-pipelines-test-01`
- Storage Account e container Blob para backend remoto do Terraform state
- Pipeline GitHub Actions com autenticacao OIDC na Azure

## Como O Projeto Esta Organizado

```text
.
├── .github/workflows/terraform.yml  # Pipeline GitHub Actions para Terraform
├── bootstrap/                       # Cria RG, Storage Account e container do tfstate
├── backend.tf.example               # Modelo local de backend remoto
├── main.tf                          # Cria VNet e subnet no RG criado pelo bootstrap
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

## 10. Variaveis Terraform

Na raiz:

- `resource_group_name`: padrao `rg-azure-pipelines-test-01`
- `virtual_network_name`: padrao `vnet-azure-pipelines-test-01`
- `vnet_address_space`: padrao `["10.10.0.0/16"]`
- `subnet_name`: padrao `snet-azure-pipelines-test-01`
- `subnet_address_prefixes`: padrao `["10.10.1.0/24"]`
- `tags`: tags aplicadas na VNet

No bootstrap:

- `resource_group_name`: padrao `rg-azure-pipelines-test-01`
- `location`: padrao `brazilsouth`
- `storage_account_name`: opcional; se nao informar, o Terraform gera um nome valido com sufixo aleatorio
- `state_container_name`: padrao `tfstate`

## 11. Boas Praticas De Git

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

Devem ir para o Git arquivos como `.tf`, `.terraform.lock.hcl`, `.github/workflows/terraform.yml`, `backend.tf.example` e `README.md`.

Nao devem ir para o Git arquivos como `backend.tf`, `terraform.tfstate`, `*.tfplan` e diretorios `.terraform/`.
