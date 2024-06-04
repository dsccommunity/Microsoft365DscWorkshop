function New-DscDocumentEncryptionCertificate
{
	[CmdletBinding()]
	param (
		[Parameter()]
		[string]
		$Subject = 'DscEncryptionCert',

		[Parameter()]
		[string]
		[ValidateSet('LocalMachine', 'CurrentUser')]
		$Store = 'CurrentUser',

		[Parameter()]
		[switch]
		$PassThru
	)

	$param = @{
		DnsName           = $env:COMPUTERNAME
		KeyUsage          = 'KeyEncipherment', 'DataEncipherment', 'KeyAgreement'
		Type              = 'DocumentEncryptionCert'
		CertStoreLocation = "Cert:\\$Store\My"
		NotAfter          = (Get-Date).AddYears(2)
		Subject           = $Subject
	}

	$cert = New-SelfSignedCertificate @param

	if ($PassThru)
	{
		$cert
	}
}

function New-M365DSCSelfSignedCertificate
{
	[CmdletBinding()]
	param (
		[Parameter()]
		[string]
		$Subject = 'DscEncryptionCert',

		[Parameter()]
		[string]
		[ValidateSet('LocalMachine', 'CurrentUser')]
		$Store = 'CurrentUser',

		[Parameter()]
		[switch]
		$PassThru
	)

	$param = @{
		CertStoreLocation = "Cert:\\$Store\My"
		NotAfter          = (Get-Date).AddYears(2)
		Subject           = $Subject
		KeyExportPolicy   = 'Exportable'
		KeySpec           = 'Signature'
		KeyLength         = 2048
		KeyAlgorithm      = 'RSA'
		HashAlgorithm     = 'SHA256'
	}

	$cert = New-SelfSignedCertificate @param

	if ($PassThru)
	{
		$cert
	}

}
