# Windows release build script. Run from the root of the repository. Requires Inno Setup 6 to be installed.
#
# Phases (so CI can sign the app payload between building and packaging):
#   -Phase Build    build the app + store MSIX, then stop, leaving build\windows\x64\runner\Release
#                   ready for SignPath to sign the inner binaries.
#   -Phase Package  package the sideload MSIX + Inno installer from the (now-signed) Release\ dir.
#   -Phase All      both, back-to-back (default — local builds with no signing round-trip).
#
# Outputs:
#   windows\bluebubbles-store.msix      (Build/All) MS Store submission only — not attached to releases
#   windows\bluebubbles.msix            (Package/All) directly-distributed, unsigned; SignPath signs it in CI
#                                       (only when SIGNED_MSIX_PUBLISHER is set)
#   windows\bluebubbles_installer.exe   (Package/All)
param(
    [ValidateSet('All', 'Build', 'Package')]
    [string]$Phase = 'All'
)

$ErrorActionPreference = 'Stop'

# Ctrl+C tears PowerShell down before `finally`/`trap` get a look in, and the fvm/flutter/dart
# batch shims leave dart.exe, MSBuild and friends building away in the background. So take the
# console signal in .NET instead — it fires on a separate thread while the build command is
# still blocking the main one — kill the process tree from there, then exit.
Add-Type -Name Ctrl -Namespace Build -MemberDefinition @'
    [DllImport("kernel32.dll")] static extern uint GetConsoleProcessList(uint[] pids, uint count);
    [DllImport("kernel32.dll")] static extern IntPtr GetStdHandle(int which);
    [DllImport("kernel32.dll")] static extern bool GetConsoleMode(IntPtr handle, out uint mode);
    [DllImport("kernel32.dll")] static extern bool SetConsoleMode(IntPtr handle, uint mode);

    static uint _inMode, _outMode;
    static System.Collections.Generic.List<int> _spare;   // us, plus whatever was here first

    // Everything attached to this console: the set Windows warns about when you close the tab,
    // and unlike a parent-PID walk it still finds a dart.exe whose cmd.exe shim already exited.
    // ponytail: misses anything that made its own console — that doesn't hold the tab open either.
    static System.Collections.Generic.List<int> Attached() {
        var pids = new uint[256];
        uint found = GetConsoleProcessList(pids, 256);
        var list = new System.Collections.Generic.List<int>();
        for (int i = 0; i < found && i < 256; i++) list.Add((int)pids[i]);
        return list;
    }

    public static void KillTreeOnCtrlC() {
        _spare = Attached();
        GetConsoleMode(GetStdHandle(-10), out _inMode);
        GetConsoleMode(GetStdHandle(-11), out _outMode);
        System.Console.CancelKeyPress += delegate(object sender, System.ConsoleCancelEventArgs e) {
            // e.Cancel stays false: kill what the build started, then let PowerShell handle the
            // signal as usual. Killing this process too would take the terminal with it.
            foreach (var pid in Attached()) {
                if (_spare.Contains(pid)) continue;
                try {
                    var p = System.Diagnostics.Process.GetProcessById(pid);
                    System.Console.Error.WriteLine("Stopping " + p.ProcessName + " (" + pid + ")");
                    p.Kill();
                } catch { }   // already gone, or not ours to touch
            }
            // A killed dart.exe never restores the console mode it changed
            SetConsoleMode(GetStdHandle(-10), _inMode);
            SetConsoleMode(GetStdHandle(-11), _outMode);
            System.Console.Error.WriteLine("Build cancelled.");
        };
    }
'@
[Build.Ctrl]::KillTreeOnCtrlC()

# Flutter version to build with; override with the FLUTTER_VERSION env var.
$flutterVersion = if ($env:FLUTTER_VERSION) { $env:FLUTTER_VERSION } else { '3.44.6' }

Set-Location (Join-Path $PSScriptRoot '..')

# Runs a command and aborts the build if it fails.
function Invoke-Checked {
    param([Parameter(Mandatory)][string[]]$Command, [Parameter(ValueFromRemainingArguments)][string[]]$Rest)
    & $Command[0] @($Command | Select-Object -Skip 1) @Rest
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

# Switch the project to the pinned Flutter version via fvm.
# Set FLUTTER_CMD to bypass fvm and use a preinstalled Flutter instead.
if ($env:FLUTTER_CMD) {
    $flutterCmd = $env:FLUTTER_CMD -split ' '
    $dartCmd = @('dart')
} else {
    Invoke-Checked @('fvm') use $flutterVersion --force
    $flutterCmd = 'fvm', 'flutter'
    $dartCmd = 'fvm', 'dart'
}

$releaseDir = 'build\windows\x64\runner\Release'

if ($Phase -ne 'Package') {
    # --- Build phase: produce the Release\ output and the store MSIX ---

    # Clean the Release output first: the installer ships Release\*.dll wholesale,
    # so leftovers from removed plugins would get packaged into the installer.
    if (Test-Path $releaseDir) { Remove-Item $releaseDir -Recurse -Force }

    Invoke-Checked $flutterCmd pub get --enforce-lockfile

    # Runs `flutter build windows` and packages the MS Store MSIX
    # (windows\bluebubbles-store.msix). Microsoft signs this one, so pass --store
    # explicitly (store mode is no longer set in pubspec.yaml). Built from the
    # unsigned Release output — Microsoft re-signs the package at ingestion.
    # --windows-build-args=--no-pub: the inner `flutter build windows` reuses the
    # lockfile-enforced resolution above instead of re-running pub get unenforced.
    # --split-debug-info pulls the Dart AOT debug symbols out of the binary (they trip
    # AV malware heuristics otherwise) into build\windows\symbols, which CI uploads.
    Invoke-Checked $dartCmd run msix:create --store '--windows-build-args=--no-pub --split-debug-info=build/windows/symbols' --output-name bluebubbles-store

    Get-FileHash 'windows\bluebubbles-store.msix' -Algorithm SHA256 | Format-List Path, Hash
}

if ($Phase -ne 'Build') {
    # --- Package phase: wrap the Release\ binaries (signed by CI in between) ---

    $iscc = if ($env:ISCC_PATH) { $env:ISCC_PATH } else { "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe" }
    if (-not (Test-Path $iscc)) { throw "Inno Setup compiler not found at '$iscc'. Install Inno Setup 6 or set ISCC_PATH." }

    if (-not (Test-Path $releaseDir)) { throw "Release output '$releaseDir' not found — run the Build phase first." }

    # Build the directly-distributed MSIX, left unsigned for SignPath to sign in CI.
    # Reuses the Release output from the store build above. SIGNED_MSIX_PUBLISHER must
    # equal the SignPath certificate's subject DN, or Windows will reject the signature.
    # Only built when PACKAGE_MSIX=true (CI sets this when the payload was signed): an
    # unsigned msix can't be installed, so packaging one for the signing fallback — or
    # for a local build without signing — is pointless. Skipped when either is unset.
    if ($env:PACKAGE_MSIX -eq 'true' -and $env:SIGNED_MSIX_PUBLISHER) {
        # MakeAppx needs a valid X.500 DN here; a plain display name yields a cryptic
        # 0x80080204 "manifest is not valid". Fail with a clear message instead.
        if ($env:SIGNED_MSIX_PUBLISHER -notmatch '(^|,)\s*CN=') {
            throw "SIGNED_MSIX_PUBLISHER must be an X.500 DN starting with 'CN=' (got: '$env:SIGNED_MSIX_PUBLISHER')."
        }
        # Must differ from the store package's CLSID (pubspec.yaml) or, with both installed,
        # one package swallows the other's toast actions. Keep in sync with
        # _sideloadMsixNotificationGuid in lib/services/backend/notifications/notifications_service.dart.
        $msixArgs = @(
            '--build-windows', 'false',
            '--sign-msix', 'false',
            '--publisher', $env:SIGNED_MSIX_PUBLISHER,
            '--toast-activator-clsid', '68c6675d-9acf-4098-b539-20b5792427b5',
            '--output-name', 'bluebubbles'
        )
        if ($env:SIGNED_MSIX_IDENTITY) { $msixArgs += @('--identity-name', $env:SIGNED_MSIX_IDENTITY) }
        Invoke-Checked $dartCmd run msix:create @msixArgs
        # fvm swallows the child exit code, so Invoke-Checked can't see a msix failure.
        if (-not (Test-Path 'windows\bluebubbles.msix')) { throw "msix:create did not produce windows\bluebubbles.msix — see the output above." }
    }

    # Compile the Inno Setup installer
    Invoke-Checked @($iscc) 'windows\bluebubbles_installer_script.iss'

    $hashTargets = @('windows\bluebubbles_installer.exe')
    if (Test-Path 'windows\bluebubbles.msix') { $hashTargets += 'windows\bluebubbles.msix' }
    Get-FileHash $hashTargets -Algorithm SHA256 | Format-List Path, Hash
}
