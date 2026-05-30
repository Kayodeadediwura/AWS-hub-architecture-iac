# 1. Provision the Enterprise Resource Group Boundary
resource "azurerm_resource_group" "network_rg" {
  name     = var.rg_name
  location = var.location
  tags = {
    Environment = "Production-Staging"
    ManagedBy   = "Terraform-IaC"
    Owner       = "Enterprise-Cloud-Migration"
  }
}

# 2. Deploy the Central Hub VNet
resource "azurerm_virtual_network" "hub" {
  name                = "vnet-uk-hub"
  location            = azurerm_resource_group.network_rg.location
  resource_group_name = azurerm_resource_group.network_rg.name
  address_space       = ["10.0.0.0/16"]
  tags                = azurerm_resource_group.network_rg.tags
}

# 3. Deploy Spoke-A (Finance Department)
resource "azurerm_virtual_network" "spoke_a" {
  name                = "vnet-uk-spoke-finance"
  location            = azurerm_resource_group.network_rg.location
  resource_group_name = azurerm_resource_group.network_rg.name
  address_space       = ["10.1.0.0/16"]
  tags                = azurerm_resource_group.network_rg.tags
}

resource "azurerm_subnet" "finance_subnet" {
  name                 = "sub-finance-production"
  resource_group_name  = azurerm_resource_group.network_rg.name
  virtual_network_name = azurerm_virtual_network.spoke_a.name
  address_prefixes     = ["10.1.1.0/24"]
}

# 4. Deploy Spoke-B (HR Department)
resource "azurerm_virtual_network" "spoke_b" {
  name                = "vnet-uk-spoke-hr"
  location            = azurerm_resource_group.network_rg.location
  resource_group_name = azurerm_resource_group.network_rg.name
  address_space       = ["10.2.0.0/16"]
  tags                = azurerm_resource_group.network_rg.tags
}

resource "azurerm_subnet" "hr_subnet" {
  name                 = "sub-hr-production"
  resource_group_name  = azurerm_resource_group.network_rg.name
  virtual_network_name = azurerm_virtual_network.spoke_b.name
  address_prefixes     = ["10.2.1.0/24"]
}

# 5. Build Bidirectional VNet Peering: Hub <─> Finance
resource "azurerm_virtual_network_peering" "hub_to_finance" {
  name                      = "peer-hub-to-finance"
  resource_group_name       = azurerm_resource_group.network_rg.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke_a.id
}

resource "azurerm_virtual_network_peering" "finance_to_hub" {
  name                      = "peer-finance-to-hub"
  resource_group_name       = azurerm_resource_group.network_rg.name
  virtual_network_name      = azurerm_virtual_network.spoke_a.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
}

# 6. Build Bidirectional VNet Peering: Hub <─> HR
resource "azurerm_virtual_network_peering" "hub_to_hr" {
  name                      = "peer-hub-to-hr"
  resource_group_name       = azurerm_resource_group.network_rg.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke_b.id
}

resource "azurerm_virtual_network_peering" "hr_to_hub" {
  name                      = "peer-hr-to-hub"
  resource_group_name       = azurerm_resource_group.network_rg.name
  virtual_network_name      = azurerm_virtual_network.spoke_b.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
}

# 7. Security Layer: Prevent HR from talking directly to Finance Subnet
resource "azurerm_network_security_group" "finance_nsg" {
  name                = "nsg-finance-security-core"
  location            = azurerm_resource_group.network_rg.location
  resource_group_name = azurerm_resource_group.network_rg.name

  security_rule {
    name                       = "Block-HR-Lateral-Movement"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.2.0.0/16" 
    destination_address_prefix = "10.1.1.0/24" 
  }
}

resource "azurerm_subnet_network_security_group_association" "finance_assoc" {
  subnet_id                 = azurerm_subnet.finance_subnet.id
  network_security_group_id = azurerm_network_security_group.finance_nsg.id
}