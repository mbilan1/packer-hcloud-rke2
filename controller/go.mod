module github.com/mbilan1/packer-hcloud-rke2/controller

go 1.23

require (
	k8s.io/api v0.32.0
	k8s.io/apimachinery v0.32.0
	sigs.k8s.io/controller-runtime v0.20.0
)

// NOTE: Run `go mod tidy` to populate go.sum and resolve transitive dependencies.
// This go.mod declares only direct imports; controller-runtime brings in client-go,
// structured-merge-diff, etc. transitively.
