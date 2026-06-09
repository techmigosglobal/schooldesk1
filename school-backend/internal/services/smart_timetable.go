package services

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"sort"
	"strconv"
	"strings"
	"time"

	"school-backend/internal/models"

	"gorm.io/gorm"
)

type SmartTimetableEngine struct {
	db *gorm.DB
}

func NewSmartTimetableEngine(db *gorm.DB) *SmartTimetableEngine {
	return &SmartTimetableEngine{db: db}
}

type SmartTimetableRequest struct {
	SectionID             string                   `json:"section_id"`
	AcademicYearID        string                   `json:"academic_year_id"`
	TermID                string                   `json:"term_id"`
	Mode                  string                   `json:"mode"`
	Days                  []int                    `json:"days"`
	PeriodsPerDay         int                      `json:"periods_per_day"`
	StartTime             string                   `json:"start_time"`
	PeriodDurationMinutes int                      `json:"period_duration_minutes"`
	GapMinutes            int                      `json:"gap_minutes"`
	Breaks                []map[string]interface{} `json:"breaks"`
	RegenerateScope       bool                     `json:"regenerate_scope"`
}

type SmartTimetablePlan struct {
	JobID       string                       `json:"job_id,omitempty"`
	Stages      []SmartTimetableStage        `json:"stages"`
	Summary     SmartTimetableSummary        `json:"summary"`
	Suggestions []SmartTimetableSuggestion   `json:"suggestions"`
	Conflicts   []SmartTimetableConflict     `json:"conflicts"`
	Logs        []SmartTimetableLog          `json:"logs"`
	Template    SmartTimetableTemplateConfig `json:"template"`
}

type SmartTimetableStage struct {
	Label  string `json:"label"`
	Status string `json:"status"`
}

type SmartTimetableSummary struct {
	Sections             int `json:"sections"`
	WorkingDays          int `json:"working_days"`
	PeriodsPerDay        int `json:"periods_per_day"`
	RequestedSlots       int `json:"requested_slots"`
	ExistingSlots        int `json:"existing_slots"`
	SuggestedSlots       int `json:"suggested_slots"`
	BlockedSlots         int `json:"blocked_slots"`
	ReservedBreaks       int `json:"reserved_breaks"`
	CreatedSlots         int `json:"created_slots"`
	SkippedSlots         int `json:"skipped_slots"`
	ConflictCount        int `json:"conflict_count"`
	FirstPeriodWins      int `json:"first_period_wins"`
	FirstPeriodFallbacks int `json:"first_period_fallbacks"`
}

type SmartTimetableSuggestion struct {
	SectionID      string   `json:"section_id"`
	ClassName      string   `json:"class_name"`
	AcademicYearID string   `json:"academic_year_id"`
	TermID         string   `json:"term_id"`
	DayOfWeek      int      `json:"day_of_week"`
	DayLabel       string   `json:"day_label"`
	PeriodNumber   int      `json:"period_number"`
	SubjectID      string   `json:"subject_id"`
	SubjectName    string   `json:"subject_name"`
	StaffID        string   `json:"staff_id"`
	StaffName      string   `json:"staff_name"`
	RoomID         string   `json:"room_id"`
	RoomName       string   `json:"room_name"`
	StartTime      string   `json:"start_time"`
	EndTime        string   `json:"end_time"`
	Status         string   `json:"status"`
	Confidence     int      `json:"confidence"`
	Blocking       bool     `json:"blocking"`
	Reasons        []string `json:"reasons"`
}

type SmartTimetableConflict struct {
	Type         string `json:"type"`
	Severity     string `json:"severity"`
	Message      string `json:"message"`
	DayOfWeek    int    `json:"day_of_week"`
	PeriodNumber int    `json:"period_number"`
	EntityID     string `json:"entity_id"`
	EntityLabel  string `json:"entity_label"`
}

type SmartTimetableLog struct {
	Stage      string `json:"stage"`
	Severity   string `json:"severity"`
	Message    string `json:"message"`
	EntityType string `json:"entity_type,omitempty"`
	EntityID   string `json:"entity_id,omitempty"`
}

type SmartTimetableTemplateConfig struct {
	Days                  []int                               `json:"days"`
	PeriodsPerDay         int                                 `json:"periods_per_day"`
	StartTime             string                              `json:"start_time"`
	PeriodDurationMinutes int                                 `json:"period_duration_minutes"`
	GapMinutes            int                                 `json:"gap_minutes"`
	Breaks                map[int]map[int]SmartTimetableBreak `json:"breaks"`
}

type SmartTimetableBreak struct {
	Label     string `json:"label"`
	Type      string `json:"type,omitempty"`
	StartTime string `json:"start_time,omitempty"`
	EndTime   string `json:"end_time,omitempty"`
}

type SmartTimetableGenerateResult struct {
	SmartTimetablePlan
	Created []models.TimetableSlot `json:"created"`
}

type SmartTimetableSlotInput struct {
	SlotID         string `json:"slot_id"`
	SectionID      string `json:"section_id"`
	AcademicYearID string `json:"academic_year_id"`
	TermID         string `json:"term_id"`
	DayOfWeek      int    `json:"day_of_week"`
	PeriodNumber   int    `json:"period_number"`
	SubjectID      string `json:"subject_id"`
	StaffID        string `json:"staff_id"`
	RoomID         string `json:"room_id"`
	StartTime      string `json:"start_time"`
	EndTime        string `json:"end_time"`
}

type schedulingLimits struct {
	MaxWeekly      int
	MaxDaily       int
	MaxConsecutive int
}

type subjectPlanItem struct {
	ID        string
	Name      string
	Type      string
	Weight    int
	Mandatory bool
}

type staffAssignment struct {
	StaffID   string
	SubjectID string
	GradeID   string
	SectionID string
	Primary   bool
}

type smartContext struct {
	SchoolID             string
	AcademicYearID       string
	TermID               string
	Template             SmartTimetableTemplateConfig
	Sections             []models.Section
	Staff                map[string]models.Staff
	Rooms                map[string]models.Room
	SubjectsByGrade      map[string][]subjectPlanItem
	AssignmentsBySubject map[string][]staffAssignment
	Existing             []models.TimetableSlot
	StaffBusy            map[string]map[int]map[int]bool
	ClassBusy            map[string]map[int]map[int]bool
	RoomBusy             map[string]map[int]map[int]bool
	StaffWeeklyLoad      map[string]int
	StaffDailyLoad       map[string]map[int]int
	Unavailable          map[string]map[int]map[int]bool
	Limits               schedulingLimits
}

func (e *SmartTimetableEngine) Preview(ctx context.Context, schoolID string, req SmartTimetableRequest) (SmartTimetablePlan, error) {
	if e == nil || e.db == nil {
		return SmartTimetablePlan{}, errors.New("smart timetable engine database is not configured")
	}
	state, err := e.loadContext(ctx, schoolID, req)
	if err != nil {
		return SmartTimetablePlan{}, err
	}

	plan := SmartTimetablePlan{
		Stages:   defaultSmartTimetableStages("completed"),
		Template: state.Template,
		Logs: []SmartTimetableLog{
			{Stage: "Validating Constraints", Severity: "info", Message: "Validated classes, subjects, staff, rooms, academic year, and term from backend data."},
		},
	}
	plan.Conflicts = e.detectExistingConflicts(state)

	for _, section := range state.Sections {
		subjects := state.SubjectsByGrade[section.GradeID]
		if len(subjects) == 0 {
			plan.Logs = append(plan.Logs, SmartTimetableLog{
				Stage:      "Validating Constraints",
				Severity:   "warning",
				Message:    "No grade-subject periods are configured for " + classLabel(section) + ".",
				EntityType: "section",
				EntityID:   section.ID,
			})
			continue
		}
		remaining := subjectRemaining(subjects)
		repeatedFrequencyLogged := false
		previousByDay := map[int]string{}

		for _, day := range state.Template.Days {
			for period := 1; period <= state.Template.PeriodsPerDay; period++ {
				plan.Summary.RequestedSlots++
				start, end := periodTime(state.Template, period)
				if row, ok := breakConfig(state.Template, day, period); ok {
					start, end = breakTime(state.Template, period, row)
					label := firstNonEmpty(row.Label, "Break")
					plan.Summary.ReservedBreaks++
					plan.Suggestions = append(plan.Suggestions, SmartTimetableSuggestion{
						SectionID: section.ID, ClassName: classLabel(section),
						AcademicYearID: state.AcademicYearID, TermID: state.TermID,
						DayOfWeek: day, DayLabel: weekdayLabel(day), PeriodNumber: period,
						SubjectName: label, StartTime: start, EndTime: end,
						Status: "reserved_break", Confidence: 100,
						Reasons: []string{"Break/lunch reserved by timetable template."},
					})
					continue
				}
				if state.ClassBusy[section.ID] != nil && state.ClassBusy[section.ID][day] != nil && state.ClassBusy[section.ID][day][period] {
					plan.Summary.ExistingSlots++
					continue
				}
				if allRemainingZero(remaining) {
					remaining = subjectRemaining(subjects)
					if !repeatedFrequencyLogged {
						plan.Logs = append(plan.Logs, SmartTimetableLog{
							Stage: "Optimizing Timetable", Severity: "info",
							Message:    "Configured weekly subject frequencies were fully used for " + classLabel(section) + "; continuing balanced rotation for remaining open periods.",
							EntityType: "section", EntityID: section.ID,
						})
						repeatedFrequencyLogged = true
					}
				}

				subject := chooseSubject(subjects, remaining, previousByDay[day])
				reasons := []string{}
				firstPeriodPreferred := false
				if period == 1 {
					if teacherSubject, ok, reason := e.classTeacherSubject(state, section, subjects, day, period); ok {
						subject = teacherSubject
						firstPeriodPreferred = true
						reasons = append(reasons, "Class teacher first-period preference applied.")
						plan.Summary.FirstPeriodWins++
					} else if reason != "" {
						reasons = append(reasons, reason)
						plan.Logs = append(plan.Logs, SmartTimetableLog{
							Stage: "Allocating Class Teachers", Severity: "info",
							Message: reason, EntityType: "section", EntityID: section.ID,
						})
						plan.Summary.FirstPeriodFallbacks++
					}
				}

				staff, staffReasons, ok := e.chooseStaff(state, section, subject, day, period, firstPeriodPreferred)
				reasons = append(reasons, staffReasons...)
				roomID, roomName, roomReasons, roomBlocking := e.chooseRoom(state, section, subject, day, period)
				reasons = append(reasons, roomReasons...)
				blocking := !ok || roomBlocking
				confidence := 94
				status := "ready"
				if blocking {
					confidence = 0
					status = "blocked"
					plan.Summary.BlockedSlots++
				} else if len(reasons) > 0 {
					confidence = 78
				}
				if !blocking {
					markBusy(state.StaffBusy, staff.ID, day, period)
					markBusy(state.ClassBusy, section.ID, day, period)
					if roomID != "" {
						markBusy(state.RoomBusy, roomID, day, period)
					}
					state.StaffWeeklyLoad[staff.ID]++
					if state.StaffDailyLoad[staff.ID] == nil {
						state.StaffDailyLoad[staff.ID] = map[int]int{}
					}
					state.StaffDailyLoad[staff.ID][day]++
					remaining[subject.ID]--
					previousByDay[day] = subject.ID
					plan.Summary.SuggestedSlots++
				}
				plan.Suggestions = append(plan.Suggestions, SmartTimetableSuggestion{
					SectionID: section.ID, ClassName: classLabel(section),
					AcademicYearID: state.AcademicYearID, TermID: state.TermID,
					DayOfWeek: day, DayLabel: weekdayLabel(day), PeriodNumber: period,
					SubjectID: subject.ID, SubjectName: subject.Name,
					StaffID: staff.ID, StaffName: staffDisplayName(staff),
					RoomID: roomID, RoomName: roomName,
					StartTime: start, EndTime: end, Status: status,
					Confidence: confidence, Blocking: blocking, Reasons: reasons,
				})
			}
		}
	}

	plan.Summary.Sections = len(state.Sections)
	plan.Summary.WorkingDays = len(state.Template.Days)
	plan.Summary.PeriodsPerDay = state.Template.PeriodsPerDay
	plan.Summary.ConflictCount = len(plan.Conflicts)
	plan.Summary.SkippedSlots = plan.Summary.BlockedSlots + plan.Summary.ReservedBreaks + plan.Summary.ExistingSlots
	return plan, nil
}

func (e *SmartTimetableEngine) Generate(ctx context.Context, schoolID, userID, role string, req SmartTimetableRequest) (SmartTimetableGenerateResult, error) {
	now := time.Now().UTC()
	job := models.TimetableGenerationJob{
		SchoolID: schoolID, AcademicYearID: strings.TrimSpace(req.AcademicYearID),
		TermID: strings.TrimSpace(req.TermID), Scope: generationScope(req),
		Status: "processing", ProgressStage: "Validating Constraints",
		RequestedBy: userID, RequestedRole: role, StartedAt: &now,
	}
	if err := e.db.WithContext(ctx).Create(&job).Error; err != nil {
		return SmartTimetableGenerateResult{}, err
	}
	e.persistJobLog(ctx, job.ID, "Validating Constraints", "info", "Smart timetable generation started.", "", "")

	if strings.EqualFold(req.Mode, "regenerate_scope") || req.RegenerateScope {
		if err := e.deleteGenerationScope(ctx, schoolID, req); err != nil {
			e.failJob(ctx, &job, err)
			return SmartTimetableGenerateResult{}, err
		}
	}

	plan, err := e.Preview(ctx, schoolID, req)
	if err != nil {
		e.failJob(ctx, &job, err)
		return SmartTimetableGenerateResult{}, err
	}
	plan.JobID = job.ID
	for _, log := range plan.Logs {
		e.persistJobLog(ctx, job.ID, log.Stage, log.Severity, log.Message, log.EntityType, log.EntityID)
	}

	created := make([]models.TimetableSlot, 0)
	for _, suggestion := range plan.Suggestions {
		if suggestion.Blocking {
			continue
		}
		if suggestion.Status != "ready" && suggestion.Status != "reserved_break" {
			continue
		}
		var existing int64
		e.db.WithContext(ctx).Model(&models.TimetableSlot{}).
			Where("section_id = ? AND academic_year_id = ? AND term_id = ? AND day_of_week = ? AND period_number = ?",
				suggestion.SectionID, suggestion.AcademicYearID, suggestion.TermID, suggestion.DayOfWeek, suggestion.PeriodNumber).
			Count(&existing)
		if existing > 0 {
			continue
		}
		start, startErr := clockPointer(suggestion.StartTime)
		end, endErr := clockPointer(suggestion.EndTime)
		if startErr != nil || endErr != nil {
			continue
		}
		slotType := "regular"
		if suggestion.Status == "reserved_break" {
			slotType = "break:" + strings.TrimSpace(firstNonEmpty(suggestion.SubjectName, "Break"))
		}
		slot := models.TimetableSlot{
			SectionID: suggestion.SectionID, AcademicYearID: suggestion.AcademicYearID,
			TermID: suggestion.TermID, DayOfWeek: suggestion.DayOfWeek,
			PeriodNumber: suggestion.PeriodNumber, SubjectID: suggestion.SubjectID,
			StaffID: suggestion.StaffID, StartTime: start, EndTime: end, SlotType: slotType,
		}
		if suggestion.Status == "ready" && suggestion.RoomID != "" {
			roomID := suggestion.RoomID
			slot.RoomID = &roomID
		}
		if err := e.db.WithContext(ctx).Create(&slot).Error; err != nil {
			e.failJob(ctx, &job, err)
			return SmartTimetableGenerateResult{}, err
		}
		created = append(created, slot)
	}

	completedAt := time.Now().UTC()
	plan.Summary.CreatedSlots = len(created)
	plan.Summary.SkippedSlots = plan.Summary.RequestedSlots - len(created)
	summary, _ := json.Marshal(plan.Summary)
	job.Status = "completed"
	job.ProgressStage = "Finalizing Schedule"
	job.Summary = string(summary)
	job.CompletedAt = &completedAt
	if err := e.db.WithContext(ctx).Save(&job).Error; err != nil {
		return SmartTimetableGenerateResult{}, err
	}
	e.persistJobLog(ctx, job.ID, "Finalizing Schedule", "success", fmt.Sprintf("Created %d timetable slots.", len(created)), "job", job.ID)
	return SmartTimetableGenerateResult{SmartTimetablePlan: plan, Created: created}, nil
}

func (e *SmartTimetableEngine) ValidateSlots(ctx context.Context, schoolID string, slots []SmartTimetableSlotInput) ([]SmartTimetableConflict, []SmartTimetableLog, error) {
	conflicts := []SmartTimetableConflict{}
	logs := []SmartTimetableLog{}
	for _, slot := range slots {
		sectionLabel, staffLabel, roomLabel := "", "", ""
		if slot.SectionID == "" || slot.AcademicYearID == "" || slot.DayOfWeek <= 0 || slot.PeriodNumber <= 0 {
			conflicts = append(conflicts, SmartTimetableConflict{Type: "invalid_slot", Severity: "high", Message: "A timetable slot is missing class, academic year, day, or period.", DayOfWeek: slot.DayOfWeek, PeriodNumber: slot.PeriodNumber})
			continue
		}
		var section models.Section
		if err := e.db.WithContext(ctx).Preload("Grade").Joins("JOIN grades ON grades.id = sections.grade_id").First(&section, "sections.id = ? AND grades.school_id = ?", slot.SectionID, schoolID).Error; err == nil {
			sectionLabel = classLabel(section)
		}
		if slot.StaffID != "" {
			var staff models.Staff
			if err := e.db.WithContext(ctx).First(&staff, "id = ? AND school_id = ?", slot.StaffID, schoolID).Error; err == nil {
				staffLabel = staffDisplayName(staff)
			}
			var count int64
			q := e.db.WithContext(ctx).Model(&models.TimetableSlot{}).
				Joins("JOIN sections ON sections.id = timetable_slots.section_id").
				Joins("JOIN grades ON grades.id = sections.grade_id").
				Where("grades.school_id = ? AND timetable_slots.staff_id = ? AND timetable_slots.academic_year_id = ? AND timetable_slots.day_of_week = ? AND timetable_slots.period_number = ?",
					schoolID, slot.StaffID, slot.AcademicYearID, slot.DayOfWeek, slot.PeriodNumber)
			if slot.SlotID != "" {
				q = q.Where("timetable_slots.id <> ?", slot.SlotID)
			}
			q.Count(&count)
			if count > 0 {
				conflicts = append(conflicts, SmartTimetableConflict{Type: "teacher_overlap", Severity: "high", EntityID: slot.StaffID, EntityLabel: staffLabel, DayOfWeek: slot.DayOfWeek, PeriodNumber: slot.PeriodNumber, Message: fmt.Sprintf("Unable to assign %s on %s Period %d because the teacher is already assigned to another class.", firstNonEmpty(staffLabel, "this teacher"), weekdayLabel(slot.DayOfWeek), slot.PeriodNumber)})
			}
		}
		var classCount int64
		q := e.db.WithContext(ctx).Model(&models.TimetableSlot{}).
			Where("section_id = ? AND academic_year_id = ? AND day_of_week = ? AND period_number = ?", slot.SectionID, slot.AcademicYearID, slot.DayOfWeek, slot.PeriodNumber)
		if slot.SlotID != "" {
			q = q.Where("id <> ?", slot.SlotID)
		}
		q.Count(&classCount)
		if classCount > 0 {
			conflicts = append(conflicts, SmartTimetableConflict{Type: "class_overlap", Severity: "high", EntityID: slot.SectionID, EntityLabel: sectionLabel, DayOfWeek: slot.DayOfWeek, PeriodNumber: slot.PeriodNumber, Message: fmt.Sprintf("Unable to place %s on %s Period %d because this class already has a saved period.", firstNonEmpty(sectionLabel, "this class"), weekdayLabel(slot.DayOfWeek), slot.PeriodNumber)})
		}
		if slot.RoomID != "" {
			var room models.Room
			if err := e.db.WithContext(ctx).First(&room, "id = ? AND school_id = ?", slot.RoomID, schoolID).Error; err == nil {
				roomLabel = room.RoomNumber
			}
			var count int64
			rq := e.db.WithContext(ctx).Model(&models.TimetableSlot{}).
				Joins("JOIN sections ON sections.id = timetable_slots.section_id").
				Joins("JOIN grades ON grades.id = sections.grade_id").
				Where("grades.school_id = ? AND timetable_slots.room_id = ? AND timetable_slots.academic_year_id = ? AND timetable_slots.day_of_week = ? AND timetable_slots.period_number = ?",
					schoolID, slot.RoomID, slot.AcademicYearID, slot.DayOfWeek, slot.PeriodNumber)
			if slot.SlotID != "" {
				rq = rq.Where("timetable_slots.id <> ?", slot.SlotID)
			}
			rq.Count(&count)
			if count > 0 {
				conflicts = append(conflicts, SmartTimetableConflict{Type: "room_overlap", Severity: "high", EntityID: slot.RoomID, EntityLabel: roomLabel, DayOfWeek: slot.DayOfWeek, PeriodNumber: slot.PeriodNumber, Message: fmt.Sprintf("Unable to use %s on %s Period %d because the room is already booked.", firstNonEmpty(roomLabel, "this room"), weekdayLabel(slot.DayOfWeek), slot.PeriodNumber)})
			}
		}
	}
	if len(conflicts) == 0 {
		logs = append(logs, SmartTimetableLog{Stage: "Resolving Conflicts", Severity: "success", Message: "No class, teacher, or room conflicts detected."})
	}
	return conflicts, logs, nil
}

func (e *SmartTimetableEngine) loadContext(ctx context.Context, schoolID string, req SmartTimetableRequest) (smartContext, error) {
	state := smartContext{
		SchoolID: schoolID, Staff: map[string]models.Staff{}, Rooms: map[string]models.Room{},
		SubjectsByGrade: map[string][]subjectPlanItem{}, AssignmentsBySubject: map[string][]staffAssignment{},
		StaffBusy: map[string]map[int]map[int]bool{}, ClassBusy: map[string]map[int]map[int]bool{}, RoomBusy: map[string]map[int]map[int]bool{},
		StaffWeeklyLoad: map[string]int{}, StaffDailyLoad: map[string]map[int]int{}, Unavailable: map[string]map[int]map[int]bool{},
		Limits: schedulingLimits{MaxWeekly: 32, MaxDaily: 5, MaxConsecutive: 3},
	}
	var year models.AcademicYear
	yearQuery := e.db.WithContext(ctx).Where("school_id = ?", schoolID)
	if strings.TrimSpace(req.AcademicYearID) != "" {
		yearQuery = yearQuery.Where("id = ?", strings.TrimSpace(req.AcademicYearID))
	} else {
		yearQuery = yearQuery.Order("is_current DESC, start_date DESC")
	}
	if err := yearQuery.First(&year).Error; err != nil {
		return state, errors.New("academic year does not belong to this school")
	}
	state.AcademicYearID = year.ID
	var term models.Term
	termQuery := e.db.WithContext(ctx).Where("academic_year_id = ?", year.ID)
	if strings.TrimSpace(req.TermID) != "" {
		termQuery = termQuery.Where("id = ?", strings.TrimSpace(req.TermID))
	} else {
		termQuery = termQuery.Order("is_current DESC, start_date ASC")
	}
	if err := termQuery.First(&term).Error; err != nil {
		return state, errors.New("term does not belong to this academic year")
	}
	state.TermID = term.ID
	state.Template = e.loadTemplate(ctx, schoolID, state.AcademicYearID, req)

	sectionsQuery := e.db.WithContext(ctx).Preload("Grade").Preload("ClassTeacher").Preload("Room").
		Joins("JOIN grades ON grades.id = sections.grade_id").
		Where("grades.school_id = ? AND sections.academic_year_id = ?", schoolID, state.AcademicYearID).
		Order("grades.grade_number ASC, sections.section_name ASC")
	if strings.TrimSpace(req.SectionID) != "" {
		sectionsQuery = sectionsQuery.Where("sections.id = ?", strings.TrimSpace(req.SectionID))
	}
	if err := sectionsQuery.Find(&state.Sections).Error; err != nil {
		return state, err
	}
	if len(state.Sections) == 0 {
		return state, errors.New("no classes are available for smart timetable generation")
	}
	gradeIDs := make([]string, 0)
	for _, section := range state.Sections {
		gradeIDs = append(gradeIDs, section.GradeID)
	}

	var staffRows []models.Staff
	if err := e.db.WithContext(ctx).Where("school_id = ? AND (status = '' OR LOWER(status) = ?)", schoolID, "active").Find(&staffRows).Error; err != nil {
		return state, err
	}
	for _, staff := range staffRows {
		state.Staff[staff.ID] = staff
	}
	if len(state.Staff) == 0 {
		return state, errors.New("no active backend staff records are available")
	}

	var rooms []models.Room
	_ = e.db.WithContext(ctx).Where("school_id = ?", schoolID).Find(&rooms).Error
	for _, room := range rooms {
		state.Rooms[room.ID] = room
	}

	var gradeSubjects []models.GradeSubject
	_ = e.db.WithContext(ctx).Preload("Subject").
		Where("grade_id IN ?", uniqueStrings(gradeIDs)).
		Find(&gradeSubjects).Error
	for _, row := range gradeSubjects {
		if row.Subject == nil {
			continue
		}
		weight := row.PeriodsPerWeek
		if weight <= 0 {
			weight = 1
		}
		state.SubjectsByGrade[row.GradeID] = append(state.SubjectsByGrade[row.GradeID], subjectPlanItem{
			ID: row.SubjectID, Name: firstNonEmpty(row.Subject.SubjectName, row.Subject.SubjectCode, row.SubjectID),
			Type: row.Subject.SubjectType, Weight: weight, Mandatory: row.IsMandatory,
		})
	}
	for gradeID, subjects := range state.SubjectsByGrade {
		sort.SliceStable(subjects, func(i, j int) bool {
			if subjects[i].Mandatory != subjects[j].Mandatory {
				return subjects[i].Mandatory
			}
			if subjects[i].Weight != subjects[j].Weight {
				return subjects[i].Weight > subjects[j].Weight
			}
			return subjects[i].Name < subjects[j].Name
		})
		state.SubjectsByGrade[gradeID] = subjects
	}

	var assignments []models.StaffSubject
	_ = e.db.WithContext(ctx).Where("grade_id IN ?", uniqueStrings(gradeIDs)).Find(&assignments).Error
	for _, row := range assignments {
		sectionID := ""
		if row.SectionID != nil {
			sectionID = strings.TrimSpace(*row.SectionID)
		}
		state.AssignmentsBySubject[row.SubjectID] = append(state.AssignmentsBySubject[row.SubjectID], staffAssignment{
			StaffID: row.StaffID, SubjectID: row.SubjectID, GradeID: row.GradeID, SectionID: sectionID, Primary: row.IsPrimary,
		})
	}

	var existing []models.TimetableSlot
	if err := e.db.WithContext(ctx).Model(&models.TimetableSlot{}).
		Joins("JOIN sections ON sections.id = timetable_slots.section_id").
		Joins("JOIN grades ON grades.id = sections.grade_id").
		Where("grades.school_id = ? AND timetable_slots.academic_year_id = ? AND timetable_slots.term_id = ?", schoolID, state.AcademicYearID, state.TermID).
		Find(&existing).Error; err != nil {
		return state, err
	}
	state.Existing = existing
	for _, slot := range existing {
		markBusy(state.ClassBusy, slot.SectionID, slot.DayOfWeek, slot.PeriodNumber)
		if strings.TrimSpace(slot.StaffID) != "" {
			markBusy(state.StaffBusy, slot.StaffID, slot.DayOfWeek, slot.PeriodNumber)
			state.StaffWeeklyLoad[slot.StaffID]++
			if state.StaffDailyLoad[slot.StaffID] == nil {
				state.StaffDailyLoad[slot.StaffID] = map[int]int{}
			}
			state.StaffDailyLoad[slot.StaffID][slot.DayOfWeek]++
		}
		if slot.RoomID != nil && strings.TrimSpace(*slot.RoomID) != "" {
			markBusy(state.RoomBusy, *slot.RoomID, slot.DayOfWeek, slot.PeriodNumber)
		}
	}
	e.applyConstraints(ctx, &state)
	return state, nil
}

func (e *SmartTimetableEngine) loadTemplate(ctx context.Context, schoolID, academicYearID string, req SmartTimetableRequest) SmartTimetableTemplateConfig {
	template := SmartTimetableTemplateConfig{Days: []int{1, 2, 3, 4, 5, 6}, PeriodsPerDay: 8, StartTime: "09:00", PeriodDurationMinutes: 40, GapMinutes: 5, Breaks: map[int]map[int]SmartTimetableBreak{}}
	var row models.TimetableTemplate
	if err := e.db.WithContext(ctx).Where("school_id = ? AND (academic_year_id = '' OR academic_year_id = ?)", schoolID, academicYearID).Order("is_default DESC, created_at DESC").First(&row).Error; err == nil {
		if days := intListFromJSON(row.WorkingDays); len(days) > 0 {
			template.Days = days
		}
		if row.PeriodsPerDay > 0 {
			template.PeriodsPerDay = row.PeriodsPerDay
		}
		if row.PeriodDurationMinutes > 0 {
			template.PeriodDurationMinutes = row.PeriodDurationMinutes
		}
		if row.GapMinutes >= 0 {
			template.GapMinutes = row.GapMinutes
		}
		if strings.TrimSpace(row.StartTime) != "" {
			template.StartTime = strings.TrimSpace(row.StartTime)
		}
		template.Breaks = breaksFromJSON(row.Breaks)
	}
	if len(req.Days) > 0 {
		template.Days = req.Days
	}
	if req.PeriodsPerDay > 0 {
		template.PeriodsPerDay = req.PeriodsPerDay
	}
	if strings.TrimSpace(req.StartTime) != "" {
		template.StartTime = strings.TrimSpace(req.StartTime)
	}
	if req.PeriodDurationMinutes > 0 {
		template.PeriodDurationMinutes = req.PeriodDurationMinutes
	}
	if req.GapMinutes >= 0 {
		template.GapMinutes = req.GapMinutes
	}
	if len(req.Breaks) > 0 {
		template.Breaks = breaksFromRows(req.Breaks)
	}
	if template.GapMinutes == 0 {
		template.GapMinutes = 5
	}
	return template
}

func (e *SmartTimetableEngine) applyConstraints(ctx context.Context, state *smartContext) {
	var rows []models.TimetableConstraint
	_ = e.db.WithContext(ctx).Where("school_id = ? AND is_active = ?", state.SchoolID, true).Find(&rows).Error
	for _, row := range rows {
		payload := map[string]interface{}{}
		_ = json.Unmarshal([]byte(row.Payload), &payload)
		switch strings.ToLower(strings.TrimSpace(row.ConstraintType)) {
		case "workload_limit":
			if value := intFromAny(payload["max_weekly_periods"]); value > 0 {
				state.Limits.MaxWeekly = value
			}
			if value := intFromAny(payload["max_daily_periods"]); value > 0 {
				state.Limits.MaxDaily = value
			}
			if value := intFromAny(payload["max_consecutive_periods"]); value > 0 {
				state.Limits.MaxConsecutive = value
			}
		case "teacher_unavailable":
			if row.StaffID == nil || strings.TrimSpace(*row.StaffID) == "" {
				continue
			}
			for _, day := range intsFromAny(payload["days"], intFromAny(payload["day_of_week"])) {
				for _, period := range intsFromAny(payload["periods"], intFromAny(payload["period_number"])) {
					markBusy(state.Unavailable, *row.StaffID, day, period)
				}
			}
		case "break":
			label := firstNonEmpty(fmt.Sprint(payload["label"]), "Break")
			for _, day := range intsFromAny(payload["days"], intFromAny(payload["day_of_week"])) {
				if state.Template.Breaks[day] == nil {
					state.Template.Breaks[day] = map[int]SmartTimetableBreak{}
				}
				for _, period := range intsFromAny(payload["periods"], intFromAny(payload["period_number"])) {
					state.Template.Breaks[day][period] = SmartTimetableBreak{Label: label, Type: "break"}
				}
			}
		}
	}
}

func (e *SmartTimetableEngine) classTeacherSubject(state smartContext, section models.Section, subjects []subjectPlanItem, day, period int) (subjectPlanItem, bool, string) {
	if section.ClassTeacherID == nil || strings.TrimSpace(*section.ClassTeacherID) == "" {
		return subjectPlanItem{}, false, classLabel(section) + " has no class teacher assigned for first-period preference."
	}
	classTeacherID := strings.TrimSpace(*section.ClassTeacherID)
	if _, ok := state.Staff[classTeacherID]; !ok {
		return subjectPlanItem{}, false, "Class teacher for " + classLabel(section) + " is not an active staff record."
	}
	if ok, reason := staffAvailable(state, classTeacherID, day, period); !ok {
		return subjectPlanItem{}, false, "Unable to assign class teacher for " + classLabel(section) + " on " + weekdayLabel(day) + " Period " + strconv.Itoa(period) + " because " + reason + "."
	}
	for _, subject := range subjects {
		for _, assignment := range state.AssignmentsBySubject[subject.ID] {
			if assignment.StaffID == classTeacherID && (assignment.SectionID == "" || assignment.SectionID == section.ID) {
				return subject, true, ""
			}
		}
	}
	return subjectPlanItem{}, false, "Class teacher for " + classLabel(section) + " has no mapped subject for this grade."
}

func (e *SmartTimetableEngine) chooseStaff(state smartContext, section models.Section, subject subjectPlanItem, day, period int, preferClassTeacher bool) (models.Staff, []string, bool) {
	candidates := []staffAssignment{}
	if preferClassTeacher && section.ClassTeacherID != nil {
		candidates = append(candidates, staffAssignment{StaffID: *section.ClassTeacherID, SubjectID: subject.ID, GradeID: section.GradeID, SectionID: section.ID, Primary: true})
	}
	for _, assignment := range state.AssignmentsBySubject[subject.ID] {
		if assignment.GradeID == section.GradeID && (assignment.SectionID == "" || assignment.SectionID == section.ID) {
			candidates = append(candidates, assignment)
		}
	}
	sort.SliceStable(candidates, func(i, j int) bool {
		if candidates[i].Primary != candidates[j].Primary {
			return candidates[i].Primary
		}
		return state.StaffWeeklyLoad[candidates[i].StaffID] < state.StaffWeeklyLoad[candidates[j].StaffID]
	})
	for _, candidate := range candidates {
		staff, ok := state.Staff[candidate.StaffID]
		if !ok {
			continue
		}
		if available, _ := staffAvailable(state, staff.ID, day, period); available {
			return staff, nil, true
		}
	}
	fallbacks := make([]models.Staff, 0, len(state.Staff))
	for _, staff := range state.Staff {
		fallbacks = append(fallbacks, staff)
	}
	sort.SliceStable(fallbacks, func(i, j int) bool {
		if state.StaffWeeklyLoad[fallbacks[i].ID] != state.StaffWeeklyLoad[fallbacks[j].ID] {
			return state.StaffWeeklyLoad[fallbacks[i].ID] < state.StaffWeeklyLoad[fallbacks[j].ID]
		}
		return staffDisplayName(fallbacks[i]) < staffDisplayName(fallbacks[j])
	})
	for _, staff := range fallbacks {
		if available, _ := staffAvailable(state, staff.ID, day, period); available {
			return staff, []string{"Mapped teacher was unavailable; selected least-loaded active staff."}, true
		}
	}
	if len(fallbacks) == 0 {
		return models.Staff{}, []string{"No active teacher is available."}, false
	}
	return fallbacks[0], []string{"All candidate teachers are unavailable or overloaded."}, false
}

func (e *SmartTimetableEngine) chooseRoom(state smartContext, section models.Section, subject subjectPlanItem, day, period int) (string, string, []string, bool) {
	reasons := []string{}
	needsLab := strings.Contains(strings.ToLower(subject.Type+" "+subject.Name), "lab")
	if needsLab {
		for _, room := range sortedRooms(state.Rooms) {
			if !strings.Contains(strings.ToLower(room.RoomType+" "+room.RoomNumber), "lab") {
				continue
			}
			if !isBusy(state.RoomBusy, room.ID, day, period) {
				return room.ID, room.RoomNumber, reasons, false
			}
		}
		return "", "", []string{"Lab subject could not find an available lab room."}, true
	}
	if section.RoomID != nil && strings.TrimSpace(*section.RoomID) != "" {
		roomID := strings.TrimSpace(*section.RoomID)
		room := state.Rooms[roomID]
		if !isBusy(state.RoomBusy, roomID, day, period) {
			return roomID, firstNonEmpty(room.RoomNumber, roomID), reasons, false
		}
		reasons = append(reasons, "Home room was busy; searched for another available classroom.")
	}
	for _, room := range sortedRooms(state.Rooms) {
		if !isBusy(state.RoomBusy, room.ID, day, period) {
			return room.ID, firstNonEmpty(room.RoomNumber, room.ID), reasons, false
		}
	}
	return "", "", append(reasons, "No available room was found; slot will be saved without room assignment."), false
}

func staffAvailable(state smartContext, staffID string, day, period int) (bool, string) {
	if isBusy(state.StaffBusy, staffID, day, period) {
		return false, "teacher already has a class"
	}
	if isBusy(state.Unavailable, staffID, day, period) {
		return false, "teacher is marked unavailable"
	}
	if state.StaffWeeklyLoad[staffID] >= state.Limits.MaxWeekly {
		return false, "teacher reached weekly workload limit"
	}
	if state.StaffDailyLoad[staffID] != nil && state.StaffDailyLoad[staffID][day] >= state.Limits.MaxDaily {
		return false, "teacher reached daily workload limit"
	}
	consecutive := 1
	for back := period - 1; back >= 1 && isBusy(state.StaffBusy, staffID, day, back); back-- {
		consecutive++
	}
	for next := period + 1; next <= state.Template.PeriodsPerDay && isBusy(state.StaffBusy, staffID, day, next); next++ {
		consecutive++
	}
	if consecutive > state.Limits.MaxConsecutive {
		return false, "teacher would exceed continuous period limit"
	}
	return true, ""
}

func (e *SmartTimetableEngine) detectExistingConflicts(state smartContext) []SmartTimetableConflict {
	conflicts := []SmartTimetableConflict{}
	seenStaff := map[string]models.TimetableSlot{}
	seenClass := map[string]models.TimetableSlot{}
	seenRoom := map[string]models.TimetableSlot{}
	for _, slot := range state.Existing {
		classKey := fmt.Sprintf("%s:%d:%d", slot.SectionID, slot.DayOfWeek, slot.PeriodNumber)
		if previous, ok := seenClass[classKey]; ok && previous.ID != slot.ID {
			conflicts = append(conflicts, SmartTimetableConflict{Type: "class_overlap", Severity: "high", EntityID: slot.SectionID, DayOfWeek: slot.DayOfWeek, PeriodNumber: slot.PeriodNumber, Message: fmt.Sprintf("Class has multiple saved periods on %s Period %d.", weekdayLabel(slot.DayOfWeek), slot.PeriodNumber)})
		}
		seenClass[classKey] = slot
		if slot.StaffID != "" {
			staffKey := fmt.Sprintf("%s:%d:%d", slot.StaffID, slot.DayOfWeek, slot.PeriodNumber)
			if previous, ok := seenStaff[staffKey]; ok && previous.ID != slot.ID {
				conflicts = append(conflicts, SmartTimetableConflict{Type: "teacher_overlap", Severity: "high", EntityID: slot.StaffID, DayOfWeek: slot.DayOfWeek, PeriodNumber: slot.PeriodNumber, Message: fmt.Sprintf("Teacher is double-booked on %s Period %d.", weekdayLabel(slot.DayOfWeek), slot.PeriodNumber)})
			}
			seenStaff[staffKey] = slot
		}
		if slot.RoomID != nil && *slot.RoomID != "" {
			roomKey := fmt.Sprintf("%s:%d:%d", *slot.RoomID, slot.DayOfWeek, slot.PeriodNumber)
			if previous, ok := seenRoom[roomKey]; ok && previous.ID != slot.ID {
				conflicts = append(conflicts, SmartTimetableConflict{Type: "room_overlap", Severity: "high", EntityID: *slot.RoomID, DayOfWeek: slot.DayOfWeek, PeriodNumber: slot.PeriodNumber, Message: fmt.Sprintf("Room is double-booked on %s Period %d.", weekdayLabel(slot.DayOfWeek), slot.PeriodNumber)})
			}
			seenRoom[roomKey] = slot
		}
	}
	return conflicts
}

func (e *SmartTimetableEngine) deleteGenerationScope(ctx context.Context, schoolID string, req SmartTimetableRequest) error {
	q := e.db.WithContext(ctx).Model(&models.TimetableSlot{}).Select("timetable_slots.id").
		Joins("JOIN sections ON sections.id = timetable_slots.section_id").
		Joins("JOIN grades ON grades.id = sections.grade_id").
		Where("grades.school_id = ?", schoolID)
	if strings.TrimSpace(req.AcademicYearID) != "" {
		q = q.Where("timetable_slots.academic_year_id = ?", strings.TrimSpace(req.AcademicYearID))
	}
	if strings.TrimSpace(req.TermID) != "" {
		q = q.Where("timetable_slots.term_id = ?", strings.TrimSpace(req.TermID))
	}
	if strings.TrimSpace(req.SectionID) != "" {
		q = q.Where("timetable_slots.section_id = ?", strings.TrimSpace(req.SectionID))
	}
	var slotIDs []string
	if err := q.Pluck("timetable_slots.id", &slotIDs).Error; err != nil {
		return err
	}
	if len(slotIDs) == 0 {
		return nil
	}
	return e.db.WithContext(ctx).Where("id IN ?", slotIDs).Delete(&models.TimetableSlot{}).Error
}

func (e *SmartTimetableEngine) persistJobLog(ctx context.Context, jobID, stage, severity, message, entityType, entityID string) {
	if jobID == "" {
		return
	}
	_ = e.db.WithContext(ctx).Create(&models.TimetableGenerationLog{JobID: jobID, Stage: stage, Severity: severity, Message: message, EntityType: entityType, EntityID: entityID}).Error
}

func (e *SmartTimetableEngine) failJob(ctx context.Context, job *models.TimetableGenerationJob, err error) {
	now := time.Now().UTC()
	job.Status = "failed"
	job.ErrorMessage = err.Error()
	job.CompletedAt = &now
	_ = e.db.WithContext(ctx).Save(job).Error
	e.persistJobLog(ctx, job.ID, job.ProgressStage, "error", err.Error(), "job", job.ID)
}

func defaultSmartTimetableStages(status string) []SmartTimetableStage {
	labels := []string{"Validating Constraints", "Allocating Class Teachers", "Allocating Labs and Rooms", "Optimizing Timetable", "Resolving Conflicts", "Finalizing Schedule"}
	stages := make([]SmartTimetableStage, 0, len(labels))
	for _, label := range labels {
		stages = append(stages, SmartTimetableStage{Label: label, Status: status})
	}
	return stages
}

func subjectRemaining(subjects []subjectPlanItem) map[string]int {
	result := map[string]int{}
	for _, subject := range subjects {
		weight := subject.Weight
		if weight <= 0 {
			weight = 1
		}
		result[subject.ID] = weight
	}
	return result
}

func chooseSubject(subjects []subjectPlanItem, remaining map[string]int, previous string) subjectPlanItem {
	var best subjectPlanItem
	bestScore := -1
	for _, subject := range subjects {
		score := remaining[subject.ID]
		if subject.ID == previous {
			score--
		}
		if score > bestScore {
			best = subject
			bestScore = score
		}
	}
	return best
}

func allRemainingZero(values map[string]int) bool {
	if len(values) == 0 {
		return true
	}
	for _, value := range values {
		if value > 0 {
			return false
		}
	}
	return true
}

func markBusy(target map[string]map[int]map[int]bool, id string, day, period int) {
	if strings.TrimSpace(id) == "" || day <= 0 || period <= 0 {
		return
	}
	if target[id] == nil {
		target[id] = map[int]map[int]bool{}
	}
	if target[id][day] == nil {
		target[id][day] = map[int]bool{}
	}
	target[id][day][period] = true
}

func isBusy(target map[string]map[int]map[int]bool, id string, day, period int) bool {
	return target[id] != nil && target[id][day] != nil && target[id][day][period]
}

func periodTime(template SmartTimetableTemplateConfig, period int) (string, string) {
	start, err := time.Parse("15:04", template.StartTime)
	if err != nil {
		start, _ = time.Parse("15:04", "09:00")
	}
	start = start.Add(time.Duration(period-1) * time.Duration(template.PeriodDurationMinutes+template.GapMinutes) * time.Minute)
	end := start.Add(time.Duration(template.PeriodDurationMinutes) * time.Minute)
	return start.Format("15:04"), end.Format("15:04")
}

func breakTime(template SmartTimetableTemplateConfig, period int, row SmartTimetableBreak) (string, string) {
	if strings.TrimSpace(row.StartTime) == "" || strings.TrimSpace(row.EndTime) == "" {
		return periodTime(template, period)
	}
	start, startErr := time.Parse("15:04", strings.TrimSpace(row.StartTime))
	end, endErr := time.Parse("15:04", strings.TrimSpace(row.EndTime))
	if startErr != nil || endErr != nil || !end.After(start) {
		return periodTime(template, period)
	}
	return start.Format("15:04"), end.Format("15:04")
}

func clockPointer(value string) (*time.Time, error) {
	parsed, err := time.Parse("15:04", strings.TrimSpace(value))
	if err != nil {
		return nil, err
	}
	clock := time.Date(2000, 1, 1, parsed.Hour(), parsed.Minute(), 0, 0, time.UTC)
	return &clock, nil
}

func breakConfig(template SmartTimetableTemplateConfig, day, period int) (SmartTimetableBreak, bool) {
	if template.Breaks[day] == nil {
		return SmartTimetableBreak{}, false
	}
	row, ok := template.Breaks[day][period]
	if !ok || strings.TrimSpace(row.Label) == "" {
		return SmartTimetableBreak{}, false
	}
	return row, true
}

func breaksFromJSON(raw string) map[int]map[int]SmartTimetableBreak {
	if strings.TrimSpace(raw) == "" {
		return map[int]map[int]SmartTimetableBreak{}
	}
	var rows []map[string]interface{}
	if err := json.Unmarshal([]byte(raw), &rows); err != nil {
		return map[int]map[int]SmartTimetableBreak{}
	}
	return breaksFromRows(rows)
}

func breaksFromRows(rows []map[string]interface{}) map[int]map[int]SmartTimetableBreak {
	result := map[int]map[int]SmartTimetableBreak{}
	for _, row := range rows {
		label := firstNonEmpty(fmt.Sprint(row["label"]), "Break")
		breakType := firstNonEmpty(fmt.Sprint(row["type"]), "break")
		startTime := firstNonEmpty(fmt.Sprint(row["start_time"]), fmt.Sprint(row["start"]))
		endTime := firstNonEmpty(fmt.Sprint(row["end_time"]), fmt.Sprint(row["end"]))
		for _, day := range intsFromAny(row["days"], intFromAny(row["day_of_week"])) {
			if result[day] == nil {
				result[day] = map[int]SmartTimetableBreak{}
			}
			for _, period := range intsFromAny(row["periods"], intFromAny(row["period_number"])) {
				result[day][period] = SmartTimetableBreak{
					Label:     label,
					Type:      breakType,
					StartTime: startTime,
					EndTime:   endTime,
				}
			}
		}
	}
	return result
}

func intListFromJSON(raw string) []int {
	var values []int
	if strings.TrimSpace(raw) == "" {
		return values
	}
	_ = json.Unmarshal([]byte(raw), &values)
	return values
}

func intsFromAny(value interface{}, fallback int) []int {
	result := []int{}
	switch typed := value.(type) {
	case []interface{}:
		for _, item := range typed {
			if parsed := intFromAny(item); parsed > 0 {
				result = append(result, parsed)
			}
		}
	case []int:
		for _, item := range typed {
			if item > 0 {
				result = append(result, item)
			}
		}
	}
	if len(result) == 0 && fallback > 0 {
		result = append(result, fallback)
	}
	return result
}

func intFromAny(value interface{}) int {
	switch typed := value.(type) {
	case int:
		return typed
	case int64:
		return int(typed)
	case float64:
		return int(typed)
	case json.Number:
		parsed, _ := typed.Int64()
		return int(parsed)
	case string:
		parsed, _ := strconv.Atoi(strings.TrimSpace(typed))
		return parsed
	default:
		return 0
	}
}

func uniqueStrings(values []string) []string {
	seen := map[string]bool{}
	result := []string{}
	for _, value := range values {
		value = strings.TrimSpace(value)
		if value == "" || seen[value] {
			continue
		}
		seen[value] = true
		result = append(result, value)
	}
	return result
}

func sortedRooms(rooms map[string]models.Room) []models.Room {
	result := make([]models.Room, 0, len(rooms))
	for _, room := range rooms {
		result = append(result, room)
	}
	sort.SliceStable(result, func(i, j int) bool {
		return result[i].RoomNumber < result[j].RoomNumber
	})
	return result
}

func classLabel(section models.Section) string {
	grade := ""
	if section.Grade != nil {
		grade = strings.TrimSpace(section.Grade.GradeName)
	}
	name := strings.TrimSpace(section.SectionName)
	if grade == "" && name == "" {
		return section.ID
	}
	if grade == "" {
		return "Section " + name
	}
	if name == "" {
		return grade
	}
	return grade + " - " + name
}

func staffDisplayName(staff models.Staff) string {
	name := strings.TrimSpace(strings.Join([]string{staff.FirstName, staff.LastName}, " "))
	if name != "" {
		return name
	}
	if strings.TrimSpace(staff.Email) != "" {
		return staff.Email
	}
	return staff.ID
}

func weekdayLabel(day int) string {
	labels := map[int]string{1: "Monday", 2: "Tuesday", 3: "Wednesday", 4: "Thursday", 5: "Friday", 6: "Saturday", 7: "Sunday"}
	if labels[day] == "" {
		return "Day " + strconv.Itoa(day)
	}
	return labels[day]
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" && strings.TrimSpace(value) != "<nil>" {
			return strings.TrimSpace(value)
		}
	}
	return ""
}

func generationScope(req SmartTimetableRequest) string {
	if strings.TrimSpace(req.SectionID) != "" {
		return "section:" + strings.TrimSpace(req.SectionID)
	}
	return "school"
}
