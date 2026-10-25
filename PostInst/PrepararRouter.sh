#!/bin/bash

# Pongo a disposición pública este script bajo el término de "software de dominio público".
# Puedes hacer lo que quieras con él porque es libre de verdad; no libre con condiciones como las licencias GNU y otras patrañas similares.
# Si se te llena la boca hablando de libertad entonces hazlo realmente libre.
# No tienes que aceptar ningún tipo de términos de uso o licencia para utilizarlo o modificarlo porque va sin CopyLeft.

# ----------
# Script de NiPeGun para instalar y configurar un router/cortafuegos sobre Debian.
# Unifica perfiles Ethernet, WiFi, puentes, VLANs, PPPoE, DHCP, DNS y VPN.
# Segmentación predeterminada: intdmz, intlan, intiot, intgst e intlanvpn.
# Política: aislar redes internas entre sí; salida a WAN y VPN a su propia zona.
#
# Ejecución remota:
#  curl -sL https://raw.githubusercontent.com/nipegun/debian-router-firewall-scripts/refs/heads/main/PostInst/PrepararRouter.sh | bash
#
# Debian 11: IPTables + ISC DHCP Server.
# Debian 12: NFTables + ISC DHCP Server.
# Debian 13: NFTables + Kea DHCP.
#
# Ejecución local (recomendada, con acceso a consola):
#   bash RouterFirewall-InstalacionNuevaES-Segmentado.sh
#
# Comprobar los archivos ya instalados, sin modificar el equipo:
#   bash RouterFirewall-InstalacionNuevaES-Segmentado.sh --solo-validar
#
# IMPORTANTE: dirigido a instalaciones nuevas o equipos cuya configuración
# se pueda reemplazar. Los cambios de red se escriben, pero no se aplican
# en caliente. Revisar los archivos antes de reiniciar el ordenador.
# ----------

# Definir constantes de color
  cColorAzul='\033[0;34m'
  cColorAzulClaro='\033[1;34m'
  cColorVerde='\033[1;32m'
  cColorRojo='\033[1;31m'
  cFinColor='\033[0m'

# Definir variables
  vFecha=$(date +%Y%m%d-%H%M%S)
  vDirCopias="/var/backups/RouterFirewall-$vFecha"
  vDirConfiguracion="/etc"
  vModoEquipo="router"
  vModoWAN="dhcp"
  vModoLAN="segmentado"
  vIntWAN="intwan"
  vWANDispositivo="intwan"
  vRenombrarWAN="no"
  vIntLAN="eth1"
  vIntWLAN="wlan0"
  vIntLANServicio="intlan"
  vPuertosLAN="eth1"
  vWANReal="eth0"
  vPerfilOperador="generico"
  vVLANWAN=""
  vVLANVoz=""
  vVLANTV=""
  vModoTV="manual"
  vUsuarioPPP=""
  vClavePPP=""
  vProveedorPPP="RouterWAN"
  vIPWAN=""
  vGatewayWAN=""
  vIPLAN="192.168.1.1"
  vRedLAN="192.168.1.0/24"
  vTresOctetosLAN="192.168.1"
  vInicioDHCP="192.168.1.100"
  vFinDHCP="192.168.1.199"
  vDominioLAN="home.arpa"
  vDNSExterno1="9.9.9.9"
  vDNSExterno2="149.112.112.112"
  vDNSClientes=""
  vDHCPReservas=""
  vModoIPAP="dhcp"
  vGatewayAP=""
  vModoWiFi="wpa2"
  vSSID="RouterDebian"
  vClaveWiFi=""
  vBandaWiFi="2.4"
  vCanalWiFi="1"
  vPaisWiFi="ES"
  vModoRadioWiFi="n"
  vHabilitarWPS="no"
  vFirmwareWiFi=""
  vPuertoHAProxy="443"
  vIPBackendHAProxy=""
  vPuertoBackendHAProxy="443"
  vPuertoWireGuard="51820"
  vIPWireGuard="192.168.101.1"
  vRedWireGuard="192.168.101.0/24"
  vPublicoWireGuard=""
  vClienteWireGuard=""
  vIPClienteWireGuard="192.168.101.2"
  vPuertoSSH="22"
  vNombreWireGuard="intlanvpn"
  vDestinoWireGuard="lan"
  vIntDestinoVPN="intlan"
  vRedDestinoVPN="192.168.1.0/24"
  vPuenteWiFi="intlan"
  vIPSSHRemota=""
  vRedirecciones=""
  vConfigRed="no"
  vConfigFirewall="no"
  vConfigDHCP="no"
  vConfigDNS="no"
  vConfigWiFi="no"
  vConfigHAProxy="no"
  vConfigWireGuard="no"
  vConfigFirmware="no"
  vBackendFirewall=""
  vBackendDHCP=""
  vEsPrimeraInstalacion="si"
  vCambiosRealizados="no"
  vSeleccion=""
  vErrorEnCurso="no"
  aArchivosModificados=()
  aReglasRedireccion=()
  aReservasDHCP=()
  aSegmentos=("dmz" "lan" "iot" "gst")
  declare -A dNombreInterfaz=( [dmz]="intdmz" [lan]="intlan" [iot]="intiot" [gst]="intgst" )
  declare -A dIPSegmento=( [dmz]="192.168.0.1" [lan]="192.168.1.1" [iot]="192.168.2.1" [gst]="192.168.3.1" )
  declare -A dRedSegmento=( [dmz]="192.168.0.0/24" [lan]="192.168.1.0/24" [iot]="192.168.2.0/24" [gst]="192.168.3.0/24" )
  declare -A dPuertosSegmento=( [dmz]="" [lan]="eth1" [iot]="" [gst]="" )
  declare -A dInicioDHCP=( [dmz]="192.168.0.100" [lan]="192.168.1.100" [iot]="192.168.2.100" [gst]="192.168.3.100" )
  declare -A dFinDHCP=( [dmz]="192.168.0.199" [lan]="192.168.1.199" [iot]="192.168.2.199" [gst]="192.168.3.199" )
  declare -A dArchivosCopiados=()

# Determinar la versión de Debian
  if [ -f /etc/os-release ]; then             # Para systemd y freedesktop.org.
    . /etc/os-release
    cNomSO=$NAME
    cVerSO=$VERSION_ID
    vIDSO=$ID
  elif type lsb_release >/dev/null 2>&1; then # Para linuxbase.org.
    cNomSO=$(lsb_release -si)
    cVerSO=$(lsb_release -sr)
    vIDSO=$(echo "$cNomSO" | tr '[:upper:]' '[:lower:]')
  elif [ -f /etc/debian_version ]; then
    cNomSO=Debian
    cVerSO=$(cat /etc/debian_version | cut -d. -f1)
    vIDSO=debian
  else
    cNomSO=$(uname -s)
    cVerSO=$(uname -r)
    vIDSO=desconocido
  fi

# ----------
# Funciones comunes a Debian 11, 12 y 13.
# ----------

fMostrarError() {
  local pMensaje="$1"
  echo ""
  echo -e "${cColorRojo}  ERROR: $pMensaje${cFinColor}" >&2
  echo ""
}

fMostrarInformacion() {
  local pMensaje="$1"
  echo ""
  echo -e "${cColorAzulClaro}  $pMensaje${cFinColor}"
  echo ""
}

fMostrarCorrecto() {
  local pMensaje="$1"
  echo -e "${cColorVerde}  $pMensaje${cFinColor}"
}

fPedirValor() {
  local pTitulo="$1"
  local pValorInicial="$2"
  dialog --stdout --clear --backtitle "Router/Firewall Debian" --inputbox "$pTitulo" 11 80 "$pValorInicial"
}

fPedirClave() {
  local pTitulo="$1"
  dialog --stdout --clear --backtitle "Router/Firewall Debian" --passwordbox "$pTitulo" 11 80
}

fConfirmar() {
  local pTitulo="$1"
  dialog --stdout --clear --backtitle "Router/Firewall Debian" --yesno "$pTitulo" 13 85
}

fEstaSeleccionada() {
  local pOpcion="$1"
  echo "$vSeleccion" | grep -Fxq "$pOpcion"
}

fValidarIPv4() {
  local pIP="$1"
  local vOcteto
  local aOctetos=()
  [[ "$pIP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] || return 1
  IFS=. read -r -a aOctetos <<< "$pIP"
  for vOcteto in "${aOctetos[@]}"; do
    (( 10#$vOcteto <= 255 )) || return 1
  done
  return 0
}

fValidarInterfaz() {
  local pInterfaz="$1"
  [[ "$pInterfaz" =~ ^[a-zA-Z0-9_.-]{1,15}$ ]] || return 1
  [ -d "/sys/class/net/$pInterfaz" ] || return 1
}

fValidarPuerto() {
  local pPuerto="$1"
  [[ "$pPuerto" =~ ^[0-9]{1,5}$ ]] || return 1
  (( 10#$pPuerto >= 1 && 10#$pPuerto <= 65535 ))
}

fValidarDominio() {
  local pDominio="$1"
  [[ "$pDominio" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$ ]] || return 1
  [[ "$pDominio" == *.* ]] || return 1
}

fValidarIPLAN() {
  if ! fValidarIPv4 "$vIPLAN"; then
    fMostrarError "Dirección IPv4 LAN incorrecta: $vIPLAN"
    exit 1
  fi
  vTresOctetosLAN="${vIPLAN%.*}"
  vRedLAN="$vTresOctetosLAN.0/24"
  if [ "${vIPLAN##*.}" = "0" ] || [ "${vIPLAN##*.}" = "255" ]; then
    fMostrarError "La puerta de enlace de una LAN /24 no puede terminar en .0 o .255."
    exit 1
  fi
  vInicioDHCP="$vTresOctetosLAN.100"
  vFinDHCP="$vTresOctetosLAN.199"
}

fComprobarRequisitos() {
  if [ "$(id -u)" -ne 0 ]; then
    fMostrarError "Este script debe ejecutarse con privilegios de administrador."
    exit 1
  fi
  if [ "$vIDSO" != "debian" ]; then
    fMostrarError "Sólo está preparado para Debian. Sistema detectado: $cNomSO"
    exit 1
  fi
  if [ ! -d /etc/network ]; then
    fMostrarError "No se encontró /etc/network. Es necesario configurar ifupdown."
    exit 1
  fi
  if ! command -v ip >/dev/null 2>&1; then
    fMostrarError "No se encontró iproute2."
    exit 1
  fi
}

fInstalarPaquetes() {
  fMostrarInformacion "Instalando los paquetes requeridos: $*"
  DEBIAN_FRONTEND=noninteractive apt-get -y install "$@"
}

fGuardarCopia() {
  local pArchivo="$1"
  if [ "${dArchivosCopiados[$pArchivo]+existe}" = "existe" ]; then
    return 0
  fi
  dArchivosCopiados["$pArchivo"]="si"
  aArchivosModificados+=("$pArchivo")
  if [ -e "$pArchivo" ] || [ -L "$pArchivo" ]; then
    cp -a --parents -- "$pArchivo" "$vDirCopias"
  else
    echo "$pArchivo" >> "$vDirCopias/archivos-nuevos.txt"
  fi
}

fRestaurarCopias() {
  local vArchivo
  echo "Restaurando las configuraciones que se hayan modificado..."
  for vArchivo in "${aArchivosModificados[@]}"; do
    if [ -e "$vDirCopias$vArchivo" ] || [ -L "$vDirCopias$vArchivo" ]; then
      mkdir -p "$(dirname "$vArchivo")"
      cp -a -- "$vDirCopias$vArchivo" "$vArchivo"
    else
      rm -f -- "$vArchivo"
    fi
  done
}

fGestionarError() {
  local vCodigoError=$?
  if [ "$vErrorEnCurso" = "si" ]; then
    exit "$vCodigoError"
  fi
  vErrorEnCurso="si"
  trap - ERR
  fMostrarError "La operación terminó con código $vCodigoError."
  if [ "$vCambiosRealizados" = "si" ]; then
    fRestaurarCopias
    echo "Los servicios instalados con APT no se desinstalan durante el rollback."
  fi
  exit "$vCodigoError"
}

fComprobarArchivos() {
  fMostrarInformacion "Comprobando configuraciones existentes sin efectuar cambios..."
  if command -v named-checkconf >/dev/null 2>&1; then
    named-checkconf -z && fMostrarCorrecto "BIND9: configuración correcta."
  fi
  if command -v dhcpd >/dev/null 2>&1 && [ -f /etc/dhcp/dhcpd.conf ]; then
    dhcpd -t -cf /etc/dhcp/dhcpd.conf && fMostrarCorrecto "ISC DHCP: configuración correcta."
  fi
  if command -v kea-dhcp4 >/dev/null 2>&1 && [ -f /etc/kea/kea-dhcp4.conf ]; then
    kea-dhcp4 -t /etc/kea/kea-dhcp4.conf && fMostrarCorrecto "Kea DHCP: configuración correcta."
  fi
  if command -v nft >/dev/null 2>&1 && [ -f /etc/nftables.conf ]; then
    nft -c -f /etc/nftables.conf && fMostrarCorrecto "nftables: configuración correcta."
  fi
  if command -v iptables-restore >/dev/null 2>&1 && [ -f /etc/iptables/rules.v4 ]; then
    iptables-restore --test < /etc/iptables/rules.v4 && fMostrarCorrecto "iptables: configuración correcta."
  fi
  if command -v haproxy >/dev/null 2>&1 && [ -f /etc/haproxy/haproxy.cfg ]; then
    haproxy -c -f /etc/haproxy/haproxy.cfg && fMostrarCorrecto "HAProxy: configuración correcta."
  fi
  if command -v wg-quick >/dev/null 2>&1 && [ -d /etc/wireguard ]; then
    local vArchivoVPN
    for vArchivoVPN in /etc/wireguard/*.conf; do
      if [ -f "$vArchivoVPN" ]; then
        wg-quick strip "$vArchivoVPN" >/dev/null && fMostrarCorrecto "WireGuard: $vArchivoVPN correcto."
      fi
    done
  fi
}

# ----------
# Preguntar por las funcionalidades que vamos a instalar.
# ----------

fSeleccionarFuncionalidades() {
  fMostrarInformacion "Interfaces detectadas:"
  ip -br link show

  vModoEquipo=$(dialog --stdout --clear --backtitle "Router/Firewall Debian" \
    --radiolist "Selecciona el tipo de instalación:" 15 90 4 \
    "router" "Enrutador con WAN y cuatro zonas segmentadas por defecto" on \
    "ap" "Punto de acceso Wi-Fi en un puente con la red existente" off) || exit 0

  if [ "$vModoEquipo" = "router" ]; then
    vSeleccion=$(dialog --stdout --separate-output --clear --backtitle "Router/Firewall Debian" \
      --checklist "Selecciona las funcionalidades a instalar:" 23 100 13 \
      1 "Configurar interfaces de red y perfiles WAN" on \
      2 "Activar forwarding, filtrado y NAT" on \
      3 "Instalar y configurar servidor DHCP IPv4" on \
      4 "Instalar y configurar DNS BIND9" on \
      5 "Crear punto de acceso Wi-Fi con hostapd" off \
      6 "Instalar y configurar HAProxy (TCP passthrough)" off \
      7 "Instalar y configurar servidor VPN WireGuard" off \
      8 "Firmware no disponible en este perfil 100% de código abierto" off \
      9 "Crear redirecciones de puertos WAN hacia la DMZ" off) || exit 0
    if ! fEstaSeleccionada 1 || ! fEstaSeleccionada 2; then
      fMostrarError "Por seguridad, un router necesita configurar red y reglas de cortafuegos."
      exit 1
    fi
    fEstaSeleccionada 2 && vConfigFirewall="si"
    fEstaSeleccionada 3 && vConfigDHCP="si"
    fEstaSeleccionada 4 && vConfigDNS="si"
    fEstaSeleccionada 5 && vConfigWiFi="si"
    fEstaSeleccionada 6 && vConfigHAProxy="si"
    fEstaSeleccionada 7 && vConfigWireGuard="si"
    if fEstaSeleccionada 8; then
      fMostrarError "El instalador no instalará firmware sin verificar que sea open source."
      exit 1
    fi
  else
    vConfigWiFi="si"
    vSeleccion=$(dialog --stdout --separate-output --clear --backtitle "Router/Firewall Debian" \
      --checklist "Punto de acceso en puente L2 (sin NAT ni servidor DHCP propio):" 18 100 7 \
      4 "Instalar DNS BIND9" off \
      5 "Configurar el punto de acceso hostapd" on \
      6 "Instalar HAProxy" off \
      7 "Instalar servidor VPN WireGuard" off \
      8 "Firmware adicional (requiere verificación de licencia)" off) || exit 0
    fEstaSeleccionada 4 && vConfigDNS="si"
    fEstaSeleccionada 6 && vConfigHAProxy="si"
    fEstaSeleccionada 7 && vConfigWireGuard="si"
    if fEstaSeleccionada 8; then
      fMostrarError "La instalación de firmware está deshabilitada hasta verificar licencias abiertas."
      exit 1
    fi
    if ! fEstaSeleccionada 5; then
      fMostrarError "El modo punto de acceso requiere configurar hostapd."
      exit 1
    fi
  fi
  vConfigRed="si"
}

# ----------
# Segmentos de red. Los nombres corresponden a puentes Linux con IPv4 /24.
# Los puertos físicos y VLANs se conectan a cada puente por separado.
# ----------

fValidarPuertosSegmentados() {
  local vSegmento
  local vPuertoSegmento
  local vBaseSegmento
  local vIDVLAN
  local -A dPuertosUsados=()
  local -A dBasesEtiquetadas=()
  local -A dBasesSinEtiqueta=()
  for vSegmento in "${aSegmentos[@]}"; do
    for vPuertoSegmento in ${dPuertosSegmento[$vSegmento]}; do
      if [ "${dPuertosUsados[$vPuertoSegmento]+existe}" = "existe" ]; then
        fMostrarError "El puerto $vPuertoSegmento está asignado a más de una zona."
        return 1
      fi
      dPuertosUsados["$vPuertoSegmento"]="si"
      vBaseSegmento="${vPuertoSegmento%%.*}"
      if ! fValidarInterfaz "$vBaseSegmento" || [ "$vBaseSegmento" = "$vIntWAN" ] || [ "$vBaseSegmento" = "$vWANDispositivo" ]; then
        fMostrarError "Puerto $vPuertoSegmento no existente o coincide con la WAN $vIntWAN."
        return 1
      fi
      if [[ "$vPuertoSegmento" == *.* ]]; then
        vIDVLAN="${vPuertoSegmento##*.}"
        if [ "${vPuertoSegmento}" != "$vBaseSegmento.$vIDVLAN" ] || [[ ! "$vIDVLAN" =~ ^[0-9]{1,4}$ ]] || (( 10#$vIDVLAN < 1 || 10#$vIDVLAN > 4094 )); then
          fMostrarError "VLAN incorrecta: $vPuertoSegmento. Usa el formato ethX.123."
          return 1
        fi
        if [ "${#vPuertoSegmento}" -gt 15 ]; then
          fMostrarError "La interfaz VLAN $vPuertoSegmento supera 15 caracteres."
          return 1
        fi
        dBasesEtiquetadas["$vBaseSegmento"]="si"
      else
        dBasesSinEtiqueta["$vBaseSegmento"]="si"
      fi
    done
  done
  for vBaseSegmento in "${!dBasesSinEtiqueta[@]}"; do
    if [ "${dBasesEtiquetadas[$vBaseSegmento]+existe}" = "existe" ]; then
      fMostrarError "No se puede asignar $vBaseSegmento sin etiqueta y también sus VLAN a distintos puentes."
      return 1
    fi
  done
  return 0
}

fConfigurarSegmentacion() {
  local vSegmento
  local vIP
  local vPrefijo
  local -A dRedesUtilizadas=()

  fMostrarInformacion "Creando por defecto DMZ, LAN, IoT e invitados con puerta de enlace .1."
  if fConfirmar "¿Personalizar las direcciones IPv4 de las cuatro zonas? Por defecto: DMZ .0, LAN .1, IoT .2 e invitados .3 (todas /24)."; then
    for vSegmento in "${aSegmentos[@]}"; do
      vIP=$(fPedirValor "IP de ${dNombreInterfaz[$vSegmento]} (debe terminar en .1):" "${dIPSegmento[$vSegmento]}") || exit 0
      dIPSegmento["$vSegmento"]="$vIP"
    done
  fi

  for vSegmento in "${aSegmentos[@]}"; do
    vIP="${dIPSegmento[$vSegmento]}"
    if ! fValidarIPv4 "$vIP" || [ "${vIP##*.}" != "1" ]; then
      fMostrarError "La IP de ${dNombreInterfaz[$vSegmento]} debe ser IPv4 y terminar en .1: $vIP"
      return 1
    fi
    vPrefijo="${vIP%.*}"
    if [ "${dRedesUtilizadas[$vPrefijo]+existe}" = "existe" ]; then
      fMostrarError "Las redes de $vSegmento y ${dRedesUtilizadas[$vPrefijo]} son iguales ($vPrefijo.0/24)."
      return 1
    fi
    dRedesUtilizadas["$vPrefijo"]="$vSegmento"
    dRedSegmento["$vSegmento"]="$vPrefijo.0/24"
    dInicioDHCP["$vSegmento"]="$vPrefijo.100"
    dFinDHCP["$vSegmento"]="$vPrefijo.199"
  done

  vIPLAN="${dIPSegmento[lan]}"
  vRedLAN="${dRedSegmento[lan]}"
  vTresOctetosLAN="${vIPLAN%.*}"
  vInicioDHCP="${dInicioDHCP[lan]}"
  vFinDHCP="${dFinDHCP[lan]}"
  vIntLANServicio="intlan"

  echo ""
  echo "  Los puertos se indican separados por espacios. También admiten VLANs tipo enp2s0.20."
  echo "  Deja vacío un segmento sin puertos físicos; se creará igualmente su puente virtual."
  echo ""
  for vSegmento in "${aSegmentos[@]}"; do
    dPuertosSegmento["$vSegmento"]=$(fPedirValor "Puertos físicos/VLAN de ${dNombreInterfaz[$vSegmento]}, separados por espacios (vacío permitido):" "${dPuertosSegmento[$vSegmento]}") || exit 0
  done
  fValidarPuertosSegmentados || return 1
  return 0
}

fRecalcularVPN() {
  local vIPDestino="${dIPSegmento[$vDestinoWireGuard]}"
  local vOcteto1
  local vOcteto2
  local vOcteto3
  local vOctetoVPN

  IFS=. read -r vOcteto1 vOcteto2 vOcteto3 vOctetoResto <<< "$vIPDestino"
  vOctetoVPN=$((10#$vOcteto3 + 100))
  if [ "$vOctetoVPN" -gt 255 ]; then
    fMostrarError "La subred $vIPDestino no permite sumar 100 al tercer octeto para la VPN."
    return 1
  fi
  vNombreWireGuard="${dNombreInterfaz[$vDestinoWireGuard]}vpn"
  vIntDestinoVPN="${dNombreInterfaz[$vDestinoWireGuard]}"
  vRedDestinoVPN="${dRedSegmento[$vDestinoWireGuard]}"
  vIPWireGuard="$vOcteto1.$vOcteto2.$vOctetoVPN.1"
  vRedWireGuard="$vOcteto1.$vOcteto2.$vOctetoVPN.0/24"
  vIPClienteWireGuard="$vOcteto1.$vOcteto2.$vOctetoVPN.2"
  local vSegmento
  for vSegmento in "${aSegmentos[@]}"; do
    if [ "${dRedSegmento[$vSegmento]}" = "$vRedWireGuard" ]; then
      fMostrarError "La VPN $vRedWireGuard coincide con la red $vSegmento."
      return 1
    fi
  done
  return 0
}

fConfigurarParametrosRed() {
  if [ "$vModoEquipo" = "router" ]; then
    vIntWAN=$(fPedirValor "Nombre REAL de la interfaz WAN (p. ej. eth0 o enp1s0):" "$vIntWAN") || exit 0
    if ! fValidarInterfaz "$vIntWAN"; then
      fMostrarError "La interfaz WAN $vIntWAN no existe o su nombre no es válido."
      exit 1
    fi
    vWANDispositivo="$vIntWAN"
    if [ "$vIntWAN" != "intwan" ]; then
      if [ -d /sys/class/net/intwan ]; then
        fMostrarError "La interfaz intwan ya existe y no coincide con la interfaz WAN elegida."
        exit 1
      fi
      if fConfirmar "¿Renombrar de forma persistente $vIntWAN a intwan mediante /etc/systemd/network/10-intwan.link? El cambio se producirá al reiniciar."; then
        vRenombrarWAN="si"
        vIntWAN="intwan"
      fi
    fi
    vModoWAN=$(dialog --stdout --clear --backtitle "Router/Firewall Debian" \
      --radiolist "Elige el tipo de conexión WAN:" 20 95 8 \
      "dhcp" "IP dinámica por DHCP sobre Ethernet" on \
      "estatica" "IP WAN estática sobre Ethernet" off \
      "pppoe" "PPPoE sin VLAN" off \
      "movistar" "Movistar España: PPPoE VLAN 6 (más VLAN voz/IPTV opcionales)" off \
      "simyo" "Simyo España: PPPoE VLAN 832 (IPTV opcional)" off \
      "vodafone" "Vodafone España: PPPoE VLAN 100 (IPTV opcional)" off \
      "vlan-dhcp" "DHCP sobre una VLAN personalizada" off) || exit 0

    case "$vModoWAN" in
      dhcp)
        vWANReal="$vIntWAN"
      ;;
      estatica)
        vWANReal="$vIntWAN"
        vIPWAN=$(fPedirValor "Dirección WAN con prefijo, por ejemplo 198.51.100.2/24:" "") || exit 0
        vGatewayWAN=$(fPedirValor "Puerta de enlace WAN (IPv4):" "") || exit 0
        if ! fValidarIPv4 "${vIPWAN%/*}" || ! fValidarIPv4 "$vGatewayWAN" || [[ ! "$vIPWAN" =~ /([0-9]|[12][0-9]|3[012])$ ]]; then
          fMostrarError "Dirección o puerta de enlace WAN incorrecta."
          exit 1
        fi
      ;;
      pppoe)
        vWANReal="ppp0"
      ;;
      movistar)
        vPerfilOperador="movistar"
        vVLANWAN="6"
        vWANReal="ppp0"
        vUsuarioPPP="adslppp@telefonicanetpa"
      ;;
      simyo)
        vPerfilOperador="simyo"
        vVLANWAN="832"
        vWANReal="ppp0"
      ;;
      vodafone)
        vPerfilOperador="vodafone"
        vVLANWAN="100"
        vWANReal="ppp0"
      ;;
      vlan-dhcp)
        vVLANWAN=$(fPedirValor "Identificador de VLAN para el tráfico WAN (1 a 4094):" "100") || exit 0
        vWANReal="$vIntWAN.$vVLANWAN"
      ;;
    esac

    if [ -n "$vVLANWAN" ]; then
      if [ "${#vIntWAN}" -gt 10 ]; then
        fMostrarError "La interfaz WAN VLAN ($vIntWAN.$vVLANWAN) podría superar el límite Linux de 15 caracteres."
        exit 1
      fi
      if [[ ! "$vVLANWAN" =~ ^[0-9]{1,4}$ ]] || (( 10#$vVLANWAN < 1 || 10#$vVLANWAN > 4094 )); then
        fMostrarError "El ID de la VLAN WAN debe estar entre 1 y 4094."
        exit 1
      fi
    fi

    if [[ "$vModoWAN" = "pppoe" || "$vWANReal" = "ppp0" ]]; then
      vUsuarioPPP=$(fPedirValor "Usuario de autenticación PPPoE:" "$vUsuarioPPP") || exit 0
      vClavePPP=$(fPedirClave "Contraseña PPPoE (no aparecerá en pantalla):") || exit 0
      if [ -z "$vUsuarioPPP" ] || [ -z "$vClavePPP" ] || [[ "$vUsuarioPPP$vClavePPP" == *\"* ]] || [[ "$vUsuarioPPP$vClavePPP" == *\\* ]]; then
        fMostrarError "Credenciales PPPoE vacías o con caracteres no admitidos (comillas o barras invertidas)."
        exit 1
      fi
    fi

    if [[ "$vModoWAN" = "movistar" || "$vModoWAN" = "simyo" || "$vModoWAN" = "vodafone" ]]; then
      if fConfirmar "¿Quieres crear también las VLAN de voz/televisión del operador? Se crean las interfaces, pero no se configura el servicio IPTV/VoIP de extremo a extremo."; then
        case "$vModoWAN" in
          movistar)
            vVLANVoz="3"
            vVLANTV="2"
          ;;
          simyo)
            vVLANTV="838"
          ;;
          vodafone)
            vVLANTV="105"
          ;;
        esac
      fi
    fi

    vModoLAN=$(dialog --stdout --clear --backtitle "Router/Firewall Debian" \
      --radiolist "Elige la organización de las redes internas:" 19 100 6 \
      "segmentado" "DMZ, LAN, IoT e invitados en interfaces intdmz/intlan/intiot/intgst" on \
      "ethernet" "Una sola LAN por Ethernet (modo anterior)" off \
      "puente" "Una sola LAN en puente br0 (modo anterior)" off \
      "wifi" "Una sola LAN Wi-Fi (modo anterior)" off \
      "puente-wifi" "Una sola LAN en puente Ethernet + Wi-Fi (modo anterior)" off) || exit 0
    case "$vModoLAN" in
      segmentado)
        fConfigurarSegmentacion || exit 1
      ;;
      ethernet)
        vIntLAN=$(fPedirValor "Interfaz Ethernet LAN:" "$vIntLAN") || exit 0
        vIntLANServicio="$vIntLAN"
      ;;
      puente|puente-wifi)
        vPuertosLAN=$(fPedirValor "Interfaces Ethernet que formarán br0, separadas por espacios (p. ej. eth1 eth2 eth3 eth4):" "$vPuertosLAN") || exit 0
        vIntLANServicio="br0"
      ;;
      wifi)
        vConfigWiFi="si"
        vIntLANServicio="br0"
        vPuertosLAN=""
      ;;
    esac
    if [ "$vModoLAN" = "puente-wifi" ]; then
      vConfigWiFi="si"
    fi
    if [ "$vConfigWiFi" = "si" ] && [ "$vModoLAN" = "ethernet" ]; then
      fMostrarError "Para Wi-Fi con Ethernet LAN selecciona 'puente-wifi', o usa 'wifi' para LAN inalámbrica exclusiva."
      exit 1
    fi
  else
    vModoLAN="puente-wifi"
    vPuertosLAN=$(fPedirValor "Interfaces cableadas para br0 (p. ej. eth0 o eth0 eth1):" "eth0") || exit 0
    vIntLANServicio="br0"
    vModoIPAP=$(dialog --stdout --clear --backtitle "Router/Firewall Debian" \
      --radiolist "Dirección de gestión del puente br0:" 12 80 2 \
      "dhcp" "Recibir IP desde el DHCP de la red existente" on \
      "estatica" "Asignar una IP estática de gestión" off) || exit 0
  fi

  if [ "$vModoLAN" = "segmentado" ]; then
    fValidarPuertosSegmentados || exit 1
  elif [ "$vModoLAN" = "ethernet" ]; then
    if ! fValidarInterfaz "$vIntLAN" || [ "$vIntLAN" = "$vIntWAN" ]; then
      fMostrarError "La LAN Ethernet debe existir y ser distinta de la interfaz WAN."
      exit 1
    fi
  elif [ "$vModoLAN" != "wifi" ]; then
    local aPuertosLAN=()
    local vPuertoLAN
    if [ -z "$vPuertosLAN" ]; then
      fMostrarError "El puente necesita al menos un puerto Ethernet."
      exit 1
    fi
    read -r -a aPuertosLAN <<< "$vPuertosLAN"
    for vPuertoLAN in "${aPuertosLAN[@]}"; do
      if ! fValidarInterfaz "$vPuertoLAN" || { [ "$vModoEquipo" = "router" ] && [ "$vPuertoLAN" = "$vIntWAN" ]; }; then
        fMostrarError "El puerto LAN $vPuertoLAN no existe, no es válido o coincide con la WAN."
        exit 1
      fi
    done
  fi

  if [ "$vModoLAN" != "segmentado" ] && { [ "$vModoEquipo" = "router" ] || [ "$vModoIPAP" = "estatica" ]; }; then
    vIPLAN=$(fPedirValor "IP de la LAN/gestión (se utiliza una subred /24):" "$vIPLAN") || exit 0
    fValidarIPLAN
  fi
  if [ "$vModoEquipo" = "ap" ] && [ "$vModoIPAP" = "dhcp" ] && [ "$vConfigDNS" = "si" ]; then
    fMostrarError "Para servir DNS desde un AP necesitamos una IP de gestión estática."
    exit 1
  fi
  if [ "$vModoEquipo" = "ap" ] && [ "$vModoIPAP" = "estatica" ]; then
    vGatewayAP=$(fPedirValor "Puerta de enlace para la gestión del punto de acceso:" "${vIPLAN%.*}.254") || exit 0
    if ! fValidarIPv4 "$vGatewayAP"; then
      fMostrarError "Puerta de enlace del AP inválida."
      exit 1
    fi
  fi

  if [ "$vModoEquipo" = "router" ] && [ "$vConfigDHCP" = "si" ] && [ "$vModoLAN" = "segmentado" ]; then
    vDHCPReservas=$(fPedirValor "Reservas de cualquier zona: MAC=IP, separadas por comas (o vacío):" "") || exit 0
  fi

  if [ "$vModoEquipo" = "router" ] && [ "$vConfigDHCP" = "si" ] && [ "$vModoLAN" != "segmentado" ]; then
    vInicioDHCP=$(fPedirValor "Primera dirección IP del rango DHCP:" "$vInicioDHCP") || exit 0
    vFinDHCP=$(fPedirValor "Última dirección IP del rango DHCP:" "$vFinDHCP") || exit 0
    vDHCPReservas=$(fPedirValor "Reservas opcionales MAC=IP separadas por comas (o vacío):" "") || exit 0
    if ! fValidarIPv4 "$vInicioDHCP" || ! fValidarIPv4 "$vFinDHCP" || [[ "$vInicioDHCP$vFinDHCP" != "$vTresOctetosLAN".* ]]; then
      fMostrarError "El rango DHCP contiene direcciones incorrectas."
      exit 1
    fi
    if [ "${vInicioDHCP%.*}" != "$vTresOctetosLAN" ] || [ "${vFinDHCP%.*}" != "$vTresOctetosLAN" ] || (( 10#${vInicioDHCP##*.} > 10#${vFinDHCP##*.} )); then
      fMostrarError "El rango DHCP debe estar dentro de la LAN /24 y en orden ascendente."
      exit 1
    fi
    if (( 10#${vInicioDHCP##*.} < 1 || 10#${vFinDHCP##*.} > 254 )); then
      fMostrarError "El rango DHCP no puede incluir .0 o .255 en una LAN /24."
      exit 1
    fi
    if (( 10#${vIPLAN##*.} >= 10#${vInicioDHCP##*.} && 10#${vIPLAN##*.} <= 10#${vFinDHCP##*.} )); then
      fMostrarError "La IP del router no puede coincidir con los extremos del rango DHCP."
      exit 1
    fi
  fi

  if [ "$vConfigDNS" = "si" ] || [ "$vConfigDHCP" = "si" ]; then
    vDominioLAN=$(fPedirValor "Dominio DNS interno (recomendado home.arpa):" "$vDominioLAN") || exit 0
    if ! fValidarDominio "$vDominioLAN"; then
      fMostrarError "Nombre del dominio LAN no válido."
      exit 1
    fi
  fi
  if [ "$vConfigDHCP" = "si" ]; then
    if [ "$vConfigDNS" = "si" ]; then
      vDNSClientes="$vIPLAN"
    else
      vDNSClientes="$vDNSExterno1, $vDNSExterno2"
    fi
  fi
}

fConfigurarParametrosWiFi() {
  if [ "$vConfigWiFi" != "si" ]; then
    return 0
  fi
  vIntWLAN=$(fPedirValor "Interfaz inalámbrica con capacidad AP (p. ej. wlan0):" "$vIntWLAN") || exit 0
  if ! fValidarInterfaz "$vIntWLAN" || [ "$vIntWLAN" = "$vIntWAN" ] || [ "$vIntWLAN" = "$vWANDispositivo" ]; then
    fMostrarError "La interfaz inalámbrica no existe o coincide con la WAN."
    exit 1
  fi
  if [ "$vModoLAN" = "segmentado" ]; then
    vZonaWiFi=$(dialog --stdout --clear --backtitle "Router/Firewall Debian" \
      --radiolist "¿A qué zona conectar el SSID Wi-Fi?" 15 85 4 \
      "lan" "intlan: equipos de confianza" on \
      "iot" "intiot: dispositivos IoT" off \
      "gst" "intgst: invitados" off \
      "dmz" "intdmz: zona DMZ" off) || exit 0
    vPuenteWiFi="${dNombreInterfaz[$vZonaWiFi]}"
  else
    vPuenteWiFi="br0"
  fi
  vSSID=$(fPedirValor "SSID del punto de acceso Wi-Fi:" "$vSSID") || exit 0
  if [ -z "$vSSID" ] || [ "${#vSSID}" -gt 32 ] || [[ "$vSSID" == *$'\n'* ]]; then
    fMostrarError "El SSID debe tener entre 1 y 32 caracteres."
    exit 1
  fi
  vModoWiFi=$(dialog --stdout --clear --backtitle "Router/Firewall Debian" \
    --radiolist "Elige seguridad para el punto de acceso:" 14 95 3 \
    "wpa2" "WPA2-Personal con AES/CCMP (recomendado por compatibilidad)" on \
    "wpa3" "WPA3-Personal (requiere tarjeta y clientes compatibles)" off \
    "abierto" "Red abierta SIN cifrado (sólo uso deliberado)" off) || exit 0
  if [ "$vModoWiFi" != "abierto" ]; then
    vClaveWiFi=$(fPedirClave "Contraseña del punto de acceso (8 a 63 caracteres):") || exit 0
    if [ "${#vClaveWiFi}" -lt 8 ] || [ "${#vClaveWiFi}" -gt 63 ] || [[ "$vClaveWiFi" == *$'\n'* ]]; then
      fMostrarError "La contraseña Wi-Fi debe tener entre 8 y 63 caracteres, sin saltos de línea."
      exit 1
    fi
  fi
  vBandaWiFi=$(dialog --stdout --clear --backtitle "Router/Firewall Debian" \
    --radiolist "Frecuencia Wi-Fi (comprueba que el hardware admita modo AP):" 12 80 2 \
    "2.4" "2,4 GHz (canal 1 por defecto)" on \
    "5" "5 GHz (canal 36 por defecto)" off) || exit 0
  if [ "$vBandaWiFi" = "5" ]; then
    vCanalWiFi="36"
  else
    vCanalWiFi="1"
  fi
  vCanalWiFi=$(fPedirValor "Canal Wi-Fi (revisar iw list para canales soportados):" "$vCanalWiFi") || exit 0
  vPaisWiFi=$(fPedirValor "Código de país de dos letras:" "$vPaisWiFi") || exit 0
  if [[ ! "$vCanalWiFi" =~ ^[0-9]{1,3}$ ]] || [[ ! "$vPaisWiFi" =~ ^[A-Z]{2}$ ]]; then
    fMostrarError "Canal Wi-Fi o código de país inválidos."
    exit 1
  fi
  vModoRadioWiFi=$(dialog --stdout --clear --backtitle "Router/Firewall Debian" \
    --radiolist "Estándar de radio (según capacidad de la tarjeta Wi-Fi):" 14 94 3 \
    "legado" "Modo 802.11a/g (máxima compatibilidad, menor rendimiento)" off \
    "n" "Modo 802.11n (HT): apropiado para muchas Atheros" on \
    "ac" "Modo 802.11ac (VHT): sólo con tarjeta y driver compatibles en 5 GHz" off) || exit 0
  if [ "$vModoRadioWiFi" = "ac" ]; then
    if [ "$vBandaWiFi" != "5" ] || [[ ! " 36 40 44 48 " == *" $vCanalWiFi "* ]]; then
      fMostrarError "Para 802.11ac esta versión del script admite la banda de 5 GHz, canales 36/40/44/48."
      exit 1
    fi
  fi
  if [ "$vModoWiFi" = "wpa2" ] && fConfirmar "¿Habilitar WPS mediante botón (PBC)? Es menos seguro que desactivarlo, y no es necesario para WPA2."; then
    vHabilitarWPS="si"
  fi
}

fConfigurarParametrosOpcionales() {
  if [ "$vConfigFirmware" = "si" ]; then
    vFirmwareWiFi=$(dialog --stdout --clear --backtitle "Router/Firewall Debian" \
      --radiolist "Firmware adicional (los blobs pueden NO ser de código abierto):" 16 95 6 \
      "atheros" "Atheros: firmware-atheros y firmware-ath9k-htc" on \
      "intel" "Intel: firmware-iwlwifi" off \
      "realtek" "Realtek: firmware-realtek" off \
      "broadcom" "Broadcom: firmware-brcm80211" off \
      "ninguno" "No instalar blobs de firmware" off) || exit 0
  fi

  if [ "$vConfigHAProxy" = "si" ]; then
    vPuertoHAProxy=$(fPedirValor "Puerto TCP público de HAProxy (443, 8443, etc.):" "$vPuertoHAProxy") || exit 0
    if [ "$vModoLAN" = "segmentado" ]; then
      vIPBackendHAProxy=$(fPedirValor "IP backend HAProxy (DMZ recomendada):" "${dIPSegmento[dmz]%.*}.10") || exit 0
    else
      vIPBackendHAProxy=$(fPedirValor "IP del servidor backend de HAProxy:" "$vTresOctetosLAN.10") || exit 0
    fi
    vPuertoBackendHAProxy=$(fPedirValor "Puerto TCP del backend de HAProxy:" "$vPuertoBackendHAProxy") || exit 0
    if ! fValidarPuerto "$vPuertoHAProxy" || ! fValidarPuerto "$vPuertoBackendHAProxy" || ! fValidarIPv4 "$vIPBackendHAProxy"; then
      fMostrarError "Parámetros de HAProxy incorrectos."
      exit 1
    fi
  fi

  if [ "$vConfigWireGuard" = "si" ]; then
    if [ "$vModoLAN" = "segmentado" ]; then
      vDestinoWireGuard=$(dialog --stdout --clear --backtitle "Router/Firewall Debian" \
        --radiolist "Zona a la que dará acceso la VPN (tercer octeto +100):" 15 95 4 \
        "lan" "intlanvpn: VPN de acceso a LAN" on \
        "gst" "intgstvpn: VPN de invitados" off \
        "iot" "intiotvpn: VPN IoT" off \
        "dmz" "intdmzvpn: VPN DMZ" off) || exit 0
      fRecalcularVPN || exit 1
    else
      vIPWireGuard=$(fPedirValor "IP del servidor WireGuard (se usa subred /24):" "$vIPWireGuard") || exit 0
    fi
    vPuertoWireGuard=$(fPedirValor "Puerto UDP de WireGuard:" "$vPuertoWireGuard") || exit 0
    vPublicoWireGuard=$(fPedirValor "IP pública o FQDN para el endpoint de los clientes (opcional):" "") || exit 0
    if ! fValidarIPv4 "$vIPWireGuard" || ! fValidarPuerto "$vPuertoWireGuard"; then
      fMostrarError "Dirección o puerto de WireGuard incorrectos."
      exit 1
    fi
    if [ "$vModoLAN" != "segmentado" ]; then
      vRedWireGuard="${vIPWireGuard%.*}.0/24"
      vIPClienteWireGuard="${vIPWireGuard%.*}.2"
    fi
    if [ "$vRedWireGuard" = "$vRedLAN" ] || [ "${vIPWireGuard##*.}" = "0" ] || [ "${vIPWireGuard##*.}" = "255" ]; then
      fMostrarError "La subred WireGuard debe ser diferente de la LAN; la IP no puede terminar en .0 o .255."
      exit 1
    fi
    if [[ -n "$vPublicoWireGuard" && ! "$vPublicoWireGuard" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]]; then
      fMostrarError "El endpoint público de WireGuard no es una IP ni un FQDN válido."
      exit 1
    fi
    if fConfirmar "¿Generamos un primer cliente WireGuard con sus claves y archivo de configuración?"; then
      vClienteWireGuard=$(fPedirValor "Nombre del primer cliente (letras, números, guion y guion bajo):" "cliente1") || exit 0
      vIPClienteWireGuard=$(fPedirValor "IP del cliente WireGuard:" "${vIPWireGuard%.*}.2") || exit 0
      if [[ ! "$vClienteWireGuard" =~ ^[a-zA-Z0-9_-]{1,48}$ ]] || ! fValidarIPv4 "$vIPClienteWireGuard" || [ "${vIPClienteWireGuard%.*}" != "${vIPWireGuard%.*}" ] || [ "$vIPClienteWireGuard" = "$vIPWireGuard" ] || [ "${vIPClienteWireGuard##*.}" = "0" ] || [ "${vIPClienteWireGuard##*.}" = "255" ]; then
        fMostrarError "Nombre o dirección IPv4 del cliente incorrectos."
        exit 1
      fi
    fi
  fi

  if [ "$vModoEquipo" = "router" ] && fEstaSeleccionada 9; then
    vRedirecciones=$(fPedirValor "Redirecciones (PROTO:PUERTO_WAN:IP_DESTINO:PUERTO_LOCAL), separadas por comas. Ej.: tcp:8443:192.168.0.10:443" "") || exit 0
    if [ "$vConfigFirewall" != "si" ]; then
      fMostrarError "Las redirecciones NAT requieren la opción de cortafuegos y NAT."
      exit 1
    fi
  fi
  if [ "$vConfigFirewall" = "si" ]; then
    vIPSSHRemota=$(fPedirValor "Permitir SSH a este router desde una IPv4 WAN concreta (vacío = sólo LAN/VPN):" "") || exit 0
    if [ -n "$vIPSSHRemota" ] && ! fValidarIPv4 "$vIPSSHRemota"; then
      fMostrarError "IP de administración SSH remota incorrecta."
      exit 1
    fi
  fi
}

fValidarOpciones() {
  local vEntrada
  local vMAC
  local vIPReserva
  local vProtocolo
  local vPuertoExterno
  local vIPDestino
  local vPuertoInterno
  local vSegmento
  local vReservaValida
  local aEntrada=()
  local aPartes=()

  if [ -n "$vDHCPReservas" ]; then
    IFS=, read -r -a aEntrada <<< "$vDHCPReservas"
    for vEntrada in "${aEntrada[@]}"; do
      vMAC="${vEntrada%%=*}"
      vIPReserva="${vEntrada#*=}"
      if [[ ! "$vMAC" =~ ^([a-fA-F0-9]{2}:){5}[a-fA-F0-9]{2}$ ]] || ! fValidarIPv4 "$vIPReserva"; then
        fMostrarError "Reserva DHCP inválida: $vEntrada"
        exit 1
      fi
      if [ "${vIPReserva##*.}" = "0" ] || [ "${vIPReserva##*.}" = "255" ]; then
        fMostrarError "No se pueden reservar la dirección de red o la de difusión: $vIPReserva"
        exit 1
      fi
      if [ "$vModoLAN" = "segmentado" ]; then
        vReservaValida="no"
        for vSegmento in "${aSegmentos[@]}"; do
          if [ "${vIPReserva%.*}" = "${dIPSegmento[$vSegmento]%.*}" ] && [ "${vIPReserva##*.}" != "1" ]; then
            vReservaValida="si"
          fi
        done
        if [ "$vReservaValida" != "si" ]; then
          fMostrarError "La reserva $vIPReserva no pertenece a una zona interna o usa la IP del router."
          exit 1
        fi
      elif [ "${vIPReserva%.*}" != "$vTresOctetosLAN" ]; then
        fMostrarError "Reserva DHCP fuera de la LAN: $vEntrada"
        exit 1
      fi
      aReservasDHCP+=("$vMAC=$vIPReserva")
    done
  fi

  if [ -n "$vRedirecciones" ]; then
    IFS=, read -r -a aEntrada <<< "$vRedirecciones"
    for vEntrada in "${aEntrada[@]}"; do
      IFS=: read -r -a aPartes <<< "$vEntrada"
      if [ "${#aPartes[@]}" -ne 4 ]; then
        fMostrarError "Redirección NAT inválida: $vEntrada"
        exit 1
      fi
      vProtocolo="${aPartes[0]}"
      vPuertoExterno="${aPartes[1]}"
      vIPDestino="${aPartes[2]}"
      vPuertoInterno="${aPartes[3]}"
      if [[ "$vProtocolo" != "tcp" && "$vProtocolo" != "udp" ]] || ! fValidarPuerto "$vPuertoExterno" || ! fValidarIPv4 "$vIPDestino" || ! fValidarPuerto "$vPuertoInterno"; then
        fMostrarError "Redirección NAT inválida: $vEntrada"
        exit 1
      fi
      if [ "$vModoLAN" = "segmentado" ] && [ "${vIPDestino%.*}" != "${dIPSegmento[dmz]%.*}" ]; then
        fMostrarError "Por defecto, las publicaciones WAN sólo pueden dirigirse a la DMZ: $vEntrada"
        exit 1
      fi
      aReglasRedireccion+=("$vEntrada")
    done
  fi
}

fMostrarResumen() {
  local vResumen
  vResumen="Versión: Debian $cVerSO"$'\n'
  vResumen+="Equipo: $vModoEquipo"$'\n'
  vResumen+="WAN: $vIntWAN / modo $vModoWAN / salida $vWANReal"$'\n'
  if [ "$vRenombrarWAN" = "si" ]; then
    vResumen+="  Se renombrará $vWANDispositivo a intwan en el siguiente arranque"$'\n'
  fi
  vResumen+="Redes interiores: $vModoLAN"$'\n'
  if [ "$vModoLAN" = "segmentado" ]; then
    for vSegmento in "${aSegmentos[@]}"; do
      vResumen+="  ${dNombreInterfaz[$vSegmento]}: ${dIPSegmento[$vSegmento]}/24 | ${dPuertosSegmento[$vSegmento]}"$'\n'
    done
  else
    vResumen+="LAN: $vIntLANServicio / $vIPLAN/24"$'\n'
    vResumen+="Puertos LAN: $vPuertosLAN"$'\n'
  fi
  vResumen+="Firewall: $vBackendFirewall ($vConfigFirewall)"$'\n'
  vResumen+="DHCP: $vBackendDHCP ($vConfigDHCP)"$'\n'
  vResumen+="DNS: BIND9 ($vConfigDNS)"$'\n'
  vResumen+="Wi-Fi: hostapd ($vConfigWiFi) / SSID: $vSSID"$'\n'
  vResumen+="HAProxy: $vConfigHAProxy"$'\n'
  vResumen+="WireGuard: $vConfigWireGuard / $vNombreWireGuard / $vIPWireGuard"$'\n'
  vResumen+="Port-forwarding: ${#aReglasRedireccion[@]} reglas"$'\n'
  vResumen+=$'\n'"Las contraseñas no se mostrarán."$'\n'
  vResumen+=$'\n'"El script reemplazará ficheros de red y servicios seleccionados."$'\n'
  vResumen+="Los cambios de red y firewall NO se aplicarán en caliente."$'\n'
  vResumen+="Se recomienda consola local antes del primer reinicio."$'\n'
  dialog --clear --backtitle "Router/Firewall Debian" --yesno "$vResumen" 23 100
}

# ----------
# Configuración de las interfaces de red, VLANs, puentes y PPPoE.
# ----------

fInstalarBase() {
  fMostrarInformacion "Actualizando índice de paquetes..."
  apt-get -y update
  fInstalarPaquetes ifupdown iproute2 dialog
  if [ "$vModoLAN" = "puente" ] || [ "$vModoLAN" = "puente-wifi" ] || [ "$vModoLAN" = "wifi" ] || [ "$vModoLAN" = "segmentado" ]; then
    fInstalarPaquetes bridge-utils
  fi
  if [ -n "$vVLANWAN" ] || [ -n "$vVLANVoz" ] || [ -n "$vVLANTV" ] || [ "$vModoLAN" = "segmentado" ]; then
    fInstalarPaquetes vlan
  fi
  if [ "$vWANReal" = "ppp0" ]; then
    fInstalarPaquetes ppp pppoe
  fi
  if [ "$vModoEquipo" = "router" ]; then
    fInstalarPaquetes curl ca-certificates
  fi
}

fConfigurarInterfaces() {
  local vPuertoLAN
  local aPuertosLAN=()
  local vArchivo="/etc/network/interfaces"

  fMostrarInformacion "Preparando el fichero $vArchivo..."

  # Asignar el nombre persistente intwan a la NIC de WAN usando systemd .link.
  # La interfaz se renombrará durante el siguiente arranque; no se aplica en caliente.
  if [ "$vRenombrarWAN" = "si" ]; then
    local vArchivoWAN="/etc/systemd/network/10-intwan.link"
    local vMACWAN
    if [ ! -e "/sys/class/net/$vWANDispositivo/device" ]; then
      fMostrarError "$vWANDispositivo no parece ser una NIC física que podamos renombrar con seguridad."
      return 1
    fi
    vMACWAN=$(cat "/sys/class/net/$vWANDispositivo/address")
    if [[ ! "$vMACWAN" =~ ^([a-fA-F0-9]{2}:){5}[a-fA-F0-9]{2}$ ]]; then
      fMostrarError "No se puede obtener la MAC de la WAN ($vWANDispositivo)."
      return 1
    fi
    mkdir -p /etc/systemd/network
    fGuardarCopia "$vArchivoWAN"
    echo "[Match]"                     > "$vArchivoWAN"
    echo "MACAddress=$vMACWAN"         >> "$vArchivoWAN"
    echo ""                            >> "$vArchivoWAN"
    echo "[Link]"                      >> "$vArchivoWAN"
    echo "NamePolicy="                 >> "$vArchivoWAN"
    echo "Name=intwan"                >> "$vArchivoWAN"
  fi
  fGuardarCopia "$vArchivo"
  echo "# /etc/network/interfaces"                         >  "$vArchivo"
  echo "# Generado por RouterFirewall-InstalacionNuevaES-Segmentado.sh" >> "$vArchivo"
  echo ""                                                   >> "$vArchivo"
  echo "auto lo"                                            >> "$vArchivo"
  echo "iface lo inet loopback"                             >> "$vArchivo"
  echo ""                                                   >> "$vArchivo"
  echo "source /etc/network/interfaces.d/*"                 >> "$vArchivo"
  echo ""                                                   >> "$vArchivo"

  if [ "$vModoEquipo" = "router" ]; then
    if [ -n "$vVLANWAN" ]; then
      echo "auto $vIntWAN"                           >> "$vArchivo"
      echo "iface $vIntWAN inet manual"              >> "$vArchivo"
      echo ""                                         >> "$vArchivo"
      echo "auto $vIntWAN.$vVLANWAN"                 >> "$vArchivo"
      if [ "$vModoWAN" = "vlan-dhcp" ]; then
        echo "iface $vIntWAN.$vVLANWAN inet dhcp"     >> "$vArchivo"
      else
        echo "iface $vIntWAN.$vVLANWAN inet manual"   >> "$vArchivo"
      fi
      echo "  vlan-raw-device $vIntWAN"             >> "$vArchivo"
      echo ""                                         >> "$vArchivo"
    else
      echo "auto $vIntWAN"                           >> "$vArchivo"
      case "$vModoWAN" in
        dhcp)
          echo "iface $vIntWAN inet dhcp"            >> "$vArchivo"
        ;;
        estatica)
          echo "iface $vIntWAN inet static"         >> "$vArchivo"
          echo "  address $vIPWAN"                   >> "$vArchivo"
          echo "  gateway $vGatewayWAN"             >> "$vArchivo"
        ;;
        pppoe)
          echo "iface $vIntWAN inet manual"         >> "$vArchivo"
        ;;
      esac
      echo ""                                         >> "$vArchivo"
    fi

    if [ -n "$vVLANVoz" ]; then
      echo "# VLAN de voz (la provisión de VoIP requiere configuración adicional)" >> "$vArchivo"
      echo "auto $vIntWAN.$vVLANVoz"                                      >> "$vArchivo"
      echo "iface $vIntWAN.$vVLANVoz inet manual"                         >> "$vArchivo"
      echo "  vlan-raw-device $vIntWAN"                                   >> "$vArchivo"
      echo ""                                                             >> "$vArchivo"
    fi
    if [ -n "$vVLANTV" ]; then
      echo "# VLAN de IPTV (la provisión de IPTV requiere configuración adicional)" >> "$vArchivo"
      echo "auto $vIntWAN.$vVLANTV"                                       >> "$vArchivo"
      echo "iface $vIntWAN.$vVLANTV inet manual"                          >> "$vArchivo"
      echo "  vlan-raw-device $vIntWAN"                                   >> "$vArchivo"
      echo ""                                                             >> "$vArchivo"
    fi
    if [ "$vWANReal" = "ppp0" ]; then
      echo "auto RouterWAN"                        >> "$vArchivo"
      echo "iface RouterWAN inet ppp"              >> "$vArchivo"
      echo "  provider RouterWAN"                  >> "$vArchivo"
      echo ""                                       >> "$vArchivo"
    fi
  fi

  if [ "$vModoLAN" = "segmentado" ]; then
    # Declaramos cada NIC y VLAN una sola vez, aunque varias VLAN compartan trunk.
    local vSegmento
    local vPuertos
    local vPuerto
    local vBase
    local vIDVLAN
    local vNombre
    local -A dDeclarados=()

    for vSegmento in "${aSegmentos[@]}"; do
      vPuertos="${dPuertosSegmento[$vSegmento]}"
      vNombre="${dNombreInterfaz[$vSegmento]}"
      for vPuerto in $vPuertos; do
        vBase="${vPuerto%%.*}"
        if [ "${dDeclarados[$vBase]+existe}" != "existe" ]; then
          echo "auto $vBase"                        >> "$vArchivo"
          echo "iface $vBase inet manual"            >> "$vArchivo"
          echo ""                                     >> "$vArchivo"
          dDeclarados["$vBase"]="si"
        fi
        if [[ "$vPuerto" == *.* ]] && [ "${dDeclarados[$vPuerto]+existe}" != "existe" ]; then
          vIDVLAN="${vPuerto##*.}"
          echo "auto $vPuerto"                      >> "$vArchivo"
          echo "iface $vPuerto inet manual"          >> "$vArchivo"
          echo "  vlan-raw-device $vBase"            >> "$vArchivo"
          echo ""                                     >> "$vArchivo"
          dDeclarados["$vPuerto"]="si"
        fi
      done
    done

    for vSegmento in "${aSegmentos[@]}"; do
      vPuertos="${dPuertosSegmento[$vSegmento]}"
      vNombre="${dNombreInterfaz[$vSegmento]}"
      echo "# Zona de seguridad $vSegmento"           >> "$vArchivo"
      echo "auto $vNombre"                            >> "$vArchivo"
      echo "iface $vNombre inet static"               >> "$vArchivo"
      echo "  address ${dIPSegmento[$vSegmento]}/24" >> "$vArchivo"
      if [ -z "$vPuertos" ]; then
        echo "  bridge_ports none"                    >> "$vArchivo"
      else
        echo "  bridge_ports $vPuertos"               >> "$vArchivo"
      fi
      # STP si hay más de un puerto, para evitar bucles Ethernet accidentales.
      read -r -a aPuertosLAN <<< "$vPuertos"
      if [ "${#aPuertosLAN[@]}" -gt 1 ]; then
        echo "  bridge_stp on"                       >> "$vArchivo"
        echo "  bridge_fd 15"                        >> "$vArchivo"
      else
        echo "  bridge_stp off"                      >> "$vArchivo"
        echo "  bridge_fd 0"                         >> "$vArchivo"
      fi
      echo ""                                         >> "$vArchivo"
    done
    if [ "$vConfigWiFi" = "si" ]; then
      echo "allow-hotplug $vIntWLAN"                 >> "$vArchivo"
      echo "iface $vIntWLAN inet manual"             >> "$vArchivo"
      echo "# hostapd añadirá $vIntWLAN a $vPuenteWiFi" >> "$vArchivo"
      echo ""                                         >> "$vArchivo"
    fi
  elif [ "$vModoLAN" = "ethernet" ]; then
    echo "auto $vIntLAN"                           >> "$vArchivo"
    echo "iface $vIntLAN inet static"              >> "$vArchivo"
    echo "  address $vIPLAN/24"                    >> "$vArchivo"
    echo ""                                         >> "$vArchivo"
  else
    if [ -n "$vPuertosLAN" ]; then
      read -r -a aPuertosLAN <<< "$vPuertosLAN"
      for vPuertoLAN in "${aPuertosLAN[@]}"; do
        echo "auto $vPuertoLAN"                     >> "$vArchivo"
        echo "iface $vPuertoLAN inet manual"        >> "$vArchivo"
        echo ""                                     >> "$vArchivo"
      done
    fi
    if [ "$vConfigWiFi" = "si" ]; then
      echo "allow-hotplug $vIntWLAN"                 >> "$vArchivo"
      echo "iface $vIntWLAN inet manual"             >> "$vArchivo"
      echo ""                                        >> "$vArchivo"
    fi
    echo "auto br0"                                  >> "$vArchivo"
    if [ "$vModoEquipo" = "ap" ] && [ "$vModoIPAP" = "dhcp" ]; then
      echo "iface br0 inet dhcp"                    >> "$vArchivo"
    else
      echo "iface br0 inet static"                  >> "$vArchivo"
      echo "  address $vIPLAN/24"                   >> "$vArchivo"
      if [ "$vModoEquipo" = "ap" ] && [ -n "$vGatewayAP" ]; then
        echo "  gateway $vGatewayAP"               >> "$vArchivo"
      fi
    fi
    if [ -z "$vPuertosLAN" ]; then
      echo "  bridge_ports none"                     >> "$vArchivo"
    else
      echo "  bridge_ports $vPuertosLAN"             >> "$vArchivo"
    fi
    # Con varias interfaces Ethernet es más seguro activar STP para evitar bucles.
    if [ "${#aPuertosLAN[@]}" -gt 1 ]; then
      echo "  bridge_stp on"                          >> "$vArchivo"
      echo "  bridge_fd 15"                          >> "$vArchivo"
    else
      echo "  bridge_stp off"                         >> "$vArchivo"
      echo "  bridge_fd 0"                           >> "$vArchivo"
    fi
    echo "  # hostapd añade la interfaz inalámbrica si usamos bridge=br0" >> "$vArchivo"
    echo ""                                          >> "$vArchivo"
  fi

  # Cargar 8021q durante el arranque si se usa alguna VLAN.
  if [ -n "$vVLANWAN" ] || [ -n "$vVLANVoz" ] || [ -n "$vVLANTV" ] || [ "$vModoLAN" = "segmentado" ]; then
    fGuardarCopia "/etc/modules-load.d/routerfirewall.conf"
    echo "8021q" > /etc/modules-load.d/routerfirewall.conf
  fi

  # Habilitar el forwarding IPv4 de forma persistente en modo router.
  if [ "$vModoEquipo" = "router" ]; then
    fGuardarCopia "/etc/sysctl.d/90-routerfirewall.conf"
    echo "# Enrutamiento IPv4 mediante el kernel Linux" > /etc/sysctl.d/90-routerfirewall.conf
    echo "net.ipv4.ip_forward=1"                    >> /etc/sysctl.d/90-routerfirewall.conf
    echo "# La configuración IPv6 de este instalador no implementa enrutamiento IPv6" >> /etc/sysctl.d/90-routerfirewall.conf
    echo "net.ipv6.conf.all.forwarding=0"           >> /etc/sysctl.d/90-routerfirewall.conf
  fi

  if [ "$vWANReal" = "ppp0" ]; then
    fConfigurarPPPoE
  fi
  ifquery --list >/dev/null
  fMostrarCorrecto "Se generó $vArchivo (pendiente de aplicar al reiniciar)."
}

fConfigurarPPPoE() {
  local vArchivo="/etc/ppp/peers/RouterWAN"
  local vInterfazPPPoE="$vIntWAN"

  if [ -n "$vVLANWAN" ]; then
    vInterfazPPPoE="$vIntWAN.$vVLANWAN"
  fi
  mkdir -p /etc/ppp/peers
  fGuardarCopia "$vArchivo"
  echo "# Configuración PPPoE: $vPerfilOperador" > "$vArchivo"
  echo "noipdefault"                              >> "$vArchivo"
  echo "defaultroute"                             >> "$vArchivo"
  echo "replacedefaultroute"                      >> "$vArchivo"
  echo "hide-password"                            >> "$vArchivo"
  echo "noauth"                                   >> "$vArchivo"
  echo "persist"                                  >> "$vArchivo"
  echo "maxfail 0"                                >> "$vArchivo"
  echo "holdoff 5"                                >> "$vArchivo"
  echo "lcp-echo-interval 15"                     >> "$vArchivo"
  echo "lcp-echo-failure 3"                       >> "$vArchivo"
  echo "mtu 1492"                                 >> "$vArchivo"
  echo "mru 1492"                                 >> "$vArchivo"
  echo "plugin rp-pppoe.so"                       >> "$vArchivo"
  echo "nic-$vInterfazPPPoE"                      >> "$vArchivo"
  echo "user \"$vUsuarioPPP\""                >> "$vArchivo"
  chmod 600 "$vArchivo"

  # Sobrescribir sólo las credenciales propias de este instalador en instalaciones nuevas.
  # Los ficheros originales se incluyen en la copia de seguridad previa.
  local vArchivoPAP="/etc/ppp/pap-secrets"
  local vArchivoCHAP="/etc/ppp/chap-secrets"
  fGuardarCopia "$vArchivoPAP"
  fGuardarCopia "$vArchivoCHAP"
  echo "# Credenciales de RouterWAN"                  > "$vArchivoCHAP"
  echo "\"$vUsuarioPPP\" * \"$vClavePPP\""   >> "$vArchivoCHAP"
  echo "# Credenciales de RouterWAN"                  > "$vArchivoPAP"
  echo "\"$vUsuarioPPP\" * \"$vClavePPP\""   >> "$vArchivoPAP"
  chmod 600 "$vArchivoCHAP" "$vArchivoPAP"
}

# ----------
# Configuración de IPtables para Debian 11.
# ----------

fConfigurarIPTables() {
  local vArchivo="/etc/iptables/rules.v4"
  local vArchivoIPv6="/etc/iptables/rules.v6"
  local vEntrada
  local vProtocolo
  local vPuertoExterno
  local vIPDestino
  local vPuertoInterno
  local vSegmento
  local vIntDestino
  local vIntSegmento

  fMostrarInformacion "Generando filtrado, aislamiento entre zonas y NAT con iptables (Debian 11)..."
  fInstalarPaquetes iptables iptables-persistent
  mkdir -p /etc/iptables
  fGuardarCopia "$vArchivo"
  echo "# Reglas IPv4 de RouterFirewall-InstalacionNuevaES-Segmentado.sh" > "$vArchivo"
  echo "*filter"                                                >> "$vArchivo"
  echo ":INPUT DROP [0:0]"                                    >> "$vArchivo"
  echo ":FORWARD DROP [0:0]"                                  >> "$vArchivo"
  echo ":OUTPUT ACCEPT [0:0]"                                 >> "$vArchivo"
  echo "-A INPUT -i lo -j ACCEPT"                             >> "$vArchivo"
  echo "-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT" >> "$vArchivo"
  echo "-A INPUT -m conntrack --ctstate INVALID -j DROP"     >> "$vArchivo"
  echo "-A INPUT -i $vWANReal -p udp --sport 67 --dport 68 -j ACCEPT" >> "$vArchivo"

  if [ "$vModoLAN" = "segmentado" ]; then
    # Sólo LAN puede administrar el cortafuegos y consultar el DNS interno.
    echo "-A INPUT -i intlan -p tcp --dport $vPuertoSSH -j ACCEPT" >> "$vArchivo"
    if [ "$vConfigDNS" = "si" ]; then
      echo "-A INPUT -i intlan -p udp --dport 53 -j ACCEPT" >> "$vArchivo"
      echo "-A INPUT -i intlan -p tcp --dport 53 -j ACCEPT" >> "$vArchivo"
    fi
    if [ "$vConfigDHCP" = "si" ]; then
      for vSegmento in "${aSegmentos[@]}"; do
        vIntSegmento="${dNombreInterfaz[$vSegmento]}"
        echo "-A INPUT -i $vIntSegmento -p udp --sport 68 --dport 67 -j ACCEPT" >> "$vArchivo"
      done
    fi
    for vSegmento in "${aSegmentos[@]}"; do
      vIntSegmento="${dNombreInterfaz[$vSegmento]}"
      echo "-A INPUT -i $vIntSegmento -p icmp --icmp-type echo-request -j ACCEPT" >> "$vArchivo"
    done
  else
    echo "-A INPUT -i $vIntLANServicio -j ACCEPT"          >> "$vArchivo"
  fi

  if [ -n "$vIPSSHRemota" ]; then
    echo "-A INPUT -i $vWANReal -s $vIPSSHRemota/32 -p tcp --dport $vPuertoSSH -j ACCEPT" >> "$vArchivo"
  fi
  if [ "$vConfigWireGuard" = "si" ]; then
    echo "-A INPUT -i $vWANReal -p udp --dport $vPuertoWireGuard -j ACCEPT" >> "$vArchivo"
    if [ "$vModoLAN" = "segmentado" ]; then
      echo "-A INPUT -i $vNombreWireGuard -p icmp -j ACCEPT" >> "$vArchivo"
      if [ "$vDestinoWireGuard" = "lan" ]; then
        echo "-A INPUT -i $vNombreWireGuard -p tcp --dport $vPuertoSSH -j ACCEPT" >> "$vArchivo"
        if [ "$vConfigDNS" = "si" ]; then
          echo "-A INPUT -i $vNombreWireGuard -p udp --dport 53 -j ACCEPT" >> "$vArchivo"
          echo "-A INPUT -i $vNombreWireGuard -p tcp --dport 53 -j ACCEPT" >> "$vArchivo"
        fi
      fi
    else
      echo "-A INPUT -i $vNombreWireGuard -j ACCEPT"         >> "$vArchivo"
    fi
  fi
  if [ "$vConfigHAProxy" = "si" ]; then
    echo "-A INPUT -i $vWANReal -p tcp --dport $vPuertoHAProxy -j ACCEPT" >> "$vArchivo"
  fi
  echo "-A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT" >> "$vArchivo"
  echo "-A FORWARD -m conntrack --ctstate INVALID -j DROP" >> "$vArchivo"
  if [ "$vModoLAN" = "segmentado" ]; then
    # Todas las zonas pueden salir a Internet, pero entre zonas no existe
    # ninguna regla de permiso: FORWARD DROP es el bloqueo por defecto.
    for vSegmento in "${aSegmentos[@]}"; do
      vIntSegmento="${dNombreInterfaz[$vSegmento]}"
      echo "-A FORWARD -i $vIntSegmento -o $vWANReal -j ACCEPT" >> "$vArchivo"
    done
    if [ "$vConfigWireGuard" = "si" ]; then
      echo "-A FORWARD -i $vNombreWireGuard -o $vIntDestinoVPN -d $vRedDestinoVPN -j ACCEPT" >> "$vArchivo"
    fi
  else
    echo "-A FORWARD -i $vIntLANServicio -o $vWANReal -j ACCEPT" >> "$vArchivo"
    if [ "$vConfigWireGuard" = "si" ]; then
      echo "-A FORWARD -i $vNombreWireGuard -o $vIntLANServicio -j ACCEPT" >> "$vArchivo"
      echo "-A FORWARD -i $vIntLANServicio -o $vNombreWireGuard -j ACCEPT" >> "$vArchivo"
      echo "-A FORWARD -i $vNombreWireGuard -o $vWANReal -j ACCEPT" >> "$vArchivo"
    fi
  fi
  for vEntrada in "${aReglasRedireccion[@]}"; do
    IFS=: read -r vProtocolo vPuertoExterno vIPDestino vPuertoInterno <<< "$vEntrada"
    vIntDestino="$vIntLANServicio"
    if [ "$vModoLAN" = "segmentado" ]; then
      vIntDestino="intdmz"
    fi
    echo "-A FORWARD -i $vWANReal -o $vIntDestino -d $vIPDestino -p $vProtocolo --dport $vPuertoInterno -m conntrack --ctstate NEW -j ACCEPT" >> "$vArchivo"
  done
  echo "COMMIT"                                               >> "$vArchivo"
  echo ""                                                     >> "$vArchivo"
  echo "*nat"                                                 >> "$vArchivo"
  echo ":PREROUTING ACCEPT [0:0]"                             >> "$vArchivo"
  echo ":INPUT ACCEPT [0:0]"                                  >> "$vArchivo"
  echo ":OUTPUT ACCEPT [0:0]"                                 >> "$vArchivo"
  echo ":POSTROUTING ACCEPT [0:0]"                            >> "$vArchivo"
  if [ "$vModoLAN" = "segmentado" ]; then
    for vSegmento in "${aSegmentos[@]}"; do
      echo "-A POSTROUTING -s ${dRedSegmento[$vSegmento]} -o $vWANReal -j MASQUERADE" >> "$vArchivo"
    done
  else
    echo "-A POSTROUTING -s $vRedLAN -o $vWANReal -j MASQUERADE" >> "$vArchivo"
    if [ "$vConfigWireGuard" = "si" ]; then
      echo "-A POSTROUTING -s $vRedWireGuard -o $vWANReal -j MASQUERADE" >> "$vArchivo"
    fi
  fi
  for vEntrada in "${aReglasRedireccion[@]}"; do
    IFS=: read -r vProtocolo vPuertoExterno vIPDestino vPuertoInterno <<< "$vEntrada"
    echo "-A PREROUTING -i $vWANReal -p $vProtocolo --dport $vPuertoExterno -j DNAT --to-destination $vIPDestino:$vPuertoInterno" >> "$vArchivo"
  done
  echo "COMMIT"                                              >> "$vArchivo"

  fGuardarCopia "$vArchivoIPv6"
  echo "# Filtrado IPv6; IPv6 forwarding no se habilita" > "$vArchivoIPv6"
  echo "*filter"                                               >> "$vArchivoIPv6"
  echo ":INPUT DROP [0:0]"                                    >> "$vArchivoIPv6"
  echo ":FORWARD DROP [0:0]"                                  >> "$vArchivoIPv6"
  echo ":OUTPUT ACCEPT [0:0]"                                 >> "$vArchivoIPv6"
  echo "-A INPUT -i lo -j ACCEPT"                             >> "$vArchivoIPv6"
  echo "-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT" >> "$vArchivoIPv6"
  echo "-A INPUT -p ipv6-icmp -j ACCEPT"                      >> "$vArchivoIPv6"
  if [ "$vModoLAN" = "segmentado" ]; then
    echo "-A INPUT -i intlan -p tcp --dport $vPuertoSSH -j ACCEPT" >> "$vArchivoIPv6"
  else
    echo "-A INPUT -i $vIntLANServicio -j ACCEPT"          >> "$vArchivoIPv6"
  fi
  echo "COMMIT"                                              >> "$vArchivoIPv6"

  iptables-restore --test < "$vArchivo"
  ip6tables-restore --test < "$vArchivoIPv6"
  systemctl enable netfilter-persistent.service
  fMostrarCorrecto "iptables validado (sin aplicar reglas en caliente)."
}

# ----------
# Configuración de NFTables para Debian 12 y Debian 13.
# ----------

fConfigurarNFTables() {
  local vArchivo="/etc/nftables.conf"
  local vEntrada
  local vProtocolo
  local vPuertoExterno
  local vIPDestino
  local vPuertoInterno
  local vSegmento
  local vIntSegmento
  local vIntDestino

  fMostrarInformacion "Generando filtrado y NAT con nftables (Debian $cVerSO)..."
  fInstalarPaquetes nftables
  fGuardarCopia "$vArchivo"
  echo "#!/usr/sbin/nft -f"                                     > "$vArchivo"
  echo ""                                                      >> "$vArchivo"
  echo "flush ruleset"                                         >> "$vArchivo"
  echo ""                                                      >> "$vArchivo"
  echo "table inet filter {"                                   >> "$vArchivo"
  echo "  chain input {"                                       >> "$vArchivo"
  echo "    type filter hook input priority 0; policy drop;"  >> "$vArchivo"
  echo '    iifname "lo" accept'                              >> "$vArchivo"
  echo '    ct state established,related accept'               >> "$vArchivo"
  echo '    ct state invalid drop'                            >> "$vArchivo"
  echo '    meta l4proto ipv6-icmp accept'                     >> "$vArchivo"
  echo "    iifname \"$vWANReal\" udp sport 67 udp dport 68 accept" >> "$vArchivo"

  if [ "$vModoLAN" = "segmentado" ]; then
    echo "    iifname \"intlan\" tcp dport $vPuertoSSH accept" >> "$vArchivo"
    if [ "$vConfigDNS" = "si" ]; then
      echo '    iifname "intlan" udp dport 53 accept'          >> "$vArchivo"
      echo '    iifname "intlan" tcp dport 53 accept'          >> "$vArchivo"
    fi
    if [ "$vConfigDHCP" = "si" ]; then
      for vSegmento in "${aSegmentos[@]}"; do
        vIntSegmento="${dNombreInterfaz[$vSegmento]}"
        echo "    iifname \"$vIntSegmento\" udp sport 68 udp dport 67 accept" >> "$vArchivo"
      done
    fi
    for vSegmento in "${aSegmentos[@]}"; do
      vIntSegmento="${dNombreInterfaz[$vSegmento]}"
      echo "    iifname \"$vIntSegmento\" icmp type echo-request accept" >> "$vArchivo"
    done
  else
    echo "    iifname \"$vIntLANServicio\" accept"          >> "$vArchivo"
  fi

  if [ -n "$vIPSSHRemota" ]; then
    echo "    iifname \"$vWANReal\" ip saddr $vIPSSHRemota tcp dport $vPuertoSSH accept" >> "$vArchivo"
  fi
  if [ "$vConfigWireGuard" = "si" ]; then
    echo "    iifname \"$vWANReal\" udp dport $vPuertoWireGuard accept" >> "$vArchivo"
    if [ "$vModoLAN" = "segmentado" ]; then
      echo "    iifname \"$vNombreWireGuard\" icmp type echo-request accept" >> "$vArchivo"
      if [ "$vDestinoWireGuard" = "lan" ]; then
        echo "    iifname \"$vNombreWireGuard\" tcp dport $vPuertoSSH accept" >> "$vArchivo"
        if [ "$vConfigDNS" = "si" ]; then
          echo "    iifname \"$vNombreWireGuard\" udp dport 53 accept" >> "$vArchivo"
          echo "    iifname \"$vNombreWireGuard\" tcp dport 53 accept" >> "$vArchivo"
        fi
      fi
    else
      echo "    iifname \"$vNombreWireGuard\" accept"      >> "$vArchivo"
    fi
  fi
  if [ "$vConfigHAProxy" = "si" ]; then
    echo "    iifname \"$vWANReal\" tcp dport $vPuertoHAProxy accept" >> "$vArchivo"
  fi
  echo "  }"                                                   >> "$vArchivo"
  echo "  chain forward {"                                     >> "$vArchivo"
  echo '    type filter hook forward priority 0; policy drop;' >> "$vArchivo"
  echo '    ct state established,related accept'               >> "$vArchivo"
  echo '    ct state invalid drop'                            >> "$vArchivo"
  if [ "$vModoLAN" = "segmentado" ]; then
    # Las zonas no tienen acceso entre sí salvo permisos explícitos (VPN a su zona).
    for vSegmento in "${aSegmentos[@]}"; do
      vIntSegmento="${dNombreInterfaz[$vSegmento]}"
      echo "    iifname \"$vIntSegmento\" oifname \"$vWANReal\" accept" >> "$vArchivo"
    done
    if [ "$vConfigWireGuard" = "si" ]; then
      echo "    iifname \"$vNombreWireGuard\" oifname \"$vIntDestinoVPN\" ip daddr $vRedDestinoVPN accept" >> "$vArchivo"
    fi
  else
    echo "    iifname \"$vIntLANServicio\" oifname \"$vWANReal\" accept" >> "$vArchivo"
    if [ "$vConfigWireGuard" = "si" ]; then
      echo "    iifname \"$vNombreWireGuard\" oifname \"$vIntLANServicio\" accept" >> "$vArchivo"
      echo "    iifname \"$vIntLANServicio\" oifname \"$vNombreWireGuard\" accept" >> "$vArchivo"
      echo "    iifname \"$vNombreWireGuard\" oifname \"$vWANReal\" accept" >> "$vArchivo"
    fi
  fi
  for vEntrada in "${aReglasRedireccion[@]}"; do
    IFS=: read -r vProtocolo vPuertoExterno vIPDestino vPuertoInterno <<< "$vEntrada"
    vIntDestino="$vIntLANServicio"
    if [ "$vModoLAN" = "segmentado" ]; then
      vIntDestino="intdmz"
    fi
    echo "    iifname \"$vWANReal\" oifname \"$vIntDestino\" ip daddr $vIPDestino $vProtocolo dport $vPuertoInterno ct state new accept" >> "$vArchivo"
  done
  echo "  }"                                                   >> "$vArchivo"
  echo "  chain output {"                                      >> "$vArchivo"
  echo '    type filter hook output priority 0; policy accept;' >> "$vArchivo"
  echo "  }"                                                   >> "$vArchivo"
  echo "}"                                                     >> "$vArchivo"
  echo ""                                                      >> "$vArchivo"
  echo "table ip nat {"                                        >> "$vArchivo"
  echo "  chain prerouting {"                                 >> "$vArchivo"
  echo '    type nat hook prerouting priority dstnat; policy accept;' >> "$vArchivo"
  for vEntrada in "${aReglasRedireccion[@]}"; do
    IFS=: read -r vProtocolo vPuertoExterno vIPDestino vPuertoInterno <<< "$vEntrada"
    echo "    iifname \"$vWANReal\" $vProtocolo dport $vPuertoExterno dnat to $vIPDestino:$vPuertoInterno" >> "$vArchivo"
  done
  echo "  }"                                                   >> "$vArchivo"
  echo "  chain postrouting {"                                >> "$vArchivo"
  echo '    type nat hook postrouting priority srcnat; policy accept;' >> "$vArchivo"
  if [ "$vModoLAN" = "segmentado" ]; then
    for vSegmento in "${aSegmentos[@]}"; do
      echo "    oifname \"$vWANReal\" ip saddr ${dRedSegmento[$vSegmento]} masquerade" >> "$vArchivo"
    done
  else
    echo "    oifname \"$vWANReal\" ip saddr $vRedLAN masquerade" >> "$vArchivo"
    if [ "$vConfigWireGuard" = "si" ]; then
      echo "    oifname \"$vWANReal\" ip saddr $vRedWireGuard masquerade" >> "$vArchivo"
    fi
  fi
  echo "  }"                                                   >> "$vArchivo"
  echo "}"                                                     >> "$vArchivo"
  nft -c -f "$vArchivo"
  systemctl enable nftables.service
  fMostrarCorrecto "nftables validado (sin aplicar reglas en caliente)."
}

# ----------
# Servidor DHCP IPv4 con ISC DHCP Server (Debian 11 y Debian 12).
# ----------

fConfigurarISCDHCP() {
  local vArchivo="/etc/dhcp/dhcpd.conf"
  local vEntrada
  local vMAC
  local vIPReserva
  local vNumero=1
  local vSegmento
  local vDNS
  local vInterfaces=""

  fMostrarInformacion "Instalando y configurando ISC DHCP Server..."
  fInstalarPaquetes isc-dhcp-server
  if [ "$vModoLAN" = "segmentado" ]; then
    for vSegmento in "${aSegmentos[@]}"; do
      vInterfaces+="${dNombreInterfaz[$vSegmento]} "
    done
    vInterfaces="${vInterfaces% }"
  else
    vInterfaces="$vIntLANServicio"
  fi

  fGuardarCopia "/etc/default/isc-dhcp-server"
  echo "DHCPDv4_CONF=/etc/dhcp/dhcpd.conf" > /etc/default/isc-dhcp-server
  echo "INTERFACESv4=\"$vInterfaces\""      >> /etc/default/isc-dhcp-server
  echo 'INTERFACESv6=""'                     >> /etc/default/isc-dhcp-server

  fGuardarCopia "$vArchivo"
  echo "# Configuración DHCP por zonas"              > "$vArchivo"
  echo "authoritative;"                            >> "$vArchivo"
  echo "default-lease-time 600;"                   >> "$vArchivo"
  echo "max-lease-time 7200;"                      >> "$vArchivo"
  if [ "$vModoLAN" != "segmentado" ]; then
    echo "option domain-name \"$vDominioLAN\";" >> "$vArchivo"
  fi

  if [ "$vModoLAN" = "segmentado" ]; then
    for vSegmento in "${aSegmentos[@]}"; do
      vDNS="$vDNSExterno1, $vDNSExterno2"
      # LAN usa el BIND9 local. DMZ/IoT/invitados usan DNS externos
      # para no revelar por DNS el inventario de la LAN.
      if [ "$vSegmento" = "lan" ] && [ "$vConfigDNS" = "si" ]; then
        vDNS="${dIPSegmento[lan]}"
      fi
      echo ""                                                >> "$vArchivo"
      echo "# Segmento $vSegmento (${dNombreInterfaz[$vSegmento]})" >> "$vArchivo"
      echo "subnet ${dIPSegmento[$vSegmento]%.*}.0 netmask 255.255.255.0 {" >> "$vArchivo"
      echo "  range ${dInicioDHCP[$vSegmento]} ${dFinDHCP[$vSegmento]};" >> "$vArchivo"
      echo "  option routers ${dIPSegmento[$vSegmento]};" >> "$vArchivo"
      echo "  option domain-name-servers $vDNS;"        >> "$vArchivo"
      if [ "$vSegmento" = "lan" ]; then
        echo "  option domain-name \"$vDominioLAN\";" >> "$vArchivo"
      fi
      for vEntrada in "${aReservasDHCP[@]}"; do
        vMAC="${vEntrada%%=*}"
        vIPReserva="${vEntrada#*=}"
        if [ "${vIPReserva%.*}" = "${dIPSegmento[$vSegmento]%.*}" ]; then
          echo "  host Reserva$vNumero {"              >> "$vArchivo"
          echo "    hardware ethernet $vMAC;"         >> "$vArchivo"
          echo "    fixed-address $vIPReserva;"       >> "$vArchivo"
          echo "  }"                                   >> "$vArchivo"
          vNumero=$((vNumero+1))
        fi
      done
      echo "}"                                       >> "$vArchivo"
    done
  else
    echo "subnet $vTresOctetosLAN.0 netmask 255.255.255.0 {" >> "$vArchivo"
    echo "  range $vInicioDHCP $vFinDHCP;"        >> "$vArchivo"
    echo "  option routers $vIPLAN;"              >> "$vArchivo"
    echo "  option domain-name-servers $vDNSClientes;" >> "$vArchivo"
    for vEntrada in "${aReservasDHCP[@]}"; do
      vMAC="${vEntrada%%=*}"
      vIPReserva="${vEntrada#*=}"
      echo "  host Reserva$vNumero {"                >> "$vArchivo"
      echo "    hardware ethernet $vMAC;"           >> "$vArchivo"
      echo "    fixed-address $vIPReserva;"         >> "$vArchivo"
      echo "  }"                                     >> "$vArchivo"
      vNumero=$((vNumero+1))
    done
    echo "}"                                         >> "$vArchivo"
  fi
  dhcpd -t -cf "$vArchivo"
  systemctl enable isc-dhcp-server.service
  fMostrarCorrecto "ISC DHCP configurado en: $vInterfaces"
}

# ----------
# Servidor DHCP IPv4 con Kea (Debian 13).
# ----------

fConfigurarKeaDHCP() {
  local vArchivo="/etc/kea/kea-dhcp4.conf"
  local vEntrada
  local vMAC
  local vIPReserva
  local vSeparador
  local vSeparadorRed
  local vSegmento
  local vIP
  local vRed
  local vInicio
  local vFin
  local vDNS
  local vNumero=0
  local vNumeroReserva=0
  local vTotalReservas=0
  local aZonas=()

  fMostrarInformacion "Instalando y configurando Kea DHCP4..."
  fInstalarPaquetes kea-dhcp4-server
  mkdir -p /etc/kea
  fGuardarCopia "$vArchivo"

  if [ "$vModoLAN" = "segmentado" ]; then
    aZonas=("${aSegmentos[@]}")
  else
    aZonas=("lan")
  fi

  echo "{"                                                     > "$vArchivo"
  echo '  "Dhcp4": {'                                        >> "$vArchivo"
  echo '    "interfaces-config": {'                          >> "$vArchivo"
  echo -n '      "interfaces": ['                        >> "$vArchivo"
  for vSegmento in "${aZonas[@]}"; do
    if [ "$vNumero" -gt 0 ]; then
      echo -n ', '                                       >> "$vArchivo"
    fi
    if [ "$vModoLAN" = "segmentado" ]; then
      echo -n "\"${dNombreInterfaz[$vSegmento]}\""  >> "$vArchivo"
    else
      echo -n "\"$vIntLANServicio\""                 >> "$vArchivo"
    fi
    vNumero=$((vNumero+1))
  done
  echo ']'                                                >> "$vArchivo"
  echo '    },'                                           >> "$vArchivo"
  echo '    "lease-database": {'                         >> "$vArchivo"
  echo '      "type": "memfile",'                     >> "$vArchivo"
  echo '      "persist": true,'                          >> "$vArchivo"
  echo '      "name": "/var/lib/kea/kea-leases4.csv",' >> "$vArchivo"
  echo '      "lfc-interval": 3600'                    >> "$vArchivo"
  echo '    },'                                           >> "$vArchivo"
  echo '    "valid-lifetime": 7200,'                     >> "$vArchivo"
  echo '    "subnet4": ['                                >> "$vArchivo"

  vNumero=0
  for vSegmento in "${aZonas[@]}"; do
    vNumero=$((vNumero+1))
    vIP="$vIPLAN"
    vRed="$vRedLAN"
    vInicio="$vInicioDHCP"
    vFin="$vFinDHCP"
    vDNS="$vDNSClientes"
    if [ "$vModoLAN" = "segmentado" ]; then
      vIP="${dIPSegmento[$vSegmento]}"
      vRed="${dRedSegmento[$vSegmento]}"
      vInicio="${dInicioDHCP[$vSegmento]}"
      vFin="${dFinDHCP[$vSegmento]}"
      vDNS="$vDNSExterno1, $vDNSExterno2"
      if [ "$vSegmento" = "lan" ] && [ "$vConfigDNS" = "si" ]; then
        vDNS="${dIPSegmento[lan]}"
      fi
    fi

    echo '      {'                                               >> "$vArchivo"
    echo "        \"id\": $vNumero,"                     >> "$vArchivo"
    echo "        \"subnet\": \"$vRed\","            >> "$vArchivo"
    echo '        "pools": ['                                  >> "$vArchivo"
    echo "          { \"pool\": \"$vInicio - $vFin\" }" >> "$vArchivo"
    echo '        ],'                                          >> "$vArchivo"
    echo '        "option-data": ['                            >> "$vArchivo"
    echo "          { \"name\": \"routers\", \"data\": \"$vIP\" }," >> "$vArchivo"
    if [ "$vModoLAN" != "segmentado" ] || [ "$vSegmento" = "lan" ]; then
      echo "          { \"name\": \"domain-name-servers\", \"data\": \"$vDNS\" }," >> "$vArchivo"
      echo "          { \"name\": \"domain-name\", \"data\": \"$vDominioLAN\" }" >> "$vArchivo"
    else
      echo "          { \"name\": \"domain-name-servers\", \"data\": \"$vDNS\" }" >> "$vArchivo"
    fi
    echo '        ],'                                          >> "$vArchivo"
    echo '        "reservations": ['                         >> "$vArchivo"
    vTotalReservas=0
    for vEntrada in "${aReservasDHCP[@]}"; do
      vIPReserva="${vEntrada#*=}"
      if [ "${vIPReserva%.*}" = "${vIP%.*}" ]; then
        vTotalReservas=$((vTotalReservas+1))
      fi
    done
    vNumeroReserva=0
    for vEntrada in "${aReservasDHCP[@]}"; do
      vMAC="${vEntrada%%=*}"
      vIPReserva="${vEntrada#*=}"
      if [ "${vIPReserva%.*}" = "${vIP%.*}" ]; then
        vNumeroReserva=$((vNumeroReserva+1))
        vSeparador=","
        if [ "$vNumeroReserva" -eq "$vTotalReservas" ]; then
          vSeparador=""
        fi
        echo "          { \"hw-address\": \"$vMAC\", \"ip-address\": \"$vIPReserva\" }$vSeparador" >> "$vArchivo"
      fi
    done
    echo '        ]'                                           >> "$vArchivo"
    vSeparadorRed=","
    if [ "$vNumero" -eq "${#aZonas[@]}" ]; then
      vSeparadorRed=""
    fi
    echo "      }$vSeparadorRed"                           >> "$vArchivo"
  done
  echo '    ]'                                             >> "$vArchivo"
  echo '  }'                                               >> "$vArchivo"
  echo '}'                                                 >> "$vArchivo"
  kea-dhcp4 -t "$vArchivo"
  systemctl enable kea-dhcp4-server.service
  fMostrarCorrecto "Kea configurado con ${#aZonas[@]} ámbitos DHCP."
}

# ----------
# Servidor DNS BIND9 con zona directa e inversa y registro de consultas.
# ----------

# ----------
# BIND9 para varios segmentos con ACL restringida a LAN y VPN de LAN.
# DMZ, IoT e invitados reciben DNS público desde DHCP por defecto.
# ----------

fConfigurarBIND9Segmentado() {
  local vOcteto1
  local vOcteto2
  local vOcteto3
  local vZonaInversa
  local vSegmento
  local vIP
  local vArchivoZonaDirecta="/etc/bind/db.$vDominioLAN.directa"
  local vArchivoZonaInversa
  local vNombreServidor="ns1.$vDominioLAN."
  local vFechaZona
  local vIPEscucha="127.0.0.1; ${dIPSegmento[lan]};"
  local vACLConsulta="127.0.0.1; ${dRedSegmento[lan]};"

  fMostrarInformacion "Configurando BIND9 con resolución interna y zonas inversas por segmento..."
  fInstalarPaquetes bind9 bind9-utils dnsutils
  vFechaZona=$(date +%Y%m%d)01
  if [ "$vConfigWireGuard" = "si" ] && [ "$vDestinoWireGuard" = "lan" ]; then
    vIPEscucha="$vIPEscucha $vIPWireGuard;"
    vACLConsulta="$vACLConsulta $vRedWireGuard;"
  fi

  fGuardarCopia "/etc/bind/named.conf.options"
  echo 'options {'                                       > /etc/bind/named.conf.options
  echo '  directory "/var/cache/bind";'                >> /etc/bind/named.conf.options
  echo "  listen-on { $vIPEscucha };"                  >> /etc/bind/named.conf.options
  echo '  listen-on-v6 { none; };'                    >> /etc/bind/named.conf.options
  echo '  recursion yes;'                              >> /etc/bind/named.conf.options
  echo "  allow-query { $vACLConsulta };"             >> /etc/bind/named.conf.options
  echo "  allow-recursion { $vACLConsulta };"         >> /etc/bind/named.conf.options
  echo "  allow-query-cache { $vACLConsulta };"       >> /etc/bind/named.conf.options
  echo '  allow-transfer { none; };'                   >> /etc/bind/named.conf.options
  echo '  dnssec-validation auto;'                    >> /etc/bind/named.conf.options
  echo '  forwarders {'                               >> /etc/bind/named.conf.options
  echo "    $vDNSExterno1;"                           >> /etc/bind/named.conf.options
  echo "    $vDNSExterno2;"                           >> /etc/bind/named.conf.options
  echo '  };'                                         >> /etc/bind/named.conf.options
  echo '};'                                           >> /etc/bind/named.conf.options

  mkdir -p /var/log/named
  chown bind:bind /var/log/named
  fGuardarCopia "/etc/bind/named.conf.log"
  echo 'logging {'                                         > /etc/bind/named.conf.log
  echo '  channel fichero_general {'                   >> /etc/bind/named.conf.log
  echo '    file "/var/log/named/default.log" versions 10 size 10m;' >> /etc/bind/named.conf.log
  echo '    print-time yes;'                           >> /etc/bind/named.conf.log
  echo '    print-severity yes;'                       >> /etc/bind/named.conf.log
  echo '    severity info;'                            >> /etc/bind/named.conf.log
  echo '  };'                                         >> /etc/bind/named.conf.log
  echo '  channel fichero_consultas {'                 >> /etc/bind/named.conf.log
  echo '    file "/var/log/named/queries.log" versions 10 size 10m;' >> /etc/bind/named.conf.log
  echo '    print-time yes;'                           >> /etc/bind/named.conf.log
  echo '    severity info;'                            >> /etc/bind/named.conf.log
  echo '  };'                                         >> /etc/bind/named.conf.log
  echo '  category default { fichero_general; };'    >> /etc/bind/named.conf.log
  echo '  category queries { fichero_consultas; };'  >> /etc/bind/named.conf.log
  echo '};'                                           >> /etc/bind/named.conf.log

  if ! grep -Fqx 'include "/etc/bind/named.conf.log";' /etc/bind/named.conf; then
    fGuardarCopia "/etc/bind/named.conf"
    echo 'include "/etc/bind/named.conf.log";' >> /etc/bind/named.conf
  fi

  fGuardarCopia "$vArchivoZonaDirecta"
  echo '$TTL 3600'                                         > "$vArchivoZonaDirecta"
  echo "@ IN SOA $vNombreServidor admin.$vDominioLAN. (" >> "$vArchivoZonaDirecta"
  echo "  $vFechaZona 3600 900 1209600 3600 )"       >> "$vArchivoZonaDirecta"
  echo "@ IN NS $vNombreServidor"                     >> "$vArchivoZonaDirecta"
  echo "ns1 IN A ${dIPSegmento[lan]}"                 >> "$vArchivoZonaDirecta"
  echo "router IN A ${dIPSegmento[lan]}"              >> "$vArchivoZonaDirecta"
  for vSegmento in "${aSegmentos[@]}"; do
    echo "${dNombreInterfaz[$vSegmento]} IN A ${dIPSegmento[$vSegmento]}" >> "$vArchivoZonaDirecta"
  done
  if [ "$vConfigWireGuard" = "si" ]; then
    echo "$vNombreWireGuard IN A $vIPWireGuard"       >> "$vArchivoZonaDirecta"
  fi

  fGuardarCopia "/etc/bind/named.conf.local"
  echo "zone \"$vDominioLAN\" {"                    > /etc/bind/named.conf.local
  echo '  type master;'                               >> /etc/bind/named.conf.local
  echo "  file \"$vArchivoZonaDirecta\";"         >> /etc/bind/named.conf.local
  echo '  allow-transfer { none; };'                 >> /etc/bind/named.conf.local
  echo '};'                                         >> /etc/bind/named.conf.local

  for vSegmento in "${aSegmentos[@]}"; do
    vIP="${dIPSegmento[$vSegmento]}"
    IFS=. read -r vOcteto1 vOcteto2 vOcteto3 vOctetoResto <<< "$vIP"
    vZonaInversa="$vOcteto3.$vOcteto2.$vOcteto1.in-addr.arpa"
    vArchivoZonaInversa="/etc/bind/db.$vDominioLAN.$vSegmento.inversa"
    fGuardarCopia "$vArchivoZonaInversa"
    echo '$TTL 3600'                                        > "$vArchivoZonaInversa"
    echo "@ IN SOA $vNombreServidor admin.$vDominioLAN. (" >> "$vArchivoZonaInversa"
    echo "  $vFechaZona 3600 900 1209600 3600 )"        >> "$vArchivoZonaInversa"
    echo "@ IN NS $vNombreServidor"                      >> "$vArchivoZonaInversa"
    echo "1 IN PTR ${dNombreInterfaz[$vSegmento]}.$vDominioLAN." >> "$vArchivoZonaInversa"
    echo ""                                               >> /etc/bind/named.conf.local
    echo "zone \"$vZonaInversa\" {"                    >> /etc/bind/named.conf.local
    echo '  type master;'                                  >> /etc/bind/named.conf.local
    echo "  file \"$vArchivoZonaInversa\";"            >> /etc/bind/named.conf.local
    echo '  allow-transfer { none; };'                    >> /etc/bind/named.conf.local
    echo '};'                                             >> /etc/bind/named.conf.local
    named-checkzone "$vZonaInversa" "$vArchivoZonaInversa"
  done
  named-checkzone "$vDominioLAN" "$vArchivoZonaDirecta"
  named-checkconf -z
  systemctl enable named.service 2>/dev/null || systemctl enable bind9.service
  fMostrarCorrecto "BIND9 restringido a LAN y VPN de LAN, con zonas inversas de las cuatro redes."
}

fConfigurarBIND9() {
  if [ "$vModoLAN" = "segmentado" ]; then
    fConfigurarBIND9Segmentado
    return $?
  fi
  local vOcteto1
  local vOcteto2
  local vOcteto3
  local vOcteto4
  local vZonaInversa
  local vArchivoZonaDirecta="/etc/bind/db.$vDominioLAN.directa"
  local vArchivoZonaInversa="/etc/bind/db.$vDominioLAN.inversa"
  local vIPEscucha="127.0.0.1;"
  local vACLConsulta="127.0.0.1; $vRedLAN;"
  local vNombreServidor="ns1.$vDominioLAN."
  local vFechaZona

  fMostrarInformacion "Instalando y configurando el servidor DNS BIND9..."
  fInstalarPaquetes bind9 bind9-utils dnsutils
  vOcteto1=$(echo "$vIPLAN" | cut -d. -f1)
  vOcteto2=$(echo "$vIPLAN" | cut -d. -f2)
  vOcteto3=$(echo "$vIPLAN" | cut -d. -f3)
  vOcteto4=$(echo "$vIPLAN" | cut -d. -f4)
  vZonaInversa="$vOcteto3.$vOcteto2.$vOcteto1.in-addr.arpa"
  vFechaZona=$(date +%Y%m%d)01

  if [ "$vModoEquipo" = "router" ] || [ "$vModoIPAP" = "estatica" ]; then
    vIPEscucha="$vIPEscucha $vIPLAN;"
  else
    echo "En modo AP con gestión DHCP, BIND9 escuchará sólo en 127.0.0.1."
  fi
  if [ "$vConfigWireGuard" = "si" ]; then
    vACLConsulta="$vACLConsulta $vRedWireGuard;"
  fi

  fGuardarCopia "/etc/bind/named.conf.options"
  echo "options {"                                                  > /etc/bind/named.conf.options
  echo '  directory "/var/cache/bind";'                          >> /etc/bind/named.conf.options
  echo "  listen-on { $vIPEscucha };"                             >> /etc/bind/named.conf.options
  echo '  listen-on-v6 { none; };'                                >> /etc/bind/named.conf.options
  echo '  recursion yes;'                                        >> /etc/bind/named.conf.options
  echo "  allow-query { $vACLConsulta };"                         >> /etc/bind/named.conf.options
  echo "  allow-recursion { $vACLConsulta };"                     >> /etc/bind/named.conf.options
  echo "  allow-query-cache { $vACLConsulta };"                   >> /etc/bind/named.conf.options
  echo '  allow-transfer { none; };'                              >> /etc/bind/named.conf.options
  echo '  dnssec-validation auto;'                                 >> /etc/bind/named.conf.options
  echo '  forwarders {'                                           >> /etc/bind/named.conf.options
  echo "    $vDNSExterno1;"                                      >> /etc/bind/named.conf.options
  echo "    $vDNSExterno2;"                                      >> /etc/bind/named.conf.options
  echo '  };'                                                     >> /etc/bind/named.conf.options
  echo '};'                                                       >> /etc/bind/named.conf.options

  # Registro de consultas y eventos BIND9. /var/log/named es compatible
  # con la política AppArmor habitual de Debian; comprobarlo en cada equipo.
  mkdir -p /var/log/named
  chown bind:bind /var/log/named
  fGuardarCopia "/etc/bind/named.conf.log"
  echo 'logging {'                                                     > /etc/bind/named.conf.log
  echo '  channel fichero_general {'                                >> /etc/bind/named.conf.log
  echo '    file "/var/log/named/default.log" versions 10 size 10m;' >> /etc/bind/named.conf.log
  echo '    print-time yes;'                                       >> /etc/bind/named.conf.log
  echo '    print-severity yes;'                                   >> /etc/bind/named.conf.log
  echo '    severity info;'                                        >> /etc/bind/named.conf.log
  echo '  };'                                                      >> /etc/bind/named.conf.log
  echo '  channel fichero_consultas {'                               >> /etc/bind/named.conf.log
  echo '    file "/var/log/named/queries.log" versions 10 size 10m;' >> /etc/bind/named.conf.log
  echo '    print-time yes;'                                       >> /etc/bind/named.conf.log
  echo '    severity info;'                                        >> /etc/bind/named.conf.log
  echo '  };'                                                      >> /etc/bind/named.conf.log
  echo '  channel fichero_seguridad {'                              >> /etc/bind/named.conf.log
  echo '    file "/var/log/named/security.log" versions 10 size 10m;' >> /etc/bind/named.conf.log
  echo '    print-time yes;'                                       >> /etc/bind/named.conf.log
  echo '    severity info;'                                        >> /etc/bind/named.conf.log
  echo '  };'                                                      >> /etc/bind/named.conf.log
  echo '  category default { fichero_general; };'                  >> /etc/bind/named.conf.log
  echo '  category queries { fichero_consultas; };'                >> /etc/bind/named.conf.log
  echo '  category security { fichero_seguridad; };'               >> /etc/bind/named.conf.log
  echo '};'                                                        >> /etc/bind/named.conf.log

  # Si se vuelve a ejecutar, no duplicar la inclusión en named.conf.
  if ! grep -Fqx 'include "/etc/bind/named.conf.log";' /etc/bind/named.conf; then
    fGuardarCopia "/etc/bind/named.conf"
    echo 'include "/etc/bind/named.conf.log";' >> /etc/bind/named.conf
  fi

  fGuardarCopia "$vArchivoZonaDirecta"
  echo '$TTL 3600'                                               > "$vArchivoZonaDirecta"
  echo "@ IN SOA $vNombreServidor admin.$vDominioLAN. ("        >> "$vArchivoZonaDirecta"
  echo "  $vFechaZona 3600 900 1209600 3600 )"                   >> "$vArchivoZonaDirecta"
  echo "@ IN NS $vNombreServidor"                                >> "$vArchivoZonaDirecta"
  echo "ns1 IN A $vIPLAN"                                        >> "$vArchivoZonaDirecta"
  echo "router IN A $vIPLAN"                                     >> "$vArchivoZonaDirecta"
  if [ "$vConfigWireGuard" = "si" ]; then
    echo "vpn IN A $vIPWireGuard"                                 >> "$vArchivoZonaDirecta"
  fi

  fGuardarCopia "$vArchivoZonaInversa"
  echo '$TTL 3600'                                               > "$vArchivoZonaInversa"
  echo "@ IN SOA $vNombreServidor admin.$vDominioLAN. ("         >> "$vArchivoZonaInversa"
  echo "  $vFechaZona 3600 900 1209600 3600 )"                    >> "$vArchivoZonaInversa"
  echo "@ IN NS $vNombreServidor"                                 >> "$vArchivoZonaInversa"
  echo "$vOcteto4 IN PTR router.$vDominioLAN."                   >> "$vArchivoZonaInversa"

  fGuardarCopia "/etc/bind/named.conf.local"
  echo "zone \"$vDominioLAN\" {"                        > /etc/bind/named.conf.local
  echo '  type master;'                                 >> /etc/bind/named.conf.local
  echo "  file \"$vArchivoZonaDirecta\";"             >> /etc/bind/named.conf.local
  echo '  allow-transfer { none; };'                   >> /etc/bind/named.conf.local
  echo '};'                                           >> /etc/bind/named.conf.local
  echo ""                                             >> /etc/bind/named.conf.local
  echo "zone \"$vZonaInversa\" {"                    >> /etc/bind/named.conf.local
  echo '  type master;'                                 >> /etc/bind/named.conf.local
  echo "  file \"$vArchivoZonaInversa\";"             >> /etc/bind/named.conf.local
  echo '  allow-transfer { none; };'                   >> /etc/bind/named.conf.local
  echo '};'                                           >> /etc/bind/named.conf.local

  named-checkzone "$vDominioLAN" "$vArchivoZonaDirecta"
  named-checkzone "$vZonaInversa" "$vArchivoZonaInversa"
  named-checkconf -z
  systemctl enable named.service 2>/dev/null || systemctl enable bind9.service
  fMostrarCorrecto "BIND9 configurado con resolución interna, inversa y logs."
}

# ----------
# Punto de acceso Wi-Fi. Se evita forzar opciones HT/VHT no soportadas.
# ----------

fConfigurarFirmwareWiFi() {
  local aPaquetes=()
  local vPaquete
  case "$vFirmwareWiFi" in
    atheros)
      aPaquetes=(firmware-atheros firmware-ath9k-htc)
    ;;
    intel)
      aPaquetes=(firmware-iwlwifi)
    ;;
    realtek)
      aPaquetes=(firmware-realtek)
    ;;
    broadcom)
      aPaquetes=(firmware-brcm80211)
    ;;
    *)
      return 0
    ;;
  esac
  echo "Los paquetes de firmware pueden incluir componentes binarios privativos."
  for vPaquete in "${aPaquetes[@]}"; do
    if apt-cache show "$vPaquete" >/dev/null 2>&1; then
      fInstalarPaquetes "$vPaquete"
    else
      echo "El paquete $vPaquete no está disponible: revisa el componente non-free-firmware/non-free de APT."
    fi
  done
}

fConfigurarHostAPD() {
  local vArchivo="/etc/hostapd/hostapd.conf"
  fMostrarInformacion "Configurando el punto de acceso Wi-Fi mediante hostapd..."
  fInstalarPaquetes hostapd iw
  mkdir -p /etc/hostapd
  fGuardarCopia "$vArchivo"
  echo "# Punto de acceso del router Debian"                     > "$vArchivo"
  echo "interface=$vIntWLAN"                                   >> "$vArchivo"
  echo 'driver=nl80211'                                        >> "$vArchivo"
  echo "bridge=$vPuenteWiFi"                                   >> "$vArchivo"
  echo "country_code=$vPaisWiFi"                             >> "$vArchivo"
  echo 'ieee80211d=1'                                         >> "$vArchivo"
  echo "ssid=$vSSID"                                         >> "$vArchivo"
  echo "channel=$vCanalWiFi"                                 >> "$vArchivo"
  if [ "$vModoRadioWiFi" != "legado" ]; then
    echo 'ieee80211n=1'                                     >> "$vArchivo"
  fi
  if [ "$vModoRadioWiFi" = "ac" ]; then
    echo 'ieee80211ac=1'                                    >> "$vArchivo"
    echo 'vht_oper_chwidth=1'                                >> "$vArchivo"
    echo 'vht_oper_centr_freq_seg0_idx=42'                    >> "$vArchivo"
  fi
  if [ "$vBandaWiFi" = "5" ]; then
    echo 'hw_mode=a'                                         >> "$vArchivo"
  else
    echo 'hw_mode=g'                                         >> "$vArchivo"
  fi
  echo 'wmm_enabled=1'                                       >> "$vArchivo"
  echo 'ignore_broadcast_ssid=0'                             >> "$vArchivo"
  echo 'ctrl_interface=/run/hostapd'                          >> "$vArchivo"
  echo 'ctrl_interface_group=0'                               >> "$vArchivo"
  if [ "$vModoWiFi" = "wpa2" ]; then
    echo 'wpa=2'                                             >> "$vArchivo"
    echo 'wpa_key_mgmt=WPA-PSK'                              >> "$vArchivo"
    echo 'rsn_pairwise=CCMP'                                 >> "$vArchivo"
    echo "wpa_passphrase=$vClaveWiFi"                        >> "$vArchivo"
  elif [ "$vModoWiFi" = "wpa3" ]; then
    echo 'wpa=2'                                             >> "$vArchivo"
    echo 'wpa_key_mgmt=SAE'                                  >> "$vArchivo"
    echo 'ieee80211w=2'                                     >> "$vArchivo"
    echo 'rsn_pairwise=CCMP'                                 >> "$vArchivo"
    echo "sae_password=$vClaveWiFi"                          >> "$vArchivo"
  else
    echo "# Red Wi-Fi abierta solicitada expresamente."       >> "$vArchivo"
  fi
  if [ "$vHabilitarWPS" = "si" ]; then
    echo 'eap_server=1'                                      >> "$vArchivo"
    echo 'wps_state=2'                                       >> "$vArchivo"
    echo "uuid=$(cat /proc/sys/kernel/random/uuid)"         >> "$vArchivo"
    echo 'config_methods=push_button'                        >> "$vArchivo"
    echo 'device_name=RouterDebian'                          >> "$vArchivo"
    echo 'device_type=6-0050F204-1'                          >> "$vArchivo"
  fi
  chmod 600 "$vArchivo"
  fGuardarCopia "/etc/default/hostapd"
  if [ -f /etc/default/hostapd ]; then
    sed -i -e 's|^#\?DAEMON_CONF=.*|DAEMON_CONF="/etc/hostapd/hostapd.conf"|g' /etc/default/hostapd
    if ! grep -q '^DAEMON_CONF=' /etc/default/hostapd; then
      echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' >> /etc/default/hostapd
    fi
  else
    echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' > /etc/default/hostapd
  fi
  systemctl unmask hostapd.service
  systemctl enable hostapd.service
  fMostrarCorrecto "hostapd configurado. La compatibilidad Wi-Fi se verificará al levantar el AP."
}

# ----------
# Proxy inverso y balanceador HAProxy (TCP passthrough).
# ----------

fConfigurarHAProxy() {
  local vArchivo="/etc/haproxy/haproxy.cfg"
  fMostrarInformacion "Instalando y configurando HAProxy..."
  fInstalarPaquetes haproxy
  fGuardarCopia "$vArchivo"
  echo "# HAProxy - Proxy TCP transparente"                       > "$vArchivo"
  echo 'global'                                                   >> "$vArchivo"
  echo '  log /dev/log local0'                                     >> "$vArchivo"
  echo '  maxconn 2048'                                           >> "$vArchivo"
  echo ''                                                        >> "$vArchivo"
  echo 'defaults'                                                 >> "$vArchivo"
  echo '  log global'                                             >> "$vArchivo"
  echo '  mode tcp'                                               >> "$vArchivo"
  echo '  timeout connect 5s'                                     >> "$vArchivo"
  echo '  timeout client 60s'                                     >> "$vArchivo"
  echo '  timeout server 60s'                                     >> "$vArchivo"
  echo ''                                                        >> "$vArchivo"
  echo 'frontend frontend_tcp'                                    >> "$vArchivo"
  echo "  bind *:$vPuertoHAProxy"                                >> "$vArchivo"
  echo '  default_backend backend_tcp'                            >> "$vArchivo"
  echo ''                                                        >> "$vArchivo"
  echo 'backend backend_tcp'                                      >> "$vArchivo"
  echo "  server servidor1 $vIPBackendHAProxy:$vPuertoBackendHAProxy check" >> "$vArchivo"
  haproxy -c -f "$vArchivo"
  systemctl enable haproxy.service
  fMostrarCorrecto "HAProxy configurado: TCP $vPuertoHAProxy -> $vIPBackendHAProxy:$vPuertoBackendHAProxy."
}

# ----------
# Servidor WireGuard y primer cliente opcional.
# ----------

fConfigurarWireGuard() {
  local vArchivo="/etc/wireguard/$vNombreWireGuard.conf"
  local vArchivoClavePrivada="/etc/wireguard/server-$vNombreWireGuard.key"
  local vArchivoClavePublica="/etc/wireguard/server-$vNombreWireGuard.pub"
  local vClavePrivada
  local vClavePublica
  local vClaveClientePrivada
  local vClaveClientePublica
  local vArchivoCliente
  local vNombreCliente

  fMostrarInformacion "Instalando y configurando el servidor WireGuard..."
  fInstalarPaquetes wireguard-tools
  if [ -n "$vClienteWireGuard" ]; then
    fInstalarPaquetes qrencode
  fi
  install -d -m 700 /etc/wireguard
  umask 077
  if [ ! -s "$vArchivoClavePrivada" ]; then
    fGuardarCopia "$vArchivoClavePrivada"
    wg genkey > "$vArchivoClavePrivada"
  fi
  chmod 600 "$vArchivoClavePrivada"
  vClavePrivada=$(cat "$vArchivoClavePrivada")
  vClavePublica=$(echo "$vClavePrivada" | wg pubkey)
  fGuardarCopia "$vArchivoClavePublica"
  echo "$vClavePublica" > "$vArchivoClavePublica"
  chmod 600 "$vArchivoClavePublica"

  fGuardarCopia "$vArchivo"
  echo "# Configuración del servidor WireGuard"              > "$vArchivo"
  echo "[Interface]"                                        >> "$vArchivo"
  echo "Address = $vIPWireGuard/24"                         >> "$vArchivo"
  echo "ListenPort = $vPuertoWireGuard"                     >> "$vArchivo"
  echo "PrivateKey = $vClavePrivada"                        >> "$vArchivo"

  if [ -n "$vClienteWireGuard" ]; then
    vNombreCliente="$vClienteWireGuard"
    install -d -m 700 /root/wireguard-clientes
    vArchivoCliente="/root/wireguard-clientes/$vNombreCliente.conf"
    if [ -e "$vArchivoCliente" ]; then
      fMostrarError "Ya existe el fichero $vArchivoCliente. No se sobrescribirá ninguna clave de cliente."
      return 1
    fi
    fGuardarCopia "$vArchivoCliente"
    vClaveClientePrivada=$(wg genkey)
    vClaveClientePublica=$(echo "$vClaveClientePrivada" | wg pubkey)
    echo ""                                                   >> "$vArchivo"
    echo "[Peer]"                                             >> "$vArchivo"
    echo "# $vNombreCliente"                                  >> "$vArchivo"
    echo "PublicKey = $vClaveClientePublica"                  >> "$vArchivo"
    echo "AllowedIPs = $vIPClienteWireGuard/32"               >> "$vArchivo"
    echo "[Interface]"                                         > "$vArchivoCliente"
    echo "Address = $vIPClienteWireGuard/32"                  >> "$vArchivoCliente"
    echo "PrivateKey = $vClaveClientePrivada"                 >> "$vArchivoCliente"
    if [ "$vConfigDNS" = "si" ] && { [ "$vModoLAN" != "segmentado" ] || [ "$vDestinoWireGuard" = "lan" ]; }; then
      echo "DNS = $vIPLAN"                                    >> "$vArchivoCliente"
    fi
    echo ""                                                    >> "$vArchivoCliente"
    echo "[Peer]"                                            >> "$vArchivoCliente"
    echo "PublicKey = $vClavePublica"                         >> "$vArchivoCliente"
    if [ -n "$vPublicoWireGuard" ]; then
      echo "Endpoint = $vPublicoWireGuard:$vPuertoWireGuard"  >> "$vArchivoCliente"
    else
      echo "# Endpoint = CAMBIAR-POR-IP-O-DOMINIO:$vPuertoWireGuard" >> "$vArchivoCliente"
    fi
    if [ "$vModoLAN" = "segmentado" ]; then
      echo "AllowedIPs = $vRedDestinoVPN, $vRedWireGuard" >> "$vArchivoCliente"
    else
      echo "AllowedIPs = $vRedLAN, $vRedWireGuard"       >> "$vArchivoCliente"
    fi
    echo "PersistentKeepalive = 25"                          >> "$vArchivoCliente"
    chmod 600 "$vArchivoCliente"
    fGuardarCopia "/root/wireguard-clientes/$vNombreCliente.png"
    qrencode -o "/root/wireguard-clientes/$vNombreCliente.png" < "$vArchivoCliente"
    chmod 600 "/root/wireguard-clientes/$vNombreCliente.png"
  fi

  chmod 600 "$vArchivo"
  wg-quick strip "$vArchivo" > /dev/null
  systemctl enable "wg-quick@$vNombreWireGuard.service"
  fMostrarCorrecto "WireGuard preparado para arrancar después de configurar la red."
}

# ----------
# Ejecutar las funciones comunes a las tres versiones de Debian.
# ----------

fPrepararAsistente() {
  fComprobarRequisitos

  # Instalar dialog sólo si no existe. Así se mantiene el menú que uso en
  # los scripts anteriores para seleccionar componentes antes de instalarlos.
  if ! command -v dialog >/dev/null 2>&1; then
    apt-get -y update
    DEBIAN_FRONTEND=noninteractive apt-get -y install dialog
  fi

  if systemctl is-active --quiet NetworkManager.service || systemctl is-active --quiet systemd-networkd.service; then
    if ! fConfirmar "Se ha detectado NetworkManager o systemd-networkd. Este instalador escribe /etc/network/interfaces usando ifupdown. Asegúrate de desactivar la gestión duplicada de estas interfaces. ¿Continuar?"; then
      exit 0
    fi
  fi

  fSeleccionarFuncionalidades
  fConfigurarParametrosRed
  fConfigurarParametrosWiFi
  fConfigurarParametrosOpcionales
  fValidarOpciones

  if ! fMostrarResumen; then
    echo "Instalación cancelada. No se ha modificado la configuración de red."
    exit 0
  fi
  if [ -n "${SSH_CONNECTION:-}" ]; then
    if ! fConfirmar "ATENCIÓN: estás conectado por SSH. Los cambios se aplicarán al reiniciar. Si la red o el firewall quedan mal configurados, podrías perder el acceso. ¿Continuar?"; then
      exit 0
    fi
  fi

  mkdir -p "$vDirCopias"
  chmod 700 "$vDirCopias"
  echo "Inicio de la instalación: $(date -Is)" > "$vDirCopias/instalacion.txt"
  echo "Sistema: Debian $cVerSO"             >> "$vDirCopias/instalacion.txt"
  echo "Modo de equipo: $vModoEquipo"         >> "$vDirCopias/instalacion.txt"
  vCambiosRealizados="si"
  fGuardarCopia "/etc/network/interfaces"
  set -Ee -o pipefail
  trap fGestionarError ERR
}

fConfigurarServiciosComunes() {
  if [ "$vConfigFirmware" = "si" ]; then
    fConfigurarFirmwareWiFi
  fi
  if [ "$vConfigWiFi" = "si" ]; then
    fConfigurarHostAPD
  fi
  if [ "$vConfigDNS" = "si" ]; then
    fConfigurarBIND9
  fi
  if [ "$vConfigHAProxy" = "si" ]; then
    fConfigurarHAProxy
  fi
  if [ "$vConfigWireGuard" = "si" ]; then
    fConfigurarWireGuard
  fi
}

fFinalizarInstalacion() {
  trap - ERR
  fMostrarInformacion "Instalación finalizada."
  echo "  Copias de seguridad: $vDirCopias"
  echo "  Archivo de red: /etc/network/interfaces"
  if [ "$vConfigFirewall" = "si" ]; then
    if [ "$vBackendFirewall" = "iptables" ]; then
      echo "  Reglas IPv4: /etc/iptables/rules.v4"
      echo "  Reglas IPv6: /etc/iptables/rules.v6"
    else
      echo "  Reglas nftables: /etc/nftables.conf"
    fi
  fi
  if [ "$vConfigDHCP" = "si" ]; then
    if [ "$vBackendDHCP" = "kea" ]; then
      echo "  DHCP: /etc/kea/kea-dhcp4.conf"
    else
      echo "  DHCP: /etc/dhcp/dhcpd.conf"
    fi
  fi
  if [ "$vConfigDNS" = "si" ]; then
    echo "  DNS: /etc/bind/"
  fi
  if [ "$vConfigWiFi" = "si" ]; then
    echo "  Wi-Fi: /etc/hostapd/hostapd.conf"
  fi
  if [ "$vConfigWireGuard" = "si" ]; then
    echo "  VPN: /etc/wireguard/$vNombreWireGuard.conf"
    if [ -n "$vClienteWireGuard" ]; then
      echo "  Cliente VPN: /root/wireguard-clientes/$vClienteWireGuard.conf"
    fi
  fi
  echo ""
  echo -e "${cColorAzulClaro}  IMPORTANTE:${cFinColor}"
  echo "  No se han recargado directamente las interfaces ni las reglas."
  echo "  La instalación de paquetes APT puede iniciar algunos demonios."
  echo "  Revisa WAN, DMZ, LAN, IoT, invitados, VPN, hostapd, firewall, DHCP y DNS antes de reiniciar."
  echo "  En Debian 11 el mantenimiento de seguridad LTS finalizó el 31-08-2026."
  echo "  Para operaciones críticas utiliza una consola local o acceso fuera de banda."
  echo ""
}

# ----------
# Ejecutar comandos dependiendo de la versión de Debian detectada.
# Sólo Debian 11, Debian 12 y Debian 13.
# ----------

  if [ "$cVerSO" == "13" ]; then

    echo ""
    echo -e "${cColorAzulClaro}  Iniciando el script de instalación del router para Debian 13 (Trixie)...${cFinColor}"
    echo ""
    vBackendFirewall="nftables"
    vBackendDHCP="kea"

    if [ "${1:-}" = "--solo-validar" ]; then
      fComprobarArchivos
      exit $?
    fi
    fPrepararAsistente
    fInstalarBase
    fConfigurarInterfaces
    if [ "$vConfigFirewall" = "si" ]; then
      fConfigurarNFTables
    fi
    if [ "$vConfigDHCP" = "si" ]; then
      fConfigurarKeaDHCP
    fi
    fConfigurarServiciosComunes
    fFinalizarInstalacion

  elif [ "$cVerSO" == "12" ]; then

    echo ""
    echo -e "${cColorAzulClaro}  Iniciando el script de instalación del router para Debian 12 (Bookworm)...${cFinColor}"
    echo ""
    vBackendFirewall="nftables"
    vBackendDHCP="isc-dhcp-server"

    if [ "${1:-}" = "--solo-validar" ]; then
      fComprobarArchivos
      exit $?
    fi
    fPrepararAsistente
    fInstalarBase
    fConfigurarInterfaces
    if [ "$vConfigFirewall" = "si" ]; then
      fConfigurarNFTables
    fi
    if [ "$vConfigDHCP" = "si" ]; then
      fConfigurarISCDHCP
    fi
    fConfigurarServiciosComunes
    fFinalizarInstalacion

  elif [ "$cVerSO" == "11" ]; then

    echo ""
    echo -e "${cColorAzulClaro}  Iniciando el script de instalación del router para Debian 11 (Bullseye)...${cFinColor}"
    echo ""
    echo -e "${cColorRojo}  ADVERTENCIA: Debian 11 no recibe actualizaciones de seguridad LTS desde el 31-08-2026.${cFinColor}"
    vBackendFirewall="iptables"
    vBackendDHCP="isc-dhcp-server"

    if [ "${1:-}" = "--solo-validar" ]; then
      fComprobarArchivos
      exit $?
    fi
    fPrepararAsistente
    fInstalarBase
    fConfigurarInterfaces
    if [ "$vConfigFirewall" = "si" ]; then
      fConfigurarIPTables
    fi
    if [ "$vConfigDHCP" = "si" ]; then
      fConfigurarISCDHCP
    fi
    fConfigurarServiciosComunes
    fFinalizarInstalacion

  else

    echo ""
    echo -e "${cColorRojo}  Sólo son compatibles Debian 11, Debian 12 y Debian 13. Versión detectada: $cVerSO.${cFinColor}"
    echo ""
    exit 1

  fi
