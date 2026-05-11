Using Namespace Microsoft.PowerShell.SecretManagement

function Resolve-SecretFilePath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $VaultPath,

        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [string] $Extension
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        throw "Secret name cannot be empty."
    }

    $normalizedName = $Name.Replace('\', '/')
    $segments = $normalizedName -split '/'

    if ($segments.Count -eq 0) {
        throw "Secret name cannot be empty."
    }

    foreach ($segment in $segments) {
        if ([string]::IsNullOrWhiteSpace($segment)) {
            throw "Secret name '$Name' contains empty path segments."
        }

        if ($segment -eq '.' -or $segment -eq '..') {
            throw "Secret name '$Name' contains unsupported relative path segments."
        }

        if ($segment -notmatch '^[A-Za-z0-9._-]+$') {
            throw "Secret name '$Name' contains invalid characters."
        }
    }

    $vaultRoot = [System.IO.Path]::GetFullPath($VaultPath)
    $normalizedRoot = $vaultRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)

    $relativeDirectory = if ($segments.Count -gt 1) { [System.IO.Path]::Combine($segments[0..($segments.Count - 2)]) } else { "" }
    $leafFile = "$($segments[-1]).$Extension"
    $relativePath = if ([string]::IsNullOrWhiteSpace($relativeDirectory)) { $leafFile } else { [System.IO.Path]::Combine($relativeDirectory, $leafFile) }

    $candidate = [System.IO.Path]::GetFullPath((Join-Path -Path $vaultRoot -ChildPath $relativePath))

    $prefix = "$normalizedRoot$([System.IO.Path]::DirectorySeparatorChar)"
    if (-not $candidate.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Secret path for '$Name' resolves outside the vault directory."
    }

    return $candidate
}

function Get-SecretNameFromFilePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $VaultPath,

        [Parameter(Mandatory = $true)]
        [string] $SecretFilePath
    )

    $vaultRoot = [System.IO.Path]::GetFullPath($VaultPath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $secretFullPath = [System.IO.Path]::GetFullPath($SecretFilePath)

    $prefix = "$vaultRoot$([System.IO.Path]::DirectorySeparatorChar)"
    if (-not $secretFullPath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Secret file '$SecretFilePath' resolves outside vault root '$VaultPath'."
    }

    $relativePath = $secretFullPath.Substring($prefix.Length)
    if ($relativePath.EndsWith('.age', [System.StringComparison]::OrdinalIgnoreCase)) {
        $relativePath = $relativePath.Substring(0, $relativePath.Length - 4)
    }

    return $relativePath.Replace('\', '/')
}

function Get-Secret {
    [CmdletBinding()]
    param (
        [string] $Name,
        [string] $VaultName,
        [hashtable] $AdditionalParameters)

    $VaultParameters = (Get-SecretVault -Name $VaultName).VaultParameters
    $identityFile = $VaultParameters.IdentityFile
    $vaultPath = $VaultParameters.Path
    $secretPath = Resolve-SecretFilePath -VaultPath $vaultPath -Name $Name -Extension "age"
    if (-not (Test-Path -Path $secretPath)) {
        return $null
    }

    $secret = & age -d -i $identityFile $secretPath 2>&1
    if ($LASTEXITCODE -ne 0) {
        $errorText = ($secret | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
        throw "Failed to decrypt secret '$Name' from '$secretPath': $errorText"
    }

    return ($secret -join [Environment]::NewLine)
}

function Set-Secret {
    [CmdletBinding()]
    param (
        [string] $Name,
        [object] $Secret,
        [string] $VaultName,
        [hashtable] $AdditionalParameters
    )

    $VaultParameters = (Get-SecretVault -Name $VaultName).VaultParameters
    $vaultPath = $VaultParameters.Path

    $secretPath = Resolve-SecretFilePath -VaultPath $vaultPath -Name $Name -Extension "age"
    $recipients = Join-Path $vaultPath -ChildPath ".age-recipients.txt"

    $secretDirectory = Split-Path -Path $secretPath -Parent
    if (-not (Test-Path -Path $secretDirectory -PathType Container)) {
        New-Item -Path $secretDirectory -ItemType Directory -Force | Out-Null
    }

    $result = $Secret | & age -R $recipients -o $secretPath 2>&1
    if ($LASTEXITCODE -ne 0) {
        $errorText = ($result | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
        throw "Failed to encrypt secret '$Name' to '$secretPath': $errorText"
    }
}

function Remove-Secret {
    [CmdletBinding()]
    param (
        [string] $Name,
        [string] $VaultName,
        [hashtable] $AdditionalParameters)

    $VaultParameters = (Get-SecretVault -Name $VaultName).VaultParameters
    $vaultPath = $VaultParameters.Path

    $secretPath = Resolve-SecretFilePath -VaultPath $vaultPath -Name $Name -Extension "age"
    $metadataPath = Resolve-SecretFilePath -VaultPath $vaultPath -Name $Name -Extension "metadata"

    if (Test-Path -Path $secretPath) {
        Remove-Item -Path $secretPath -Force | Out-Null
    }

    if (Test-Path -Path $metadataPath) {
        Remove-Item -Path $metadataPath -Force | Out-Null
    }
}

function Get-SecretInfo {
    [CmdletBinding()]
    param (
        [string] $Filter,
        [string] $VaultName,
        [hashtable] $AdditionalParameters)

    $VaultParameters = (Get-SecretVault -Name $VaultName).VaultParameters
    $vaultPath = $VaultParameters.Path

    if ([string]::IsNullOrEmpty($Filter)) {
        $Filter = "*"
    }

    $pattern = [WildcardPattern]::new($Filter)

    $secretList = Get-ChildItem -Path $vaultPath -Filter "*.age" -File -Recurse
    foreach ($secretFile in $secretList) {
        $secretName = Get-SecretNameFromFilePath -VaultPath $vaultPath -SecretFilePath $secretFile.FullName
        if (-not $pattern.IsMatch($secretName)) {
            continue
        }

        $metadataPath = Resolve-SecretFilePath -VaultPath $vaultPath -Name $secretName -Extension "metadata"
        $metadata = @{}
        if (Test-Path -Path $metadataPath) {
            try {
                $metadata = Get-Content -Path $metadataPath -Raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop
            }
            catch {
            }
        }

        Write-Output (
            [Microsoft.PowerShell.SecretManagement.SecretInformation]::new(
                $secretName,
                [Microsoft.PowerShell.SecretManagement.SecretType]::String,
                $VaultName,
                $metadata)
        )
    }
}

function Set-SecretInfo {
    [CmdletBinding()]
    param (
        [string] $Name,
        [hashtable] $Metadata,
        [string] $VaultName,
        [hashtable] $AdditionalParameters)

    $VaultParameters = (Get-SecretVault -Name $VaultName).VaultParameters
    $vaultPath = $VaultParameters.Path

    $secretMetadataPath = Resolve-SecretFilePath -VaultPath $vaultPath -Name $Name -Extension "metadata"

    $metadataDirectory = Split-Path -Path $secretMetadataPath -Parent
    if (-not (Test-Path -Path $metadataDirectory -PathType Container)) {
        New-Item -Path $metadataDirectory -ItemType Directory -Force | Out-Null
    }

    $Metadata | ConvertTo-Json -Depth 10 | Out-File -FilePath $secretMetadataPath -Encoding UTF8
}

function Test-SecretVault {
    [CmdletBinding()]
    param (
        [string] $VaultName,
        [hashtable] $AdditionalParameters)

    return $true
}
