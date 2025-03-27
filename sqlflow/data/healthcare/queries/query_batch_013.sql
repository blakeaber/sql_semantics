-- Query 1:
WITH PatientVisitCounts AS (
    SELECT p.patient_id, COUNT(v.visit_id) AS visit_count
    FROM patients p
    INNER JOIN visits v ON p.patient_id = v.patient_id
    GROUP BY p.patient_id
)
SELECT pv.patient_id, pv.visit_count, AVG(bp.billed_amount) AS avg_billed_amount
FROM PatientVisitCounts pv
INNER JOIN claims c ON pv.patient_id = c.patient_id
INNER JOIN (
    SELECT claim_id, AVG(amount) AS billed_amount
    FROM billing
    GROUP BY claim_id
) bp ON c.claim_id = bp.claim_id
HAVING AVG(bp.billed_amount) > 1000;

-- Query 2:
WITH RecentDiagnoses AS (
    SELECT visit_id, diagnosis_code
    FROM diagnoses
    WHERE diagnosis_date > DATE_SUB(CURDATE(), INTERVAL 1 YEAR)
)
SELECT p.patient_id, p.first_name, p.last_name, COUNT(rd.diagnosis_code) AS diagnosis_count
FROM patients p
INNER JOIN visits v ON p.patient_id = v.patient_id
INNER JOIN RecentDiagnoses rd ON v.visit_id = rd.visit_id
GROUP BY p.patient_id
ORDER BY diagnosis_count DESC;

-- Query 3:
SELECT p.patient_id, p.first_name, p.last_name, e.employment_type,
       CASE
           WHEN e.employment_type = 'Full-time' THEN 'Employed'
           ELSE 'Other'
       END AS employment_status
FROM patients p
INNER JOIN (
    SELECT patient_id, employment_type
    FROM employment_status
    WHERE status_date = (
        SELECT MAX(status_date)
        FROM employment_status es
        WHERE es.patient_id = employment_status.patient_id
    )
) e ON p.patient_id = e.patient_id;

-- Query 4:
WITH ProcedureCounts AS (
    SELECT visit_id, COUNT(procedure_id) AS procedure_count
    FROM procedures
    GROUP BY visit_id
)
SELECT v.visit_id, v.visit_date, CASE
           WHEN pc.procedure_count > 5 THEN 'Multiple Procedures'
           ELSE 'Few Procedures'
       END AS procedure_category
FROM visits v
INNER JOIN ProcedureCounts pc ON v.visit_id = pc.visit_id;

-- Query 5:
WITH YearlyAggregate AS (
    SELECT YEAR(v.visit_date) AS visit_year, COUNT(v.visit_id) AS num_visits
    FROM visits v
    GROUP BY YEAR(v.visit_date)
)
SELECT ya.visit_year, ya.num_visits, AVG(l.result_value) AS avg_lab_result
FROM YearlyAggregate ya
INNER JOIN labs l ON ya.visit_year = YEAR(l.collected_date)
GROUP BY ya.visit_year;

-- Query 6:
SELECT p.patient_id, p.first_name, p.last_name, AVG(hs.height_cm) AS avg_height
FROM patients p
INNER JOIN visits v ON p.patient_id = v.patient_id
INNER JOIN vitals hs ON v.visit_id = hs.visit_id
GROUP BY p.patient_id;

-- Query 7:
SELECT d.diagnosis_code, et.encounter_type_name, COUNT(*) AS total_diagnoses
FROM diagnoses d
INNER JOIN visits v ON d.visit_id = v.visit_id
INNER JOIN encounter_types et ON v.encounter_type_id = et.encounter_type_id
GROUP BY d.diagnosis_code, et.encounter_type_name
HAVING COUNT(*) > 10;

-- Query 8:
WITH HighRiskScores AS (
    SELECT patient_id, MAX(score_value) AS max_score
    FROM risk_scores
    GROUP BY patient_id
)
SELECT p.patient_id, p.first_name, p.last_name, hrs.max_score
FROM patients p
INNER JOIN HighRiskScores hrs ON p.patient_id = hrs.patient_id
WHERE hrs.max_score > 80;

-- Query 9:
SELECT v.location, COUNT(DISTINCT d.diagnosis_code) AS distinct_diagnoses
FROM visits v
INNER JOIN diagnoses d ON v.visit_id = d.visit_id
GROUP BY v.location
HAVING COUNT(DISTINCT d.diagnosis_code) > 5;

-- Query 10:
WITH LastVisitDate AS (
    SELECT patient_id, MAX(visit_date) AS last_visit
    FROM visits
    GROUP BY patient_id
)
SELECT p.patient_id, p.first_name, p.last_name, lv.last_visit, ins.payer_name
FROM patients p
INNER JOIN LastVisitDate lv ON p.patient_id = lv.patient_id
INNER JOIN insurance ins ON p.insurance_id = ins.insurance_id;