package verify

default allow := false

allow {
    x := input.message
    x == data.world
}
