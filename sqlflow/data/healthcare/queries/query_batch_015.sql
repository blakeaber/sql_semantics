-- Query 1
WITH PatientAge AS (
    SELECT patient_id, 
           EXTRACT(YEAR FROM AGE(NOW(), date_of_birth)) AS age
    FROM patients
)
SELECT p.first_name, p.last_name, pa.age, COUNT(v.visit_id) AS total_visits
FROM PatientAge pa
JOIN patients p ON pa.patient_id = p.patient_id
JOIN visits v ON p.patient_id = v.patient_id
LEFT JOIN (
    SELECT visit_id
    FROM procedures
    WHERE procedure_date > NOW() - INTERVAL '1 year'
) recent_procedures ON v.visit_id = recent_procedures.visit_id
GROUP BY p.first_name, p.last_name, pa.age
HAVING COUNT(v.visit_id) > 5;

-- Query 2
WITH HighRiskPatients AS (
    SELECT patient_id, 
           MAX(score_value) AS max_risk_score
    FROM risk_scores
    GROUP BY patient_id
    HAVING MAX(score_value) > 80
)
SELECT p.first_name, p.last_name, hrp.max_risk_score, d.diagnosis_code
FROM HighRiskPatients hrp
JOIN patients p ON hrp.patient_id = p.patient_id
JOIN visits v ON p.patient_id = v.patient_id
JOIN diagnoses d ON v.visit_id = d.visit_id
WHERE d.diagnosis_type IN ('Critical', 'Severe');

-- Query 3
WITH BillingInfo AS (
    SELECT visit_id, 
           SUM(amount) AS total_billed
    FROM billing
    GROUP BY visit_id
)
SELECT p.first_name, p.last_name, v.visit_date, b.total_billed,
       CASE WHEN was_emergency THEN 'Emergency' ELSE 'Non-Emergency' END AS visit_type
FROM visits v
JOIN patients p ON v.patient_id = p.patient_id
JOIN BillingInfo b ON v.visit_id = b.visit_id
LEFT JOIN (
    SELECT visit_id
    FROM claims
    WHERE claim_status = 'Denied'
) denied_claims ON v.visit_id = denied_claims.visit_id
WHERE denied_claims.visit_id IS NOT NULL;

-- Query 4
SELECT p.first_name, p.last_name, AVG(l.result_value) AS avg_lab_result
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN (
    SELECT visit_id, 
           result_value
    FROM labs
    WHERE result_flag = 'Abnormal'
) abnormal_labs ON v.visit_id = abnormal_labs.visit_id
GROUP BY p.first_name, p.last_name
HAVING AVG(abnormal_labs.result_value) > 5;

-- Query 5
WITH ProviderSpecialtyVisits AS (
    SELECT provider_id, 
           COUNT(DISTINCT visit_id) AS num_visits
    FROM visits
    GROUP BY provider_id
)
SELECT prv.first_name, prv.last_name, prv.specialty, psv.num_visits
FROM providers prv
JOIN ProviderSpecialtyVisits psv ON prv.provider_id = psv.provider_id
LEFT JOIN (
    SELECT provider_id, 
           COUNT(*) AS denied_claims
    FROM claims
    WHERE claim_status = 'Denied'
    GROUP BY provider_id
) denied ON prv.provider_id = denied.provider_id;

-- Query 6
WITH RecentDiagnoses AS (
    SELECT patient_id, 
           diagnosis_date, 
           ROW_NUMBER() OVER (PARTITION BY patient_id ORDER BY diagnosis_date DESC) as rn
    FROM diagnoses
)
SELECT p.first_name, p.last_name, d.diagnosis_code, r.max_risk
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN RecentDiagnoses r ON v.visit_id = r.visit_id
JOIN (SELECT visit_id, MAX(score_value) AS max_risk
      FROM risk_scores
      GROUP BY visit_id) risk ON v.visit_id = risk.visit_id
WHERE r.rn = 1;

-- Query 7
SELECT p.first_name, p.last_name, s.survey_type, AVG(survey_score) AS avg_score
FROM patients p
JOIN surveys s ON p.patient_id = s.patient_id
WHERE s.survey_date > CURRENT_DATE - INTERVAL '6 months'
GROUP BY p.first_name, p.last_name, s.survey_type
HAVING AVG(survey_score) > 70;

-- Query 8
WITH EmploymentHistory AS (
    SELECT patient_id, 
           MAX(status_date) AS latest_status_date
    FROM employment_status
    GROUP BY patient_id
)
SELECT p.first_name, p.last_name, e.employment_type, e.employer_name
FROM patients p
JOIN EmploymentHistory eh ON p.patient_id = eh.patient_id
JOIN employment_status e ON eh.patient_id = e.patient_id AND eh.latest_status_date = e.status_date
JOIN conditions c ON p.patient_id = c.patient_id
WHERE c.condition_status = 'Active';

-- Query 9
SELECT p.first_name, p.last_name, COUNT(m.medication_id) AS num_medications, AVG(d.paid_amount) AS avg_payment
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN medications m ON v.visit_id = m.visit_id
LEFT JOIN (
    SELECT visit_id, 
           SUM(paid_amount) AS paid_amount
    FROM claims
    GROUP BY visit_id
) d ON v.visit_id = d.visit_id
GROUP BY p.first_name, p.last_name
HAVING COUNT(m.medication_id) > 3;

-- Query 10
SELECT i.imaging_type, i.body_part, AVG(l.result_value) AS avg_lab_result
FROM imaging i
JOIN visits v ON i.visit_id = v.visit_id
JOIN patients p ON v.patient_id = p.patient_id
JOIN (
    SELECT visit_id, 
           result_value
    FROM labs
) l ON v.visit_id = l.visit_id
GROUP BY i.imaging_type, i.body_part
HAVING COUNT(DISTINCT p.patient_id) > 10;