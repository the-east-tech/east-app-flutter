# API Contracts for Future Java Spring Boot Backend

Frontend version: `east_app_staffreward_v6`

Current Flutter mode: hardcoded sample data.

These APIs are placeholders for future backend integration.

---

## 1. Authentication and Users

### POST `/api/auth/login`

Request:

```json
{
  "email": "manager@theeast.local",
  "password": "demo-password"
}
```

Response:

```json
{
  "success": true,
  "token": "jwt-token-here",
  "user": {
    "userId": "MANAGER-001",
    "name": "Manager A",
    "role": "MANAGER",
    "branchId": "BRANCH-001"
  }
}
```

### GET `/api/users/me`

Response:

```json
{
  "userId": "MANAGER-001",
  "name": "Manager A",
  "role": "MANAGER",
  "branchId": "BRANCH-001"
}
```

### GET `/api/users`

Response:

```json
[
  {
    "userId": "STAFF-001",
    "name": "Ah Ming",
    "role": "STAFF",
    "branchId": "BRANCH-001",
    "status": "ACTIVE"
  }
]
```

### PUT `/api/users/{userId}`

Request:

```json
{
  "name": "Ah Ming",
  "role": "STAFF",
  "status": "ACTIVE"
}
```

Response:

```json
{
  "success": true,
  "message": "User updated successfully"
}
```

---

## 2. Dashboard and Announcements

### GET `/api/dashboard/home`

Response:

```json
{
  "todayTaskCount": 8,
  "completedTaskCount": 5,
  "pendingApprovalCount": 3,
  "rewardPoints": 1280,
  "stockVarianceCount": 3
}
```

### GET `/api/dashboard/today-progress`

Response:

```json
{
  "completed": 5,
  "total": 8,
  "percentage": 62.5
}
```

### GET `/api/announcements`

Response:

```json
[
  {
    "announcementId": "ANN-001",
    "title": "Morning briefing",
    "message": "Check today SOP before starting work.",
    "createdBy": "MANAGER-001",
    "createdAt": "2026-06-09T08:00:00"
  }
]
```

### POST `/api/announcements`

Request:

```json
{
  "title": "Stock check reminder",
  "message": "All stock verification must be completed before closing.",
  "createdBy": "MANAGER-001"
}
```

Response:

```json
{
  "success": true,
  "announcementId": "ANN-002"
}
```

---

## 3. Tasks

### GET `/api/tasks/today`

Response:

```json
[
  {
    "taskId": "TASK-001",
    "title": "Clean dining table area",
    "description": "Wipe tables and reset chairs.",
    "category": "Cleanliness",
    "assignedTo": "STAFF-001",
    "status": "PENDING",
    "dueAt": "2026-06-09T14:00:00"
  }
]
```

### GET `/api/tasks/{taskId}`

Response:

```json
{
  "taskId": "TASK-001",
  "title": "Clean dining table area",
  "description": "Wipe tables and reset chairs.",
  "category": "Cleanliness",
  "assignedTo": "STAFF-001",
  "status": "PENDING"
}
```

### POST `/api/tasks`

Request:

```json
{
  "title": "Check freezer temperature",
  "description": "Record freezer temperature before closing.",
  "category": "Safety",
  "assignedTo": "STAFF-002",
  "createdBy": "MANAGER-001",
  "dueAt": "2026-06-09T22:00:00"
}
```

Response:

```json
{
  "success": true,
  "taskId": "TASK-009"
}
```

### PUT `/api/tasks/{taskId}`

Request:

```json
{
  "title": "Check freezer temperature",
  "description": "Record freezer temperature and take photo.",
  "category": "Safety",
  "assignedTo": "STAFF-002",
  "dueAt": "2026-06-09T22:00:00"
}
```

Response:

```json
{
  "success": true,
  "message": "Task updated successfully"
}
```

### DELETE `/api/tasks/{taskId}`

Response:

```json
{
  "success": true,
  "message": "Task deleted successfully"
}
```

### POST `/api/tasks/{taskId}/submit`

Request:

```json
{
  "taskId": "TASK-001",
  "staffId": "STAFF-001",
  "staffName": "Ah Ming",
  "photoUrl": "https://your-storage-url/task-photo-001.jpg",
  "remarks": "Table cleaned and reset",
  "submittedAt": "2026-06-09T10:30:00"
}
```

Response:

```json
{
  "success": true,
  "message": "Task evidence submitted successfully",
  "submissionId": "SUB-001",
  "status": "PENDING_SUPERVISOR_APPROVAL"
}
```

### GET `/api/tasks/submissions`

Response:

```json
[
  {
    "submissionId": "SUB-001",
    "taskId": "TASK-001",
    "taskTitle": "Clean dining table area",
    "staffId": "STAFF-001",
    "staffName": "Ah Ming",
    "photoUrl": "https://your-storage-url/task-photo-001.jpg",
    "status": "PENDING_SUPERVISOR_APPROVAL",
    "submittedAt": "2026-06-09T10:30:00"
  }
]
```

---

## 4. Approvals

### GET `/api/approvals/supervisor/pending`

Response:

```json
[
  {
    "submissionId": "SUB-001",
    "taskTitle": "Clean dining table area",
    "staffName": "Ah Ming",
    "photoUrl": "https://your-storage-url/task-photo-001.jpg",
    "status": "PENDING_SUPERVISOR_APPROVAL"
  }
]
```

### POST `/api/approvals/supervisor/{submissionId}`

Request:

```json
{
  "submissionId": "SUB-001",
  "supervisorId": "SUP-001",
  "supervisorName": "Supervisor A",
  "approved": true,
  "remarks": "Photo evidence is clear",
  "reviewedAt": "2026-06-09T11:00:00"
}
```

Response:

```json
{
  "success": true,
  "message": "Supervisor approval completed",
  "status": "PENDING_MANAGER_FINAL_APPROVAL"
}
```

### GET `/api/approvals/manager/pending`

Response:

```json
[
  {
    "submissionId": "SUB-001",
    "taskTitle": "Clean dining table area",
    "staffName": "Ah Ming",
    "supervisorName": "Supervisor A",
    "photoUrl": "https://your-storage-url/task-photo-001.jpg",
    "status": "PENDING_MANAGER_FINAL_APPROVAL"
  }
]
```

### POST `/api/approvals/manager/{submissionId}`

Request:

```json
{
  "submissionId": "SUB-001",
  "managerId": "MANAGER-001",
  "managerName": "Manager A",
  "approved": true,
  "score": 92,
  "remarks": "Good work, task completed properly",
  "finalReviewedAt": "2026-06-09T12:00:00"
}
```

Response:

```json
{
  "success": true,
  "message": "Manager final approval completed",
  "status": "APPROVED",
  "score": 92
}
```

### GET `/api/approvals/history`

Response:

```json
[
  {
    "approvalId": "APP-001",
    "submissionId": "SUB-001",
    "approvalLevel": "MANAGER",
    "approvedBy": "MANAGER-001",
    "approved": true,
    "score": 92,
    "remarks": "Good work",
    "createdAt": "2026-06-09T12:00:00"
  }
]
```

---

## 5. Rewards

### GET `/api/rewards/me`

Response:

```json
{
  "userId": "STAFF-001",
  "totalPoints": 1280,
  "monthlyPoints": 320
}
```

### GET `/api/rewards/transactions`

Response:

```json
[
  {
    "transactionId": "RWD-001",
    "userId": "STAFF-001",
    "points": 20,
    "reason": "Task approved",
    "sourceSubmissionId": "SUB-001",
    "createdAt": "2026-06-09T12:00:00"
  }
]
```

### POST `/api/rewards/adjust`

Request:

```json
{
  "userId": "STAFF-001",
  "points": 10,
  "reason": "Manual bonus",
  "createdBy": "MANAGER-001"
}
```

Response:

```json
{
  "success": true,
  "message": "Reward adjusted successfully"
}
```

### GET `/api/rewards/summary`

Response:

```json
{
  "totalIssuedPoints": 5200,
  "topStaffUserId": "STAFF-001",
  "topStaffName": "Ah Ming"
}
```

---

## 6. Ranking

### GET `/api/ranking/daily`

Response:

```json
[
  {
    "rank": 1,
    "userId": "STAFF-001",
    "staffName": "Ah Ming",
    "score": 96,
    "rewardPoints": 1280
  }
]
```

### GET `/api/ranking/weekly`

Same response shape as daily ranking.

### GET `/api/ranking/monthly`

Same response shape as daily ranking.

### GET `/api/ranking/branch/{branchId}`

Same response shape as daily ranking, filtered by branch.

---

## 7. Knowledge / SOP

### GET `/api/sop`

Response:

```json
[
  {
    "sopId": "SOP-001",
    "title": "How to Check Cold Cup Stock",
    "description": "Steps to verify cold cup stock balance before closing.",
    "category": "Stock",
    "level": "Level 2",
    "mediaType": "VIDEO",
    "mediaUrl": "https://your-storage-url/sop-video-001.mp4",
    "createdBy": "MANAGER-001",
    "createdAt": "2026-06-09T10:30:00"
  }
]
```

### GET `/api/sop/{sopId}`

Response: one SOP object using the same shape as above.

### POST `/api/sop`

Request:

```json
{
  "title": "How to Check Cold Cup Stock",
  "description": "Steps to verify cold cup stock balance before closing.",
  "category": "Stock",
  "level": "Level 2",
  "mediaType": "VIDEO",
  "mediaUrl": "https://your-storage-url/sop-video-001.mp4",
  "createdBy": "MANAGER-001",
  "createdAt": "2026-06-09T10:30:00"
}
```

Response:

```json
{
  "success": true,
  "message": "SOP created successfully",
  "sopId": "SOP-001",
  "category": "Stock",
  "level": "Level 2"
}
```

### PUT `/api/sop/{sopId}`

Request: same shape as POST `/api/sop`.

Response:

```json
{
  "success": true,
  "message": "SOP updated successfully"
}
```

### DELETE `/api/sop/{sopId}`

Response:

```json
{
  "success": true,
  "message": "SOP deleted successfully"
}
```

### GET `/api/sop/categories`

Response:

```json
[
  "Cleanliness",
  "Hygiene",
  "Quality",
  "Safety",
  "Stock",
  "Inventory"
]
```

### GET `/api/sop/levels`

Response:

```json
[
  "Level 1",
  "Level 2",
  "Level 3",
  "Level 4"
]
```

---

## 8. Stock, manager only

### GET `/api/stock/summary`

Response:

```json
{
  "totalItems": 8,
  "totalSuppliers": 4,
  "lowStockCount": 1,
  "varianceCount": 3,
  "lastVerifiedAt": "2026-06-09T10:30:00",
  "lastVerifiedBy": "MANAGER-001"
}
```

### GET `/api/stock/suppliers`

Response:

```json
[
  {
    "supplierId": "SUP-001",
    "supplierName": "Supreme Range",
    "contactPerson": "TBC",
    "phone": "TBC",
    "status": "ACTIVE"
  }
]
```

### GET `/api/stock/items`

Response:

```json
[
  {
    "itemId": "ITEM-001",
    "itemName": "美人鱼",
    "supplierId": "SUP-001",
    "supplierName": "Supreme Range",
    "category": "Food Ingredient",
    "unit": "pack",
    "systemBalance": 12,
    "physicalBalance": 12,
    "minimumStock": 5,
    "status": "OK"
  }
]
```

### GET `/api/stock/items/{itemId}`

Response: one stock item object using the same shape as above.

### GET `/api/stock/by-supplier/{supplierId}`

Response: list of stock items for one supplier.

### POST `/api/stock/items`

Request:

```json
{
  "itemName": "虾酱",
  "supplierId": "SUP-001",
  "category": "Sauce",
  "unit": "bottle",
  "minimumStock": 4,
  "createdBy": "MANAGER-001"
}
```

Response:

```json
{
  "success": true,
  "itemId": "ITEM-009"
}
```

### PUT `/api/stock/items/{itemId}`

Request:

```json
{
  "itemName": "虾酱",
  "supplierId": "SUP-001",
  "category": "Sauce",
  "unit": "bottle",
  "minimumStock": 4,
  "status": "ACTIVE"
}
```

Response:

```json
{
  "success": true,
  "message": "Stock item updated successfully"
}
```

### POST `/api/stock/verify`

Request:

```json
{
  "itemId": "ITEM-002",
  "supplierId": "SUP-001",
  "managerId": "MANAGER-001",
  "systemBalance": 8,
  "physicalBalance": 7,
  "variance": -1,
  "reason": "Missing",
  "remarks": "One bottle missing during stock check",
  "photoUrl": "https://your-storage-url/stock-photo-001.jpg",
  "verifiedAt": "2026-06-09T10:30:00"
}
```

Response:

```json
{
  "success": true,
  "message": "Stock balance verified successfully",
  "verificationId": "STOCK-VERIFY-001",
  "itemId": "ITEM-002",
  "status": "Variance"
}
```

### GET `/api/stock/verification-history`

Response:

```json
[
  {
    "verificationId": "STOCK-VERIFY-001",
    "itemId": "ITEM-002",
    "itemName": "虾酱",
    "supplierName": "Supreme Range",
    "systemBalance": 8,
    "physicalBalance": 7,
    "variance": -1,
    "reason": "Missing",
    "verifiedBy": "MANAGER-001",
    "verifiedAt": "2026-06-09T10:30:00"
  }
]
```

### POST `/api/stock/movement`

Request:

```json
{
  "itemId": "ITEM-002",
  "movementType": "STOCK_OUT",
  "quantity": 1,
  "reason": "Used in kitchen",
  "createdBy": "MANAGER-001",
  "createdAt": "2026-06-09T10:30:00"
}
```

Response:

```json
{
  "success": true,
  "movementId": "MOVE-001",
  "message": "Stock movement recorded successfully"
}
```

### GET `/api/stock/low-stock`

Response:

```json
[
  {
    "itemId": "ITEM-004",
    "itemName": "热杯",
    "supplierName": "A-Z",
    "physicalBalance": 10,
    "minimumStock": 8,
    "status": "Low Stock"
  }
]
```

---

## 9. Media Upload

### POST `/api/media/upload/task-photo`

Multipart form fields:

- `file`
- `taskId`
- `uploadedBy`

Response:

```json
{
  "success": true,
  "mediaUrl": "https://your-storage-url/task-photo-001.jpg"
}
```

### POST `/api/media/upload/sop-media`

Multipart form fields:

- `file`
- `sopId`
- `uploadedBy`

Response:

```json
{
  "success": true,
  "mediaUrl": "https://your-storage-url/sop-video-001.mp4"
}
```

### POST `/api/media/upload/stock-photo`

Multipart form fields:

- `file`
- `itemId`
- `uploadedBy`

Response:

```json
{
  "success": true,
  "mediaUrl": "https://your-storage-url/stock-photo-001.jpg"
}
```

---

## 10. Audit Logs

### GET `/api/audit/logs`

Response:

```json
[
  {
    "auditId": "AUD-001",
    "entityType": "STOCK_ITEM",
    "entityId": "ITEM-002",
    "action": "VERIFY_STOCK",
    "performedBy": "MANAGER-001",
    "remarks": "Physical count updated from 8 to 7",
    "createdAt": "2026-06-09T10:30:00"
  }
]
```

### GET `/api/audit/entity/{entityType}/{entityId}`

Response: filtered audit logs for one entity.
