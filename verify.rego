package verify

default allow := false

allow {
    msg := input.message
    msg == "hello"
}
