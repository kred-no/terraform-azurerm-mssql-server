# terraform-azurerm-mssql-server

Deploy SQL Server on Azure

| Category | Description                  | Status         | Latest Ref     | 
| :--      | :--                          | :--            | :--            |
| IaaS     | SQL Server (Virtual Machine) | In Development | rr-development |
| PaaS     | Azure SQL                    | N/A            | N/A            |
| PaaS     | Azure SQL (Managed Instance) | N/A            | N/A            |

## Features & Limitations
  
  1. Deploy an SQL server endpoint, using SQL Virtual Machine.
  1. Optionally add managed datadisks for data and/or logs.
  1. Join VM to AAD.
  1. Access SQL Host & SQL Server using "Load Balancer" IP (NAT/LB), or create a "Private Service Endpoint"
  1. Creates a customizable subnet.

  LIMITATIONS
  
  1. "SQL Virtual Machine" deployment deploys a single standalone VM


## Virtual Machine Extensions

> https://learn.microsoft.com/en-us/cli/azure/vm/extension/image?view=azure-cli-latest

```bash
# List all extensions
az vm extension image list --latest --location northeurope

# List publishers
az vm extension image list --query "[].publisher" -o tsv | sort -u

# List Extensions by Publisher
az vm extension image list-names --publisher Microsoft.SqlServer.Management --location northeurope --output table

# List Extension versions
az vm extension image list-versions -o table -l northeurope -p Microsoft.Azure.Extensions -n CustomScript
```

> https://learn.microsoft.com/en-us/azure/virtual-machines/extensions/

| Publisher                          | Name                     | Description |
| :--                                | :--                      | :--         |
| Microsoft.Azure.ActiveDirectory    | AADLoginForWindows       | Configure Windows VM for Azure AD based login.|
| Microsoft.Azure.Extensions         | CustomScript             | Automatically launch and execute VM customization tasks post configuration. |
| Microsoft.Azure.Extensions         | GuestActionForWindows    | N/A         |
| Microsoft.Azure.OpenSSH            | WindowsOpenSSH           | Install and enable OpenSSH. |
| Microsoft.Azure.RecoveryServices   | VMSnapshot               | https://learn.microsoft.com/en-us/azure/virtual-machines/extensions/backup-azure-sql-server-running-azure-vm |
| Microsoft.Compute                  | BGInfo                   | N/A         |
| Microsoft.Compute                  | CustomScriptExtension    | https://learn.microsoft.com/en-us/azure/virtual-machines/extensions/custom-script-windows |
| Microsoft.Compute                  | JsonADDomainExtension    | N/A         |
| Microsoft.Powershell               | DSC                      | https://learn.microsoft.com/en-us/azure/virtual-machines/extensions/dsc-overview |
| Microsoft.SoftwareUpdateManagement | WindowsOsUpdateExtension | N/A         |
| Microsoft.SqlServer.Management     | SqlIaaSAgent             | N/A         |

## Help

```bash
# Git Configuration
git config --list
git config --global push.default current
git config --global core.autocrlf false
git config --global core.eol lf
```

```powershell
# Get current public IP-address
(Invoke-WebRequest -uri "http://ifconfig.me/ip").Content
```

```powershell
# Connect using Bastion Native Client (rdp)
$BastionHost="<BASTION-HOSTNAME>"
$ResGroup="<RESOURCE-GROUP-NAME>"
$TargetId="<TARGET-AZURE-RESOURCE-ID>"

az network bastion rdp --name $BastionHost --resource-group $ResGroup --target-resource-id $TargetId
```
## References

* https://github.com/kumarvna/terraform-azurerm-mssql-db/blob/master/main.tf
