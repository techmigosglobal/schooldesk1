package repositories

import (
	"strings"

	"school-backend/internal/models"

	"gorm.io/gorm"
)

type AcademicRepository struct {
	db *gorm.DB
}

func NewAcademicRepository(db *gorm.DB) *AcademicRepository {
	return &AcademicRepository{db: db}
}

func (r *AcademicRepository) AcademicYear(schoolID, academicYearID string) (models.AcademicYear, error) {
	var year models.AcademicYear
	err := r.db.First(&year, "id = ? AND school_id = ?", strings.TrimSpace(academicYearID), strings.TrimSpace(schoolID)).Error
	return year, err
}

func (r *AcademicRepository) GradeExists(schoolID, gradeID string) bool {
	return r.exists(&models.Grade{}, "id = ? AND school_id = ?", strings.TrimSpace(gradeID), strings.TrimSpace(schoolID))
}

func (r *AcademicRepository) SubjectExists(schoolID, subjectID string) bool {
	return r.exists(&models.Subject{}, "id = ? AND school_id = ?", strings.TrimSpace(subjectID), strings.TrimSpace(schoolID))
}

func (r *AcademicRepository) StaffExists(schoolID, staffID string) bool {
	return r.exists(&models.Staff{}, "id = ? AND school_id = ? AND status = ?", strings.TrimSpace(staffID), strings.TrimSpace(schoolID), "active")
}

func (r *AcademicRepository) Section(schoolID, sectionID string) (models.Section, error) {
	var section models.Section
	err := r.db.Joins("JOIN grades ON grades.id = sections.grade_id").
		First(&section, "sections.id = ? AND grades.school_id = ?", strings.TrimSpace(sectionID), strings.TrimSpace(schoolID)).Error
	return section, err
}

func (r *AcademicRepository) GradeSubjectExists(schoolID, academicYearID, gradeID, subjectID string) bool {
	return r.exists(&models.GradeSubject{},
		"school_id = ? AND academic_year_id = ? AND grade_id = ? AND subject_id = ?",
		strings.TrimSpace(schoolID),
		strings.TrimSpace(academicYearID),
		strings.TrimSpace(gradeID),
		strings.TrimSpace(subjectID),
	)
}

func (r *AcademicRepository) StaffSubjectExists(schoolID, academicYearID, staffID, subjectID, gradeID, sectionID string) bool {
	query := r.db.Model(&models.StaffSubject{}).
		Where("school_id = ? AND academic_year_id = ? AND staff_id = ? AND subject_id = ? AND grade_id = ?",
			strings.TrimSpace(schoolID),
			strings.TrimSpace(academicYearID),
			strings.TrimSpace(staffID),
			strings.TrimSpace(subjectID),
			strings.TrimSpace(gradeID),
		)
	if strings.TrimSpace(sectionID) != "" {
		query = query.Where("(section_id = ? OR section_id IS NULL OR section_id = '')", strings.TrimSpace(sectionID))
	}
	var count int64
	_ = query.Count(&count).Error
	return count > 0
}

func (r *AcademicRepository) exists(model interface{}, query string, args ...interface{}) bool {
	var count int64
	_ = r.db.Model(model).Where(query, args...).Count(&count).Error
	return count > 0
}
