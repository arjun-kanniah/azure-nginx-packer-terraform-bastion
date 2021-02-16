provider "azurerm" {
  features {}
}

# Create a resource group
resource "azurerm_resource_group" "web-server" {
    name     = "${var.prefix}-rg"
    location = var.location
    tags     = var.tags
}

# Create a virtual network
resource "azurerm_virtual_network" "web-server" {
    name                = "${var.prefix}-vnet"
    address_space       = ["10.0.0.0/24"]
    location            = azurerm_resource_group.web-server.location
    resource_group_name = azurerm_resource_group.web-server.name
    tags                = var.tags
}

# Create a subnet
resource "azurerm_subnet" "web-server" {
    name                 = "${var.prefix}-subnet"
    resource_group_name  = azurerm_resource_group.web-server.name
    virtual_network_name = azurerm_virtual_network.web-server.name
    address_prefixes     = ["10.0.0.0/24"]
}

# Create a network security group with the required security rules
resource "azurerm_network_security_group" "web-server" {
    name                = "${var.prefix}-nsg"
    location            = azurerm_resource_group.web-server.location
    resource_group_name = azurerm_resource_group.web-server.name

    // Security rule to allow HTTP traffic from Load Balancer to the VM on the user defined application port
    security_rule {
        name                       = "allow-lb-to-vm"
        priority                   = 100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "TCP"
        source_port_range          = "*"
        destination_port_range     = var.application_port
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

     // Security rule to allow SSH connectivity from Bastion Host to the VM
    security_rule {
        name                       = "allow-ssh-from-bastion"
        priority                   = 110
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "TCP"
        source_port_range          = "*"
        destination_port_range     = 22
        source_address_prefix      = "*"
        destination_address_prefix = "VirtualNetwork"
    }

    tags = var.tags
}

# Associate NSG to the Subnet
resource "azurerm_subnet_network_security_group_association" "web-server" {
    subnet_id      = azurerm_subnet.web-server.id
    network_security_group_id = azurerm_network_security_group.web-server.id
 }

# Create public IP for Load Balancer
resource "azurerm_public_ip" "web-server" {
    name                = "${var.prefix}-lb-public-ip"
    location            = azurerm_resource_group.web-server.location
    resource_group_name = azurerm_resource_group.web-server.name
    allocation_method   = "Static"
    domain_name_label   = "${var.prefix}-lb"
    tags                = var.tags
 }

# Create a Load Balancer
resource "azurerm_lb" "web-server" {
    name                = "${var.prefix}-load-balancer"
    location            = azurerm_resource_group.web-server.location
    resource_group_name = azurerm_resource_group.web-server.name

    frontend_ip_configuration {
        name                 = "${var.prefix}-public-ip-address"
        public_ip_address_id = azurerm_public_ip.web-server.id
    }

    tags = var.tags
}

# Create health probe for the load balancer
resource "azurerm_lb_probe" "web-server" {
    name                = "${var.prefix}-http-probe"
    resource_group_name = azurerm_resource_group.web-server.name
    loadbalancer_id     = azurerm_lb.web-server.id
    port                = var.application_port
}

# Create a backend address pool for the load balancer to connect to
resource "azurerm_lb_backend_address_pool" "web-server" {
    name                = "${var.prefix}-backend-address-pool"   
    loadbalancer_id     = azurerm_lb.web-server.id
}

# Create load balancer connectivity rule to route trafic from load balancer port to application port
resource "azurerm_lb_rule" "web-server" {
    resource_group_name            = azurerm_resource_group.web-server.name
    loadbalancer_id                = azurerm_lb.web-server.id
    name                           = "http"
    protocol                       = "Tcp"
    frontend_port                  = var.lb_port
    backend_port                   = var.application_port
    backend_address_pool_id        = azurerm_lb_backend_address_pool.web-server.id
    frontend_ip_configuration_name = azurerm_lb.web-server.frontend_ip_configuration[0].name
    probe_id                       = azurerm_lb_probe.web-server.id
}

# Declare the packer image to be used in the VM
data "azurerm_image" "packer-image" {
    name                = "${var.packer-prefix}-image"
    resource_group_name = "${var.packer-prefix}-rg"
}

# Create VMs using the Packer created image as a scale set
resource "azurerm_virtual_machine_scale_set" "web-server" {
  name                = "${var.prefix}-vm-scale-set"
  location            = azurerm_resource_group.web-server.location
  resource_group_name = azurerm_resource_group.web-server.name
  upgrade_policy_mode = "Manual"

  sku {
    name     = "Standard_DS1_v2"
    tier     = "Standard"
    capacity = var.capacity
  }

  storage_profile_image_reference {
    id = data.azurerm_image.packer-image.id
  }

  storage_profile_os_disk {
    name              = ""
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_profile_data_disk {
    lun            = 0
    caching        = "ReadWrite"
    create_option  = "Empty"
    disk_size_gb   = 10
  }

  os_profile {
    computer_name_prefix = "${var.prefix}-vm"
    admin_username       = var.username
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path     = "/home/${var.username}/.ssh/authorized_keys"
      key_data = file("~/.ssh/id_rsa.pub")
    }
  }

  network_profile {
    name    = "${var.prefix}-TerraformNetworkProfile"
    primary = true

    ip_configuration {
      name                                   = "${var.prefix}-IPConfiguration"
      subnet_id                              = azurerm_subnet.web-server.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.web-server.id]
      primary                                = true
    }
  }
  
  tags = var.tags
}

# Create a Public IP for Bastion Host
resource "azurerm_public_ip" "bastion" {
  name                = "${var.prefix}-bastion-public-ip"
  location            = azurerm_resource_group.web-server.location
  resource_group_name = azurerm_resource_group.web-server.name
  allocation_method   = "Static"
  domain_name_label   = "${var.prefix}-bastion-ssh"
  tags                = var.tags
}

# Create a network interface (NIC) for the bastion host
resource "azurerm_network_interface" "bastion" {
  name                = "${var.prefix}-bastion-nic"
  location            = azurerm_resource_group.web-server.location
  resource_group_name = azurerm_resource_group.web-server.name

  ip_configuration {
    name                          = "${var.prefix}-IPConfiguration"
    subnet_id                     = azurerm_subnet.web-server.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.bastion.id
  }

  tags = var.tags
}

# Create a VM to serve as a Bastion Host
resource "azurerm_virtual_machine" "bastion" {
  name                  = "${var.prefix}-bastion"
  location              = azurerm_resource_group.web-server.location
  resource_group_name   = azurerm_resource_group.web-server.name
  network_interface_ids = [azurerm_network_interface.bastion.id]
  vm_size               = "Standard_DS1_v2"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "bastion-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "bastion"
    admin_username = var.username
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path     = "/home/${var.username}/.ssh/authorized_keys"
      key_data = file("~/.ssh/id_rsa.pub")
    }
  }

  tags = var.tags
}

output "lb_fqdn" {
    value = azurerm_public_ip.web-server.fqdn
}

output "bastion_public_ip" {
    value = azurerm_public_ip.bastion.ip_address
}