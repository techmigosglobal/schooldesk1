package handlers

import (
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"

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
		".mp4": true, ".mov": true, ".m4v": true, ".webm": true,
	}
	if !allowed[ext] {
		fail(c, http.StatusBadRequest, "Unsupported file type. Allowed: jpg, png, webp, pdf, doc, docx, mp4, mov, m4v, webm")
		return
	}
	maxSize := int64(15 * 1024 * 1024)
	if ext == ".mp4" || ext == ".mov" || ext == ".m4v" || ext == ".webm" {
		maxSize = 50 * 1024 * 1024
	}
	if file.Size > maxSize {
		fail(c, http.StatusBadRequest, "Uploaded file is too large")
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
	publishedPath := "/" + dest
	if bytes, err := os.ReadFile(dest); err == nil && database.DB != nil {
		record := models.UploadedFile{}
		values := models.UploadedFile{
			SchoolID:     schoolID,
			Path:         publishedPath,
			OriginalName: file.Filename,
			ContentType:  file.Header.Get("Content-Type"),
			Size:         file.Size,
			Data:         bytes,
		}
		_ = database.DB.Where("path = ?", publishedPath).
			Assign(values).
			FirstOrCreate(&record)
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"url":     publishedPath,
		"name":    file.Filename,
		"size":    file.Size,
	})
}

// DownloadFile serves uploaded files through the API surface.
// GET /api/v1/uploads/*filepath
func (h *UploadHandler) DownloadFile(c *gin.Context) {
	rawPath := strings.TrimPrefix(c.Param("filepath"), "/")
	if rawPath == "" {
		fail(c, http.StatusBadRequest, "File path is required")
		return
	}

	uploadRoot, err := filepath.Abs("uploads")
	if err != nil {
		fail(c, http.StatusInternalServerError, "Failed to resolve upload storage")
		return
	}
	fullPath, err := filepath.Abs(filepath.Join(uploadRoot, filepath.Clean(rawPath)))
	if err != nil {
		fail(c, http.StatusBadRequest, "Invalid file path")
		return
	}
	if fullPath != uploadRoot && !strings.HasPrefix(fullPath, uploadRoot+string(os.PathSeparator)) {
		fail(c, http.StatusBadRequest, "Invalid file path")
		return
	}
	if _, err := os.Stat(fullPath); err != nil {
		if os.IsNotExist(err) {
			if h.downloadFromDatabase(c, rawPath) {
				return
			}
			fail(c, http.StatusNotFound, "File not found")
			return
		}
		fail(c, http.StatusInternalServerError, "Failed to read file")
		return
	}

	c.File(fullPath)
}

func (h *UploadHandler) downloadFromDatabase(c *gin.Context, rawPath string) bool {
	if database.DB == nil {
		return false
	}
	candidates := []string{"/uploads/" + rawPath, "uploads/" + rawPath}
	var file models.UploadedFile
	if err := database.DB.Where("path IN ?", candidates).First(&file).Error; err != nil {
		return false
	}
	contentType := file.ContentType
	if contentType == "" {
		contentType = http.DetectContentType(file.Data)
	}
	c.Data(http.StatusOK, contentType, file.Data)
	return true
}
