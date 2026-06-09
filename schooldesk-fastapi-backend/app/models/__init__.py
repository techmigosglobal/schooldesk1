from app.models.auth import Permission, Role, RolePermission, School, Section, User, UserRole
from app.models.base import Base
from app.models.catalog import (
    AcademicTerm,
    AcademicYear,
    FeeStructure,
    Grade,
    GradeSubject,
    LeaveApplication,
    LeaveBalance,
    LeaveType,
    Room,
    Staff,
    StaffSubject,
    Student,
    StudentLeaveApplication,
    Subject,
)
from app.models.goal_task import (
    ApprovalRequest,
    AuditLog,
    Goal,
    GoalKeyResult,
    NotificationLog,
    Task,
    TaskChecklistItem,
    TaskComment,
)
from app.models.vps import VpsFee
from app.models.attendance import StaffAttendance, StudentAttendance
from app.models.exam import Exam, ExamMark
from app.models.timetable import TimetableSlot
from app.models.guardian import Guardian
from app.models.app_record import AppRecord

__all__ = [
    "AppRecord",
    "ApprovalRequest",
    "AcademicTerm",
    "AcademicYear",
    "AuditLog",
    "Base",
    "Goal",
    "GoalKeyResult",
    "FeeStructure",
    "Grade",
    "GradeSubject",
    "Guardian",
    "LeaveApplication",
    "LeaveBalance",
    "LeaveType",
    "NotificationLog",
    "Permission",
    "Role",
    "RolePermission",
    "Room",
    "School",
    "Section",
    "Staff",
    "StaffAttendance",
    "StaffSubject",
    "Student",
    "Exam",
    "ExamMark",
    "StudentAttendance",
    "StudentLeaveApplication",
    "Subject",
    "Task",
    "TaskChecklistItem",
    "TaskComment",
    "TimetableSlot",
    "User",
    "UserRole",
    "VpsFee",
]
