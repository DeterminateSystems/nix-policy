package rbac

default allow := false

allow = true {
    expected := data.expected
    password := input.password
    password == expected
}
