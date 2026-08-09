<#
.SYNOPSIS
    Turns raw phone recordings into game-ready audio for Godot.

.DESCRIPTION
    Does the boring, repeatable half of audio editing so Audacity is left for the
    creative half (picking takes, building loops). Per file:

      1. convert          .m4a and friends -> 44.1 kHz WAV/OGG that Godot can import
      2. high-pass        remove rumble, handling noise, traffic below the useful range
      3. trim silence     top and tail only, keeping 50 ms of lead-in
      4. normalise        one consistent level across every file in the batch
      5. fade             8 ms at each end, or every playback starts with a click

    It never touches the source folder. Raw recordings are negatives: keep them.

.PARAMETER Source
    Folder of raw recordings. Reads .m4a .wav .mp3 .aac .caf .flac.

.PARAMETER Out
    Where to write. Defaults to <Source>\processed.

.PARAMETER Preset
    can       spray, rattle, cap click. 120 Hz high-pass, mono, peak-normalised.
              Everything useful in an aerosol is high up; below 120 Hz is handling.
    passby    tram going past, car, footsteps. 40 Hz, mono, peak-normalised.
              Mono because it will sit on an AudioStreamPlayer3D and pan.
    ambience  tram interior, room tone, street beds. 40 Hz, STEREO, loudness-matched,
              no silence trim, exported as OGG. Stereo because it is a non-positional
              bed and it will sound much wider than a mono one.
    voice     dialogue. 90 Hz, mono, loudness-matched so no line jumps out.

.PARAMETER Peak
    Peak target in dBFS for `can` and `passby`. Default -3.

.PARAMETER Force
    Overwrite existing output files. Without it, already-processed files are skipped.

.EXAMPLE
    .\tools\prep_audio.ps1 -Source "D:\recordings\cans" -Preset can
    .\tools\prep_audio.ps1 -Source "D:\recordings\tram" -Preset ambience
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Source,
    [string]$Out = "",
    [ValidateSet("can", "passby", "ambience", "voice")][string]$Preset = "can",
    [double]$Peak = -3.0,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# A Serbian (or German, or French) Windows formats 3.5 as "3,5" — and a comma inside an
# ffmpeg filter string SEPARATES FILTERS. One locale-formatted number would turn
# "volume=-3.5dB" into two filters, one of them nonsense. Pin the culture so every number
# this script prints or splices into a command is invariant, whatever the machine is set
# to. This is not paranoia: it is the exact reason audio tooling breaks on non-US PCs.
[Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::InvariantCulture

# --- tools -----------------------------------------------------------------

if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Host "ffmpeg is not installed." -ForegroundColor Red
    Write-Host "  winget install Gyan.FFmpeg"
    Write-Host "Then open a NEW terminal so PATH picks it up."
    exit 1
}
if (-not (Test-Path $Source)) { Write-Host "No such folder: $Source" -ForegroundColor Red; exit 1 }
if ($Out -eq "") { $Out = Join-Path $Source "processed" }
if (-not (Test-Path $Out)) { New-Item -ItemType Directory -Path $Out | Out-Null }

# --- presets ---------------------------------------------------------------
# One row per preset so there is exactly one place to retune. See the help above
# for why each number is what it is.

$presets = @{
    can      = @{ HighPass = 120; Channels = 1; Trim = $true;  Mode = "peak";     Lufs = 0;   Ext = "wav" }
    passby   = @{ HighPass = 40;  Channels = 1; Trim = $true;  Mode = "peak";     Lufs = 0;   Ext = "wav" }
    ambience = @{ HighPass = 40;  Channels = 2; Trim = $false; Mode = "loudness"; Lufs = -23; Ext = "ogg" }
    voice    = @{ HighPass = 90;  Channels = 1; Trim = $true;  Mode = "loudness"; Lufs = -18; Ext = "wav" }
}
$p = $presets[$Preset]

$FADE = 0.008  # seconds. Long enough to kill the click, short enough to not be heard.

# --- helpers ---------------------------------------------------------------

function ConvertTo-CommandLine {
    # Start-Process takes ONE argument string, so anything containing a space has to be
    # quoted here or a path like "cap click.m4a" arrives as two arguments.
    param([string[]]$Items)
    $quoted = $Items | ForEach-Object {
        if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ }
    }
    return ($quoted -join " ")
}

function Invoke-Ffmpeg {
    # ffmpeg writes its ENTIRE log to stderr, including on success. PowerShell 5.1 wraps
    # a native command's stderr into error records (NativeCommandError) and, with
    # ErrorActionPreference = Stop, that kills the script on a perfectly good encode.
    # Start-Process has no such behaviour: it redirects to a file and hands back a real
    # exit code, which is the only trustworthy success signal here.
    param([string[]]$FfArgs)
    $log = Join-Path $env:TEMP "prep_audio_ff.txt"
    $proc = Start-Process -FilePath "ffmpeg" -ArgumentList (ConvertTo-CommandLine $FfArgs) `
        -NoNewWindow -Wait -PassThru -RedirectStandardError $log
    $text = ""
    if (Test-Path $log) { $text = Get-Content $log -Raw }
    return @{ Ok = ($proc.ExitCode -eq 0); Log = $text }
}

function Get-Duration {
    param([string]$Path)
    $outFile = Join-Path $env:TEMP "prep_audio_dur.txt"
    $a = @("-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", "--", $Path)
    Start-Process -FilePath "ffprobe" -ArgumentList (ConvertTo-CommandLine $a) `
        -NoNewWindow -Wait -RedirectStandardOutput $outFile | Out-Null
    return [double](Get-Content $outFile -Raw).Trim()
}

function Get-PeakDb {
    # Measured AFTER cleaning, because the high-pass changes the peak.
    param([string]$Path)
    $r = Invoke-Ffmpeg @("-hide_banner", "-i", $Path, "-af", "volumedetect", "-f", "null", "-")
    if ($r.Log -match "max_volume:\s*(-?[\d.]+) dB") { return [double]$Matches[1] }
    return 0.0
}

# --- run -------------------------------------------------------------------

$files = Get-ChildItem -Path $Source -File | Where-Object {
    $_.Extension -match "^\.(m4a|wav|mp3|aac|caf|flac)$"
}
if ($files.Count -eq 0) { Write-Host "No audio files in $Source" -ForegroundColor Yellow; exit 0 }

Write-Host "$($files.Count) file(s), preset '$Preset' -> $Out" -ForegroundColor Cyan
$report = @()

foreach ($f in $files) {
    # Godot is happiest with lowercase, no spaces.
    $stem = ($f.BaseName -replace "[^\w\-]+", "_").ToLower()
    $dest = Join-Path $Out "$stem.$($p.Ext)"

    if ((Test-Path $dest) -and (-not $Force)) {
        Write-Host "  skip  $($f.Name) (exists, use -Force)" -ForegroundColor DarkGray
        continue
    }

    $tmp = Join-Path $env:TEMP "prep_audio_$stem.wav"

    # Pass 1 — clean. High-pass, optional top-and-tail trim, target rate/channels.
    $chain = "highpass=f=$($p.HighPass)"
    if ($p.Trim) {
        $sr = "silenceremove=start_periods=1:start_silence=0.05:start_threshold=-50dB:detection=peak"
        # Trailing silence has no ffmpeg filter of its own: reverse, trim the new
        # "start", reverse back.
        $chain = "$chain,$sr,areverse,$sr,areverse"
    }
    $r = Invoke-Ffmpeg @(
        "-y", "-hide_banner", "-i", $f.FullName,
        "-af", $chain, "-ar", "44100", "-ac", "$($p.Channels)",
        "-c:a", "pcm_s16le", $tmp
    )
    if (-not $r.Ok) {
        Write-Host "  FAIL  $($f.Name)" -ForegroundColor Red
        Write-Host ($r.Log -split "`n" | Select-Object -Last 4) -ForegroundColor DarkRed
        continue
    }

    $dur = Get-Duration $tmp

    # Pass 2 — level, then fades. Fades come last because the trim above changed the
    # duration, and the fade-out has to be placed against the FINAL length.
    $gainDesc = ""
    if ($p.Mode -eq "peak") {
        $measured = Get-PeakDb $tmp
        $gain = $Peak - $measured
        $gainDesc = "{0:+0.0;-0.0} dB" -f $gain
        $level = "volume=$($gain)dB"
    }
    else {
        # EBU R128. Single pass is slightly less exact than two, and far more exact
        # than eyeballing it — which is all that matters for consistency between takes.
        $gainDesc = "$($p.Lufs) LUFS"
        $level = "loudnorm=I=$($p.Lufs):TP=-2.0:LRA=11"
    }
    $fadeOutAt = [math]::Max($dur - $FADE, 0)
    # Every variable here MUST be wrapped in $( ). In a double-quoted PowerShell string a
    # colon straight after a variable name means a scope qualifier — "$fadeOutAt:d" is
    # read as variable `d` in scope `fadeOutAt`, which is empty, and the filter silently
    # becomes "st==0.008". ffmpeg then refuses the whole chain.
    $chain2 = "$level,afade=t=in:st=0:d=$($FADE),afade=t=out:st=$($fadeOutAt):d=$($FADE)"

    $codec = @("-c:a", "pcm_s16le")
    if ($p.Ext -eq "ogg") { $codec = @("-c:a", "libvorbis", "-q:a", "6") }

    $r = Invoke-Ffmpeg (@(
        "-y", "-hide_banner", "-i", $tmp, "-af", $chain2, "-ar", "44100"
    ) + $codec + @($dest))

    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    if (-not $r.Ok) {
        Write-Host "  FAIL  $($f.Name) (level pass)" -ForegroundColor Red
        Write-Host "        chain: $chain2" -ForegroundColor DarkRed
        Write-Host (($r.Log -split "`n" | Select-Object -Last 4) -join "`n") -ForegroundColor DarkRed
        continue
    }

    $kb = [math]::Round((Get-Item $dest).Length / 1KB)
    Write-Host ("  ok    {0,-28} {1,6:0.00}s  {2,-10} {3,6} KB" -f $stem, $dur, $gainDesc, $kb)
    $report += [pscustomobject]@{ File = "$stem.$($p.Ext)"; Seconds = [math]::Round($dur, 2) }
}

Write-Host ""
Write-Host "Done. $($report.Count) file(s) in $Out" -ForegroundColor Green
Write-Host ""
Write-Host "Next, in Godot:" -ForegroundColor Cyan
Write-Host "  - copy these into audio/sfx/ or audio/ambience/ (LFS already covers wav/ogg)"
if ($p.Ext -eq "ogg" -or $Preset -eq "can") {
    Write-Host "  - anything that LOOPS: select it, Import tab, Loop Mode = Forward, Reimport."
    Write-Host "    Forgetting this is why a loop 'does not loop'."
}
if ($p.Channels -eq 1) {
    Write-Host "  - these are mono, so they will pan correctly on an AudioStreamPlayer3D."
}
