# AgeSecretVault

AgeSecretVault is a PowerShell SecretManagement extension that stores secrets as age-encrypted files on disk.

Each secret is one file, and all secrets live under a configured root directory. This makes it easy to manage secrets alongside infrastructure as code and check-in encrypted secret files into git safely (as long as your private key is of course never committed).

## Features

- PowerShell SecretManagement vault extension
- Secrets encrypted with age
- One file per secret (`<name>.age`)
- Optional per-secret metadata file (`<name>.metadata`)
- Nested secret names supported (for example, `prod/db/password`)

## Requirements

- PowerShell 7.2+
- [Microsoft.PowerShell.SecretManagement](https://www.powershellgallery.com/packages/Microsoft.PowerShell.SecretManagement)
- [age](https://github.com/FiloSottile/age) installed and available on `PATH`

## Secret Storage Model

The vault uses a directory you provide as the root path.

- Secret ciphertext files: `<SecretName>.age`
- Secret metadata files: `<SecretName>.metadata`
- Recipient list: `.age-recipients.txt` (public keys used for encryption)

Example layout:

```text
secrets/
	.age-recipients.txt
	mysecret.age
	app/
		db/password.age
		db/password.metadata
```

## Register The Vault

Use `Register-SecretVault` with `Path` and `IdentityFile` vault parameters.

```powershell
Register-SecretVault -Name HomelabSecrets -ModuleName ./Scripts/AgeSecretVault -VaultParameters @{
		"Path" = "C:\git\homelab\secrets"
		"IdentityFile" = "$Env:USERPROFILE\.config\age\keys.txt"
}
```

Parameter details:

- `Path`: Root directory where encrypted secret files are stored.
- `IdentityFile`: age identity file containing private key(s) for decryption.

## Usage

Add a secret:

```powershell
Set-Secret -Name mysecret -Vault HomelabSecrets -Secret "Super_Secr3t!"
```

Get a secret as plain text:

```powershell
Get-Secret -Name mysecret -Vault HomelabSecrets -AsPlainText
```

Remove a secret:

```powershell
Remove-Secret -Name mysecret -Vault HomelabSecrets
```

Set metadata for a secret:

```powershell
Set-SecretInfo -Name mysecret -Vault HomelabSecrets -Metadata @{
		owner = "platform"
		rotation = "30d"
}
```

List secrets (optionally with filter):

```powershell
Get-SecretInfo -Vault HomelabSecrets
Get-SecretInfo -Vault HomelabSecrets -Name "app/*"
```

## age Integration

Secrets are encrypted and decrypted with age:

- `IdentityFile` contains private key(s) used to decrypt
- `.age-recipients.txt` contains public key(s) used to encrypt

Encrypt directly with age:

```powershell
echo <secret value> | age -R .age-recipients.txt -o <secret name>.age
```

Decrypt directly with age:

```powershell
age -i c:\users\bpoe\.config\age\keys.txt -d <secret name>.age
```

## Security Notes

- Safe to commit encrypted `*.age` files and `.age-recipients.txt` to git.
- Never commit your private identity file (for example, `keys.txt`).
- Restrict file permissions on private key files.
- Rotate recipients and re-encrypt secrets when keys change.

## Notes On Secret Names

- Allowed characters in each secret name segment: letters, numbers, `.`, `_`, `-`
- Forward slash (`/`) creates subdirectories
- Relative path segments like `.` and `..` are rejected

Examples:

- `mysecret`
- `prod/db/password`
- `api/tokens/github`

## Development

This repository contains:

- Root module manifest: `AgeSecretVault/AgeSecretVault.psd1`
- SecretManagement extension module:
	- `AgeSecretVault/AgeSecretVault.Extension/AgeSecretVault.Extension.psd1`
	- `AgeSecretVault/AgeSecretVault.Extension/AgeSecretVault.Extension.psm1`

If you are developing locally, register the vault using a module path that points to `AgeSecretVault` in this repository.
