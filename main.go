package main

import (
	"context"
	"fmt"
	"log"
	//"os"
	"syscall"
	"time"

	"github.com/containerd/containerd"
	"github.com/containerd/containerd/cio"
	"github.com/containerd/containerd/leases"
	"github.com/containerd/containerd/namespaces"
	"github.com/containerd/containerd/oci"
	"github.com/containerd/containerd/snapshots"
	// "github.com/opencontainers/image-spec/identity"
	specs "github.com/opencontainers/runtime-spec/specs-go"
	"github.com/sanity-io/litter"
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
	l, err := manager.Create(ctx, leases.WithRandomID(), leases.WithExpiration(time.Second*15))
	if err != nil {
		return fmt.Errorf("failed to create lease: %s", err)
	}

	// Update current context to add lease
	ctx = leases.WithLease(ctx, l.ID)

	baseImage, err := client.Pull(ctx, "docker.io/alexeldeib/test:dev", containerd.WithPullUnpack)
	if err != nil {
		return err
	}
	log.Printf("Successfully pulled %s image\n", baseImage.Name())

	userImage, err := client.Pull(ctx, "docker.io/library/hello-world:latest", containerd.WithPullSnapshotter("devmapper"), containerd.WithPullUnpack)
	if err != nil {
		return err
	}
	log.Printf("Successfully pulled %s image\n", userImage.Name())

	// if err := userImage.Unpack(ctx); err != nil {
	// 	return err
	// }
	// log.Printf("Successfully unpacked %s image\n", userImage.Name())

	desc, err := userImage.Config(ctx)
	if err != nil {
		return err
	}
	log.Printf("Successfully parsed image desc\n")

	// diffs, err := userImage.RootFS(ctx)
	// if err != nil {
	// 	return err
	// }
	// chainID := identity.ChainID(diffs)

	log.Printf("Successfully got desc id %s\n", desc.Digest.String())

	cs := client.ContentStore()
	info, err := cs.Info(ctx, desc.Digest)
	if err != nil {
		return err
	}
	log.Printf("Successfully parsed image info\n")

	litter.Dump(info)

	snapshotLabel, ok := info.Labels["containerd.io/gc.ref.snapshot.devmapper"]
	if !ok {
		return fmt.Errorf("failed to find snapshot label")
	}

	// baseImageSpec, err := baseImage.Spec(ctx)
	// if err != nil {
	// 	return err
	// }

	snapshotter := client.SnapshotService("devmapper")

	noGcOpt := snapshots.WithLabels(map[string]string{
		"containerd.io/gc.root": time.Now().UTC().Format(time.RFC3339),
	})

	mounts, err := snapshotter.Prepare(ctx, "instance", snapshotLabel, noGcOpt)
	if err != nil {
		return fmt.Errorf("failed to prepare snapshot: %v", err)
	}
	defer func() {
		if err := snapshotter.Remove(ctx, "instance"); err != nil {
			log.Printf("failed to remove snapshot: %v", err)
		}
	}()
	fmt.Printf("%#+v\n", mounts)

	if len(mounts) != 1 {
		return fmt.Errorf("expected 1 mount, found %d", len(mounts))
	}

	ociMounts := []specs.Mount{
		{
			Source:      mounts[0].Source,
			Destination: mounts[0].Source,
			Type:        "bind",
			Options:     []string{"rbind", "rw"},
		},
		{
			Source:      "/dev/kvm",
			Destination: "/dev/kvm",
			Type:        "bind",
			Options:     []string{"rbind", "rw"},
		},
	}

	container, err := client.NewContainer(
		ctx,
		"vmm",
		containerd.WithNewSnapshot("vmm-snapshot", baseImage),
		containerd.WithNewSpec(
			oci.WithDefaultSpec(),
			oci.WithImageConfig(baseImage),
			oci.WithDefaultUnixDevices,
			oci.WithAllDevicesAllowed,
			oci.WithHostDevices,
			oci.WithPrivileged,
			oci.WithMounts(ociMounts),
		),
	)
	if err != nil {
		return err
	}
	defer container.Delete(ctx, containerd.WithSnapshotCleanup)
	log.Printf("Successfully created container with ID %s and snapshot with ID vmm-snapshot", container.ID())

	task, err := container.NewTask(ctx, cio.NewCreator(cio.WithStdio))
	if err != nil {
		return err
	}
	defer task.Delete(ctx)

	// make sure we wait before calling start
	exitStatusC, err := task.Wait(ctx)
	if err != nil {
		fmt.Println(err)
	}

	// call start on the task to execute the redis server
	if err := task.Start(ctx); err != nil {
		return err
	}

	// sleep for a lil bit to see the logs
	time.Sleep(10 * time.Second)

	// kill the process and get the exit status
	if err := task.Kill(ctx, syscall.SIGTERM); err != nil {
		return err
	}

	// wait for the process to fully exit and print out the exit status

	status := <-exitStatusC
	code, _, err := status.Result()
	if err != nil {
		return err
	}
	fmt.Printf("vmm exited with status: %d\n", code)

	return nil
}
