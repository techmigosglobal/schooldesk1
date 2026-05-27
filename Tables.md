
 Classes table:

|   |   |
|---|---|
|**Column**|**Purpose**|
|class_id|Primary key|
|school_id|School support|
|academic_year_id|Year-wise data|
|class_name|Example: LKG, 1, 2, 10|
|class_code|Short code like CLS-01|
|section_id|If sections are separate|
|class_teacher_id|Assigned teacher|
|room_id|Optional classroom|
|medium|English, Telugu, etc.|
|sort_order|Display order|
|is_active|Active or archived|
|created_at|Audit|
|updated_at|Audit|



Attendance Table:

|   |   |
|---|---|
|**Column**|**Purpose**|
|attendance_id|Primary key|
|school_id|School mapping|
|academic_year_id|Academic year|
|attendance_type|Student/Staff|
|student_id|Student mapping|
|staff_id|Staff mapping|
|class_id|Class mapping|
|section_id|Section mapping|
|attendance_date|Attendance date|
|status|Present/Absent/Late/Half-day|
|check_in_time|Entry time|
|check_out_time|Exit time|
|remarks|Notes|
|marked_by|User who marked attendance|
|created_at|Created timestamp|
|updated_at|Updated timestamp|



Fees Table:

|   |   |
|---|---|
|**Column**|**Purpose**|
|fee_id|Primary key|
|school_id|School reference|
|academic_year_id|Academic year|
|student_id|Student mapping|
|class_id|Class mapping|
|section_id|Section mapping|
|fee_type_id|Tuition/Transport/Exam/etc|
|invoice_no|Fee invoice|
|receipt_no|Payment receipt|
|due_date|Payment due date|
|amount|Total amount|
|discount_amount|Discount|
|fine_amount|Late fine|
|paid_amount|Amount paid|
|balance_amount|Remaining balance|
|payment_mode|Cash/Card/UPI/Bank|
|payment_status|Paid/Pending/Partial|
|transaction_id|Payment gateway reference|
|remarks|Notes|
|created_at|Created timestamp|
|updated_at|Updated timestamp|





Exams Table:


|   |   |
|---|---|
|**Column**|**Purpose**|
|exam_id|Primary key|
|school_id|School reference|
|academic_year_id|Academic year|
|term_id|Academic term|
|exam_type_id|Exam type reference|
|exam_name|Midterm/Final/etc|
|start_date|Campaign start date|
|end_date|Campaign end date|
|is_published|Visible to parents/students|
|created_at|Created timestamp|
|updated_at|Updated timestamp|



HomeWorktable:

|   |   |
|---|---|
|**Column**|**Purpose**|
|homework_id|Primary key|
|school_id|School reference|
|academic_year_id|Academic year|
|class_id|Class mapping|
|section_id|Section mapping|
|subject_id|Subject mapping|
|staff_id|Assigned teacher|
|student_id|Optional direct student assignment|
|title|Homework title|
|description|Homework details|
|assigned_date|Assignment date|
|submission_date|Due date|
|attachment_url|PDF/Image attachment|
|submission_mode|Online/Offline|
|status|Active/Closed|
|created_at|Created timestamp|
|updated_at|Updated timestamp|



Leaves Table:

|   |   |
|---|---|
|**Column**|**Purpose**|
|leave_id|Primary key|
|school_id|School reference|
|user_type|Student/Staff|
|student_id|Student mapping|
|staff_id|Staff mapping|
|leave_type_id|Sick/Casual/etc|
|from_date|Leave start|
|to_date|Leave end|
|total_days|Total leave days|
|reason|Leave reason|
|document_url|Medical proof|
|approval_status|Pending/Approved/Rejected|
|approved_by|Approver|
|approved_at|Approval timestamp|
|remarks|Additional notes|
|created_at|Created timestamp|
|updated_at|Updated timestamp|





Notifications Table:


|   |   |
|---|---|
|**Column**|**Purpose**|
|notification_id|Primary key|
|school_id|School reference|
|title|Notification title|
|message|Notification content|
|notification_type|Alert/Event/Fee/etc|
|target_role|Student/Teacher/Parent|
|target_user_id|Specific user|
|priority|Low/Medium/High|
|delivery_mode|App/SMS/Email|
|is_read|Read status|
|read_at|Read timestamp|
|sent_by|Sender|
|sent_at|Sent timestamp|
|expiry_date|Notification expiry|
|created_at|Created timestamp|
|updated_at|Updated timestamp|





Holidays Table:



|   |   |
|---|---|
|**Column**|**Purpose**|
|holiday_id|Primary key|
|school_id|School reference|
|holiday_name|Holiday title|
|holiday_type|National/School/Festival|
|start_date|Holiday start|
|end_date|Holiday end|
|description|Holiday details|
|is_optional|Optional holiday flag|
|applicable_for|Students/Staff/Both|
|created_by|Creator|
|status|Active/Inactive|
|created_at|Created timestamp|
|updated_at|Updated timestamp|





Events Table:


|   |   |
|---|---|
|**Column**|**Purpose**|
|event_id|Primary key|
|school_id|School reference|
|event_name|Event title|
|event_type|Sports/Cultural/Meeting|
|description|Event details|
|start_date|Event start date|
|end_date|Event end date|
|start_time|Event start time|
|end_time|Event end time|
|venue|Event location|
|organizer_id|Event organizer|
|audience_type|Students/Parents/Staff|
|attachment_url|Poster/document|
|status|Upcoming/Ongoing/Completed|
|created_at|Created timestamp|
|updated_at|Updated timestamp|





Approval Centre for principal:


|   |   |
|---|---|
|**Column**|**Purpose**|
|approval_id|Primary unique ID|
|school_id|School reference|
|academic_year_id|Academic year mapping|
|request_type|Type of approval (student_admission, leave, fee_discount, etc.)|
|module_name|ERP module source (fees, students, staffs, etc.)|
|reference_table|Original table name where request originated|
|reference_id|Record ID from source table|
|requested_by|User ID who initiated request|
|requested_role|Role of requester (admin, teacher, accountant)|
|assigned_to|Principal or authority ID|
|approval_level|Level 1/2/3 approval workflow|
|priority|Low/Medium/High/Critical|
|title|Short approval title|
|description|Detailed request description|
|old_value_json|Previous data before modification|
|new_value_json|Proposed updated data|
|attachment_url|Supporting document/PDF|
|remarks_by_requester|Notes from requester|
|approval_status|Pending/Approved/Rejected/On Hold|
|approved_by|Principal/authority ID|
|approved_at|Approval timestamp|
|rejection_reason|Reason if rejected|
|action_taken|Final action summary|
|notification_sent|Whether notification triggered|
|deadline_date|Approval due date|
|created_at|Request created timestamp|
|updated_at|Last updated timestamp|





**communications Table Structure**



|   |   |
|---|---|
|**Column**|**Purpose**|
|message_id|Primary unique ID|
|school_id|School reference|
|sender_id|User sending message|
|sender_role|principal, teacher, parent|
|receiver_id|User receiving message|
|receiver_role|principal, teacher, parent|
|student_id|Optional student reference for parent chat|
|message_type|text, image, pdf, announcement|
|message_content|Actual message text|
|attachment_url|Optional attachment|
|priority|Low/Medium/High|
|is_read|Read status|
|read_at|Read timestamp|
|reply_to_message_id|Thread/reply support|
|is_deleted_by_sender|Soft delete for sender|
|is_deleted_by_receiver|Soft delete for receiver|
|sent_at|Message sent timestamp|
|created_at|Record created timestamp|
|updated_at|Last updated timestamp|





**Recommended Chat Types**



|   |   |
|---|---|
|**Chat Type**|**Example**|
|Principal ↔ Teacher|Staff meeting discussion|
|Principal ↔ Parent|Student performance discussion|
|Principal → All Teachers|Announcement|
|Principal → Multiple Parents|Circular/Notice|





Principal Reports analytics table:



|   |   |
|---|---|
|**Column**|**Purpose**|
|report_id|Primary unique ID|
|school_id|School reference|
|academic_year_id|Academic year mapping|
|report_name|Report title|
|report_type|attendance, fees, exam, staff, etc.|
|module_name|Source module|
|generated_by|User generating report|
|generated_role|Principal/Admin|
|class_id|Optional class filter|
|section_id|Optional section filter|
|student_id|Optional student filter|
|staff_id|Optional staff filter|
|date_from|Report start date|
|date_to|Report end date|
|report_parameters_json|Stored filter parameters|
|report_summary_json|Analytics summary data|
|chart_data_json|Dashboard chart data|
|total_records|Total records analyzed|
|report_file_url|Exported PDF/Excel path|
|report_status|Generating/Completed/Failed|
|is_scheduled|Scheduled report flag|
|schedule_frequency|Daily/Weekly/Monthly|
|last_generated_at|Last generation timestamp|
|remarks|Additional notes|
|created_at|Record created timestamp|
|updated_at|Last updated timestamp|
