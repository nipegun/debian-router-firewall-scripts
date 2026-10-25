# PrepararRouter.sh

**Estado:** versión de laboratorio, pendiente de probar en Debian 11, Debian 12 y Debian 13 reales.

## Objetivo

Unificar el despliegue de los enrutadores/cortafuegos Debian usando las convenciones del autor y una segmentación IPv4 predeterminada. El script continúa utilizando Bash, `dialog`, comentarios en castellano, `echo` para generar configuraciones, los prefijos `v`/`c`/`a`/`d`/`f`, sangría de dos espacios y ramas explícitas de Debian 13, Debian 12 y Debian 11. No contiene ramas para versiones anteriores.

## Segmentos predeterminados

| Zona | Interfaz lógica | IPv4 de la interfaz | Red | Rango DHCP |
|---|---|---|---|---|
| DMZ | `intdmz` | `192.168.0.1/24` | `192.168.0.0/24` | `.100`-`.199` |
| LAN | `intlan` | `192.168.1.1/24` | `192.168.1.0/24` | `.100`-`.199` |
| IoT | `intiot` | `192.168.2.1/24` | `192.168.2.0/24` | `.100`-`.199` |
| Invitados | `intgst` | `192.168.3.1/24` | `192.168.3.0/24` | `.100`-`.199` |
| VPN de LAN | `intlanvpn` | `192.168.101.1/24` | `192.168.101.0/24` | Sin DHCP: WireGuard |
| WAN | `intwan` | DHCP por defecto | Operador | Sin DHCP servidor |

Las cuatro interfaces de las zonas internas se crean como **puentes Linux** con nombres estables, independientemente de las NIC físicas asignadas. Cada una puede recibir un puerto físico, múltiples puertos o una o varias interfaces VLAN del tipo `enp2s0.20`. Si se deja una zona sin puertos, su puente se crea igualmente y no tendrá conectividad física hasta conectarlo con un puerto, VLAN u otra interfaz.

La WAN admite DHCP, IPv4 estática, PPPoE, perfiles Movistar/Simyo/Vodafone y DHCP en VLAN. Si la NIC WAN física no se llama `intwan`, el asistente ofrece crear `/etc/systemd/network/10-intwan.link` para renombrarla al reiniciar, utilizando su dirección MAC. En PPPoE, la NIC física se llama `intwan`, pero la sesión que tiene la dirección pública se presenta en `ppp0`. La detección y renombrado con `.link` requieren pruebas en el equipo concreto.

## Elección de VPN

El asistente permite seleccionar **una VPN de destino por instalación**. Por defecto es la LAN:

- `intlanvpn`: `192.168.101.1/24` y permiso de acceso a `192.168.1.0/24`.
- `intgstvpn`: `192.168.103.1/24` y permiso de acceso a `192.168.3.0/24`.
- `intiotvpn`: `192.168.102.1/24` y permiso de acceso a `192.168.2.0/24`.
- `intdmzvpn`: `192.168.100.1/24` y permiso de acceso a `192.168.0.0/24`.

Para cualquier tercer octeto de una red de destino, la interfaz VPN toma `octeto + 100`. El script rechaza resultados superiores a 255 o una VPN que coincida con alguna de las redes internas. La misma ejecución no crea simultáneamente las cuatro VPN. El archivo y la unidad de servicio se nombran según la VPN elegida (`/etc/wireguard/intlanvpn.conf`, `wg-quick@intlanvpn.service`, etc.). El archivo de cliente usa split tunnel, sin enviar Internet por la VPN.

## Selección de servicios según versión

| Debian | DHCP | Filtrado/NAT |
|---|---|---|
| 11 (Bullseye) | `isc-dhcp-server`, cuatro ámbitos DHCP | `iptables` + `iptables-persistent` |
| 12 (Bookworm) | `isc-dhcp-server`, cuatro ámbitos DHCP | `nftables` |
| 13 (Trixie) | `kea-dhcp4-server`, cuatro ámbitos DHCP | `nftables` |

Las tres ramas pueden instalar BIND9, HAProxy TCP, WireGuard y hostapd. El SSID Wi-Fi se conecta al puente de **una zona elegida**; el script no genera varios SSID/BSS simultáneos.

## Reglas iniciales de seguridad

- Políticas de INPUT y FORWARD por defecto: **DROP**; conexiones ESTABLISHED/RELATED permitidas.
- Las zonas DMZ, LAN, IoT e invitados pueden acceder a Internet mediante NAT de salida.
- El tráfico iniciado desde una zona hacia otra queda bloqueado salvo reglas explícitas.
- La VPN solo puede iniciar conexiones hacia su zona de destino; la respuesta se permite mediante conntrack.
- La LAN puede acceder por SSH al router y consultar BIND9. La VPN de LAN tiene permisos equivalentes en la interfaz VPN.
- El servidor DHCP acepta solicitudes por las cuatro interfaces internas.
- DMZ, IoT e invitados reciben los DNS públicos 9.9.9.9 y 149.112.112.112; LAN recibe 192.168.1.1 cuando BIND9 está instalado. El sufijo `home.arpa` solo se entrega por DHCP a LAN.
- BIND9 escucha en localhost, LAN y, si se instala, la VPN de LAN; no habilita recursión desde la WAN ni desde las zonas aisladas.
- Las redirecciones de puertos desde la WAN solo admiten destinos de la red DMZ en el modo segmentado; no se crean redirecciones RDP por defecto.
- El script **no configura IPv6 como enrutador**. La ausencia de IPv6 segmentado es deliberada y debe revisarse antes de utilizar IPv6 en producción.

Estas políticas son **valores iniciales propuestos**, no equivalen necesariamente a la política final de cada despliegue. En particular, la salida a Internet de DMZ e IoT podría limitarse más y los accesos necesarios entre LAN y dispositivos IoT necesitarán excepciones expresas.

## Instalación y validación

Ejecutar en consola física o acceso fuera de banda sobre un Debian nuevo con APT operativo:

```bash
bash RouterFirewall-InstalacionNuevaES-Segmentado.sh
```

Para validar configuraciones que ya estén instaladas, sin modificar el sistema:

```bash
bash RouterFirewall-InstalacionNuevaES-Segmentado.sh --solo-validar
```

El instalador no activa las interfaces ni carga las nuevas reglas de cortafuegos en caliente; están previstas para el siguiente arranque. La instalación de paquetes con APT sí puede arrancar servicios. Las configuraciones reemplazadas se respaldan bajo `/var/backups/RouterFirewall-AAAAMMDD-HHMMSS/`. Si un comando falla, se intenta restaurar la configuración, pero **no se revierten instalaciones APT ni todos los posibles efectos colaterales**.

## Resultados de pruebas

- Sintaxis Bash: comprobada con `bash -n`.
- Generación de ficheros simulada en directorio aislado: interfaces, VLANs, NAT, reglas nftables e iptables, ISC DHCP, Kea DHCP, BIND9 y WireGuard.
- Kea: JSON analizado correctamente con cuatro ámbitos y los rangos, IPs y DNS previstos.
- Reglas estructurales verificadas: DROP entre zonas, salida WAN, VPN a LAN y VPN a invitados.
- WireGuard: nomenclatura e IPs simuladas correctamente para `intlanvpn` (`101`) e `intgstvpn` (`103`).
- Sin acceso en este entorno a los binarios reales de Kea, BIND9, nftables e iptables de las tres versiones: **no se han ejecutado validaciones funcionales en los sistemas de destino**, ni se han comprobado arranques reales tras reinicio.

## Aspectos que todavía necesitan revisión antes de producción

- Hardware: asignación física y soporte de VLANs/puentes; comprobar que `intwan` no genere conflictos con otras reglas de nomenclatura, y que el puerto de administración permita recuperar el acceso.
- En `/etc/network/interfaces.d/` pueden existir definiciones de red adicionales que entren en conflicto con las generadas.
- Orden de arranque: verificar que los puentes y `intlanvpn` estén disponibles cuando Kea/BIND9/hostapd tengan que asociarse a ellos.
- Los cambios en WAN que dependan de un operador deben contrastarse con su provisión actual. Crear VLANs auxiliares no configura de forma completa IPTV ni VoIP.
- El instalador reemplaza ficheros importantes; puede eliminar personalizaciones existentes en las configuraciones de red y servicios.
- No migra concesiones/reservas ISC DHCP de sistemas ya desplegados a Kea.
- No configura interfaces L3 IPv6 ni DHCPv6.
- No proporciona actualmente multi-WAN, BGP/OSPF, alta disponibilidad, varias VPN simultáneas ni múltiples SSID simultáneos.
- La instalación de firmware no se ofrece sin verificar previamente licencias open source.
- **Debian 11 está fuera del periodo LTS desde el 31-08-2026**: mantener esa rama no implica recomendarla para nuevas instalaciones expuestas a Internet.

## Fuentes del diseño

- [Plantilla de programación](https://github.com/nipegun/debian-scripts/blob/main/InstDeSoftware/_/InstalacionNuevaES.sh)
- [Scripts originales de enrutador/cortafuegos](https://github.com/nipegun/debian-router-firewall-scripts/tree/main/PostInst)
