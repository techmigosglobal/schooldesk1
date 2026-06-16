package handlers

import (
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

type UploadHandler struct{}

func NewUploadHandler() *UploadHandler { return &UploadHandler{} }

// UploadFile handles multipart file upload for teachers (event posts, lesson planners).
// POST /api/v1/uploads
// Form field: "file"
// Returns: { "url": "/uploads/shared/<school>/<filename>" }
func (h *UploadHandler) UploadFile(c *gin.Context) {
	file, err := c.FormFile("file")
	if err != nil {
		fail(c, http.StatusBadRequest, "No file provided (field: file)")
		return
	}

	ext := strings.ToLower(filepath.Ext(file.Filename))
	allowed := map[string]bool{
		".jpg": true, ".jpeg": true, ".png": true, ".webp": true,
		".pdf": true, ".doc": true, ".docx": true,
	}
	if !allowed[ext] {
		fail(c, http.StatusBadRequest, "Unsupported file type. Allowed: jpg, png, pdf, doc, docx")
		return
	}

	schoolID := scopedSchoolID(c)
	dir := filepath.Join("uploads", "shared", schoolID)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		fail(c, http.StatusInternalServerError, "Failed to prepare upload storage")
		return
	}

	filename := fmt.Sprintf("%d_%s%s", time.Now().UnixNano(),
		strings.TrimSuffix(filepath.Base(file.Filename), ext), ext)
	dest := filepath.ToSlash(filepath.Join(dir, filename))

	if err := c.SaveUploadedFile(file, dest); err != nil {
		fail(c, http.StatusInternalServerError, "Failed to save file")
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"url":     "/" + dest,
		"name":    file.Filename,
		"size":    file.Size,
	})
}
