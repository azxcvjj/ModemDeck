package callmedia

import (
	"fmt"
	"github.com/pion/webrtc/v4"
	"net"
	"strconv"
	"strings"
)

// A bridge-network container must advertise its published media address and
// use the same bounded UDP range mapped by Docker. Defaults remain unchanged.
func mediaNetworkSettings(address, ports string) (webrtc.SettingEngine, error) {
	var settings webrtc.SettingEngine
	address, ports = strings.TrimSpace(address), strings.TrimSpace(ports)
	if address == "" && ports == "" {
		return settings, nil
	}
	ip := net.ParseIP(address)
	if ip == nil || ip.To4() == nil || ip.IsUnspecified() || ip.IsMulticast() || ip.IsLoopback() {
		return settings, fmt.Errorf("MODEMDECK_MEDIA_ADVERTISE_IP must be a reachable unicast IPv4 address")
	}
	pair := strings.Split(ports, "-")
	if len(pair) != 2 {
		return settings, fmt.Errorf("MODEMDECK_MEDIA_UDP_RANGE must be min-max")
	}
	low, e1 := strconv.ParseUint(pair[0], 10, 16)
	high, e2 := strconv.ParseUint(pair[1], 10, 16)
	if e1 != nil || e2 != nil || low < 1024 || high < low {
		return settings, fmt.Errorf("invalid MODEMDECK_MEDIA_UDP_RANGE")
	}
	if err := settings.SetEphemeralUDPPortRange(uint16(low), uint16(high)); err != nil {
		return settings, err
	}
	settings.SetNAT1To1IPs([]string{ip.String()}, webrtc.ICECandidateTypeHost)
	settings.SetNetworkTypes([]webrtc.NetworkType{webrtc.NetworkTypeUDP4})
	return settings, nil
}
