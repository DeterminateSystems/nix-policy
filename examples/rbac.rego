package rbac

default allow := false

allow = true {
    expected := data.expected
    msg := input.password
    msg == expected
}
