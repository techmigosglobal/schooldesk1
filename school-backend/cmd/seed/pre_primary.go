package main

import (
	"school-backend/internal/database"
	"school-backend/internal/models"
)

func seedPrePrimaryTemplates(schoolID, yearID string) error {
	// Template for Playgroup
	playgroupTemplate := models.PrePrimaryTimetableTemplate{
		BaseModel:      models.BaseModel{ID: "template-playgroup"},
		SchoolID:       schoolID,
		AcademicYearID: yearID,
		Name:           "Playgroup Timetable",
	}
	if err := database.DB.Where("id = ?", playgroupTemplate.ID).FirstOrCreate(&playgroupTemplate).Error; err != nil {
		return err
	}

	// Template for Nursery
	nurseryTemplate := models.PrePrimaryTimetableTemplate{
		BaseModel:      models.BaseModel{ID: "template-nursery"},
		SchoolID:       schoolID,
		AcademicYearID: yearID,
		Name:           "Nursery Timetable",
	}
	if err := database.DB.Where("id = ?", nurseryTemplate.ID).FirstOrCreate(&nurseryTemplate).Error; err != nil {
		return err
	}

	// Template for PP1
	pp1Template := models.PrePrimaryTimetableTemplate{
		BaseModel:      models.BaseModel{ID: "template-pp1"},
		SchoolID:       schoolID,
		AcademicYearID: yearID,
		Name:           "PP1 Timetable",
	}
	if err := database.DB.Where("id = ?", pp1Template.ID).FirstOrCreate(&pp1Template).Error; err != nil {
		return err
	}

	// Days and Slots logic
	if err := seedPlaygroupDaysAndSlots(playgroupTemplate.ID); err != nil {
		return err
	}
	if err := seedNurseryDaysAndSlots(nurseryTemplate.ID); err != nil {
		return err
	}
	if err := seedPP1DaysAndSlots(pp1Template.ID); err != nil {
		return err
	}

	// We should also ensure Grades and Sections are created and linked
	if err := seedPrePrimaryGradesAndSections(schoolID, yearID, playgroupTemplate.ID, nurseryTemplate.ID, pp1Template.ID); err != nil {
		return err
	}

	return nil
}

// parseTime removed

func seedPlaygroupDaysAndSlots(templateID string) error {
	// Mon to Fri
	for day := 1; day <= 5; day++ {
		dayRecord := models.PrePrimaryTimetableDay{
			BaseModel:  models.BaseModel{ID: "day-playgroup-" + string(rune('0'+day))},
			TemplateID: templateID,
			DayOfWeek:  day,
		}
		if err := database.DB.Where("id = ?", dayRecord.ID).FirstOrCreate(&dayRecord).Error; err != nil {
			return err
		}

		// Slots
		slots := []models.PrePrimaryTimetableSlot{
			{StartTime: "09:00", EndTime: "09:20", ActivityName: "Welcome"},
			{StartTime: "09:20", EndTime: "09:50", ActivityName: "Circle Time"},
			{StartTime: "09:50", EndTime: "10:05", ActivityName: "Snack Time", IsBreak: true},
			{StartTime: "10:05", EndTime: "10:20", ActivityName: "IGNITE Math"},
			{StartTime: "10:20", EndTime: "10:35", ActivityName: "IGNITE Lang"},
			{StartTime: "10:35", EndTime: "11:05", ActivityName: "Fit & Fabulous"},
			{StartTime: "11:05", EndTime: "11:15", ActivityName: "Story Time"},
			{StartTime: "11:15", EndTime: "11:30", ActivityName: "Recall & Dispersal"},
		}

		for i, slot := range slots {
			slot.ID = dayRecord.ID + "-slot-" + string(rune('0'+i))
			slot.DayID = dayRecord.ID
			if err := database.DB.Where("id = ?", slot.ID).FirstOrCreate(&slot).Error; err != nil {
				return err
			}
		}
	}
	return nil
}

func seedNurseryDaysAndSlots(templateID string) error {
	// Mon to Fri
	for day := 1; day <= 5; day++ {
		dayRecord := models.PrePrimaryTimetableDay{
			BaseModel:  models.BaseModel{ID: "day-nursery-" + string(rune('0'+day))},
			TemplateID: templateID,
			DayOfWeek:  day,
		}
		if err := database.DB.Where("id = ?", dayRecord.ID).FirstOrCreate(&dayRecord).Error; err != nil {
			return err
		}

		// Slots
		slots := []models.PrePrimaryTimetableSlot{
			{StartTime: "08:30", EndTime: "08:45", ActivityName: "Welcome / Free Play"},
			{StartTime: "08:45", EndTime: "09:25", ActivityName: "Circle Time"},
			{StartTime: "09:25", EndTime: "09:40", ActivityName: "Snack Time", IsBreak: true},
			{StartTime: "09:40", EndTime: "10:05", ActivityName: "IGNITE Math"},
			{StartTime: "10:05", EndTime: "10:30", ActivityName: "IGNITE Lang"},
			{StartTime: "10:30", EndTime: "11:00", ActivityName: "Fit & Fabulous / Sand / Water"},
			{StartTime: "11:00", EndTime: "11:20", ActivityName: "Creative Corners / Sensorial"},
			{StartTime: "11:20", EndTime: "11:45", ActivityName: "Lunch", IsBreak: true},
			{StartTime: "11:45", EndTime: "12:15", ActivityName: "Relaxation / Nap"},
			{StartTime: "12:15", EndTime: "12:30", ActivityName: "Recall / Dispersal"},
		}

		for i, slot := range slots {
			slot.ID = dayRecord.ID + "-slot-" + string(rune('0'+i))
			slot.DayID = dayRecord.ID
			if err := database.DB.Where("id = ?", slot.ID).FirstOrCreate(&slot).Error; err != nil {
				return err
			}
		}
	}
	return nil
}

func seedPP1DaysAndSlots(templateID string) error {
	// Mon to Fri
	for day := 1; day <= 5; day++ {
		dayRecord := models.PrePrimaryTimetableDay{
			BaseModel:  models.BaseModel{ID: "day-pp1-" + string(rune('0'+day))},
			TemplateID: templateID,
			DayOfWeek:  day,
		}
		if err := database.DB.Where("id = ?", dayRecord.ID).FirstOrCreate(&dayRecord).Error; err != nil {
			return err
		}

		// Slots
		slots := []models.PrePrimaryTimetableSlot{
			{StartTime: "08:30", EndTime: "08:45", ActivityName: "Welcome / Reading Corners"},
			{StartTime: "08:45", EndTime: "09:20", ActivityName: "Circle Time"},
			{StartTime: "09:20", EndTime: "09:35", ActivityName: "Snack Time", IsBreak: true},
			{StartTime: "09:35", EndTime: "10:05", ActivityName: "IGNITE Math"},
			{StartTime: "10:05", EndTime: "10:35", ActivityName: "IGNITE Lang"},
			{StartTime: "10:35", EndTime: "11:05", ActivityName: "Fit & Fabulous / Play area"},
			{StartTime: "11:05", EndTime: "11:35", ActivityName: "IGNITE General Awareness"},
			{StartTime: "11:35", EndTime: "12:00", ActivityName: "Lunch", IsBreak: true},
			{StartTime: "12:00", EndTime: "12:15", ActivityName: "Relaxation"},
			{StartTime: "12:15", EndTime: "12:30", ActivityName: "Recall / Dispersal"},
		}

		for i, slot := range slots {
			slot.ID = dayRecord.ID + "-slot-" + string(rune('0'+i))
			slot.DayID = dayRecord.ID
			if err := database.DB.Where("id = ?", slot.ID).FirstOrCreate(&slot).Error; err != nil {
				return err
			}
		}
	}
	return nil
}

func seedPrePrimaryGradesAndSections(schoolID, yearID, pgTemplateID, nurseryTemplateID, pp1TemplateID string) error {
	// Playgroup
	pgGrade := models.Grade{
		BaseModel:   models.BaseModel{ID: "grade-default-playgroup"},
		SchoolID:    schoolID,
		GradeNumber: -2,
		GradeName:   "Playgroup",
	}
	if err := database.DB.Where("id = ?", pgGrade.ID).FirstOrCreate(&pgGrade).Error; err != nil {
		return err
	}

	pgSection := models.Section{
		BaseModel:                     models.BaseModel{ID: "section-default-playgroup-a"},
		GradeID:                       pgGrade.ID,
		AcademicYearID:                yearID,
		SchoolID:                      schoolID,
		SectionName:                   "A",
		Capacity:                      30,
		PrePrimaryTimetableTemplateID: &pgTemplateID,
	}
	if err := database.DB.Where("id = ?", pgSection.ID).FirstOrCreate(&pgSection).Error; err != nil {
		return err
	}
	database.DB.Model(&pgSection).Update("pre_primary_timetable_template_id", pgTemplateID)

	// Nursery
	nurseryGrade := models.Grade{
		BaseModel:   models.BaseModel{ID: "grade-default-nursery"},
		SchoolID:    schoolID,
		GradeNumber: -1,
		GradeName:   "Nursery",
	}
	if err := database.DB.Where("id = ?", nurseryGrade.ID).FirstOrCreate(&nurseryGrade).Error; err != nil {
		return err
	}

	nurserySection := models.Section{
		BaseModel:                     models.BaseModel{ID: "section-default-nursery-a"},
		GradeID:                       nurseryGrade.ID,
		AcademicYearID:                yearID,
		SchoolID:                      schoolID,
		SectionName:                   "A",
		Capacity:                      30,
		PrePrimaryTimetableTemplateID: &nurseryTemplateID,
	}
	if err := database.DB.Where("id = ?", nurserySection.ID).FirstOrCreate(&nurserySection).Error; err != nil {
		return err
	}
	database.DB.Model(&nurserySection).Update("pre_primary_timetable_template_id", nurseryTemplateID)

	// PP1 Section assignment to PP1 template
	// PP1 Grade and Section A were seeded in seedAcademicFixtures, let's just update Section A
	pp1Section := models.Section{BaseModel: models.BaseModel{ID: "section-default-pp1a"}}
	if err := database.DB.Where("id = ?", pp1Section.ID).First(&pp1Section).Error; err == nil {
		database.DB.Model(&pp1Section).Update("pre_primary_timetable_template_id", pp1TemplateID)
	}

	return nil
}
