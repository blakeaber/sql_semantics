-- Query 1
WITH RecentVisits AS (
    SELECT patient_id, MAX(visit_date) AS last_visit_date
    FROM visits
    WHERE was_emergency = TRUE
    GROUP BY patient_id
)
SELECT p.first_name, p.last_name, r.last_visit_date,
       COUNT(v.visit_id) OVER(PARTITION BY v.patient_id) AS visit_count,
       CASE WHEN COUNT(d.diagnosis_id) > 5 THEN 'Common' ELSE 'Rare' END AS diagnosis_frequency
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN RecentVisits r ON p.patient_id = r.patient_id
LEFT JOIN diagnostics d ON v.visit_id = d.visit_id
JOIN insurance i ON p.insurance_id = i.insurance_id
WHERE i.plan_type IN (
    SELECT plan_type
    FROM insurance
    WHERE expiration_date > CURRENT_DATE
)
HAVING visit_count > 3;

-- Query 2
WITH ProviderSpecialties AS (
    SELECT provider_id, specialty
    FROM providers
    WHERE specialty LIKE '%Cardiology%'
)
SELECT v.visit_id, v.visit_date, p.first_name, p.last_name,
       COALESCE(ps.specialty, 'General') AS provider_specialty,
       (EXTRACT(YEAR FROM v.discharge_time) - EXTRACT(YEAR FROM v.admission_time)) AS stay_duration
FROM visits v
JOIN patients p ON v.patient_id = p.patient_id
JOIN ProviderSpecialties ps ON v.provider_id = ps.provider_id
LEFT JOIN (
    SELECT visit_id, COUNT(procedure_id) AS procedure_count
    FROM procedures
    WHERE procedure_date > '2022-01-01'
    GROUP BY visit_id
) pr ON v.visit_id = pr.visit_id
WHERE pr.procedure_count > 2
ORDER BY stay_duration DESC;

-- Query 3
WITH AllergyCounts AS (
    SELECT patient_id, COUNT(allergy_id) AS allergy_count
    FROM allergies
    GROUP BY patient_id
)
SELECT p.patient_id, p.first_name, p.last_name, ac.allergy_count,
       (SELECT AVG(score_value) FROM risk_scores rs WHERE rs.patient_id = p.patient_id) AS avg_risk_score
FROM patients p
JOIN AllergyCounts ac ON p.patient_id = ac.patient_id
LEFT JOIN visits v ON p.patient_id = v.patient_id
JOIN screenings s ON p.patient_id = s.patient_id
WHERE s.result NOT LIKE 'Negative'
AND ac.allergy_count > 0
ORDER BY avg_risk_score DESC;

-- Query 4
WITH ProcedureAnalysis AS (
    SELECT visit_id, MAX(procedure_date) AS last_procedure_date
    FROM procedures
    GROUP BY visit_id
)
SELECT v.visit_date, p.first_name, p.last_name,
       CASE WHEN v.was_emergency THEN 'Emergency' ELSE 'Routine' END AS visit_type,
       COUNT(i.imaging_id) OVER() AS total_imagings,
       ra.race_ethnicity_name
FROM visits v
JOIN patients p ON v.patient_id = p.patient_id
LEFT JOIN imaging i ON v.visit_id = i.visit_id
JOIN race_ethnicity ra ON p.race_ethnicity_id = ra.race_ethnicity_id
JOIN ProcedureAnalysis pa ON v.visit_id = pa.visit_id
WHERE i.body_part IN ('Chest', 'Head')
AND pa.last_procedure_date > '2022-01-01'
ORDER BY total_imagings DESC;

-- Query 5
WITH LabResultSummary AS (
    SELECT patient_id, AVG(result_value) AS avg_lab_result
    FROM labs l
    JOIN visits v ON l.visit_id = v.visit_id
    GROUP BY patient_id
)
SELECT p.first_name, p.last_name, lrs.avg_lab_result,
       CASE WHEN lrs.avg_lab_result > 5.0 THEN 'High' ELSE 'Normal' END AS lab_risk_level,
       (p.created_at - p.updated_at) AS account_active_duration
FROM patients p
LEFT JOIN LabResultSummary lrs ON p.patient_id = lrs.patient_id
JOIN employment_status es ON p.patient_id = es.patient_id
JOIN contacts c ON p.address_id = c.address_id
WHERE es.employment_type = 'Full-Time'
ORDER BY lab_risk_level, account_active_duration;

-- Query 6
WITH IncomeAnalysis AS (
    SELECT patient_id, SUM(billed_amount) AS total_billed,
           SUM(paid_amount) AS total_paid
    FROM claims
    JOIN billing b ON claims.claim_id = b.claim_id
    GROUP BY patient_id
)
SELECT p.first_name, p.last_name, ia.total_billed, ia.total_paid,
       (ia.total_billed - ia.total_paid) AS outstanding_balance,
       COUNT(v.vital_id) OVER(PARTITION BY v.patient_id) AS vital_records_count
FROM patients p
JOIN IncomeAnalysis ia ON p.patient_id = ia.patient_id
LEFT JOIN vitals v ON p.patient_id = v.visit_id
WHERE ia.total_paid > 1000.0
AND v.heart_rate > 100
ORDER BY outstanding_balance;

-- Query 7
WITH MedicationDetails AS (
    SELECT visit_id, medication_name, COUNT(medication_id) as med_count
    FROM medications
    GROUP BY visit_id, medication_name
    HAVING med_count > 3
)
SELECT v.visit_id, v.visit_date, p.first_name, p.last_name,
       md.medication_name, md.med_count,
       ROUND(AVG(l.result_value) OVER(PARTITION BY v.visit_id), 2) AS avg_lab_results
FROM visits v
JOIN patients p ON v.patient_id = p.patient_id
JOIN MedicationDetails md ON v.visit_id = md.visit_id
LEFT JOIN labs l ON v.visit_id = l.visit_id
ORDER BY avg_lab_results DESC;

-- Query 8
WITH LanguageDiversity AS (
    SELECT language_id, COUNT(patient_id) AS patient_count
    FROM patients
    GROUP BY language_id
)
SELECT l.language_name, ld.patient_count,
       COUNT(distinct c.condition_id) OVER(PARTITION BY c.patient_id) AS unique_conditions_count,
       CASE WHEN ld.patient_count > 100 THEN 'High' ELSE 'Low' END AS language_popularity
FROM languages l
JOIN LanguageDiversity ld ON l.language_id = ld.language_id
LEFT JOIN conditions c ON ld.language_id = c.language_id
ORDER BY language_popularity, unique_conditions_count;

-- Query 9
WITH InsurancePayerSummary AS (
    SELECT payer_name, COUNT(insurance_id) AS total_plans
    FROM insurance
    GROUP BY payer_name
)
SELECT i.payer_name, ips.total_plans,
       SUM(cl.claim_amount) AS total_claims,
       ROW_NUMBER() OVER(PARTITION BY i.payer_name ORDER BY cl.claim_amount DESC) AS claim_ranking
FROM insurance i
JOIN InsurancePayerSummary ips ON i.payer_name = ips.payer_name
LEFT JOIN claims cl ON i.insurance_id = cl.insurance_id
WHERE ips.total_plans > 50
GROUP BY i.payer_name, ips.total_plans
ORDER BY claim_ranking;

-- Query 10
WITH RiskAssessment AS (
    SELECT patient_id, AVG(score_value) AS avg_risk_score
    FROM risk_scores
    GROUP BY patient_id
)
SELECT p.first_name, p.last_name, ra.avg_risk_score,
       COUNT(pr.procedure_id) OVER(PARTITION BY pr.visit_id) AS procedure_count,
       CASE
           WHEN ra.avg_risk_score > 5 THEN 'High Risk'
           WHEN ra.avg_risk_score BETWEEN 3 AND 5 THEN 'Medium Risk'
           ELSE 'Low Risk' 
       END AS risk_category
FROM patients p
JOIN RiskAssessment ra ON p.patient_id = ra.patient_id
JOIN visits v ON p.patient_id = v.patient_id
LEFT JOIN procedures pr ON v.visit_id = pr.visit_id
WHERE v.was_emergency = TRUE
AND procedure_count > 2
ORDER BY risk_category;