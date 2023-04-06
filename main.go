package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/containerd/containerd"
	"github.com/containerd/containerd/leases"
	"github.com/containerd/containerd/namespaces"
	"github.com/containerd/containerd/snapshots"
)

func main() {
	if err := run(); err != nil {
		log.Fatal(err)
	}
}

func run() error {
	ctx := namespaces.WithNamespace(context.Background(), "example")

	client, err := containerd.New("/run/containerd/containerd.sock")
	if err != nil {
		return err
	}
	defer client.Close()

	manager := client.LeasesService()
	l, err := manager.Create(ctx, leases.WithRandomID(), leases.WithExpiration(time.Second*10))
	if err != nil {
		return fmt.Errorf("failed to create lease: %s", err)
	}

	// Update current context to add lease
	ctx = leases.WithLease(ctx, l.ID)

	// ctx, done, err := client.WithLease(ctx)
	// if err != nil {
	// 	return err
	// }
	// defer done(ctx)

	snapshotter := client.SnapshotService("overlayfs")
	tmpDir := "/tmp/unpack"

	err = os.MkdirAll(tmpDir, 0666)
	if err != nil {
		return err
	}

	defer os.RemoveAll(tmpDir)

	layerPath := "/opt/fc/images/layer.tar" // just a path to layer tar file.
	noGcOpt := snapshots.WithLabels(map[string]string{
		// "containerd.io/gc.root": time.Now().UTC().Format(time.RFC3339),
	})

	mounts, err := snapshotter.Prepare(ctx, "foo", "", noGcOpt)
	if err != nil {
		return fmt.Errorf("failed to prepare snapshot: %v", err)
	}

	_, _ = layerPath, mounts

	// fmt.Printf("%#+v\n", mounts)

	// if err := mount.All(mounts, tmpDir); err != nil {
	// 	return fmt.Errorf("failed to mount all: %v", err)
	// }
	// defer mount.UnmountAll(tmpDir, 0)

	// layer, err := os.Open(layerPath)
	// if err != nil {
	// 	return fmt.Errorf("failed to open layer: %v", err)
	// }

	// _, err = archive.UnpackLayer(tmpDir, layer, nil) // unpack into layer location
	// if err != nil {
	// 	return fmt.Errorf("failed to unpack layer: %v", err)
	// }

	// // at this point you'd *think* tmpDir would have the unpacked layer.
	// // but it doesn't. it's empty. why?
	// // we took an empty parent layer, prepared it, and mounted the snapshot.
	// // we mounted the snapshotter dir over the target dir.
	// // we end up unpacking into the snapshot dir instead (I think?).
	// // otherwise we'd see the mounted contents of the parent layers,
	// // while our writes would still go to the active snapshot.

	// if err := snapshotter.Commit(ctx, "bar", "foo", noGcOpt); err != nil {
	// 	return fmt.Errorf("failed to commit snapshot: %v", err)
	// }

	// at this point the original snapshot is gone, but the new one could be seen in storage
	// ctr -n example snapshot ls
	// to clean up:
	// ctr -n example snapshot rm foo

	return nil
}
