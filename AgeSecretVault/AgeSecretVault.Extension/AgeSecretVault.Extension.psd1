@{
    RootModule = '.\AgeSecretVault.Extension.psm1'
    ModuleVersion = '0.1.0'
    GUID = '68112433-9041-4426-a9b5-2d39051c7c4a'
    Author = 'Brandon Poe'
    Description = 'Nested SecretManagement extension module for AgeSecretVault.'
    PowerShellVersion = '7.2'
    FunctionsToExport = @(
        'Set-Secret',
        'Get-Secret',
        'Remove-Secret',
        'Get-SecretInfo',
        'Set-SecretInfo',
        'Test-SecretVault'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
}
