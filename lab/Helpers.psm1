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
	$certname = 'KeyVaultAccess'
	$param = @{
		Subject           = "CN=$certname"
		CertStoreLocation = 'Cert:\LocalMachine\My'
		KeyExportPolicy   = 'Exportable'
		KeySpec           = 'Signature'
		KeyLength         = 2048
		KeyAlgorithm      = 'RSA'
		HashAlgorithm     = 'SHA256'
	}
	New-SelfSignedCertificate @param

	#$pass = ConvertTo-SecureString -String Somepass1 -Force -AsPlainText
	Export-Certificate -Cert $cert -FilePath ".\$certname.cer"
	#Export-PfxCertificate -Cert $cert -FilePath ".\$certname.pfx" -Password $pass
}
