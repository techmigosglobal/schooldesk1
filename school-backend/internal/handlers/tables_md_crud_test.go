package handlers

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"school-backend/internal/database"

	"github.com/gin-gonic/gin"
)

func TestTablesMDCRUDHandlerUsesCustomPrimaryKeyAndSchoolScope(t *testing.T) {
	if err := database.SetupTestDB(); err != nil {
		t.Fatalf("setup test db: %v", err)
	}

	gin.SetMode(gin.TestMode)
	handler := NewTablesMDCRUDHandler(TablesMDResource{
		Module:       "classes",
		Table:        "classes",
		PrimaryKey:   "class_id",
		SchoolScoped: true,
		Required:     []string{"class_name"},
		Columns:      TablesMDColumns["classes"],
	})

	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set("school_id", "school-from-token")
		c.Set("user_id", "principal-user")
		c.Set("role_name", "Principal")
		c.Next()
	})
	router.POST("/classes", handler.Create)
	router.GET("/classes/:id", handler.Get)

	create := httptest.NewRecorder()
	router.ServeHTTP(create, httptest.NewRequest(
		http.MethodPost,
		"/classes",
		bytes.NewBufferString(`{"class_id":"class-pp1-a","school_id":"client-school","class_name":"PP1 A","academic_year_id":"year-1"}`),
	))
	if create.Code != http.StatusCreated {
		t.Fatalf("create status=%d body=%s", create.Code, create.Body.String())
	}

	var row map[string]interface{}
	if err := database.DB.Table("classes").Where("class_id = ?", "class-pp1-a").Take(&row).Error; err != nil {
		t.Fatalf("load created class: %v", err)
	}
	if got := row["school_id"]; got != "school-from-token" {
		t.Fatalf("school_id=%v, want token school scope", got)
	}

	get := httptest.NewRecorder()
	router.ServeHTTP(get, httptest.NewRequest(http.MethodGet, "/classes/class-pp1-a", nil))
	if get.Code != http.StatusOK {
		t.Fatalf("get status=%d body=%s", get.Code, get.Body.String())
	}

	var response struct {
		Success bool                   `json:"success"`
		Data    map[string]interface{} `json:"data"`
	}
	if err := json.Unmarshal(get.Body.Bytes(), &response); err != nil {
		t.Fatalf("decode get response: %v", err)
	}
	if !response.Success || response.Data["class_id"] != "class-pp1-a" {
		t.Fatalf("unexpected response: %+v", response)
	}
}
