<#
 .SYNOPSIS
    PoshSemanticVersion module.
#>

param ()

Set-StrictMode -Version Latest

# Initialization code is BELOW the function definitions.


#region Classes

class SemanticVersion {

}

#endregion Classes


#region Internal functions


function Debug-SemanticVersion {
    <#
     .SYNOPSIS
        Finds problems with a Semantic Version string and recommends solutions.

     .DESCRIPTION
        The Debug-SemanticVersion function finds problems with a Semantic Version string and recommends solutions.

        It is used by other functions in the SemanticVersion module to get the appropriate error message when a
        Semantic Version string is invalid.

     .EXAMPLE
        An example

     .NOTES
        General notes
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        # The object to debug. Object will be converted to a string for evaluation.
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true)]
        [object[]]
        [Alias('Version')]
        $InputObject,

        # The name of the parameter that is being debugged/validated. If specified, the name will be added to the returned exception and error details objects.
        [string]
        $ParameterName = 'InputObject'
    )

    begin {
        # Default values.
        [System.Management.Automation.ErrorCategory] $errorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
    }

    process {
        foreach ($item in $InputObject) {
            [string] $version = $item -as [string]
            [bool] $isValid = $version -match ('^' + $SemanticVersionPattern + '$')
            [string] $messageId = ''
            [string] $message = ''
            [string] $recommendedAction = ''
            [hashtable] $outputHash = @{
                Message = ''
            }

            if ($isValid) {
                $messageId = 'ValidSemanticVersion'
                $message = $messages[$messageId] -f $version
                $outputHash['Message'] = $message
                $outputHash['RecommendedAction'] = $recommendedAction
            }
            else {
                $messageId = 'InvalidSemanticVersion'
                $message = $messages[$messageId] -f $version
                $recommendedAction = $messages[$messageId + 'RecommendedAction']

                [System.ArgumentException] $ex = New-Object -TypeName System.ArgumentException -ArgumentList @($message, $ParameterName)
                $outputHash['Exception'] = $ex
                $outputHash['Category'] = $errorCategory
                $outputHash['TargetObject'] = $item
                $outputHash['CategoryActivity'] = 'Debug-SemanticVersion'
                $outputHash['CategoryTargetName'] = $ParameterName
                $outputHash['CategoryTargetType'] = $item.GetType()
                $outputHash['CategoryReason'] = $messageId

                [string] $normalVersion = ''
                [string] $prereleaseLabel = ''
                [string] $buildLabel = ''

                # Try to split the string into the standard semver parts in order to find out why it is invalid.
                # normalVersion-preRelease+build
                $elementCountSplit = $version -split '\.'
                if ($elementCountSplit.Length -eq 3) {
                    $normalVersion = $version
                    $prereleaseLabel = ''
                    $buildLabel = ''
                }
                elseif ($version.Contains('-') -and $version.Contains('+')) {
                    $normalVersion = @($version -split '\-', 2)[0]
                    $prereleaseLabel = @(@($version -split '\-', 2)[-1] -split '\+', 2)[0]
                    $buildLabel = @(@($version -split '\-', 2)[-1] -split '\+', 2)[-1]
                }
                # normalVersion-preRelease
                elseif ($version.Contains('-') -and -not $version.Contains('+')) {
                    $normalVersion = @($version -split '\-', 2)[0]
                    $prereleaseLabel = @($version -split '\-', 2)[-1]
                    $buildLabel = ''
                }
                # normalVersion+build
                elseif (-not $version.Contains('-') -and $version.Contains('+')) {
                    $normalVersion = @($version -split '\+', 2)[0]
                    $prereleaseLabel = ''
                    $buildLabel = @($version -split '\+', 2)[-1]
                }
                # normalVersion
                else {
                    $normalVersion = $version
                    $prereleaseLabel = ''
                    $buildLabel = ''
                }

                Write-Debug "`$normalVersion: $normalVersion"
                Write-Debug "`$prereleaseLabel: $prereleaseLabel"
                Write-Debug "`$buildLabel: $buildLabel"

                # Validate normal version.
                if ($normalVersion -notmatch ('^' + $NormalVersionPattern + '$')) {
                    $messageId = 'InvalidNormalVersion'
                    $message = $messages[$messageId]
                    $recommendedAction = $messages[$messageId + 'RecommendedAction']

                    [string[]] $normalVersionElements = @($normalVersion -split '\.')
                    if ($normalVersionElements.Length -ne 3) {
                        $messageId = 'InvalidNormalVersionElementCount'
                        $message = $messages[$messageId] -f $normalVersion, $normalVersionElements.Length
                        $recommendedAction = $messages[$messageId + 'RecommendedAction']
                    }
                    else {
                        for ($i = 0; $i -lt $normalVersionElements.Length; $i++) {
                            switch ($i) {
                                0 {$elementName = 'Major'}
                                1 {$elementName = 'Minor'}
                                2 {$elementName = 'Patch'}
                            }

                            if ($normalVersionElements[$i] -match ('^' + $NormalVersionElementPattern + '$')) {
                                continue
                            }
                            elseif ($normalVersionElements[$i].Trim() -eq '') {
                                $messageId = 'NormalVersionElementIsEmpty'
                                $message = $messages[$messageId] -f $elementName
                                $recommendedAction = $messages[$messageId + 'RecommendedAction'] -f $elementName
                                break
                            }
                            #elseif ($normalVersionElements[$i] -as [int] -as [string] -ne $normalVersionElements[$i]) {
                            else {
                                #$message = '{0} version must not contain leading zeros.' -f $elementName
                                $messageId = 'CannotConvertNormalVersionElementToInt'
                                $message = $messages[$messageId] -f $elementName
                                $recommendedAction = $messages[$messageId + 'RecommendedAction']
                                break
                            }
                        }
                    }
                }
                # Validate pre-release.
                elseif ($prereleaseLabel.Length -ne 0 -and $prereleaseLabel -notmatch ('^' + $PreReleasePattern + '$')) {
                    $messageId = 'InvalidMetadataLabel'
                    $message = $messages[$messageId] -f $textInfo.ToTitleCase($messages['PreReleaseLabelName'])
                    $recommendedAction = $messages[$messageId + 'RecommendedAction'] -f $messages['PreReleaseLabelName']

                    [string[]] $prereleaseIdentifers = @($prereleaseLabel -split '\.')
                    for ($i = 0; $i -lt $prereleaseIdentifers.Length; $i++) {
                        if ($prereleaseIdentifers[$i] -match ('^' + $PreReleaseIdentifierPattern + '$')) {
                            continue
                        }
                        elseif ($prereleaseIdentifers[$i].Trim() -eq '') {
                            $messageId = 'MetadataIdentifierIsEmpty'
                            $message = $messages[$messageId] -f $textInfo.ToTitleCase($messages['PreReleaseLabelName']), $i
                            $recommendedAction = $messages[$messageId + 'RecommendedAction'] -f $messages['PreReleaseLabelName']
                        }
                        else {
                            $messageId = 'InvalidPreReleaseIdentifier'
                            $message = $messages[$messageId] -f $i
                            $recommendedAction = $messages[$messageId + 'RecommendedAction']
                        }
                    }
                }
                # Validate build.
                elseif ($buildLabel.Length -ne 0 -and $buildLabel -notmatch ('^' + $BuildPattern + '$')) {
                    $messageId = 'InvalidMetadataLabel'
                    $message = $messages[$messageId] -f $textInfo.ToTitleCase($messages['BuildLabelName'])
                    $recommendedAction = $messages[$messageId + 'RecommendedAction'] -f $messages['BuildLabelName']

                    [string[]] $buildIdentifers = @($buildLabel -split '\.')
                    for ($i = 0; $i -lt $buildIdentifers.Length; $i++) {
                        if ($buildIdentifers[$i] -match ('^' + $BuildIdentifierPattern + '$')) {
                            continue
                        }
                        elseif ($buildIdentifers[$i].Trim() -eq '') {
                            $messageId = 'MetadataIdentifierIsEmpty'
                            $message = $messages[$messageId] -f $textInfo.ToTitleCase($messages['BuildLabelName']), $i
                            $recommendedAction = $messages[$messageId + 'RecommendedAction'] -f $messages['BuildLabelName']
                        }
                        else {
                            $messageId = 'InvalidBuildIdentifier'
                            $message = $messages[$messageId] -f $i
                            $recommendedAction = $messages[$messageId + 'RecommendedAction']
                        }
                    }
                }

                $outputHash['CategoryReason'] = $messageId
                $outputHash['ErrorId'] = $messageId
                $outputHash['Message'] = $message
                $outputHash['RecommendedAction'] = $recommendedAction
            }

            $outputHash
        }
    }
}


function Split-SemanticVersion {
    <#
     .SYNOPSIS
        Splits up a Semantic Version string into a hastable.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        # The string to split into Semantic Version components.
        [Parameter(Mandatory=$true)]
        [ValidateScript({
            if (Test-SemanticVersion -InputObject $_) {
                return $true
            }
            else {
                $erHash = Debug-SemanticVersion -InputObject $_ -ParameterName string
                $er = Write-Error @erHash 2>&1
                throw ($er)
            }
        })]
        [string]
        [Alias('Version', 'String')]
        $InputObject
    )

    [hashtable] $semVerHash = @{}

    if ($InputObject -match ('^' + $NamedSemanticVersionPattern + '$')) {
        $semVerHash['Major'] = $Matches['major']
        $semVerHash['Minor'] = $Matches['minor']
        $semVerHash['Patch'] = $Matches['patch']

        if ($Matches.ContainsKey('prerelease')) {
            $semVerHash['PreRelease'] =  [string[]] @($Matches['prerelease'] -split '\.')
        }
        else {
            $semVerHash['PreRelease'] = @()
        }

        if ($Matches.ContainsKey('build')) {
            $semVerHash['Build'] = [string[]] @($Matches['build'] -split '\.')
        }
        else {
            $semVerHash['Build'] = @()
        }
    }
    else {
        throw 'Unable to parse string.'
    }

    $semVerHash
}


#endregion Internal functions


#region Exported functions


[System.Collections.Generic.List[string]] $exportedFunctions = [System.Collections.Generic.List[string]]::new()
[System.Collections.Generic.List[string]] $exportedAliases = [System.Collections.Generic.List[string]]::new()


$exportedFunctions.Add('New-SemanticVersion')
$exportedAliases.Add('nsemver')
function New-SemanticVersion {
    <#
     .SYNOPSIS
        Creates a new semantic version.

     .DESCRIPTION
        Creates a new object representing a semantic version number.

     .EXAMPLE
        New-SemanticVersion -String '1.2.3-alpha.4+build.5'

        Major      : 1
        Minor      : 2
        Patch      : 3
        PreRelease : alpha.4
        Build      : build.5

        This command converts a valid Semantic Version string into a Semantic Version object. The output of the command
        is a Semantic Version object with the elements of the version split into separate properties.

     .EXAMPLE
        New-SemanticVersion -Major 1 -Minor 2 -Patch 3 -PreRelease alpha.4 -Build build.5

        Major      : 1
        Minor      : 2
        Patch      : 3
        PreRelease : alpha.4
        Build      : build.5

        This command takes the Major, Minor, Patch, PreRelease, and Build parameters and produces the same output as the
        previous example.

     .EXAMPLE
        New-SemanticVersion -Major 1 -Minor 2 -Patch 3 -PreRelease alpha, 4 -Build build, 5

        Major      : 1
        Minor      : 2
        Patch      : 3
        PreRelease : alpha.4
        Build      : build.5

        This command uses arrays for the PreRelease and Build parameters, but produces the same output as the
        previous example.

     .EXAMPLE
        $semver = New-SemanticVersion -Major 1 -Minor 2 -Patch 3 -PreRelease alpha.4 -Build build.5

        $semver.ToString()

        1.2.3-alpha.4+build.5

        This example shows that the object output from the previous command can be saved to a variable. Then by
        calling the object's ToString() method, a valid Semantic Version string is returned.

     .INPUTS
        System.Object

            All Objects piped to this function are converted into Semantic Version objects.

    #>
    [CmdletBinding(DefaultParameterSetName='Elements')]
    [Alias('nsemver')]
    [OutputType([System.Management.Automation.SemanticVersion])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    param (
        # The major version must be incremented if any backwards incompatible changes are introduced to the public API.
        [Parameter(ParameterSetName='Elements')]
        [ValidateRange(0, 2147483647)]
        [int]
        $Major = 0,

        # The minor version must be incremented if new, backwards compatible functionality is introduced to the public API.
        [Parameter(ParameterSetName='Elements')]
        [ValidateRange(0, 2147483647)]
        [int]
        $Minor = 0,

        # The patch version must be incremented if only backwards compatible bug fixes are introduced.
        [Parameter(ParameterSetName='Elements')]
        [ValidateRange(0, 2147483647)]
        [int]
        $Patch = 0,

        # A pre-release version indicates that the version is unstable and might not satisfy the intended compatibility
        # requirements as denoted by its associated normal version.
        # The value can be a string or an array of strings. If an array of strings is provided, the elements of the array
        # will be joined using dot separators.
        [Parameter(ParameterSetName='Elements')]
        [AllowEmptyCollection()]
        $PreRelease = @(),

        # The build metadata.
        # The value can be a string or an array of strings. If an array of strings is provided, the elements of the array
        # will be joined using dot separators.
        [Parameter(ParameterSetName='Elements')]
        [AllowEmptyCollection()]
        $Build = @(),

        # A valid semantic version string to be converted into a SemanticVersion object.
        [Parameter(ParameterSetName='String',
                   ValueFromPipeline=$true,
                   Mandatory=$true,
                   Position=0)]
        [ValidateScript({
            if (Test-SemanticVersion -InputObject $_) {
                return $true
            }
            else {
                $erHash = Debug-SemanticVersion -InputObject $_ -ParameterName InputObject
                $er = Write-Error @erHash 2>&1
                throw ($er)
            }
        })]
        [Alias('Version', 'v', 'String')]
        $InputObject
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'Elements') {
            [string] $badParameterName = 'InputObject'

            # PSv2 does not initialize $PreRelease or $Build if they were not specifies or if they had empty arrays.
            # So they have to be reinitialized here if they were not specified.
            if ($PSBoundParameters.ContainsKey('Build')) {
                [string] $testBuild = $Build -join '.'
                if ($testBuild -notmatch ('^' + $BuildPattern + '$')) {
                    $badParameterName = 'Build'
                }
                [string[]] $Build = @($testBuild -split '\.')
            }
            else {
                [string[]] $Build = @()
            }

            if ($PSBoundParameters.ContainsKey('PreRelease')) {
                [string] $testPreRelease = $PreRelease -join '.'
                if ($testPreRelease -notmatch ('^' + $PreReleasePattern + '$')) {
                    $badParameterName = 'PreRelease'
                }
                [string[]] $PreRelease = @($testPreRelease -split '\.')
            }
            else {
                [string[]] $PreRelease = @()
            }

            [string] $InputObject = "$Major.$Minor.$Patch$(if ($PreRelease.Length -gt 0) {'-' + $($PreRelease -join '.')})$(if ($Build.Length -gt 0) {'+' + $($Build -join '.')})"

            if (-not $(Test-SemanticVersion -InputObject $InputObject)) {
                $erHash = Debug-SemanticVersion -InputObject $InputObject -ParameterName $badParameterName
                $er = Write-Error @erHash 2>&1
                $PSCmdlet.ThrowTerminatingError($er)
            }
        }

        foreach ($item in $InputObject) {
            [hashtable] $semVerHash = Split-SemanticVersion $item.ToString()

            switch ($semVerHash.Keys) {
                'Major' {
                    [int] $Major = $semVerHash['Major']
                }

                'Minor' {
                    [int] $Minor = $semVerHash['Minor']
                }

                'Patch' {
                    [int] $Patch = $semVerHash['Patch']
                }

                'PreRelease' {
                    [string[]] $PreRelease = @($semVerHash['PreRelease'])
                }

                'Build' {
                    [string[]] $Build = @($semVerHash['Build'])
                }
            }

            [System.Management.Automation.SemanticVersion]::new($Major, $Minor, $Patch, ($PreRelease -join '.'), ($Build -join '.'))
        }
    }
}


$exportedFunctions.Add('Test-SemanticVersion')
$exportedAliases.Add('tsemver')
function Test-SemanticVersion {
    <#
     .SYNOPSIS
        Tests if a string is a valid Semantic Version.

     .DESCRIPTION
        The Test-SemanticVersion function verifies that a supplied string meets the Semantic Version 2.0 specification.

        If an invalid Semantic Version string is supplied to Test-SemanticVersion and the Verbose switch is used, the
        verbose output stream will include additional details that may help when troubleshooting an invalid version.

     .EXAMPLE
        Test-SemanticVersion '1.2.3-alpha.1+build.456'

        True

        This example shows the result if the provided string is a valid Semantic Version.

     .EXAMPLE
        Test-SemanticVersion '1.2.3-alpha.01+build.456'

        False

        This example shows the result if the provided string is not a valid Semantic Version.

     .INPUTS
        System.Object

            Any object you pipe to this function will be converted to a string and tested for validity.

    #>
    [CmdletBinding(DefaultParameterSetName='BoolOutput')]
    [Alias('tsemver')]
    [OutputType([bool])]
    param (
        # The Semantic Version string to validate.
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   Position=0)]
        [object[]]
        [Alias('Version', 'v')]
        $InputObject
    )

    process {
        foreach ($item in $InputObject) {
            [string] $version = $item -as [string]

            $debugHash = Debug-SemanticVersion -InputObject $item -ParameterName InputObject
            Write-Verbose -Message ($debugHash.Message + ' ' + $debugHash.RecommendedAction)

            $version -match ('^' + $SemanticVersionPattern + '$')
        }
    }
}


$exportedFunctions.Add('Compare-SemanticVersion')
$exportedAliases.Add('crsemver')
function Compare-SemanticVersion {
    <#
     .SYNOPSIS
        Compares two semantic version numbers.

     .DESCRIPTION
        The Test-SemanticVersion function compares two semantic version numbers and returns an object that contains the
        results of the comparison.

     .EXAMPLE
        Compare-SemanticVersion -ReferenceVersion '1.1.1' -DifferenceVersion '1.2.0'

        ReferenceVersion Precedence DifferenceVersion IsCompatible
        ---------------- ---------- ----------------- ------------
        1.1.1            <          1.2.0                     True

        This command show sthe results of compare two semantic version numbers that are not equal in precedence but are
        compatible.

     .EXAMPLE
        Compare-SemanticVersion -ReferenceVersion '0.1.1' -DifferenceVersion '0.1.0'

        ReferenceVersion Precedence DifferenceVersion IsCompatible
        ---------------- ---------- ----------------- ------------
        0.1.1            >          0.1.0                    False

        This command shows the results of comparing two semantic version numbers that are are not equal in precedence
        and are not compatible.

     .EXAMPLE
        Compare-SemanticVersion -ReferenceVersion '1.2.3' -DifferenceVersion '1.2.3-0'

        ReferenceVersion Precedence DifferenceVersion IsCompatible
        ---------------- ---------- ----------------- ------------
        1.2.3            >          1.2.3-0                  False

        This command shows the results of comparing two semantic version numbers that are are not equal in precedence
        and are not compatible.

     .EXAMPLE
        Compare-SemanticVersion -ReferenceVersion '1.2.3-4+5' -DifferenceVersion '1.2.3-4+5'

        ReferenceVersion Precedence DifferenceVersion IsCompatible
        ---------------- ---------- ----------------- ------------
        1.2.3-4+5        =          1.2.3-4+5                 True

        This command shows the results of comparing two semantic version numbers that are exactly equal in precedence.

     .EXAMPLE
        Compare-SemanticVersion -ReferenceVersion '1.2.3-4+5' -DifferenceVersion '1.2.3-4+6789'

        ReferenceVersion Precedence DifferenceVersion IsCompatible
        ---------------- ---------- ----------------- ------------
        1.2.3-4+5        =          1.2.3-4+6789              True

        This command shows the results of comparing two semantic version numbers that are exactly equal in precedence,
        even if they have different build numbers.

     .INPUTS
        System.Object

            Any objects you pipe into this function are converted into strings then are evaluated as Semantic Versions.

     .OUTPUTS
        psobject

            The output objects are custom psobject with detail of how the ReferenceVersion compares with the
            DifferenceVersion

     .NOTES
        To sort a collection of Semantic Version numbers based on the semver.org precedence rules

            Sort-Object -Property Major,Minor,Patch,@{e = {$_.PreRelease -eq ''}; Ascending = $true},PreRelease,Build

    #>
    [CmdletBinding()]
    [Alias('crsemver')]
    [OutputType([psobject])]
    param (
        # Specifies the version used as a reference for comparison.
        [Parameter(Mandatory=$true,
                   ParameterSetName='Parameter Set 1',
                   Position=0)]
        [ValidateScript({
            if (Test-SemanticVersion -InputObject $_) {
                return $true
            }
            else {
                $erHash = Debug-SemanticVersion -InputObject $_ -ParameterName ReferenceVersion
                $er = Write-Error @erHash 2>&1
                throw $er
            }
        })]
        [Alias('r')]
        $ReferenceVersion,

        # Specifies the version that is compared to the reference version.
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   ParameterSetName='Parameter Set 1',
                   Position=1)]
        [ValidateScript({
            if (Test-SemanticVersion -InputObject $_) {
                return $true
            }
            else {
                $erHash = Debug-SemanticVersion -InputObject $_ -ParameterName DifferenceVersion
                $er = Write-Error @erHash 2>&1
                throw ($er)
            }
        })]
        [Alias('d', 'InputObject')]
        $DifferenceVersion
    )

    begin {
        $refVer = New-SemanticVersion -InputObject $ReferenceVersion.ToString()
    }

    process {
        foreach ($item in $DifferenceVersion) {
            $difVer = New-SemanticVersion -InputObject $item.ToString()

            [int] $precedence = $refVer.CompareTo($difVer)

            $result = [Activator]::CreateInstance([psobject])
            $result.psobject.Members.Add([Activator]::CreateInstance([System.Management.Automation.PSNoteProperty], @(
                'ReferenceVersion',
                $refVer.ToString()
            )))
            $result.psobject.Members.Add([Activator]::CreateInstance([System.Management.Automation.PSNoteProperty], @(
                'Precedence',
                $(
                    if ($precedence -eq 0) {
                        '='
                    }
                    elseif ($precedence -gt 0) {
                        '>'
                    }
                    else {
                        '<'
                    }
                )
            )))
            $result.psobject.Members.Add([Activator]::CreateInstance([System.Management.Automation.PSNoteProperty], @(
                'DifferenceVersion',
                $difVer.ToString()
            )))
            $result.psobject.Members.Add([Activator]::CreateInstance([System.Management.Automation.PSNoteProperty], @(
                'IsCompatible',
                $refVer.CompatibleWith($difVer)
            )))
            $result.psobject.Members.Add([Activator]::CreateInstance([System.Management.Automation.PSAliasProperty], @(
                #TODO: Deprecate: This should read "IsCompatible", not "AreCompatible".
                'AreCompatible',
                'IsCompatible'
            )))

            $result.pstypenames.Insert(0, 'PoshSemanticVersionComparison')

            $result
        }
    }
}


$exportedFunctions.Add('Step-SemanticVersion')
$exportedAliases.Add('stsemver')
function Step-SemanticVersion {
    <#
     .SYNOPSIS
        Increments a Semantic Version number.

     .DESCRIPTION
        The Step-SemanticVersion function increments the elements of a Semantic Version number in a way that is
        compliant with the Semantic Version 2.0 specification.

        - Incrementing the Major number will reset the Minor number and the Patch number to 0. A pre-release version
          will be incremented to the normal version number.
        - Incrementing the Minor number will reset the Patch number to 0. A pre-release version will be incremented to
          the normal version number.
        - Incrementing the Patch number does not change any other parts of the version number. A pre-release version
          will be incremented to the normal version number.
        - Incrementing the PreRelease number does not change any other parts of the version number.
        - Incrementing the Build number does not change any other parts of the version number.

     .EXAMPLE
        '1.1.1' | Step-SemanticVersion

        Major      : 1
        Minor      : 1
        Patch      : 2
        PreRelease : 0
        Build      :

        This command takes a semantic version string from the pipeline and increments the pre-release version. Because
        the element to increment was not specified, the default value of 'PreRelease was used'.

     .EXAMPLE
        Step-SemanticVersion -Version 1.1.1 -Level Minor

        Major      : 1
        Minor      : 2
        Patch      : 0
        PreRelease :
        Build      :

        This command converts the string '1.1.1' to the semantic version object equivalent of '1.2.0'.

     .EXAMPLE
        Step-SemanticVersion -v 1.1.1 -i patch

        Major      : 1
        Minor      : 1
        Patch      : 2
        PreRelease :
        Build      :

        This command converts the string '1.1.1' to the semantic version object equivalent of '1.1.2'. This example
        shows the use of the parameter aliases "v" and "i" for Version and Level (increment), respectively.

     .EXAMPLE
        Step-SemanticVersion 1.1.1 Major

        Major      : 2
        Minor      : 0
        Patch      : 0
        PreRelease :
        Build      :

        This command converts the string '1.1.1' to the semantic version object equivalent of '2.0.0'. This example
        shows the use of positional parameters.

    #>
    [CmdletBinding()]
    [Alias('stsemver')]
    [OutputType([System.Management.Automation.SemanticVersion])]
    param (
        # The Semantic Version number to be incremented.
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   Position=0)]
        [ValidateScript({
            if (Test-SemanticVersion -InputObject $_) {
                return $true
            }
            else {
                $erHash = Debug-SemanticVersion -InputObject $_ -ParameterName InputObject
                $er = Write-Error @erHash 2>&1
                throw ($er)
            }
        })]
        [Alias('Version', 'v')]
        $InputObject,

        # The desired increment type.
        # Valid values are Build, PreRelease, PrePatch, PreMinor, PreMajor, Patch, Minor, or Major.
        # The default value is PreRelease.
        [Parameter(Position=1)]
        [string]
        [ValidateSet('Build', 'PreRelease', 'PrePatch', 'PreMinor', 'PreMajor', 'Patch', 'Minor', 'Major')]
        [Alias('Level', 'Increment', 'i')]
        $Type = 'PreRelease',

        # The metadata label to use with an incrament type of Build, PreRelease, PreMajor, PreMinor, or PrePatch.
        # If specified, the value replaces the existing label. If not specified, the existing label will be incremented.
        # This parameter is ignored for an increment type of Major, Minor, or Patch.
        [Parameter(Position=2)]
        [string]
        [Alias('preid', 'Identifier')]
        $Label
    )

    $newSemVer = New-SemanticVersion -InputObject $InputObject

    if ($PSBoundParameters.ContainsKey('Label')) {
        try {
            $newSemVer.Increment($Type, $Label)
        }
        catch [System.ArgumentOutOfRangeException],[System.ArgumentException] {
            $er = Write-Error -Exception $_.Exception -Category InvalidArgument -TargetObject $InputObject 2>&1
            $PSCmdlet.ThrowTerminatingError($er)
        }
        catch {
            $er = Write-Error -Exception $_.Exception -Message ('Error using label "{0}" when incrementing version "{1}".' -f $Label, $InputObject.ToString()) -TargetObject $InputObject 2>&1
            $PSCmdlet.ThrowTerminatingError($er)
        }
    }
    else {
        $newSemVer.Increment($Type)
    }

    $newSemVer
}


#endregion Exported functions


#region Internal variables


New-Variable -Option Constant -Name CustomObjectTypeName -Value PoshSemanticVersion
$CustomObjectTypeName | Out-Null

New-Variable -Scope Script -Option Constant -Name NormalVersionElementPattern -Value $(
    '(0|[1-9]\d*)'
)

New-Variable -Scope Script -Option Constant -Name NormalVersionPattern -Value $(
    $NormalVersionElementPattern +
    '(\.' + $NormalVersionElementPattern + '){2}'
)

New-Variable -Scope Script -Option Constant -Name PreReleaseIdentifierPattern -Value $(
    '(0|(\d*[A-Z-]+|[1-9A-Z-])[\dA-Z-]*)'
)

New-Variable -Scope Script -Option Constant -Name PreReleasePattern -Value $(
    $PreReleaseIdentifierPattern +
    '(\.' + $PreReleaseIdentifierPattern + ')*'
)

New-Variable -Scope Script -Option Constant -Name BuildIdentifierPattern -Value $(
    '[\dA-Z-]+'
)

New-Variable -Scope Script -Option Constant -Name BuildPattern -Value $(
    $BuildIdentifierPattern +
    '(\.' + $BuildIdentifierPattern + ')*'
)

New-Variable -Scope Script -Option Constant -Name SemanticVersionPattern -Value $(
    $NormalVersionPattern +
    '(\-' + $PreReleasePattern + ')?' +
    '(\+' + $BuildPattern + ')?'
)
Write-Debug "`$SemanticVersionPattern: $SemanticVersionPattern"

New-Variable -Option Constant -Name NamedSemanticVersionPattern -Value $(
    '(?<major>' + $NormalVersionElementPattern + ')' +
    '\.(?<minor>' + $NormalVersionElementPattern + ')' +
    '\.(?<patch>' + $NormalVersionElementPattern + ')' +
    '(-(?<prerelease>' + $PreReleasePattern + '))?' +
    '(\+(?<build>' + $BuildPattern + '))?'
)
Write-Debug "`$NamedSemanticVersionPattern: $NamedSemanticVersionPattern"

#New-Variable -Name SemVerRegEx -Value (
#    '^(0|[1-9]\d*)' +
#    '(\.(0|[1-9]\d*)){2}' +
#    '(-(0|(\d*[A-Z-]+|[1-9A-Z-])[\dA-Z-]*)(\.(0|(\d*[A-Z-]+|[1-9A-Z-])[\dA-Z-]*))*)?' +
#    '(\+[\dA-Z-]*(\.[\dA-Z-]*)?)?' +
#    '(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$'
#) -Option Constant

#New-Variable -Name NamedSemVerRegEx -Value (
#    '^(?<major>(0|[1-9][0-9]*))' +
#    '\.(?<minor>(0|[1-9][0-9]*))' +
#    '\.(?<patch>(0|[1-9][0-9]*))' +
#    '(-(?<prerelease>(0|[1-9][0-9]*|[0-9]+[A-Za-z-]+[0-9A-Za-z-]*|[A-Za-z-]+[0-9A-Za-z-]*)(\.(0|[1-9][0-9]*|[0-9]+[A-Za-z-]+[0-9A-Za-z-]*|[A-Za-z-]+[0-9A-Za-z-]*))*))?' +
#    '(\+(?<build>[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*))?$'
#) -Option Constant

[hashtable] $messages = data {
    ConvertFrom-StringData @'
    ValidSemanticVersion="{0}" is a valid Semantic Version.
    InvalidSemanticVersion="{0}" is not a valid Semantic Version.
    InvalidSemanticVersionRecommendedAction=Verify the value meets the Semantic Version specification.
    InvalidNormalVersion=A normal version number MUST take the form X.Y.Z where X, Y, and Z are non-negative integers, and MUST NOT contain leading zeroes. X is the major version, Y is the minor version, and Z is the patch version.
    InvalidNormalVersionRecommendedAction=Verify the input string begins with three non-negative integers without leading zeros.
    InvalidNormalVersionElementCount=A normal version must have exactly 3 elements. The input normal version "{0}" has {1} element(s).
    InvalidNormalVersionElementCountRecommendedAction=Verify the input string has a normal version with 3 elements.
    NormalVersionElementIsEmpty={0} version element must not be empty.
    NormalVersionElementIsEmptyRecommendedAction=Verify the {0} version element is a non-negative integer value without leading zeros.
    CannotConvertNormalVersionElementToInt={0} version must be a non-negative integer and must not contain leading zeros.
    CannotConvertNormalVersionElementToIntRecommendedAction=Verify the {0} version element is a non-negative integer value without leading zeros.
    InvalidMetadataLabel={0} label is not valid.
    InvalidMetadataLabelRecommendedAction=Verify the {0} label is in the correct format.
    MetadataIdentifierIsEmpty={0} identifier at index {1} MUST not be empty.
    MetadataIdentifierIsEmptyRecommendedAction=Verify the {0} label has no empty identifiers.
    InvalidPreReleaseIdentifier=Pre-release indentifier at index {0} MUST comprise only ASCII alphanumerics and hyphen [0-9A-Za-z-]. Identifiers MUST NOT be empty. Numeric identifiers MUST NOT include leading zeroes.
    InvalidPreReleaseIdentifierRecommendedAction=Verify the pre-release label comprises only ASCII alphanumerics and hyphen and numeric indicators do not contain leading zeros.
    InvalidBuildIdentifier=Build indentifier at index {0} MUST comprise only ASCII alphanumerics and hyphen [0-9A-Za-z-]. Identifiers MUST NOT be empty.
    InvalidBuildIdentifierRecommendedAction=Verify the build label comprises only ASCII alphanumerics and hyphen.
    FileNotFoundError=The specified file was not found.
    PreReleaseLabelName=pre-release
    BuildLabelName=build
    ObjectNotOfType=Input object type must be of type "{0}".
    InvalidReleaseLevel=Invalid release level: "{0}".
'@
}

[hashtable] $localizedMessages = @{}

#endregion Internal variables

Import-LocalizedData -BindingVariable localizedMessages -Filename messages -ErrorAction SilentlyContinue

foreach ($key in $localizedMessages.Keys) {
    $messages[$key] = $localizedMessages[$key]
}

[System.Globalization.CultureInfo] $Script:cultureInfo = Get-Culture
[System.Globalization.TextInfo] $Script:textInfo = $cultureInfo.TextInfo

Export-ModuleMember -Function $exportedFunctions -Cmdlet @() -Variable @() -Alias $exportedAliases

Remove-Variable exportedFunctions, exportedAliases, localizedMessages, key
