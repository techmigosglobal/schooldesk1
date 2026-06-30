package models

import (
	"database/sql/driver"
	"encoding/json"
	"fmt"
)

// StringArray is a slice of strings stored as JSON in the database.
// It implements driver.Valuer/sql.Scanner so GORM can persist it in a
// text/json column, and it always marshals to a JSON array (never null).
type StringArray []string

// Value implements driver.Valuer.
func (a StringArray) Value() (driver.Value, error) {
	if a == nil {
		return []byte("[]"), nil
	}
	return json.Marshal(a)
}

// Scan implements sql.Scanner.
func (a *StringArray) Scan(value interface{}) error {
	if value == nil {
		*a = nil
		return nil
	}
	var bytes []byte
	switch v := value.(type) {
	case []byte:
		bytes = v
	case string:
		bytes = []byte(v)
	default:
		return fmt.Errorf("cannot scan %T into StringArray", value)
	}
	if len(bytes) == 0 {
		*a = nil
		return nil
	}
	return json.Unmarshal(bytes, (*[]string)(a))
}

// MarshalJSON outputs an empty array instead of null for nil slices.
func (a StringArray) MarshalJSON() ([]byte, error) {
	if a == nil {
		return []byte("[]"), nil
	}
	return json.Marshal([]string(a))
}
