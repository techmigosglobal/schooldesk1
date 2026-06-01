package services

import (
	"errors"
	"strings"

	"school-backend/internal/repositories"
)

var (
	ErrAcademicYearNotFound = errors.New("academic year must belong to this school")
	ErrAcademicYearReadOnly = errors.New("academic year is closed or archived and cannot be modified")
)

type AcademicDomainService struct {
	repo *repositories.AcademicRepository
}

func NewAcademicDomainService(repo *repositories.AcademicRepository) *AcademicDomainService {
	return &AcademicDomainService{repo: repo}
}

func (s *AcademicDomainService) EnsureAcademicYearWritable(schoolID, academicYearID string) error {
	year, err := s.repo.AcademicYear(schoolID, academicYearID)
	if err != nil {
		return ErrAcademicYearNotFound
	}
	switch strings.ToLower(strings.TrimSpace(year.Status)) {
	case "completed", "archived", "closed":
		return ErrAcademicYearReadOnly
	default:
		return nil
	}
}

func (s *AcademicDomainService) ValidateSectionContext(schoolID, academicYearID, sectionID string) (string, error) {
	section, err := s.repo.Section(schoolID, sectionID)
	if err != nil {
		return "", errors.New("section must belong to this school")
	}
	if strings.TrimSpace(section.AcademicYearID) != strings.TrimSpace(academicYearID) {
		return "", errors.New("section must belong to the selected academic year")
	}
	return section.GradeID, nil
}

func (s *AcademicDomainService) ValidateGradeSubjectMapping(schoolID, academicYearID, gradeID, subjectID string) error {
	if err := s.EnsureAcademicYearWritable(schoolID, academicYearID); err != nil {
		return err
	}
	if !s.repo.GradeExists(schoolID, gradeID) {
		return errors.New("grade must belong to this school")
	}
	if !s.repo.SubjectExists(schoolID, subjectID) {
		return errors.New("subject must belong to this school")
	}
	return nil
}

func (s *AcademicDomainService) ValidateStaffSubjectAssignment(schoolID, academicYearID, staffID, subjectID, gradeID, sectionID string) error {
	if err := s.ValidateGradeSubjectMapping(schoolID, academicYearID, gradeID, subjectID); err != nil {
		return err
	}
	if !s.repo.StaffExists(schoolID, staffID) {
		return errors.New("staff must be active staff in this school")
	}
	if strings.TrimSpace(sectionID) != "" {
		sectionGradeID, err := s.ValidateSectionContext(schoolID, academicYearID, sectionID)
		if err != nil {
			return err
		}
		if strings.TrimSpace(sectionGradeID) != strings.TrimSpace(gradeID) {
			return errors.New("section must belong to the selected grade")
		}
	}
	if !s.repo.GradeSubjectExists(schoolID, academicYearID, gradeID, subjectID) {
		return errors.New("subject must be mapped to this grade for the academic year")
	}
	if !s.repo.StaffSubjectExists(schoolID, academicYearID, staffID, subjectID, gradeID, sectionID) {
		return errors.New("staff must be assigned to this subject for the academic year")
	}
	return nil
}

func (s *AcademicDomainService) ValidateTimetableSlotRefs(schoolID, academicYearID, sectionID, subjectID, staffID string) error {
	gradeID, err := s.ValidateSectionContext(schoolID, academicYearID, sectionID)
	if err != nil {
		return err
	}
	return s.ValidateStaffSubjectAssignment(schoolID, academicYearID, staffID, subjectID, gradeID, sectionID)
}
