param(
    [Parameter(Mandatory = $true)]
    [string]$ArtifactPath
)

$ErrorActionPreference = 'Stop'

$resolvedArtifact = (Resolve-Path -LiteralPath $ArtifactPath).Path
Add-Type -AssemblyName System.IO.Compression.FileSystem
$binaryTextEncoding = [Text.Encoding]::GetEncoding(28591)

function Get-Fingerprint([string]$Value) {
    $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha256.ComputeHash($bytes)
    } finally {
        $sha256.Dispose()
    }
    $hex = -join ($hash | ForEach-Object { $_.ToString('X2') })
    return $hex.Substring(0, 12)
}

$secretEnvironmentNames = @(
    'ANTHROPIC_API_KEY',
    'DISCORD_BOT_TOKEN',
    'ELEVENLABS_API_KEY',
    'GEMINI_API_KEY',
    'GITHUB_TOKEN',
    'GIPHY_API_KEY',
    'GOOGLE_API_KEY',
    'GOOGLE_PLACES_API_KEY',
    'GROQ_API_KEY',
    'KEEPERHUB_API_KEY',
    'KLIPY_API_KEY',
    'MCPORTER_TOKEN',
    'NOTION_TOKEN',
    'OPENAI_API_KEY',
    'OPENROUTER_API_KEY',
    'OP_CONNECT_TOKEN',
    'REPLICATE_API_TOKEN',
    'SLACK_BOT_TOKEN',
    'SPOTIFY_ACCESS_TOKEN',
    'TRELLO_API_KEY',
    'TRELLO_TOKEN',
    'XAI_API_KEY'
)

$exactForbidden = @{}
foreach ($name in $secretEnvironmentNames) {
    $value = [Environment]::GetEnvironmentVariable($name)
    if (-not [string]::IsNullOrWhiteSpace($value) -and $value.Length -ge 8) {
        $exactForbidden[$name] = $value
    }
}

$secretShape = [regex]::new(
    '(?<![A-Za-z0-9_-])(' +
    'sk-[A-Za-z0-9_-]{16,}|' +
    'AIza[0-9A-Za-z_-]{20,}|' +
    'gh[pousr]_[A-Za-z0-9]{20,}|' +
    'xox[baprs]-[A-Za-z0-9-]{10,}|' +
    'kh_[A-Za-z0-9_-]{12,}' +
    ')',
    [Text.RegularExpressions.RegexOptions]::Compiled
)

$findings = @{}
$zip = [IO.Compression.ZipFile]::OpenRead($resolvedArtifact)
try {
    $entries = $zip.Entries | Where-Object {
        $_.FullName -match '(^|/)classes[^/]*\.dex$' -or
        $_.FullName -match '(kernel_blob\.bin|isolate_snapshot_data|vm_snapshot_data|libapp\.so|resources\.(arsc|pb)|AndroidManifest\.xml)$' -or
        $_.FullName -match '\.(json|xml|txt|env|properties|ya?ml|js|mjs)$'
    }

    foreach ($entry in $entries) {
        $stream = $entry.Open()
        try {
            $buffer = New-Object byte[] 1048576
            $tail = ''
            while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                $text = $tail + $binaryTextEncoding.GetString($buffer, 0, $read)

                foreach ($match in $secretShape.Matches($text)) {
                    $value = $match.Groups[1].Value
                    $fingerprint = Get-Fingerprint $value
                    $findings["shape:$fingerprint"] = [pscustomobject]@{
                        Kind = 'credential-shaped value'
                        Fingerprint = $fingerprint
                        Length = $value.Length
                        Entry = $entry.FullName
                    }
                }

                foreach ($item in $exactForbidden.GetEnumerator()) {
                    if ($text.IndexOf($item.Value, [StringComparison]::Ordinal) -ge 0) {
                        $fingerprint = Get-Fingerprint $item.Value
                        $findings["env:$($item.Key):$fingerprint"] = [pscustomobject]@{
                            Kind = "build environment value $($item.Key)"
                            Fingerprint = $fingerprint
                            Length = $item.Value.Length
                            Entry = $entry.FullName
                        }
                    }
                }

                $keep = [Math]::Min(512, $text.Length)
                $tail = $text.Substring($text.Length - $keep, $keep)
            }
        } finally {
            $stream.Dispose()
        }
    }
} finally {
    $zip.Dispose()
}

if ($findings.Count -gt 0) {
    Write-Error "Android artifact secret audit failed with $($findings.Count) redacted finding(s)."
    foreach ($finding in $findings.Values | Sort-Object Entry, Fingerprint) {
        Write-Error (
            'kind={0} len={1} fingerprint={2} entry={3}' -f
            $finding.Kind,
            $finding.Length,
            $finding.Fingerprint,
            $finding.Entry
        )
    }
    exit 1
}

$sha256 = (Get-FileHash -LiteralPath $resolvedArtifact -Algorithm SHA256).Hash
Write-Output "Android artifact secret audit passed: sha256=$sha256"
