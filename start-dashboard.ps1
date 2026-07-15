param([int]$port = 8787)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path $PSScriptRoot).Path
$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, $port)
$listener.Start()
Start-Process "http://localhost:$port/"
Write-Host "Dashboard is running at http://localhost:$port/ - keep this window open."
while ($true) {
  $client = $listener.AcceptTcpClient()
  try {
    $stream = $client.GetStream()
    $reader = [IO.StreamReader]::new($stream, [Text.Encoding]::ASCII, $false, 1024, $true)
    $request = $reader.ReadLine()
    while (($line = $reader.ReadLine()) -ne $null -and $line -ne '') { }
    $relative = 'index.html'
    if ($request -match '^GET\s+([^\s?]+)') { $relative = [Uri]::UnescapeDataString($matches[1].TrimStart('/')) }
    if ([string]::IsNullOrWhiteSpace($relative)) { $relative = 'index.html' }
    $path = [IO.Path]::GetFullPath((Join-Path $root $relative))
    if (-not $path.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $path -PathType Leaf)) { $header = "HTTP/1.1 404 Not Found`r`nContent-Length: 0`r`nConnection: close`r`n`r`n"; $stream.Write([Text.Encoding]::ASCII.GetBytes($header),0,$header.Length); continue }
    $bytes = [IO.File]::ReadAllBytes($path)
    $type = switch ([IO.Path]::GetExtension($path).ToLowerInvariant()) { '.html' {'text/html; charset=utf-8'} '.js' {'application/javascript; charset=utf-8'} '.css' {'text/css; charset=utf-8'} '.xlsx' {'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'} default {'application/octet-stream'} }
    $header = "HTTP/1.1 200 OK`r`nContent-Type: $type`r`nContent-Length: $($bytes.Length)`r`nConnection: close`r`n`r`n"
    $headBytes = [Text.Encoding]::ASCII.GetBytes($header)
    $stream.Write($headBytes,0,$headBytes.Length); $stream.Write($bytes,0,$bytes.Length)
  } catch { } finally { $client.Close() }
}
