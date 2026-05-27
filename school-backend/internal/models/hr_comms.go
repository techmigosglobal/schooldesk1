package models

import (
	"time"
)

type Announcement struct {
	BaseModel
	SchoolID        string     `gorm:"type:text;not null" json:"school_id"`
	Title           string     `gorm:"type:text;not null" json:"title"`
	Content         string     `gorm:"type:text" json:"content"`
	TargetAudience  string     `gorm:"type:text" json:"target_audience"`
	TargetGradeID   *string    `gorm:"type:text" json:"target_grade_id"`
	TargetSectionID *string    `gorm:"type:text" json:"target_section_id"`
	IsUrgent        bool       `gorm:"default:false" json:"is_urgent"`
	CreatedBy       string     `gorm:"type:text;not null" json:"created_by"`
	PublishedAt     time.Time  `json:"published_at"`
	ExpiresAt       *time.Time `json:"expires_at"`
	AttachmentURL   string     `gorm:"type:text" json:"attachment_url"`
	School          *School    `gorm:"foreignKey:SchoolID" json:"school,omitempty"`
	TargetGrade     *Grade     `gorm:"foreignKey:TargetGradeID" json:"target_grade,omitempty"`
	TargetSection   *Section   `gorm:"foreignKey:TargetSectionID" json:"target_section,omitempty"`
	Creator         *Staff     `gorm:"foreignKey:CreatedBy" json:"creator,omitempty"`
}

type EventCalendar struct {
	BaseModel
	SchoolID       string                 `gorm:"type:text;not null" json:"school_id"`
	AcademicYearID string                 `gorm:"type:text;not null" json:"academic_year_id"`
	EventTitle     string                 `gorm:"type:text;not null" json:"event_title"`
	EventType      string                 `gorm:"type:text;not null" json:"event_type"`
	Description    string                 `gorm:"type:text" json:"description"`
	StartDatetime  time.Time              `json:"start_datetime"`
	EndDatetime    time.Time              `json:"end_datetime"`
	Location       string                 `gorm:"type:text" json:"location"`
	IsHoliday      bool                   `gorm:"default:false" json:"is_holiday"`
	CreatedBy      string                 `gorm:"type:text;not null" json:"created_by"`
	School         *School                `gorm:"foreignKey:SchoolID" json:"school,omitempty"`
	AcademicYear   *AcademicYear          `gorm:"foreignKey:AcademicYearID" json:"academic_year,omitempty"`
	Creator        *Staff                 `gorm:"foreignKey:CreatedBy" json:"creator,omitempty"`
	PTMSlots       []ParentTeacherMeeting `gorm:"foreignKey:EventID" json:"ptm_slots,omitempty"`
}

type ParentTeacherMeeting struct {
	BaseModel
	EventID     string         `gorm:"type:text;not null" json:"event_id"`
	SectionID   string         `gorm:"type:text;not null" json:"section_id"`
	SlotDate    time.Time      `json:"slot_date"`
	SlotTime    string         `gorm:"type:text" json:"slot_time"`
	DurationMin int            `json:"duration_min"`
	TeacherID   string         `gorm:"type:text;not null" json:"teacher_id"`
	GuardianID  string         `gorm:"type:text;not null" json:"guardian_id"`
	StudentID   string         `gorm:"type:text;not null" json:"student_id"`
	Status      string         `gorm:"type:text;default:'scheduled'" json:"status"`
	Notes       string         `gorm:"type:text" json:"notes"`
	Event       *EventCalendar `gorm:"foreignKey:EventID" json:"event,omitempty"`
	Section     *Section       `gorm:"foreignKey:SectionID" json:"section,omitempty"`
	Teacher     *Staff         `gorm:"foreignKey:TeacherID" json:"teacher,omitempty"`
	Guardian    *Guardian      `gorm:"foreignKey:GuardianID" json:"guardian,omitempty"`
	Student     *Student       `gorm:"foreignKey:StudentID" json:"student,omitempty"`
}

type Homework struct {
	BaseModel
	SchoolID    string    `gorm:"type:text;not null" json:"school_id"`
	Title       string    `gorm:"type:text;not null" json:"title"`
	Subject     string    `gorm:"type:text" json:"subject"`
	ClassName   string    `gorm:"type:text" json:"class"`
	SectionID   string    `gorm:"type:text" json:"section_id"`
	TeacherID   string    `gorm:"type:text" json:"teacher_id"`
	StudentID   string    `gorm:"type:text" json:"student_id"`
	Description string    `gorm:"type:text" json:"description"`
	DueDate     time.Time `json:"due_date"`
	Status      string    `gorm:"type:text;default:'pending'" json:"status"`
	CreatedBy   string    `gorm:"type:text" json:"created_by"`
}

type HomeworkSubmission struct {
	BaseModel
	SchoolID      string     `gorm:"type:text;not null;index" json:"school_id"`
	HomeworkID    string     `gorm:"type:text;not null;uniqueIndex:idx_homework_submission_student" json:"homework_id"`
	StudentID     string     `gorm:"type:text;not null;uniqueIndex:idx_homework_submission_student" json:"student_id"`
	ParentUserID  string     `gorm:"type:text;not null" json:"parent_user_id"`
	AnswerText    string     `gorm:"type:text" json:"answer_text"`
	AttachmentURL string     `gorm:"type:text" json:"attachment_url"`
	Status        string     `gorm:"type:text;default:'submitted'" json:"status"`
	SubmittedAt   time.Time  `json:"submitted_at"`
	ReviewedBy    string     `gorm:"type:text" json:"reviewed_by"`
	ReviewedAt    *time.Time `json:"reviewed_at,omitempty"`
	Grade         string     `gorm:"type:text" json:"grade"`
	Remarks       string     `gorm:"type:text" json:"remarks"`

	Homework   *Homework `gorm:"foreignKey:HomeworkID" json:"homework,omitempty"`
	Student    *Student  `gorm:"foreignKey:StudentID" json:"student,omitempty"`
	ParentUser *User     `gorm:"foreignKey:ParentUserID" json:"parent_user,omitempty"`
	Reviewer   *User     `gorm:"foreignKey:ReviewedBy" json:"reviewer,omitempty"`
}

type HomeworkSubmissionRequest struct {
	StudentID     string `json:"student_id"`
	AnswerText    string `json:"answer_text"`
	AttachmentURL string `json:"attachment_url"`
}

type HomeworkSubmissionReviewRequest struct {
	Status  string `json:"status" binding:"required"`
	Grade   string `json:"grade"`
	Remarks string `json:"remarks"`
}

type DiaryEntry struct {
	BaseModel
	SchoolID  string    `gorm:"type:text;not null" json:"school_id"`
	EntryDate time.Time `json:"date"`
	ClassName string    `gorm:"type:text" json:"class"`
	SectionID string    `gorm:"type:text" json:"section_id"`
	Subject   string    `gorm:"type:text" json:"subject"`
	Title     string    `gorm:"type:text;not null" json:"title"`
	Classwork string    `gorm:"type:text" json:"classwork"`
	Homework  string    `gorm:"type:text" json:"homework"`
	Notes     string    `gorm:"type:text" json:"notes"`
	Schedule  string    `gorm:"type:text" json:"schedule"`
	EntryType string    `gorm:"type:text" json:"type"`
	TeacherID string    `gorm:"type:text" json:"teacher_id"`
	StudentID string    `gorm:"type:text" json:"student_id"`
	CreatedBy string    `gorm:"type:text" json:"created_by"`
}

type MessageConversation struct {
	BaseModel
	SchoolID        string    `gorm:"type:text;not null" json:"school_id"`
	ReferenceType   string    `gorm:"type:text" json:"reference_type"`
	ReferenceID     string    `gorm:"type:text" json:"reference_id"`
	TeacherID       string    `gorm:"type:text;not null" json:"teacher_id"`
	ParentID        string    `gorm:"type:text;not null" json:"parent_id"`
	StudentID       string    `gorm:"type:text" json:"student_id"`
	Title           string    `gorm:"type:text" json:"title"`
	LastMessage     string    `gorm:"type:text" json:"last_message"`
	LastMessageTime time.Time `json:"last_message_time"`
}

type Message struct {
	BaseModel
	ConversationID string    `gorm:"type:text;not null" json:"conversation_id"`
	SenderID       string    `gorm:"type:text;not null" json:"sender_id"`
	SenderRole     string    `gorm:"type:text;not null" json:"sender_role"`
	SenderName     string    `gorm:"type:text" json:"sender_name"`
	Body           string    `gorm:"type:text;not null" json:"body"`
	IsRead         bool      `gorm:"default:false" json:"is_read"`
	SentAt         time.Time `json:"sent_at"`
}

type NotificationLog struct {
	BaseModel
	SchoolID        string     `gorm:"type:text;not null" json:"school_id"`
	RecipientUserID string     `gorm:"type:text;not null" json:"recipient_user_id"`
	Channel         string     `gorm:"type:text;not null" json:"channel"`
	Title           string     `gorm:"type:text" json:"title"`
	Body            string     `gorm:"type:text" json:"body"`
	Category        string     `gorm:"type:text;default:'general'" json:"category"`
	Priority        string     `gorm:"type:text;default:'medium'" json:"priority"`
	Route           string     `gorm:"type:text" json:"route"`
	ReferenceType   string     `gorm:"type:text" json:"reference_type"`
	ReferenceID     *string    `gorm:"type:text" json:"reference_id"`
	IsRead          bool       `gorm:"default:false" json:"is_read"`
	ReadAt          *time.Time `json:"read_at,omitempty"`
	SentAt          time.Time  `json:"sent_at"`
	DeliveryStatus  string     `gorm:"type:text;default:'pending'" json:"delivery_status"`
	PushStatus      string     `gorm:"type:text;default:'pending'" json:"push_status"`
	PushError       string     `gorm:"type:text" json:"push_error,omitempty"`
	PushedAt        *time.Time `json:"pushed_at,omitempty"`
	School          *School    `gorm:"foreignKey:SchoolID" json:"school,omitempty"`
}

type NotificationDeviceToken struct {
	BaseModel
	SchoolID   string     `gorm:"type:text;not null;index:idx_notification_device_user" json:"school_id"`
	UserID     string     `gorm:"type:text;not null;index:idx_notification_device_user" json:"user_id"`
	Platform   string     `gorm:"type:text;not null" json:"platform"`
	Token      string     `gorm:"type:text;not null" json:"-"`
	TokenHash  string     `gorm:"type:text;not null;uniqueIndex" json:"token_hash"`
	DeviceID   string     `gorm:"type:text" json:"device_id"`
	AppVersion string     `gorm:"type:text" json:"app_version"`
	LastSeenAt time.Time  `json:"last_seen_at"`
	RevokedAt  *time.Time `json:"revoked_at,omitempty"`
	School     *School    `gorm:"foreignKey:SchoolID" json:"school,omitempty"`
	User       *User      `gorm:"foreignKey:UserID" json:"user,omitempty"`
}

type LeaveType struct {
	BaseModel
	SchoolID         string             `gorm:"type:text;not null" json:"school_id"`
	LeaveName        string             `gorm:"type:text;not null" json:"leave_name"`
	MaxDaysPerYear   int                `json:"max_days_per_year"`
	CarryForwardDays int                `json:"carry_forward_days"`
	IsPaid           bool               `gorm:"default:false" json:"is_paid"`
	ApplicableTo     string             `gorm:"type:text" json:"applicable_to"`
	School           *School            `gorm:"foreignKey:SchoolID" json:"school,omitempty"`
	Balances         []LeaveBalance     `gorm:"foreignKey:LeaveTypeID" json:"balances,omitempty"`
	Applications     []LeaveApplication `gorm:"foreignKey:LeaveTypeID" json:"applications,omitempty"`
}

type LeaveBalance struct {
	BaseModel
	StaffID        string        `gorm:"type:text;not null" json:"staff_id"`
	LeaveTypeID    string        `gorm:"type:text;not null" json:"leave_type_id"`
	AcademicYearID string        `gorm:"type:text;not null" json:"academic_year_id"`
	TotalEntitled  int           `json:"total_entitled"`
	UsedDays       float64       `json:"used_days"`
	PendingDays    float64       `json:"pending_days"`
	RemainingDays  float64       `json:"remaining_days"`
	Staff          *Staff        `gorm:"foreignKey:StaffID" json:"staff,omitempty"`
	LeaveType      *LeaveType    `gorm:"foreignKey:LeaveTypeID" json:"leave_type,omitempty"`
	AcademicYear   *AcademicYear `gorm:"foreignKey:AcademicYearID" json:"academic_year,omitempty"`
}

type LeaveApplication struct {
	BaseModel
	StaffID         string     `gorm:"type:text;not null" json:"staff_id"`
	LeaveTypeID     string     `gorm:"type:text;not null" json:"leave_type_id"`
	FromDate        time.Time  `json:"from_date"`
	ToDate          time.Time  `json:"to_date"`
	HalfDay         bool       `gorm:"default:false" json:"half_day"`
	TotalDays       float64    `json:"total_days"`
	Reason          string     `gorm:"type:text" json:"reason"`
	Status          string     `gorm:"type:text;default:'pending'" json:"status"`
	AppliedAt       time.Time  `json:"applied_at"`
	ApprovedBy      *string    `gorm:"type:text" json:"approved_by"`
	RejectionReason string     `gorm:"type:text" json:"rejection_reason"`
	Staff           *Staff     `gorm:"foreignKey:StaffID" json:"staff,omitempty"`
	LeaveType       *LeaveType `gorm:"foreignKey:LeaveTypeID" json:"leave_type,omitempty"`
	Approver        *Staff     `gorm:"foreignKey:ApprovedBy" json:"approver,omitempty"`
}

type StudentLeaveApplication struct {
	BaseModel
	SchoolID        string     `gorm:"type:text;not null;index" json:"school_id"`
	StudentID       string     `gorm:"type:text;not null;index" json:"student_id"`
	ParentUserID    string     `gorm:"type:text;not null;index" json:"parent_user_id"`
	LeaveType       string     `gorm:"type:text;not null" json:"leave_type"`
	FromDate        time.Time  `json:"from_date"`
	ToDate          time.Time  `json:"to_date"`
	HalfDay         bool       `gorm:"default:false" json:"half_day"`
	TotalDays       float64    `json:"total_days"`
	Reason          string     `gorm:"type:text;not null" json:"reason"`
	Status          string     `gorm:"type:text;default:'pending';index" json:"status"`
	AppliedAt       time.Time  `json:"applied_at"`
	DecidedBy       *string    `gorm:"type:text" json:"decided_by,omitempty"`
	DecidedByRole   string     `gorm:"type:text" json:"decided_by_role,omitempty"`
	DecidedAt       *time.Time `json:"decided_at,omitempty"`
	RejectionReason string     `gorm:"type:text" json:"rejection_reason,omitempty"`
	School          *School    `gorm:"foreignKey:SchoolID" json:"school,omitempty"`
	Student         *Student   `gorm:"foreignKey:StudentID" json:"student,omitempty"`
	ParentUser      *User      `gorm:"foreignKey:ParentUserID" json:"parent_user,omitempty"`
	Decider         *User      `gorm:"foreignKey:DecidedBy" json:"decider,omitempty"`
}

type Payroll struct {
	BaseModel
	StaffID        string        `gorm:"type:text;not null" json:"staff_id"`
	AcademicYearID string        `gorm:"type:text;not null" json:"academic_year_id"`
	Month          int           `gorm:"not null" json:"month"`
	Year           int           `gorm:"not null" json:"year"`
	BasicSalary    float64       `json:"basic_salary"`
	HRA            float64       `json:"hra"`
	DA             float64       `json:"da"`
	GrossSalary    float64       `json:"gross_salary"`
	PFDeduction    float64       `json:"pf_deduction"`
	ESIDeduction   float64       `json:"esi_deduction"`
	TDSDeduction   float64       `json:"tds_deduction"`
	NetSalary      float64       `json:"net_salary"`
	PaymentDate    time.Time     `json:"payment_date"`
	PaymentMode    string        `gorm:"type:text" json:"payment_mode"`
	Status         string        `gorm:"type:text;default:'pending'" json:"status"`
	PayslipURL     string        `gorm:"type:text" json:"payslip_url"`
	Staff          *Staff        `gorm:"foreignKey:StaffID" json:"staff,omitempty"`
	AcademicYear   *AcademicYear `gorm:"foreignKey:AcademicYearID" json:"academic_year,omitempty"`
}
