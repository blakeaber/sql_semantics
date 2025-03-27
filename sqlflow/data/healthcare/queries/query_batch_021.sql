-- Query 1
WITH FrequentVisitors AS (
    SELECT patient_id, COUNT(visit_id) AS visit_count
    FROM visits
    GROUP BY patient_id
    HAVING COUNT(visit_id) > 5
)
SELECT p.first_name, p.last_name, pe.enrollment_type, SUM(b.amount) AS total_billed
FROM patients p
JOIN FrequentVisitors fv ON p.patient_id = fv.patient_id
JOIN insurance i ON p.insurance_id = i.insurance_id
JOIN claims c ON p.patient_id = c.patient_id
JOIN billing b ON c.claim_id = b.claim_id
LEFT JOIN (SELECT patient_id, MAX(plan_type) AS enrollment_type FROM insurance GROUP BY patient_id) pe ON pe.patient_id = p.patient_id
GROUP BY p.first_name, p.last_name, pe.enrollment_type
ORDER BY total_billed DESC;

-- Query 2
WITH RecentAdmissions AS (
    SELECT visit_id, ROW_NUMBER() OVER (PARTITION BY patient_id ORDER BY admission_time DESC) AS visit_rank
    FROM visits
    WHERE was_emergency = TRUE
)
SELECT p.first_name, p.last_name, v.reason_for_visit, SUM(b.amount) AS total_cost,
       CASE WHEN SUM(b.amount) > 1000 THEN 'High' ELSE 'Normal' END AS cost_category
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN RecentAdmissions ra ON v.visit_id = ra.visit_id AND ra.visit_rank = 1
LEFT JOIN claims c ON v.visit_id = c.visit_id
LEFT JOIN billing b ON c.claim_id = b.claim_id
GROUP BY p.first_name, p.last_name, v.reason_for_visit
HAVING total_cost > 500;

-- Query 3
WITH AgeGroups AS (
    SELECT patient_id,
           EXTRACT(YEAR FROM visit_date) - EXTRACT(YEAR FROM date_of_birth) AS age
    FROM patients p
    JOIN visits v ON p.patient_id = v.patient_id
)
SELECT ag.age,
       COUNT(DISTINCT d.diagnosis_code) AS unique_diagnoses,
       AVG(l.result_value) AS avg_lab_result
FROM AgeGroups ag
JOIN visits v ON ag.patient_id = v.patient_id
JOIN diagnoses d ON v.visit_id = d.visit_id
JOIN labs l ON v.visit_id = l.visit_id
WHERE l.result_flag = 'Abnormal'
GROUP BY ag.age
ORDER BY avg_lab_result DESC;

-- Query 4
WITH PatientConditions AS (
    SELECT patient_id, COUNT(condition_id) AS condition_count
    FROM conditions
    WHERE condition_status = 'Active'
    GROUP BY patient_id
)
SELECT p.first_name, p.last_name, e.employer_name, COUNT(DISTINCT imp.impression) AS unique_impressions
FROM patients p
JOIN employment_status e ON p.patient_id = e.patient_id
JOIN visits v ON p.patient_id = v.patient_id
LEFT JOIN imaging imp ON v.visit_id = imp.visit_id
JOIN PatientConditions pc ON pc.patient_id = p.patient_id
GROUP BY p.first_name, p.last_name, e.employer_name
ORDER BY unique_impressions DESC;

-- Query 5
WITH SocialDeterminants AS (
    SELECT patient_id, COUNT(sdoh_id) AS sdoh_count
    FROM sdoh_entries
    WHERE EXTRACT(YEAR FROM recorded_date) = 2023
    GROUP BY patient_id
)
SELECT p.patient_id, COUNT(DISTINCT phs.housing_type) AS housing_variants, SUM(psd.sdoh_count) AS total_sdoh
FROM patients p
LEFT JOIN housing_status phs ON p.patient_id = phs.patient_id
JOIN visits v ON p.patient_id = v.patient_id
JOIN SocialDeterminants psd ON p.patient_id = psd.patient_id
GROUP BY p.patient_id
HAVING total_sdoh > 3;

-- Query 6
WITH MedicationUsage AS (
    SELECT visit_id, COUNT(medication_id) AS medication_count
    FROM medications
    GROUP BY visit_id
)
SELECT p.first_name, p.last_name, AVG(v.bmi) AS avg_bmi,
       MAX(CASE WHEN l.result_flag = 'High' THEN l.result_value ELSE NULL END) AS max_high_lab_result
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN vitals vt ON v.visit_id = vt.visit_id
JOIN labs l ON v.visit_id = l.visit_id
JOIN MedicationUsage mu ON v.visit_id = mu.visit_id
WHERE mu.medication_count > 2
GROUP BY p.first_name, p.last_name
ORDER BY avg_bmi DESC;

-- Query 7
WITH PaymentDetails AS (
    SELECT claim_id, payment_source, SUM(amount) AS total_paid
    FROM payments
    GROUP BY claim_id, payment_source
)
SELECT i.payer_name, pd.payment_source, AVG(pd.total_paid) AS avg_payment,
       COUNT(DISTINCT c.claim_id) AS claim_count
FROM insurance i
JOIN patients p ON i.insurance_id = p.insurance_id
JOIN claims c ON p.patient_id = c.patient_id
JOIN PaymentDetails pd ON c.claim_id = pd.claim_id
GROUP BY i.payer_name, pd.payment_source
HAVING avg_payment > 500;

-- Query 8
WITH SurveyResults AS (
    SELECT patient_id, AVG(survey_score) AS avg_score
    FROM surveys
    WHERE survey_type = 'Mental Health'
    GROUP BY patient_id
)
SELECT p.first_name, p.last_name, sr.avg_score,
       CASE WHEN rs.score_value > 7.5 THEN 'High Risk' ELSE 'Low Risk' END AS risk_category
FROM patients p
JOIN risk_scores rs ON p.patient_id = rs.patient_id
LEFT JOIN SurveyResults sr ON p.patient_id = sr.patient_id
WHERE rs.calculated_date > CURRENT_DATE - INTERVAL '1 year'
ORDER BY risk_category, sr.avg_score ASC;

-- Query 9
WITH ActiveTeams AS (
    SELECT patient_id, COUNT(care_team_id) AS team_count
    FROM patient_care_team
    GROUP BY patient_id
    HAVING COUNT(care_team_id) > 1
)
SELECT p.first_name, p.last_name, COUNT(s.screening_type) AS screenings_count,
       MIN(cn.created_at) AS earliest_note
FROM patients p
JOIN ActiveTeams at ON p.patient_id = at.patient_id
JOIN visits v ON p.patient_id = v.patient_id
JOIN screenings s ON p.patient_id = s.patient_id
LEFT JOIN clinical_notes cn ON v.visit_id = cn.visit_id
GROUP BY p.first_name, p.last_name
ORDER BY screenings_count DESC;

-- Query 10
WITH ProcedureFrequency AS (
    SELECT procedure_code, COUNT(procedure_id) AS procedure_count
    FROM procedures
    GROUP BY procedure_code
)
SELECT ep.employment_type, pf.procedure_code, pf.procedure_count,
       COUNT(race_ethnicity_name) AS race_ethnicity_count
FROM patients p
JOIN employment_status ep ON p.patient_id = ep.patient_id
JOIN visits v ON p.patient_id = v.patient_id
JOIN procedures pc ON v.visit_id = pc.visit_id
JOIN ProcedureFrequency pf ON pc.procedure_code = pf.procedure_code
JOIN race_ethnicity re ON p.race_ethnicity_id = re.race_ethnicity_id
GROUP BY ep.employment_type, pf.procedure_code, pf.procedure_count
ORDER BY procedure_count DESC;