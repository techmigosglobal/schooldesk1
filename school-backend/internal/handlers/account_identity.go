package handlers

import "strings"

func accountUsername(username, email string) string {
	cleanUsername := strings.TrimSpace(username)
	if cleanUsername != "" {
		return cleanUsername
	}
	return strings.TrimSpace(email)
}

func loginIdentityValues(username, email string) []string {
	seen := map[string]bool{}
	values := []string{}
	for _, value := range []string{username, email} {
		clean := strings.ToLower(strings.TrimSpace(value))
		if clean == "" || seen[clean] {
			continue
		}
		seen[clean] = true
		values = append(values, clean)
	}
	return values
}
