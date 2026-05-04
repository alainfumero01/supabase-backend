# ONYX-16 Windfix AI Schema

## Overview

This ERD covers the Windfix AI workflow foundation requested in `ONYX-16`.

The schema supports the full case path from intake through ERP archival:

1. Case intake linked to ERP work orders and clients
2. Image capture with GPS and capture timestamps
3. Damage detection
4. Standards lookup
5. Repair recommendation
6. Quote generation
7. Quote approval
8. Repair execution documentation
9. Repair image capture
10. Field documentation for materials, cure, and salt testing
11. Final reporting and signatures
12. ERP archival readiness

Security controls included in the schema:

- RLS enabled and forced on every Windfix table in `public`
- default-deny by design: this migration creates no allow-policies yet
- DB-level consistency triggers keep Windfix records aligned with ERP `work_orders` and `clients`
- image evidence tables require explicit capture timestamps and GPS-compatible fields

## Mermaid ERD

```mermaid
erDiagram
    WORK_ORDERS ||--o{ CASES : anchors
    CLIENTS ||--o{ CASES : owns
    EMPLOYEES o|--o{ CASES : leads

    CASES ||--o{ CASE_IMAGES : collects
    EMPLOYEES o|--o{ CASE_IMAGES : uploads
    CASE_IMAGES ||--o{ DAMAGE_DETECTIONS : feeds
    EMPLOYEES o|--o{ DAMAGE_DETECTIONS : reviews

    STANDARDS_REPOSITORY ||--o{ DAMAGE_REPAIR_MAPPING : governs
    DAMAGE_DETECTIONS ||--o{ REPAIR_RECOMMENDATIONS : informs
    DAMAGE_REPAIR_MAPPING ||--o{ REPAIR_RECOMMENDATIONS : suggests
    STANDARDS_REPOSITORY ||--o{ REPAIR_RECOMMENDATIONS : constrains
    EMPLOYEES o|--o{ REPAIR_RECOMMENDATIONS : approves

    CASES ||--o{ QUOTES : prices
    WORK_ORDERS ||--o{ QUOTES : references
    CLIENTS ||--o{ QUOTES : bills
    EMPLOYEES o|--o{ QUOTES : prepares
    QUOTES ||--o{ QUOTE_LINE_ITEMS : contains
    REPAIR_RECOMMENDATIONS o|--o{ QUOTE_LINE_ITEMS : sources
    STANDARDS_REPOSITORY o|--o{ QUOTE_LINE_ITEMS : cites
    QUOTES ||--o{ QUOTE_APPROVALS : reviews
    EMPLOYEES o|--o{ QUOTE_APPROVALS : signs_internal

    CASES ||--o{ REPAIR_DOCUMENTATION : records
    WORK_ORDERS ||--o{ REPAIR_DOCUMENTATION : executes
    QUOTES o|--o{ REPAIR_DOCUMENTATION : authorizes
    EMPLOYEES o|--o{ REPAIR_DOCUMENTATION : leads
    REPAIR_DOCUMENTATION ||--o{ REPAIR_IMAGES : captures
    EMPLOYEES o|--o{ REPAIR_IMAGES : uploads
    REPAIR_DOCUMENTATION ||--o{ FIELD_DOCUMENTATION : logs
    CASES ||--o{ FIELD_DOCUMENTATION : ties
    EMPLOYEES o|--o{ FIELD_DOCUMENTATION : records

    CASES ||--o{ FINAL_REPORTS : closes
    WORK_ORDERS ||--o{ FINAL_REPORTS : archives
    QUOTES o|--o{ FINAL_REPORTS : supports
    REPAIR_DOCUMENTATION o|--o{ FINAL_REPORTS : summarizes
    EMPLOYEES o|--o{ FINAL_REPORTS : authors
    FINAL_REPORTS ||--o{ REPORT_SIGNATURES : approves
    EMPLOYEES o|--o{ REPORT_SIGNATURES : signs_internal

    CASES ||--o{ AI_QA_REPORTS : audits
```

## Design Notes

- `cases` is the ERP bridge and carries the authoritative links to `work_orders`, `clients`, and operational owners in `employees`
- `quotes`, `repair_documentation`, and `final_reports` repeat selected ERP foreign keys for downstream reporting and archival, with DB triggers enforcing alignment back to `cases`
- `standards_repository` and `damage_repair_mapping` give the AI workflow a normalized standards layer instead of embedding standards logic in free text
- `quote_approvals` and `report_signatures` allow both internal employee-linked approvals and external named signers
- `field_documentation` is normalized as repeated records so cure logs, materials logs, and salt-test observations can each be stored independently

## Review Checklist

- Confirm the case status model is sufficient for the intended 12-step operational workflow
- Confirm whether quote approvals need stricter separation of duties beyond the current audit trail
- Confirm whether final report signatures should remain mixed internal or external records, or be split into separate internal and customer signature tables
