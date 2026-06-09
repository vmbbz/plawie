param(
    [string]$OutputRoot = "assets/openclaw/terminal",
    [string]$WorkRoot = ".tmp/termux-tmux-payload"
)

$ErrorActionPreference = "Stop"

$BaseUrl = "https://packages.termux.dev/apt/termux-main"
$Packages = @(
    @{
        Name = "tmux"
        File = "pool/main/t/tmux/tmux_3.6b_aarch64.deb"
        Sha256 = "d52ab2155b036d03b47cfb824be41e9fe4fe67b80b457716d81faa38ec1c7319"
    },
    @{
        Name = "ncurses"
        File = "pool/main/n/ncurses/ncurses_6.6.20260307+really6.5.20250830_aarch64.deb"
        Sha256 = "f44bbfdc3d42ec0217bffa978309390e59cea5a48a9a83226d4a496c42ad0b99"
    },
    @{
        Name = "libevent"
        File = "pool/main/libe/libevent/libevent_2.1.12-3_aarch64.deb"
        Sha256 = "9db37dd4a000ae43eff4e87422e5280be9b6348581702f582d2fe8bddc0f4572"
    },
    @{
        Name = "libandroid-support"
        File = "pool/main/liba/libandroid-support/libandroid-support_29-1_aarch64.deb"
        Sha256 = "f2f145d6135ad4843ac9670153be3e3944dc1e6f1736d46d2306c28f2b86f517"
    },
    @{
        Name = "libandroid-glob"
        File = "pool/main/liba/libandroid-glob/libandroid-glob_0.6-3_aarch64.deb"
        Sha256 = "2276ae8adedf0db76c2f4ffc94cc4cceb2f4f5d78e021b54e2e046d1233e7826"
    }
)

function Assert-Sha256 {
    param(
        [string]$Path,
        [string]$Expected
    )

    $Actual = (Get-FileHash -Algorithm SHA256 $Path).Hash.ToLowerInvariant()
    if ($Actual -ne $Expected) {
        throw "SHA256 mismatch for $Path. Actual=$Actual Expected=$Expected"
    }
}

$DebRoot = Join-Path $WorkRoot "debs"
$ExtractRoot = Join-Path $WorkRoot "extract"
$BinRoot = Join-Path $OutputRoot "bin"
$LibRoot = Join-Path $OutputRoot "lib"

New-Item -ItemType Directory -Force $DebRoot, $ExtractRoot, $BinRoot, $LibRoot | Out-Null

foreach ($Package in $Packages) {
    $DebPath = Join-Path $DebRoot "$($Package.Name).deb"
    curl.exe -L --fail --retry 3 -o $DebPath "$BaseUrl/$($Package.File)"
    Assert-Sha256 -Path $DebPath -Expected $Package.Sha256

    $PackageRoot = Join-Path $ExtractRoot $Package.Name
    Remove-Item -Recurse -Force $PackageRoot -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force $PackageRoot | Out-Null
    tar -xf $DebPath -C $PackageRoot
    New-Item -ItemType Directory -Force (Join-Path $PackageRoot "data") | Out-Null
    tar -xf (Join-Path $PackageRoot "data.tar.xz") -C (Join-Path $PackageRoot "data")
}

$Usr = "data/data/com.termux/files/usr"
Copy-Item (Join-Path $ExtractRoot "tmux/data/$Usr/bin/tmux") `
    (Join-Path $BinRoot "tmux") -Force
Copy-Item (Join-Path $ExtractRoot "libandroid-glob/data/$Usr/lib/libandroid-glob.so") `
    (Join-Path $LibRoot "libandroid-glob.so") -Force
Copy-Item (Join-Path $ExtractRoot "libandroid-support/data/$Usr/lib/libandroid-support.so") `
    (Join-Path $LibRoot "libandroid-support.so") -Force
Copy-Item (Join-Path $ExtractRoot "libevent/data/$Usr/lib/libevent_core-2.1.so") `
    (Join-Path $LibRoot "libevent_core-2.1.so") -Force
Copy-Item (Join-Path $ExtractRoot "ncurses/data/$Usr/lib/libncursesw.so.6.5") `
    (Join-Path $LibRoot "libncursesw.so.6") -Force

Get-ChildItem $BinRoot, $LibRoot -File |
    Sort-Object FullName |
    ForEach-Object {
        $Hash = (Get-FileHash -Algorithm SHA256 $_.FullName).Hash.ToLowerInvariant()
        "$($_.Name) $($_.Length) $Hash"
    }
