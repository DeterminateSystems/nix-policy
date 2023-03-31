package verify

default allow := false

allow = true {
    expected := data.expected
    msg := input.message
    msg == expected
}
