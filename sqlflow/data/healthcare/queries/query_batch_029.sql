-- Query 1
WITH PatientEncounters AS (
    SELECT p.patient_id, v.visit_id, v.provider_id, v.visit_date, v.was_emergency
    FROM patients p
    JOIN visits v ON p.patient_id = v.patient_id
)
SELECT p.patient_id, 
    MAX(e.encounter_count) AS max_encounters,
    SUM(CASE WHEN e.was_emergency THEN 1 ELSE 0 END) AS emergency_visits
FROM PatientEncounters e
JOIN (
    SELECT patient_id, COUNT(visit_id) AS encounter_count
    FROM visits
    WHERE visit_date BETWEEN '2022-01-01' AND '2023-01-01'
    GROUP BY patient_id
) encounter_summary ON e.patient_id = encounter_summary.patient_id
JOIN race_ethnicity re ON re.race_ethnicity_id = (SELECT race_ethnicity_id FROM patients WHERE patient_id = e.patient_id)
WHERE re.race_ethnicity_name IN ('Hispanic', 'Asian')
GROUP BY p.patient_id, re.race_ethnicity_name
HAVING COUNT(e.visit_id) > 5;

-- Query 2
WITH RecentInsurance AS (
    SELECT DISTINCT i.insurance_id, i.payer_name, MAX(i.effective_date) AS max_effective_date
    FROM insurance i
    JOIN patients p ON i.insurance_id = p.insurance_id
    GROUP BY i.insurance_id, i.payer_name
)
SELECT p.patient_id, COUNT(cl.claim_id) AS num_claims, SUM(cl.paid_amount) AS total_paid,
    ri.payer_name,
    AVG(cl.claim_amount) OVER (PARTITION BY p.patient_id) AS avg_claim_amount
FROM claims cl
JOIN patients p ON cl.patient_id = p.patient_id
JOIN RecentInsurance ri ON p.insurance_id = ri.insurance_id
JOIN payments pm ON cl.claim_id = pm.claim_id
WHERE cl.claim_date > '2021-01-01'
GROUP BY p.patient_id, ri.payer_name
HAVING SUM(cl.paid_amount) > 1000;

-- Query 3
WITH PatientConditions AS (
    SELECT patient_id, COUNT(condition_id) AS condition_count
    FROM conditions
    GROUP BY patient_id
)
SELECT p.patient_id, pe.condition_count, AVG(pe.condition_count) OVER () AS avg_conditions,
    la.language_name,
    CASE WHEN pe.condition_count > 5 THEN 'High Risk' ELSE 'Medium Risk' END AS risk_category
FROM patients p
JOIN PatientConditions pe ON p.patient_id = pe.patient_id
JOIN languages la ON p.language_id = la.language_id
JOIN (
    SELECT l.language_id, COUNT(p.patient_id) AS patient_languages
    FROM languages l
    JOIN patients p ON p.language_id = l.language_id
    GROUP BY l.language_id
) lang_summary ON la.language_id = lang_summary.language_id
WHERE la.language_name LIKE 'English%'
ORDER BY pe.condition_count DESC;

-- Query 4
WITH MedicationUse AS (
    SELECT visit_id, COUNT(medication_id) AS medication_count
    FROM medications
    GROUP BY visit_id
)
SELECT v.visit_id, COUNT(d.diagnosis_id) AS num_diagnoses, mu.medication_count,
    AVG(mu.medication_count) OVER (PARTITION BY v.provider_id) AS avg_medications,
    (v.discharge_time - v.admission_time) / INTERVAL '1 hour' AS length_of_stay
FROM visits v
JOIN MedicationUse mu ON v.visit_id = mu.visit_id
JOIN diagnoses d ON v.visit_id = d.visit_id
WHERE v.visit_date BETWEEN '2022-01-01' AND '2022-12-31'
AND v.was_emergency = TRUE
GROUP BY v.visit_id, mu.medication_count, v.provider_id
HAVING LENGTHOFSTAY >= 5;

-- Query 5
WITH EmergencyVisitSummary AS (
    SELECT v.patient_id, COUNT(visit_id) AS emergency_count
    FROM visits v
    WHERE v.was_emergency = TRUE
    GROUP BY v.patient_id
)
SELECT p.patient_id, ev.emergency_count, a.street_address,
    ROUND(SUM(cl.claim_amount)) AS total_claims,
    MAX(pe.recorded_date) AS last_sdoh_record
FROM patients p
JOIN EmergencyVisitSummary ev ON p.patient_id = ev.patient_id
JOIN addresses a ON p.address_id = a.address_id
JOIN claims cl ON p.patient_id = cl.patient_id
LEFT JOIN sdoh_entries pe ON p.patient_id = pe.patient_id
WHERE a.city IN ('New York', 'Los Angeles')
GROUP BY p.patient_id, ev.emergency_count, a.street_address
HAVING total_claims > 2000;

-- Query 6
WITH VitalsSummary AS (
    SELECT visit_id,
        AVG(bmi) AS avg_bmi,
        AVG(heart_rate) AS avg_hr
    FROM vitals
    GROUP BY visit_id
)
SELECT v.visit_id, vs.avg_bmi, vs.avg_hr,
    CASE WHEN vs.avg_bmi > 30 THEN 'Obese' ELSE 'Normal' END AS bmi_category,
    hr.risk_category
FROM visits v
JOIN VitalsSummary vs ON v.visit_id = vs.visit_id
JOIN (
    SELECT patient_id,
        CASE WHEN AVG(score_value) > 70 THEN 'High Risk' ELSE 'Low Risk' END AS risk_category
    FROM risk_scores
    GROUP BY patient_id
) hr ON v.patient_id = hr.patient_id
WHERE vs.avg_bmi IS NOT NULL
AND v.location = 'Emergency Room'
ORDER BY vs.avg_bmi DESC;

-- Query 7
WITH ClaimsSummary AS (
    SELECT cl.patient_id,
        SUM(cl.claim_amount) AS total_claims,
        AVG(cl.paid_amount) AS avg_paid
    FROM claims cl
    WHERE cl.claim_status = 'Paid'
    GROUP BY cl.patient_id
)
SELECT p.patient_id, cs.total_claims, cs.avg_paid,
    e.housing_type, h.payments_count
FROM patients p
JOIN ClaimsSummary cs ON p.patient_id = cs.patient_id
JOIN housing_status e ON p.patient_id = e.patient_id
LEFT JOIN (
    SELECT patient_id, COUNT(payment_id) AS payments_count
    FROM payments pm
    GROUP BY patient_id
) h ON p.patient_id = h.patient_id
WHERE e.housing_type = 'Renter'
AND cs.total_claims > 5000
ORDER BY cs.total_claims DESC;

-- Query 8
WITH AggregateImaging AS (
    SELECT v.visit_id, COUNT(i.imaging_id) AS imaging_count
    FROM imaging i
    JOIN visits v ON i.visit_id = v.visit_id
    GROUP BY v.visit_id
)
SELECT v.visit_id, ai.imaging_count, SUM(d.diagnosis_code) AS total_diagnosis_codes,
    i.diagnosis_type, cumulative_codes
FROM AggregateImaging ai
JOIN visits v ON ai.visit_id = v.visit_id
JOIN diagnoses d ON v.visit_id = d.visit_id
JOIN (
    SELECT diagnosis_type, SUM(diagnosis_code) AS cumulative_codes
    FROM diagnoses
    GROUP BY diagnosis_type
) i ON d.diagnosis_type = i.diagnosis_type
WHERE v.location = 'Clinic'
AND ai.imaging_count > 2
GROUP BY v.visit_id, ai.imaging_count, i.diagnosis_type, cumulative_codes
HAVING SUM(d.diagnosis_code) > 200;

-- Query 9
WITH ProviderSpecialties AS (
    SELECT provider_id, specialty,
        ROW_NUMBER() OVER (PARTITION BY specialty ORDER BY created_at DESC) as row_num
    FROM providers
)
SELECT v.visit_id, ps.specialty, COUNT(vs.vital_id) AS vital_count,
    p.created_at,
    CASE WHEN ps.row_num = 1 THEN 'Recent' ELSE 'Not Recent' END AS is_recent
FROM visits v
JOIN vitals vs ON v.visit_id = vs.visit_id
JOIN ProviderSpecialties ps ON v.provider_id = ps.provider_id
JOIN patients p ON v.patient_id = p.patient_id
WHERE ps.specialty IN ('Cardiology', 'Orthopedics')
AND v.visit_date BETWEEN '2021-01-01' AND '2022-01-01'
GROUP BY v.visit_id, ps.specialty, p.created_at, ps.row_num
HAVING COUNT(vs.vital_id) > 4;

-- Query 10
WITH EmploymentSummary AS (
    SELECT patient_id, COUNT(employment_id) AS job_changes
    FROM employment_status
    WHERE status_date BETWEEN '2020-01-01' AND '2023-01-01'
    GROUP BY patient_id
)
SELECT p.patient_id, es.job_changes, COUNT(s.survey_id) AS num_surveys,
    sc.screening_type, total_score
FROM patients p
JOIN EmploymentSummary es ON p.patient_id = es.patient_id
JOIN surveys s ON p.patient_id = s.patient_id
JOIN (
    SELECT screening_type, SUM(survey_score) AS total_score
    FROM screenings
    GROUP BY screening_type
) sc ON s.patient_id = sc.screening_type
WHERE es.job_changes > 2
AND sc.total_score > 100
GROUP BY p.patient_id, es.job_changes, sc.screening_type, total_score
HAVING num_surveys >= 3;