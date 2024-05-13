# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.9.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

locals {
  resource_group="devops-interview-gauntlet-x-rkwakye"
  location="East US"  
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "devops-interview-gauntlet-x-rkwakye"{
  name=local.resource_group
  location=local.location

          #   - "Finance_Forecast_Project_Name" = "KforceLabs" -> null
          # - "createdOn"                     = "2024-05-11T19:31:22.8650198Z" -> null
}

resource "azurerm_key_vault" "app_vault" {  
  name                        = "rkwakyevault6166195"
  location                    = local.location
  resource_group_name         = local.resource_group  
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    key_permissions = [
      "Get",
    ]
    secret_permissions = [
      "Get", "Backup", "Delete", "List", "Purge", "Recover", "Restore", "Set",
    ]
    storage_permissions = [
      "Get",
    ]
  }
  depends_on = [
    azurerm_resource_group.devops-interview-gauntlet-x-rkwakye
  ]
}

# We are defining a variable vmpassword 
variable "vmpassword" {
  description = "Password for the virtual machine"
}

# We are creating a secret in the key vault
resource "azurerm_key_vault_secret" "vmpassword" {
  name         = "vmpassword"
  value        = var.vmpassword
  key_vault_id = azurerm_key_vault.app_vault.id
  depends_on = [ azurerm_key_vault.app_vault ]
}



resource "azurerm_virtual_network" "app_network" {
  name                = "app-network"
  location            = local.location
  resource_group_name = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.name
  address_space       = ["10.0.0.0/16"]
  depends_on = [
    azurerm_resource_group.devops-interview-gauntlet-x-rkwakye
  ]
}

resource "azurerm_subnet" "SubnetA" {
  name                 = "SubnetA"
  resource_group_name  = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.name
  virtual_network_name = azurerm_virtual_network.app_network.name
  address_prefixes     = ["10.0.0.0/24"]  
  depends_on = [
    azurerm_virtual_network.app_network
  ]
}

resource "azurerm_subnet" "SubnetB" {
  name                 = "SubnetB"
  resource_group_name  = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.name
  virtual_network_name = azurerm_virtual_network.app_network.name
  address_prefixes     = ["10.0.1.0/24"]
  delegation {
    name = "delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }  
  depends_on = [
    azurerm_virtual_network.app_network
  ]
}

// This interface is for appvm1
resource "azurerm_network_interface" "app_interface1" {
  name                = "app-interface1"
  location            = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.location
  resource_group_name = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.SubnetA.id
    private_ip_address_allocation = "Dynamic" 
    public_ip_address_id = azurerm_public_ip.app_vm1_public_ip.id    
  }

  depends_on = [
    azurerm_virtual_network.app_network,
    azurerm_subnet.SubnetA
  ]
}

// This interface is for appvm2
resource "azurerm_network_interface" "app_interface2" {
  name                = "app-interface2"
  location            = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.location
  resource_group_name = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.SubnetA.id
    private_ip_address_allocation = "Dynamic"    
    public_ip_address_id = azurerm_public_ip.app_vm2_public_ip.id    
  }

  depends_on = [
    azurerm_virtual_network.app_network,
    azurerm_subnet.SubnetA
  ]
}

// This interface is for appvm3
resource "azurerm_network_interface" "app_interface3" {
  name                = "app-interface3"
  location            = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.location
  resource_group_name = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.SubnetA.id
    private_ip_address_allocation = "Dynamic"    
    public_ip_address_id = azurerm_public_ip.app_vm3_public_ip.id    
  }

  depends_on = [
    azurerm_virtual_network.app_network,
    azurerm_subnet.SubnetA
  ]
}

// This is the resource for appvm1
resource "azurerm_windows_virtual_machine" "app_vm1" {
  name                = "iis-server-01"
  resource_group_name = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.name
  location            = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.location
  size                = "Standard_D2s_v3"
  admin_username      = "demousr"
  admin_password      = azurerm_key_vault_secret.vmpassword.value
  availability_set_id = azurerm_availability_set.app_set.id
  network_interface_ids = [
    azurerm_network_interface.app_interface1.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }

  depends_on = [
    azurerm_network_interface.app_interface1,
    azurerm_availability_set.app_set
  ]
}

// This is the resource for appvm2
resource "azurerm_windows_virtual_machine" "app_vm2" {
  name                = "iis-server-02"
  resource_group_name = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.name
  location            = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.location
  size                = "Standard_D2s_v3"
  admin_username      = "demousr"
  admin_password      = azurerm_key_vault_secret.vmpassword.value
  availability_set_id = azurerm_availability_set.app_set.id
  network_interface_ids = [
    azurerm_network_interface.app_interface2.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
   depends_on = [
    azurerm_network_interface.app_interface2,
    azurerm_availability_set.app_set
  ]
}

// This is the resource for appvm3
resource "azurerm_linux_virtual_machine" "app_vm3" {
  name                = "ansible-terminal"
  resource_group_name = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.name
  location            = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.location
  size                = "Standard_D2s_v3"
  admin_username      = "demousr"
  admin_password      = azurerm_key_vault_secret.vmpassword.value
  network_interface_ids = [
    azurerm_network_interface.app_interface3.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  disable_password_authentication = false
  
  depends_on = [
    azurerm_network_interface.app_interface1,
    azurerm_availability_set.app_set
  ]
}


resource "azurerm_availability_set" "app_set" {
  name                = "app-set"
  location            = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.location
  resource_group_name = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.name
  platform_fault_domain_count = 3
  platform_update_domain_count = 3  
  depends_on = [
    azurerm_resource_group.devops-interview-gauntlet-x-rkwakye
  ]
}

resource "azurerm_storage_account" "appstore" {
  name                     = "rkwakyestore123456kforce"
  resource_group_name      = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.name
  location                 = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "data" {
  name                  = "data"
  storage_account_name  = "rkwakyestore123456kforce"
  container_access_type = "blob"
  depends_on=[
    azurerm_storage_account.appstore
    ]
}


resource "azurerm_storage_blob" "Index" {
  name                   = "index.html"
  storage_account_name   = "rkwakyestore123456kforce"
  storage_container_name = "data"
  type                   = "Block"
  source                 = "index.html"
   depends_on=[azurerm_storage_container.data]
}

resource "azurerm_storage_blob" "cat" {
  name                   = "cats.jpg"
  storage_account_name   = "rkwakyestore123456kforce"
  storage_container_name = "data"
  type                   = "Block"
  source                 = "cats.jpg"
   depends_on=[azurerm_storage_container.data]
}

// This is the extension for appvm1

resource "azurerm_virtual_machine_extension" "vm_extension1" {
  name                 = "appvm-extension"
  virtual_machine_id   = azurerm_windows_virtual_machine.app_vm1.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"
  settings = <<SETTINGS
    {
        "fileUris": [ "https://raw.githubusercontent.com/ansible/ansible/v2.13.3/examples/scripts/ConfigureRemotingForAnsible.ps1" ],
        "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File ConfigureRemotingForAnsible.ps1"
    }
    SETTINGS

}


// This is the extension for appvm2
resource "azurerm_virtual_machine_extension" "vm_extension2" {
  name                 = "appvm-extension"
  virtual_machine_id   = azurerm_windows_virtual_machine.app_vm2.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.9"
  settings = <<SETTINGS
    {
        "fileUris": [ "https://raw.githubusercontent.com/ansible/ansible/v2.13.3/examples/scripts/ConfigureRemotingForAnsible.ps1" ],
        "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File ConfigureRemotingForAnsible.ps1"
    }
    SETTINGS

}

resource "azurerm_network_security_group" "app_nsg" {
  name                = "app-nsg"
  location            = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.location
  resource_group_name = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.name

# We are creating a rule to allow traffic on port 80
  security_rule {
    name                       = "Allow_HTTP"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # We are creating a rule to allow traffic on port 3389
  security_rule {
    name                       = "Allow_RDP"
    priority                   = 201
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # We are creating a rule to allow traffic on port 22
  security_rule {
    name                       = "Allow_SSH"
    priority                   = 202
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # We are creating a rule to allow traffic on port 5986
  security_rule {
    name                       = "Allow_WinRM"
    priority                   = 203
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5986"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }  
}


resource "azurerm_subnet_network_security_group_association" "nsg_association" {
  subnet_id                 = azurerm_subnet.SubnetA.id
  network_security_group_id = azurerm_network_security_group.app_nsg.id
  depends_on = [
    azurerm_network_security_group.app_nsg
  ]
}

resource "azurerm_subnet_network_security_group_association" "nsg_association_b" {
  subnet_id                 = azurerm_subnet.SubnetB.id
  network_security_group_id = azurerm_network_security_group.app_nsg.id
  depends_on = [
    azurerm_network_security_group.app_nsg
  ]
}


resource "azurerm_public_ip" "app_vm1_public_ip" {
  name                = "app-vm1-public-ip"
  location            = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.location
  resource_group_name = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.name
  allocation_method   = "Static"
}

resource "azurerm_public_ip" "app_vm2_public_ip" {
  name                = "app-vm2-public-ip"
  location            = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.location
  resource_group_name = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.name
  allocation_method   = "Static"
}

resource "azurerm_public_ip" "app_vm3_public_ip" {
  name                = "app-vm3-public-ip"
  location            = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.location
  resource_group_name = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.name
  allocation_method   = "Static"
}

resource "azurerm_public_ip" "load_ip" {
  name                = "load-ip"
  location            = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.location
  resource_group_name = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.name
  allocation_method   = "Static"
  sku="Standard"
}

// Lets create the Load balancer
resource "azurerm_lb" "app_balancer" {
  name                = "app-balancer"
  location            = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.location
  resource_group_name = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.name
  sku="Standard"
  sku_tier = "Regional"
  frontend_ip_configuration {
    name                 = "frontend-ip"
    public_ip_address_id = azurerm_public_ip.load_ip.id
  }

  depends_on=[
    azurerm_public_ip.load_ip
  ]
}

// Here we are defining the backend pool
resource "azurerm_lb_backend_address_pool" "PoolA" {
  loadbalancer_id = azurerm_lb.app_balancer.id
  name            = "PoolA"
  depends_on=[
    azurerm_lb.app_balancer
  ]
}

resource "azurerm_lb_backend_address_pool_address" "appvm1_address" {
  name                    = "appvm1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.PoolA.id
  virtual_network_id      = azurerm_virtual_network.app_network.id
  ip_address              = azurerm_network_interface.app_interface1.private_ip_address
  depends_on=[
    azurerm_lb_backend_address_pool.PoolA
  ]
}

 resource "azurerm_lb_backend_address_pool_address" "appvm2_address" {
  name                    = "appvm2"
  backend_address_pool_id = azurerm_lb_backend_address_pool.PoolA.id
  virtual_network_id      = azurerm_virtual_network.app_network.id
  ip_address              = azurerm_network_interface.app_interface2.private_ip_address
  depends_on=[
    azurerm_lb_backend_address_pool.PoolA
  ]
 }


// Here we are defining the Health Probe
resource "azurerm_lb_probe" "ProbeA" {
  #resource_group_name = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.name
  loadbalancer_id     = azurerm_lb.app_balancer.id
  name                = "probeA"
  port                = 80
  protocol            =  "Tcp"
  depends_on=[
    azurerm_lb.app_balancer
  ]
}

// Here we are defining the Load Balancing Rule
resource "azurerm_lb_rule" "RuleA" {
  #resource_group_name            = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.name
  loadbalancer_id                = azurerm_lb.app_balancer.id
  name                           = "RuleA"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "frontend-ip"
  backend_address_pool_ids = [ azurerm_lb_backend_address_pool.PoolA.id ]
  depends_on=[
    azurerm_lb.app_balancer
  ]
}

// This is used for creating the NAT Rules

resource "azurerm_lb_nat_rule" "NATRuleA" {
  resource_group_name            = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.name
  loadbalancer_id                = azurerm_lb.app_balancer.id
  name                           = "RDPAccess"
  protocol                       = "Tcp"
  frontend_port                  = 3389
  backend_port                   = 3389
  frontend_ip_configuration_name = "frontend-ip"
  depends_on=[
    azurerm_lb.app_balancer
  ]
}

// Here we are creating the Public DNS Zone
resource "azurerm_dns_zone" "public_zone" {
  name                = "cats.internet.local"
  resource_group_name = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.name
}

output "server_names"{
  value=azurerm_dns_zone.public_zone.name_servers
}

// Pointing the domain name to the load balancer
resource "azurerm_dns_a_record" "load_balancer_record" {
  name                = "www"
  zone_name           = azurerm_dns_zone.public_zone.name
  resource_group_name = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.name
  ttl                 = 360
  records             = [azurerm_public_ip.load_ip.ip_address]
}


resource "azurerm_app_service_plan" "rkwakye_app_plan1000" {
  name                = "app-plan1000"
  location            = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.location
  resource_group_name = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.name

  sku {
    tier = "Premium"
    size = "P3V3"
  }
}

resource "azurerm_app_service" "webapp" {
  name                = "rkwakyewebapp1000"
  location            = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.location
  resource_group_name = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.name
  app_service_plan_id = azurerm_app_service_plan.rkwakye_app_plan1000.id
}

resource "azurerm_app_service_virtual_network_swift_connection" "webapp_swift_connection" {
  app_service_id = azurerm_app_service.webapp.id
  subnet_id      = azurerm_subnet.SubnetB.id
}

resource "azurerm_monitor_autoscale_setting" "webapp_autoscale" {
  name                = "webapp-autoscale"
  location            = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.location
  resource_group_name = azurerm_resource_group.devops-interview-gauntlet-x-rkwakye.name
  target_resource_id  = azurerm_app_service_plan.rkwakye_app_plan1000.id
  # target_resource_id  = azurerm_app_service.webapp.id
  profile {
    name = "default"
    capacity {
      default = 1
      minimum = 1
      maximum = 3
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_app_service_plan.rkwakye_app_plan1000.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }
}