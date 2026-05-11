@{
    RootModule = ''
    ModuleVersion = '0.1.0'
    GUID = 'f43c1f70-2c6a-4c94-9e5b-7a017cf24c01'
    Author = 'Brandon Poe'
    Description = 'PowerShell SecretManagement extension vault backed by age-encrypted files in a secrets directory.'
    PowerShellVersion = '7.2'
    NestedModules = @('.\AgeSecretVault.Extension')
    FunctionsToExport = @()
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('SecretManagement', 'age', 'secrets', 'homelab')
            ProjectUri = ''
            LicenseUri = ''
            ReleaseNotes = 'Initial local age-backed SecretManagement vault extension.'
        }
    }
}
