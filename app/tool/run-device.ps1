# Corre la app en un celular Android conectado por USB, apuntando al backend de esta máquina.
#
# El celular no puede usar `localhost` (ese es él mismo) ni `10.0.2.2` (eso es solo el emulador):
# necesita la IP de esta máquina en la Wi-Fi, y esa IP cambia de red en red. Este script la busca
# y la pasa como --dart-define, que es lo único que separa una corrida en celular de una en web.
#
# Uso, desde `app/`:
#
#   powershell -ExecutionPolicy Bypass -File tool/run-device.ps1
#
# Requisitos: el celular en la MISMA Wi-Fi que esta máquina, con depuración USB activada, y el
# backend corriendo (`cd ../server; npm run dev`).

param(
    [int]$Port = 3001,
    # La IP a usar, si la detección automática elige la interfaz equivocada (VPN, Docker, etc.).
    [string]$HostIp
)

if (-not $HostIp) {
    # Se descartan loopback, APIPA (169.254.x) y las virtuales de Hyper-V/WSL/Docker, que están
    # "arriba" pero no son la red donde vive el celular. Gana la de métrica más baja, que es la
    # que Windows usaría para salir a internet.
    $candidate = Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object {
            $_.IPAddress -notlike '127.*' -and
            $_.IPAddress -notlike '169.254.*' -and
            $_.PrefixOrigin -ne 'WellKnown'
        } |
        ForEach-Object {
            $iface = Get-NetIPInterface -InterfaceIndex $_.InterfaceIndex -AddressFamily IPv4
            [pscustomobject]@{ IP = $_.IPAddress; Metric = $iface.InterfaceMetric }
        } |
        Sort-Object Metric |
        Select-Object -First 1

    if (-not $candidate) {
        Write-Error 'No encontré una IP de red local. Pasa la tuya: -HostIp 192.168.x.x'
        exit 1
    }
    $HostIp = $candidate.IP
}

$base = "http://${HostIp}:${Port}"
Write-Host "Backend para el celular: $base" -ForegroundColor Cyan
Write-Host '(si la app no carga rutas, revisa que el firewall de Windows deje entrar ese puerto)'

flutter run `
    --dart-define=API_BASE_URL=$base `
    --dart-define=REALTIME_URL=$base
