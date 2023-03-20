terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}



resource "azurerm_resource_group" "isreal-resource-grp" {
  name     = "test_isreal"
  location = "West Europe"
}


resource "azurerm_virtual_network" "isreal-app-ntwrk" {
  name                = "isreal-network"
  location            = azurerm_resource_group.isreal-resource-grp.location
  resource_group_name = azurerm_resource_group.isreal-resource-grp.name
  address_space       = ["10.0.0.0/16"]

}


resource "azurerm_subnet" "vm-subnet" {
  name                 = "application_subnet"
  resource_group_name  = azurerm_resource_group.isreal-resource-grp.name
  virtual_network_name = azurerm_virtual_network.isreal-app-ntwrk.name
  address_prefixes     = ["10.0.1.0/24"]


}


resource "azurerm_network_interface" "vm-nic" {
  name                = "App_nic"
  location            = azurerm_resource_group.isreal-resource-grp.location
  resource_group_name = azurerm_resource_group.isreal-resource-grp.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm-subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "app-server" {
  name                = "app-server"
  resource_group_name = azurerm_resource_group.isreal-resource-grp.name
  location            = azurerm_resource_group.isreal-resource-grp.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.vm-nic.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/tf.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
}



resource "azurerm_subnet" "database-subnet" {
  name                 = "db-subnet"
  resource_group_name  = azurerm_resource_group.isreal-resource-grp.name
  virtual_network_name = azurerm_virtual_network.isreal-app-ntwrk.name
  address_prefixes     = ["10.0.2.0/24"]
  service_endpoints    = ["Microsoft.Sql"]
}

resource "azurerm_mysql_server" "app-db" {
  name                = "app-mysqlserver"
  location            = azurerm_resource_group.isreal-resource-grp.location
  resource_group_name = azurerm_resource_group.isreal-resource-grp.name

  administrator_login          = "mysqladminun"
  administrator_login_password = "H@Sh1CoR3!"

  sku_name   = "GP_Gen5_2"
  storage_mb = 5120
  version    = "5.7"

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  ssl_enforcement_enabled      = true
}

resource "azurerm_mysql_virtual_network_rule" "example" {
  name                = "mysql-vnetrule"
  resource_group_name = azurerm_resource_group.isreal-resource-grp.name
  server_name         = azurerm_mysql_server.app-db.name
  subnet_id           = azurerm_subnet.database-subnet.id
}


