# Azure-pipelines-test-01

Infraestrutura Azure com Terraform para criar:

- Um resource group: `rg-azure-pipelines-test-01`
- Uma virtual network: `vnet-azure-pipelines-test-01`
- Um bootstrap de backend remoto com Storage Account e container Blob para `tfstate`

## Estrutura

```text
.
├── bootstrap/              # Cria o RG, Storage Account e container do tfstate
├── backend.tf.example      # Exemplo para configurar o backend remoto da infra principal
├── main.tf                 # Cria a VNet no RG criado pelo bootstrap
├── outputs.tf
├── providers.tf
├── variables.tf
└── versions.tf
```

## Pre-requisitos

- Azure CLI autenticado com `az login`
- Terraform instalado
- Permissao para criar resource group, storage account, container Blob e virtual network na subscription Azure

Verifique a subscription ativa antes de aplicar:

```powershell
az account show
```

Se precisar trocar:

```powershell
az account set --subscription "<subscription-id-ou-nome>"
```

## 1. Criar o bootstrap do state

O bootstrap cria o resource group `rg-azure-pipelines-test-01`, uma Storage Account com nome unico e o container `tfstate`.

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

Guarde o valor de `storage_account_name`; ele sera usado no backend remoto da infraestrutura principal.

## 2. Configurar o backend remoto da infra principal

Copie o exemplo:

```powershell
Copy-Item backend.tf.example backend.tf
```

Edite `backend.tf` e substitua `<storage_account_name_do_output_do_bootstrap>` pelo output `storage_account_name` do bootstrap.

O arquivo `backend.tf` esta no `.gitignore` para evitar versionar configuracoes locais de backend. O modelo versionado fica em `backend.tf.example`.

## 3. Criar a infraestrutura principal

```powershell
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

## Variaveis principais

Na raiz:

- `resource_group_name`: padrao `rg-azure-pipelines-test-01`
- `virtual_network_name`: padrao `vnet-azure-pipelines-test-01`
- `vnet_address_space`: padrao `["10.10.0.0/16"]`
- `tags`: tags aplicadas na VNet

No bootstrap:

- `resource_group_name`: padrao `rg-azure-pipelines-test-01`
- `location`: padrao `brazilsouth`
- `storage_account_name`: opcional; se nao informar, o Terraform gera um nome valido com sufixo aleatorio
- `state_container_name`: padrao `tfstate`

## Boas praticas de Git

O `.gitignore` foi configurado para ignorar:

- Diretorios `.terraform/`
- Arquivos de state `*.tfstate`
- Variaveis locais `*.tfvars` e `*.tfvars.json`
- Planos `*.tfplan`, `tfplan` e `planout`
- Configuracao local `backend.tf`

O arquivo `.terraform.lock.hcl` nao foi ignorado de proposito. Depois do `terraform init`, ele deve ser versionado para manter versoes de providers reproduziveis no time e em pipelines.
