-- Query 1
WITH LatestVisitDates AS (
    SELECT patient_id, MAX(visit_date) AS latest_visit_date
    FROM visits
    GROUP BY patient_id
),
PatientDetails AS (
    SELECT p.patient_id, first_name, last_name, r.race_ethnicity_name
    FROM patients p
    JOIN race_ethnicity r ON p.race_ethnicity_id = r.race_ethnicity_id
)
SELECT pd.patient_id, pd.first_name, pd.last_name, pd.race_ethnicity_name,
    v.location, COUNT(DISTINCT d.diagnosis_code) AS unique_diagnoses
FROM PatientDetails pd
JOIN LatestVisitDates lvd ON pd.patient_id = lvd.patient_id
JOIN visits v ON lvd.latest_visit_date = v.visit_date AND pd.patient_id = v.patient_id
LEFT JOIN diagnoses d ON v.visit_id = d.visit_id
GROUP BY pd.patient_id, pd.first_name, pd.last_name, pd.race_ethnicity_name, v.location
HAVING COUNT(DISTINCT d.diagnosis_code) > 3;

-- Query 2
WITH ProcedureCounts AS (
    SELECT visit_id, COUNT(*) AS procedure_count
    FROM procedures
    GROUP BY visit_id
)
SELECT v.visit_id, p.first_name, p.last_name, e.encounter_type_name, pc.procedure_count,
    CASE
        WHEN pc.procedure_count > 5 THEN 'High'
        ELSE 'Low'
    END AS procedure_risk
FROM visits v
JOIN patients p ON v.patient_id = p.patient_id
LEFT JOIN encounter_types e ON v.encounter_type_id = e.encounter_type_id
JOIN ProcedureCounts pc ON v.visit_id = pc.visit_id
JOIN (
    SELECT v1.visit_id
    FROM visits v1
    JOIN procedures pr ON v1.visit_id = pr.visit_id
    WHERE pr.procedure_date BETWEEN '2022-01-01' AND '2022-12-31'
) AS ProcedureVisitDates ON v.visit_id = ProcedureVisitDates.visit_id;

-- Query 3
SELECT DISTINCT p.patient_id, p.first_name, p.last_name,
    AVG(b.amount) OVER (PARTITION BY p.patient_id) AS avg_billed_amount,
    SUM(pa.amount) FILTER (WHERE pa.payment_date > '2023-01-01') AS payments_this_year
FROM patients p
JOIN claims cl ON p.patient_id = cl.patient_id
JOIN billing b ON cl.claim_id = b.claim_id
LEFT JOIN payments pa ON cl.claim_id = pa.claim_id
JOIN (
    SELECT patient_id, COUNT(DISTINCT employer_name) AS total_employers
    FROM employment_status
    WHERE status_date > '2020-01-01'
    GROUP BY patient_id
) AS empStatus ON p.patient_id = empStatus.patient_id
WHERE empStatus.total_employers > 1
ORDER BY avg_billed_amount DESC;

-- Query 4
WITH HighRiskPatients AS (
    SELECT DISTINCT r.patient_id
    FROM risk_scores r
    JOIN patients p ON r.patient_id = p.patient_id
    WHERE r.score_value > 75
)
SELECT DISTINCT v.visit_id, p.first_name, p.last_name, l.language_name, v.visit_date,
    DENSE_RANK() OVER (PARTITION BY p.patient_id ORDER BY v.visit_date DESC) AS visit_rank
FROM visits v
JOIN HighRiskPatients hr ON v.patient_id = hr.patient_id
JOIN patients p ON v.patient_id = p.patient_id
JOIN languages l ON p.language_id = l.language_id
LEFT JOIN imaging i ON v.visit_id = i.visit_id
WHERE i.impression IS NOT NULL
ORDER BY visit_rank;

-- Query 5
WITH MonthlyVisitCounts AS (
    SELECT patient_id, COUNT(*) AS monthly_visits,
        EXTRACT(YEAR FROM visit_date) AS visit_year, EXTRACT(MONTH FROM visit_date) AS visit_month
    FROM visits
    GROUP BY patient_id, visit_year, visit_month
)
SELECT p.patient_id, p.first_name, p.last_name,
    MAX(monthly_visits) AS max_monthly_visits,
    MEDIAN(v.height_cm) AS median_height
FROM patients p
JOIN MonthlyVisitCounts mvc ON p.patient_id = mvc.patient_id
LEFT JOIN vitals v ON mvc.patient_id = v.visit_id
GROUP BY p.patient_id, p.first_name, p.last_name
HAVING MAX(monthly_visits) > 10;

-- Query 6
WITH EmergencyVisits AS (
    SELECT visit_id, COUNT(*) FILTER (WHERE was_emergency) AS emergency_count
    FROM visits
    WHERE visit_date BETWEEN '2023-01-01' AND '2023-12-31'
    GROUP BY visit_id
)
SELECT p.patient_id, p.first_name, p.last_name, e.emergency_count,
    AVG(d.result_value) OVER (PARTITION BY p.patient_id) AS avg_lab_result
FROM patients p
JOIN EmergencyVisits e ON p.patient_id = e.patient_id
LEFT JOIN labs d ON e.visit_id = d.visit_id
JOIN (
    SELECT h.patient_id, hs.housing_type
    FROM housing_status hs
    JOIN patients h ON hs.patient_id = h.patient_id
    WHERE hs.status_date > '2023-01-01'
) AS CurrentHousing ON p.patient_id = CurrentHousing.patient_id
WHERE e.emergency_count > 5;

-- Query 7
SELECT p.patient_id, p.first_name, p.last_name, COUNT(DISTINCT pr.procedure_id) AS procedure_count,
    CASE
        WHEN COUNT(DISTINCT m.medication_id) > 5 THEN 'Multiple Medications'
        ELSE 'Few Medications'
    END AS medication_risk
FROM patients p
LEFT JOIN visits v ON p.patient_id = v.patient_id
LEFT JOIN procedures pr ON v.visit_id = pr.visit_id
LEFT JOIN medications m ON v.visit_id = m.visit_id
GROUP BY p.patient_id, p.first_name, p.last_name
HAVING procedure_count > 3;

-- Query 8
WITH RecentDiagnoses AS (
    SELECT visit_id, diagnosis_code, diagnosis_type
    FROM diagnoses
    WHERE diagnosis_date > '2022-06-01'
)
SELECT DISTINCT v.visit_id, p.first_name, p.last_name, s.sdoh_type, rd.diagnosis_code,
    ROW_NUMBER() OVER (PARTITION BY p.patient_id ORDER BY v.visit_date DESC) AS recent_visit_rank
FROM visits v
JOIN RecentDiagnoses rd ON v.visit_id = rd.visit_id
JOIN sdoh_entries s ON v.patient_id = s.patient_id
JOIN patients p ON v.patient_id = p.patient_id
WHERE s.recorded_date BETWEEN '2022-01-01' AND '2022-12-31';

-- Query 9
SELECT DISTINCT p.patient_id, p.first_name, p.last_name, l.result_flag,
    SUM(c.claim_amount) AS total_claims, AVG(ser.survey_score) AS avg_survey_score
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
LEFT JOIN labs l ON v.visit_id = l.visit_id
JOIN claims c ON v.visit_id = c.visit_id
JOIN surveys ser ON p.patient_id = ser.patient_id
WHERE l.result_flag = 'H'
GROUP BY p.patient_id, p.first_name, p.last_name, l.result_flag
HAVING total_claims > 1000 AND avg_survey_score < 50;

-- Query 10
WITH HighCostClaims AS (
    SELECT claim_id, patient_id, SUM(billed_amount) AS total_billed
    FROM claims
    WHERE billed_amount > 1000
    GROUP BY claim_id, patient_id
)
SELECT DISTINCT p.patient_id, p.first_name, p.last_name,
    COUNT(DISTINCT sc.screening_id) AS screening_count,
    MAX(c.paid_amount) OVER (PARTITION BY p.patient_id) AS max_paid_amount
FROM HighCostClaims hcc
JOIN patients p ON hcc.patient_id = p.patient_id
LEFT JOIN screenings sc ON p.patient_id = sc.patient_id
JOIN billing b ON hcc.claim_id = b.claim_id
WHERE b.billed_date BETWEEN '2021-01-01' AND '2022-12-31'
ORDER BY max_paid_amount DESC;