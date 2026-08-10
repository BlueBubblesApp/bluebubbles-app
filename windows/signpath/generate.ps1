# Regenerates the SignPath artifact configurations that enumerate bundled DLLs
# (app.xml, msix-test.xml) from an actual Release build, so a newly added plugin
# can't silently ship unsigned.
#
#   .\windows\signpath\generate.ps1
#
# Builds first, because a stale Release dir is exactly how the DLL list goes wrong.
# Pass -ReleaseDir to skip the build and use a directory you already trust.
#
# msix.xml and installer.xml use wildcards and need no regeneration.
param([string]$ReleaseDir)

$ErrorActionPreference = 'Stop'

if (-not $ReleaseDir) {
    & "$PSScriptRoot\..\build.ps1" -Phase Build
    $ReleaseDir = "$PSScriptRoot\..\..\build\windows\x64\runner\Release"
}

if (-not (Test-Path $ReleaseDir)) { throw "no Release build at $ReleaseDir" }

# Vendor DLLs (ANGLE, SwiftShader, Vulkan, WebView2, D3D) arrive already signed by
# Microsoft/Google: SignPath must verify those and sign everything else. Read that
# split off the binaries themselves rather than keeping a list in sync by hand.
$dlls = Get-ChildItem "$ReleaseDir\*.dll" | Sort-Object Name
if (-not $dlls) { throw "no DLLs in $ReleaseDir - is the build complete?" }

$presigned = @($dlls | Get-AuthenticodeSignature |
    Where-Object { $_.Status -ne 'NotSigned' } |
    ForEach-Object { Split-Path $_.Path -Leaf })
$unsigned = @($dlls.Name | Where-Object { $presigned -notcontains $_ })

function Includes($names, $indent) {
    ($names | ForEach-Object { "$indent<include path=`"$_`" />" }) -join "`n"
}

# App payload: sign the exe and every DLL we or a plugin built; verify the vendor ones.
@"
<?xml version="1.0" encoding="utf-8"?>
<artifact-configuration xmlns="http://signpath.io/artifact-configuration/v1">
  <zip-file>
    <pe-file path="bluebubbles_app.exe">
      <authenticode-sign />
    </pe-file>
    <pe-file-set>
$(Includes $presigned '      ')
      <for-each>
        <authenticode-verify />
      </for-each>
    </pe-file-set>
    <pe-file-set>
$(Includes $unsigned '      ')
      <for-each>
        <authenticode-sign />
      </for-each>
    </pe-file-set>
  </zip-file>
</artifact-configuration>
"@ | Set-Content "$PSScriptRoot\app.xml" -Encoding utf8

# Test msix: the payload was signed with the test cert, which won't verify, so only
# the vendor DLLs are listed. (msix.xml verifies everything - release certs chain.)
@"
<?xml version="1.0" encoding="utf-8"?>
<artifact-configuration xmlns="http://signpath.io/artifact-configuration/v1">
    <zip-file>
        <msix-file path="bluebubbles.msix">
            <pe-file-set>
$(Includes $presigned '                ')
                <for-each>
                    <authenticode-verify />
                </for-each>
            </pe-file-set>
            <authenticode-sign />
        </msix-file>
    </zip-file>
</artifact-configuration>
"@ | Set-Content "$PSScriptRoot\msix-test.xml" -Encoding utf8

Write-Host "wrote app.xml ($($unsigned.Count) to sign, $($presigned.Count) pre-signed) and msix-test.xml"
