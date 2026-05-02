# ONYX-15 ERP Schema

## Overview

This ERD covers the initial PostgreSQL foundation for the three ERP modules requested in `ONYX-15`:

- Finance
- HR
- Operations

Security controls included in the schema:

- RLS enabled and forced on every application table in `public`
- default-deny by design: this migration creates no allow-policies yet
- `audit_log` is append-only through DB triggers
- DB-level segregation of duties for:
  - payroll preparation vs payroll approval
  - wire transfer initiation vs wire authorization

## Mermaid ERD

```mermaid
erDiagram
    USERS ||--o{ USER_ROLES : has
    ROLES ||--o{ USER_ROLES : grants
    USERS ||--o{ AUDIT_LOG : acts_in

    USERS ||--o{ CLIENTS : manages
    CLIENTS ||--o{ LOCATIONS : has
    CLIENTS ||--o{ PROJECTS : funds
    LOCATIONS o|--o{ PROJECTS : hosts
    CLIENTS ||--o{ WORK_ORDERS : requests
    PROJECTS ||--o{ WORK_ORDERS : contains
    LOCATIONS o|--o{ WORK_ORDERS : occurs_at

    USERS o|--o{ PROJECTS : manages
    USERS o|--o{ WORK_ORDERS : creates

    USERS ||--o| EMPLOYEES : maps_to
    EMPLOYEES o|--o{ EMPLOYEES : manages
    EMPLOYEES ||--o{ LEAVE_REQUESTS : submits
    USERS ||--o{ LEAVE_REQUESTS : requests_for
    LEAVE_REQUESTS ||--o{ LEAVE_APPROVALS : reviewed_by
    USERS ||--o{ LEAVE_APPROVALS : decides
    EMPLOYEES ||--o{ GWO_CERTIFICATIONS : holds
    USERS o|--o{ GWO_CERTIFICATIONS : verifies

    WORK_ORDERS ||--o{ WORK_ORDER_ASSIGNMENTS : assigns
    EMPLOYEES ||--o{ WORK_ORDER_ASSIGNMENTS : works_on
    USERS o|--o{ WORK_ORDER_ASSIGNMENTS : assigned_by

    EMPLOYEES ||--o{ EXPENSE_CLAIMS : incurs
    USERS ||--o{ EXPENSE_CLAIMS : submits
    EXPENSE_CLAIMS ||--o{ EXPENSE_APPROVALS : reviewed_by
    USERS ||--o{ EXPENSE_APPROVALS : decides

    USERS ||--o{ PAYROLL_RUNS : prepares
    PAYROLL_RUNS ||--o{ PAYROLL_APPROVALS : reviewed_by
    USERS ||--o{ PAYROLL_APPROVALS : approves

    USERS ||--o{ WIRE_TRANSFERS : initiates
    WIRE_TRANSFERS ||--o{ WIRE_AUTHORIZATIONS : reviewed_by
    USERS ||--o{ WIRE_AUTHORIZATIONS : authorizes

    USERS o|--o{ STANDING_PAYMENTS : owns

    CLIENTS ||--o{ INVOICES : billed_to
    PROJECTS o|--o{ INVOICES : relates_to
    USERS o|--o{ INVOICES : creates

    QUICKBOOKS_SYNC_LOG }o--|| INVOICES : syncs
```

## Module Notes

### Finance

- `expense_claims` and `expense_approvals` track employee spend and approvals
- `payroll_runs` and `payroll_approvals` enforce preparer/approver separation
- `wire_transfers` and `wire_authorizations` enforce initiator/authorizer separation
- `standing_payments`, `invoices`, and `quickbooks_sync_log` cover recurring payments and accounting synchronization

### HR

- `employees` anchors the employee master record
- `leave_requests` and `leave_approvals` support HR review workflows
- `gwo_certifications` tracks field safety/compliance credentials

### Operations

- `clients`, `locations`, and `projects` form the commercial/project hierarchy
- `work_orders` and `work_order_assignments` support field execution planning

## Review Checklist

- Review table coverage against Appia workflows for Finance, HR, and Operations
- Confirm whether additional approval chains are needed for wire transfers beyond the enforced initiator/authorizer split
- Confirm whether `users` should remain ERP-owned with optional `auth_user_id` linkage, or be fully constrained to `auth.users`
