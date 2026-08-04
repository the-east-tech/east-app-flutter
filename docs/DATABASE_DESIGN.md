# Database Design Draft

Version: `east_app_staffreward_v6`

This is a practical first-draft database design for the future Java Spring Boot backend. It is not final. Verify and refine before implementation.

---

## 1. Core tables

### `branches`

| Column | Type | Notes |
|---|---|---|
| id | varchar | Example: BRANCH-001 |
| name | varchar | Branch name |
| address | text | Optional |
| status | varchar | ACTIVE, INACTIVE |
| created_at | timestamp |  |
| updated_at | timestamp |  |

### `users`

| Column | Type | Notes |
|---|---|---|
| id | varchar | STAFF-001, SUP-001, MANAGER-001 |
| branch_id | varchar | FK to branches.id |
| name | varchar |  |
| email | varchar | Unique |
| password_hash | varchar | Only if using local login |
| role | varchar | STAFF, SUPERVISOR, MANAGER |
| status | varchar | ACTIVE, INACTIVE |
| created_at | timestamp |  |
| updated_at | timestamp |  |

### `announcements`

| Column | Type | Notes |
|---|---|---|
| id | varchar | ANN-001 |
| branch_id | varchar | FK to branches.id |
| title | varchar |  |
| message | text |  |
| created_by | varchar | FK to users.id |
| created_at | timestamp |  |

### `audit_logs`

| Column | Type | Notes |
|---|---|---|
| id | varchar | AUD-001 |
| entity_type | varchar | TASK, SOP, STOCK_ITEM, STOCK_VERIFICATION |
| entity_id | varchar | Related record ID |
| action | varchar | CREATE, UPDATE, DELETE, APPROVE, VERIFY |
| performed_by | varchar | FK to users.id |
| old_value_json | json/text | Optional |
| new_value_json | json/text | Optional |
| remarks | text | Optional |
| created_at | timestamp |  |

---

## 2. Task tables

### `tasks`

| Column | Type | Notes |
|---|---|---|
| id | varchar | TASK-001 |
| branch_id | varchar | FK to branches.id |
| title | varchar |  |
| description | text |  |
| category | varchar | Cleanliness, Hygiene, Quality, Safety, Stock, Inventory |
| created_by | varchar | Manager user ID |
| due_at | timestamp |  |
| status | varchar | ACTIVE, INACTIVE |
| created_at | timestamp |  |
| updated_at | timestamp |  |

### `task_assignments`

| Column | Type | Notes |
|---|---|---|
| id | varchar | ASSIGN-001 |
| task_id | varchar | FK to tasks.id |
| user_id | varchar | Staff assigned |
| assigned_by | varchar | Manager or supervisor |
| assigned_at | timestamp |  |

### `task_submissions`

| Column | Type | Notes |
|---|---|---|
| id | varchar | SUB-001 |
| task_id | varchar | FK to tasks.id |
| staff_id | varchar | FK to users.id |
| remarks | text |  |
| status | varchar | PENDING_SUPERVISOR_APPROVAL, PENDING_MANAGER_FINAL_APPROVAL, APPROVED, REJECTED |
| submitted_at | timestamp |  |

### `task_submission_photos`

| Column | Type | Notes |
|---|---|---|
| id | varchar | PHOTO-001 |
| submission_id | varchar | FK to task_submissions.id |
| photo_url | text | Stored media URL |
| uploaded_at | timestamp |  |

### `task_approvals`

| Column | Type | Notes |
|---|---|---|
| id | varchar | APP-001 |
| submission_id | varchar | FK to task_submissions.id |
| approval_level | varchar | SUPERVISOR, MANAGER |
| approved_by | varchar | FK to users.id |
| approved | boolean | true or false |
| score | int | Manager score 0 to 100, nullable for supervisor |
| remarks | text |  |
| created_at | timestamp |  |

---

## 3. Rewards and ranking tables

### `reward_transactions`

| Column | Type | Notes |
|---|---|---|
| id | varchar | RWD-001 |
| user_id | varchar | FK to users.id |
| points | int | Positive or negative |
| reason | varchar | Task approved, manual bonus, penalty |
| source_submission_id | varchar | Optional FK to task_submissions.id |
| created_by | varchar | Manager/system |
| created_at | timestamp |  |

### `staff_scores`

| Column | Type | Notes |
|---|---|---|
| id | varchar | SCORE-001 |
| user_id | varchar | FK to users.id |
| submission_id | varchar | FK to task_submissions.id |
| score | int | 0 to 100 |
| scored_by | varchar | Manager user ID |
| scored_at | timestamp |  |

### `ranking_snapshots`

| Column | Type | Notes |
|---|---|---|
| id | varchar | RANK-001 |
| branch_id | varchar | FK to branches.id |
| user_id | varchar | FK to users.id |
| period_type | varchar | DAILY, WEEKLY, MONTHLY |
| period_key | varchar | Example: 2026-06-09, 2026-W24, 2026-06 |
| rank_no | int | 1, 2, 3 |
| score | int | Calculated score |
| reward_points | int | Points at snapshot time |
| created_at | timestamp |  |

---

## 4. SOP / Knowledge tables

### `sop_categories`

| Column | Type | Notes |
|---|---|---|
| id | varchar | SOP-CAT-001 |
| name | varchar | Cleanliness, Hygiene, Quality, Safety, Stock, Inventory |
| sort_order | int |  |
| status | varchar | ACTIVE, INACTIVE |

### `sop_levels`

| Column | Type | Notes |
|---|---|---|
| id | varchar | SOP-LVL-001 |
| name | varchar | Level 1, Level 2, Level 3, Level 4 |
| sort_order | int |  |
| status | varchar | ACTIVE, INACTIVE |

### `sop_documents`

| Column | Type | Notes |
|---|---|---|
| id | varchar | SOP-001 |
| branch_id | varchar | FK to branches.id, nullable if global SOP |
| title | varchar |  |
| description | text |  |
| category | varchar | Store category name or FK |
| level | varchar | Store level name or FK |
| created_by | varchar | Manager user ID |
| status | varchar | ACTIVE, INACTIVE, DRAFT |
| created_at | timestamp |  |
| updated_at | timestamp |  |

### `sop_media`

| Column | Type | Notes |
|---|---|---|
| id | varchar | SOP-MEDIA-001 |
| sop_id | varchar | FK to sop_documents.id |
| media_type | varchar | IMAGE, VIDEO |
| media_url | text |  |
| uploaded_by | varchar | FK to users.id |
| uploaded_at | timestamp |  |

### `sop_view_logs`

| Column | Type | Notes |
|---|---|---|
| id | varchar | SOP-VIEW-001 |
| sop_id | varchar | FK to sop_documents.id |
| user_id | varchar | FK to users.id |
| viewed_at | timestamp |  |

---

## 5. Stock tables

### `suppliers`

| Column | Type | Notes |
|---|---|---|
| id | varchar | SUP-001 |
| supplier_name | varchar | Supreme Range, A-Z, GTI Kampar, Grand Meltique |
| contact_person | varchar | Optional |
| phone | varchar | Optional |
| email | varchar | Optional |
| status | varchar | ACTIVE, INACTIVE |
| created_at | timestamp |  |
| updated_at | timestamp |  |

### `stock_items`

| Column | Type | Notes |
|---|---|---|
| id | varchar | ITEM-001 |
| item_name | varchar | 美人鱼, 虾酱, 冷杯, 热杯 |
| category | varchar | Food Ingredient, Sauce, Packaging, Meat, Frozen Food, Bakery |
| unit | varchar | pack, bottle, carton, kg, box |
| minimum_stock | decimal | Low stock threshold |
| status | varchar | ACTIVE, INACTIVE |
| created_at | timestamp |  |
| updated_at | timestamp |  |

### `stock_item_supplier_mapping`

| Column | Type | Notes |
|---|---|---|
| id | varchar | MAP-001 |
| item_id | varchar | FK to stock_items.id |
| supplier_id | varchar | FK to suppliers.id |
| is_primary_supplier | boolean | true/false |
| created_at | timestamp |  |

### `stock_balances`

| Column | Type | Notes |
|---|---|---|
| id | varchar | BAL-001 |
| branch_id | varchar | FK to branches.id |
| item_id | varchar | FK to stock_items.id |
| system_balance | decimal | System calculated balance |
| physical_balance | decimal | Latest physical check balance |
| last_verified_by | varchar | FK to users.id |
| last_verified_at | timestamp |  |
| updated_at | timestamp |  |

### `stock_movements`

| Column | Type | Notes |
|---|---|---|
| id | varchar | MOVE-001 |
| branch_id | varchar | FK to branches.id |
| item_id | varchar | FK to stock_items.id |
| movement_type | varchar | STOCK_IN, STOCK_OUT, WASTAGE, ADJUSTMENT |
| quantity | decimal |  |
| reason | varchar |  |
| remarks | text | Optional |
| created_by | varchar | FK to users.id |
| created_at | timestamp |  |

### `stock_verifications`

| Column | Type | Notes |
|---|---|---|
| id | varchar | STOCK-VERIFY-001 |
| branch_id | varchar | FK to branches.id |
| verified_by | varchar | Manager user ID |
| status | varchar | COMPLETED, DRAFT |
| remarks | text | Optional |
| verified_at | timestamp |  |

### `stock_verification_lines`

| Column | Type | Notes |
|---|---|---|
| id | varchar | STOCK-VERIFY-LINE-001 |
| verification_id | varchar | FK to stock_verifications.id |
| item_id | varchar | FK to stock_items.id |
| supplier_id | varchar | FK to suppliers.id |
| system_balance | decimal | Balance before verification |
| physical_balance | decimal | Counted by manager |
| variance | decimal | physical - system |
| reason | varchar | Normal check, Missing, Wastage, Damaged, Supplier delivery, Manual adjustment |
| remarks | text | Optional |
| photo_url | text | Optional evidence photo |

### `purchase_records`, future phase

| Column | Type | Notes |
|---|---|---|
| id | varchar | PURCHASE-001 |
| supplier_id | varchar | FK to suppliers.id |
| branch_id | varchar | FK to branches.id |
| invoice_no | varchar | Optional |
| purchase_date | date |  |
| total_amount | decimal | Future P&L support |
| created_by | varchar | Manager user ID |
| created_at | timestamp |  |

### `purchase_record_items`, future phase

| Column | Type | Notes |
|---|---|---|
| id | varchar | PURCHASE-ITEM-001 |
| purchase_id | varchar | FK to purchase_records.id |
| item_id | varchar | FK to stock_items.id |
| quantity | decimal |  |
| unit_price | decimal |  |
| total_price | decimal |  |
