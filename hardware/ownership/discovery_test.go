package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestScannerDiscoversPortsBelowStablePhysicalDevice(t *testing.T) {
	root := t.TempDir()
	sysRoot := filepath.Join(root, "sys")
	devRoot := filepath.Join(root, "dev")
	udevRoot := filepath.Join(root, "run", "udev", "data")
	physical := filepath.Join(
		sysRoot,
		"devices",
		"pci0000:00",
		"0000:00:14.0",
		"usb1",
		"1-2",
	)
	portPath := filepath.Join(physical, "1-2:1.0", "ttyUSB0")

	for _, path := range []string{
		filepath.Join(sysRoot, "bus", "usb", "devices"),
		filepath.Join(sysRoot, "class", "tty"),
		portPath,
		devRoot,
		udevRoot,
	} {
		if err := os.MkdirAll(path, 0o755); err != nil {
			t.Fatal(err)
		}
	}
	for name, value := range map[string]string{
		"idVendor":  "2c7c\n",
		"idProduct": "0125\n",
		"serial":    "stable-serial\n",
	} {
		if err := os.WriteFile(filepath.Join(physical, name), []byte(value), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	if err := os.WriteFile(filepath.Join(portPath, "dev"), []byte("188:0\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(udevRoot, "c188:0"), []byte("E:ID_MM_CANDIDATE=1\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(physical, filepath.Join(sysRoot, "bus", "usb", "devices", "1-2")); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(portPath, filepath.Join(sysRoot, "class", "tty", "ttyUSB0")); err != nil {
		t.Fatal(err)
	}

	scanner, err := newSysfsScanner(sysRoot, devRoot, udevRoot)
	if err != nil {
		t.Fatal(err)
	}
	devices, err := scanner.scanUSBDevices()
	if err != nil {
		t.Fatal(err)
	}
	if len(devices) != 1 {
		t.Fatalf("devices = %+v", devices)
	}
	device := devices[0]
	if device.Serial != "stable-serial" ||
		device.PortPath != "/devices/pci0000:00/0000:00:14.0/usb1/1-2" {
		t.Fatalf("device = %+v", device)
	}
	if len(device.Ports) != 1 ||
		device.Ports[0].Subsystem != "tty" ||
		device.Ports[0].Name != "ttyUSB0" ||
		device.Ports[0].UDevKey != "c188:0" {
		t.Fatalf("ports = %+v", device.Ports)
	}
}

func TestSysfsBackendRequiresExplicitOptIn(t *testing.T) {
	root := t.TempDir()
	sysRoot := filepath.Join(root, "sys")
	devRoot := filepath.Join(root, "dev")
	missing := filepath.Join(root, "missing-udev")
	for _, p := range []string{sysRoot, devRoot} {
		if err := os.MkdirAll(p, 0755); err != nil {
			t.Fatal(err)
		}
	}
	if _, err := newSysfsScanner(sysRoot, devRoot, missing); err == nil {
		t.Fatal("udev must fail closed")
	}
	if _, err := newSysfsScannerWithBackend(sysRoot, devRoot, missing, "sysfs"); err != nil {
		t.Fatal(err)
	}
	if _, err := newSysfsScannerWithBackend(sysRoot, devRoot, missing, "auto"); err == nil {
		t.Fatal("unknown backend accepted")
	}
}

func TestSysfsReadinessChecksLiveKernelIdentity(t *testing.T) {
	root := t.TempDir()
	sysRoot := filepath.Join(root, "sys")
	devRoot := filepath.Join(root, "dev")
	physical := filepath.Join(sysRoot, "devices", "usb1", "1-2", "net", "wwan0")
	for _, p := range []string{physical, filepath.Join(sysRoot, "class", "net"), devRoot} {
		if err := os.MkdirAll(p, 0755); err != nil {
			t.Fatal(err)
		}
	}
	if err := os.Symlink(physical, filepath.Join(sysRoot, "class", "net", "wwan0")); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(physical, "ifindex"), []byte("9\n"), 0644); err != nil {
		t.Fatal(err)
	}
	scanner, err := newSysfsScannerWithBackend(sysRoot, devRoot, "/absent", "sysfs")
	if err != nil {
		t.Fatal(err)
	}
	port := kernelPort{Subsystem: "net", Name: "wwan0", UDevKey: "n9"}
	if err := scanner.checkPortReady(port); err != nil {
		t.Fatal(err)
	}
	port.UDevKey = "n10"
	if err := scanner.checkPortReady(port); err == nil {
		t.Fatal("stale kernel identity accepted")
	}
	port.UDevKey = "n9"
	port.DevNode = filepath.Join(devRoot, "fake")
	if err := os.WriteFile(port.DevNode, []byte("not a device"), 0644); err != nil {
		t.Fatal(err)
	}
	if err := scanner.checkPortReady(port); err == nil {
		t.Fatal("regular file accepted as device")
	}
}

func TestSysfsReadinessRejectsMismatchedCharacterDevice(t *testing.T) {
	root := t.TempDir()
	sysRoot := filepath.Join(root, "sys")
	devRoot := filepath.Join(root, "dev")
	physical := filepath.Join(sysRoot, "devices", "usb1", "1-2", "ttyUSB0")
	for _, p := range []string{physical, filepath.Join(sysRoot, "class", "tty"), devRoot} {
		if err := os.MkdirAll(p, 0755); err != nil {
			t.Fatal(err)
		}
	}
	if err := os.Symlink(physical, filepath.Join(sysRoot, "class", "tty", "ttyUSB0")); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(physical, "dev"), []byte("188:0"), 0644); err != nil {
		t.Fatal(err)
	}
	node := filepath.Join(devRoot, "ttyUSB0")
	if err := os.Symlink("/dev/null", node); err != nil {
		t.Fatal(err)
	}
	scanner, err := newSysfsScannerWithBackend(sysRoot, devRoot, "/absent", "sysfs")
	if err != nil {
		t.Fatal(err)
	}
	if err := scanner.checkPortReady(kernelPort{Subsystem: "tty", Name: "ttyUSB0", UDevKey: "c188:0", DevNode: node}); err == nil {
		t.Fatal("wrong character device accepted")
	}
}
