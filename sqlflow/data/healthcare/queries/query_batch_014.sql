-- Query 1
WITH RecentVisits AS (
    SELECT visit_id, patient_id, visit_date
    FROM visits
    WHERE visit_date > CURRENT_DATE - INTERVAL '1 year'
)
SELECT p.patient_id, p.first_name, p.last_name,
       SUM(CASE WHEN v.was_emergency THEN 1 ELSE 0 END) AS emergency_visits,
       COUNT(d.diagnosis_id) AS total_diagnoses
FROM patients p
JOIN RecentVisits rv ON p.patient_id = rv.patient_id
LEFT JOIN visits v ON rv.visit_id = v.visit_id
LEFT JOIN diagnoses d ON v.visit_id = d.visit_id
GROUP BY p.patient_id, p.first_name, p.last_name
HAVING COUNT(d.diagnosis_id) > 5;

-- Query 2
SELECT p.patient_id, p.first_name, p.last_name,
       COALESCE(icb.income_level, 'Unknown') AS income_level,
       AVG(v.visit_date - p.date_of_birth) AS avg_age_at_visit
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
LEFT JOIN (
    SELECT patient_id, income_level, MAX(recorded_date) AS last_income_date
    FROM income_brackets
    GROUP BY patient_id, income_level
) icb ON p.patient_id = icb.patient_id
GROUP BY p.patient_id, p.first_name, p.last_name, icb.income_level;

-- Query 3
WITH LabCounts AS (
    SELECT visit_id, COUNT(lab_result_id) AS lab_count
    FROM labs
    GROUP BY visit_id
)
SELECT v.visit_id, p.first_name, p.last_name, e.encounter_type_name,
       AVG(lc.lab_count) OVER (PARTITION BY p.race_ethnicity_id) AS avg_labs_per_race
FROM visits v
JOIN patients p ON v.patient_id = p.patient_id
JOIN encounter_types e ON v.encounter_type_id = e.encounter_type_id
LEFT JOIN LabCounts lc ON v.visit_id = lc.visit_id
JOIN race_ethnicity re ON p.race_ethnicity_id = re.race_ethnicity_id;

-- Query 4
SELECT v.visit_id, p.full_name, COUNT(m.medication_id) AS medication_count,
       AVG(pr.procedure_date - v.visit_date) AS avg_days_to_procedure
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
LEFT JOIN medications m ON v.visit_id = m.visit_id
LEFT JOIN (
    SELECT visit_id, procedure_date
    FROM procedures
    WHERE procedure_date IS NOT NULL
) pr ON v.visit_id = pr.visit_id
GROUP BY v.visit_id, p.full_name
HAVING medication_count > 2;

-- Query 5
WITH WeightChanges AS (
    SELECT v.visit_id, MAX(vl.weight_kg) AS max_weight, MIN(vl.weight_kg) AS min_weight
    FROM visits v
    JOIN vitals vl ON v.visit_id = vl.visit_id
    GROUP BY v.visit_id
)
SELECT p.first_name, p.last_name, ws.max_weight - ws.min_weight AS weight_change,
       AVG(cl.claim_amount) AS avg_claim_amount
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN WeightChanges ws ON v.visit_id = ws.visit_id
LEFT JOIN claims cl ON v.visit_id = cl.visit_id
GROUP BY p.first_name, p.last_name, ws.weight_change;

-- Query 6
SELECT p.patient_id, h.housing_type, COUNT(v.visit_id) AS visit_count,
       SUM(CASE WHEN v.was_emergency THEN 1 ELSE 0 END) / COUNT(v.visit_id)::FLOAT AS emergency_ratio
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
LEFT JOIN (
    SELECT patient_id, housing_type
    FROM housing_status
    WHERE status_date = (SELECT MAX(status_date) FROM housing_status WHERE patient_id = p.patient_id)
) h ON p.patient_id = h.patient_id
GROUP BY p.patient_id, h.housing_type;

-- Query 7
WITH DiagSummaries AS (
    SELECT d.visit_id, COUNT(d.diagnosis_id) AS diagnosis_count
    FROM diagnoses d
    GROUP BY d.visit_id
)
SELECT pt.first_name, pt.last_name, pr.specialty,
       COALESCE(ds.diagnosis_count, 0) AS total_diagnoses
FROM patients pt
JOIN visits v ON pt.patient_id = v.patient_id
JOIN providers pr ON v.provider_id = pr.provider_id
LEFT JOIN DiagSummaries ds ON v.visit_id = ds.visit_id
WHERE pr.specialty IN ('Cardiology', 'Oncology')
ORDER BY total_diagnoses DESC;

-- Query 8
SELECT p.patient_id, p.gender, s.survey_type,
       AVG(scores.avg_score) AS avg_survey_score
FROM patients p
JOIN (
    SELECT patient_id, survey_type, AVG(survey_score) AS avg_score
    FROM surveys
    GROUP BY patient_id, survey_type
) scores ON p.patient_id = scores.patient_id
JOIN surveys s ON scores.patient_id = s.patient_id
WHERE p.gender = 'Female'
GROUP BY p.patient_id, p.gender, s.survey_type;

-- Query 9
WITH BillingInfo AS (
    SELECT b.claim_id, SUM(b.amount) AS total_billed
    FROM billing b
    GROUP BY b.claim_id
)
SELECT i.payer_name, COUNT(c.claim_id) AS claim_count,
       AVG(bi.total_billed) AS avg_billed_amount
FROM claims c
JOIN patients p ON c.patient_id = p.patient_id
JOIN insurance i ON p.insurance_id = i.insurance_id
LEFT JOIN BillingInfo bi ON c.claim_id = bi.claim_id
WHERE c.claim_status = 'Paid'
GROUP BY i.payer_name;

-- Query 10
SELECT p.patient_id, c.condition_name, c.condition_status,
       COUNT(visits_data.visit_id) AS related_visits
FROM patients p
JOIN conditions c ON p.patient_id = c.patient_id
JOIN (
    SELECT visit_id, patient_id
    FROM visits
    WHERE admission_time > '2023-01-01'
) visits_data ON visits_data.patient_id = p.patient_id
GROUP BY p.patient_id, c.condition_name, c.condition_status
HAVING related_visits > 3;