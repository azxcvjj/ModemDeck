package callmedia

import (
	"github.com/pion/webrtc/v4"
	"strings"
	"testing"
	"time"
)

func TestMediaNetworkSettings(t *testing.T) {
	for _, v := range []struct {
		ip, ports string
		ok        bool
	}{
		{"", "", true}, {"192.0.2.1", "40000-40015", true},
		{"", "40000-40015", false}, {"192.0.2.1", "", false},
		{"0.0.0.0", "40000-40015", false}, {"127.0.0.1", "40000-40015", false},
		{"192.0.2.1", "40015-40000", false}, {"192.0.2.1", "1-2", false},
		{"192.0.2.1", "65536-65537", false}, {"192.0.2.1", "bad", false},
	} {
		_, err := mediaNetworkSettings(v.ip, v.ports)
		if (err == nil) != v.ok {
			t.Errorf("%q %q: %v", v.ip, v.ports, err)
		}
	}
}

func TestMediaNetworkAdvertisesPublishedCandidate(t *testing.T) {
	t.Setenv("MODEMDECK_MEDIA_ADVERTISE_IP", "192.0.2.10")
	t.Setenv("MODEMDECK_MEDIA_UDP_RANGE", "40000-40015")
	api, err := newWebRTCAPI()
	if err != nil {
		t.Fatal(err)
	}
	pc, err := api.NewPeerConnection(webrtc.Configuration{})
	if err != nil {
		t.Fatal(err)
	}
	defer pc.Close()
	if _, err = pc.CreateDataChannel("probe", nil); err != nil {
		t.Fatal(err)
	}
	offer, err := pc.CreateOffer(nil)
	if err != nil {
		t.Fatal(err)
	}
	done := webrtc.GatheringCompletePromise(pc)
	if err = pc.SetLocalDescription(offer); err != nil {
		t.Fatal(err)
	}
	select {
	case <-done:
	case <-time.After(5 * time.Second):
		t.Fatal("ICE gathering timeout")
	}
	found := false
	for _, line := range strings.Split(pc.LocalDescription().SDP, "\n") {
		if strings.HasPrefix(line, "a=candidate:") {
			fields := strings.Fields(line)
			if len(fields) < 6 || fields[4] != "192.0.2.10" {
				t.Fatalf("unexpected candidate: %s", line)
			}
			found = true
		}
	}
	if !found {
		t.Fatal("no published ICE candidate")
	}
}
