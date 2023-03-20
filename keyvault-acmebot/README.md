# WWT keyvault-acmebot Subsystem

This file describes how we manage some of our SSL certificates. This
infrastructure is in fact *not* managed through Terraform, but this is a
convenient place to document some aspects of it.


## Motivation

The problem is that there is no Azure-managed way to set up and renew an HTTPS
certificate for an Azure Application Gateway frontend, and that's what we use to
direct our HTTP traffic. Given that, the tempting approach is to use [Let's
Encrypt][le]. But how?

[le]: https://letsencrypt.org/


## Implementation

A project called [keyvault-acmebot][kvab] integrates the protocol that underlies
[Let's Encrypt][le], [ACME], into an Azure environment, in a way that can be
integrated with the Azure Application Gateway system.

[kvab]: https://github.com/shibayan/keyvault-acmebot
[ACME]: https://www.rfc-editor.org/rfc/rfc8555

When we installed this, it wasn't based on Terraform, but there is a [Terraform
module][tf] now.

[tf]: https://registry.terraform.io/modules/shibayan/keyvault-acmebot/azurerm/latest


## Management

[keyvault-acmebot][kvab] actually comes with a nice UI. You can manage the certs
through:

```
https://keyvault-acmebot-UUUU.azurewebsites.net/dashboard
```

where `UUUU` is the unique ID of our instance. You have to login through the
Azure identity framework so it is not a big deal if people know what `UUUU` is
for us.


## New Certificate

To set up the app to manage a new DNS Zone, it has to have the right role
assignments, as per [the wiki][1]. Might also need to reconfigure and/or restart
the function app host to get it to see a new zone.

[1] https://github.com/shibayan/keyvault-acmebot/wiki/DNS-Provider-Configuration#azure-dns
