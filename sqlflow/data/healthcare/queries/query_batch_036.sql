-- Query 1: Patient Visit Overview
WITH RecentVisits AS (
    SELECT patient_id, MAX(visit_date) AS last_visit_date
    FROM visits
    GROUP BY patient_id
)
SELECT p.patient_id, p.first_name, p.last_name, COUNT(v.visit_id) AS total_visits,
       AVG(DATEDIFF('day', v.admission_time, v.discharge_time)) AS avg_stay_days,
       CASE
           WHEN MAX(v.was_emergency) THEN 'Yes'
           ELSE 'No'
       END AS had_emergency_visit
FROM patients p
JOIN RecentVisits rv ON p.patient_id = rv.patient_id
JOIN visits v ON p.patient_id = v.patient_id AND v.visit_date = rv.last_visit_date
JOIN conditions c ON c.patient_id = p.patient_id
JOIN diagnosis d ON d.visit_id = v.visit_id
GROUP BY p.patient_id
HAVING COUNT(c.condition_id) > 5;

-- Query 2: Provider Specialty Performance
WITH SpecialtyVisitCount AS (
    SELECT provider_id, COUNT(*) AS total_visits
    FROM visits
    GROUP BY provider_id
)
SELECT pr.provider_id, pr.first_name AS provider_first_name, pr.last_name AS provider_last_name,
       pr.specialty, svc.total_visits, AVG(bp.billed_amount) AS avg_billed_amount
FROM providers pr
JOIN SpecialtyVisitCount svc ON pr.provider_id = svc.provider_id
JOIN visits v ON pr.provider_id = v.provider_id
JOIN claims c ON v.visit_id = c.visit_id
JOIN billing b ON c.claim_id = b.claim_id
WHERE pr.specialty IN (SELECT DISTINCT specialty FROM providers WHERE provider_id IN (SELECT provider_id FROM visits))
GROUP BY pr.provider_id, pr.specialty
ORDER BY avg_billed_amount DESC;

-- Query 3: Socioeconomic Impact on Health
WITH IncomeStatus AS (
    SELECT patient_id, MAX(income_level) AS latest_income_level
    FROM income_brackets
    GROUP BY patient_id
)
SELECT s.patient_id, i.latest_income_level, COUNT(cr.claim_id) AS num_claims,
       SUM(cr.claim_amount) AS total_claims, AVG(r.score_value) AS avg_risk_score
FROM surveys s
JOIN IncomeStatus i ON s.patient_id = i.patient_id
JOIN claims cr ON s.patient_id = cr.patient_id
JOIN risk_scores r ON s.patient_id = r.patient_id
WHERE cr.claim_status = 'Paid'
GROUP BY s.patient_id, i.latest_income_level
HAVING total_claims > 1000;

-- Query 4: Medication Utilization Trends
WITH MedicationTrends AS (
    SELECT m.visit_id, COUNT(*) AS num_medications
    FROM medications m
    WHERE m.start_date BETWEEN '2023-01-01' AND '2023-12-31'
    GROUP BY m.visit_id
)
SELECT pd.patient_id, pd.first_name || ' ' || pd.last_name AS full_name, COUNT(v.visit_id) AS visit_count,
       SUM(mt.num_medications) AS total_medication_count, ROUND(AVG(lb.result_value), 2) AS avg_lab_result
FROM patients pd
JOIN visits v ON pd.patient_id = v.patient_id
JOIN MedicationTrends mt ON v.visit_id = mt.visit_id
JOIN labs lb ON v.visit_id = lb.visit_id
WHERE lb.test_name = 'Glucose'
GROUP BY pd.patient_id
HAVING total_medication_count > 5;

-- Query 5: Emergency Visits and Outcomes
WITH EmergencyVisits AS (
    SELECT visit_id, patient_id, COUNT(*) AS emergency_count
    FROM visits
    WHERE was_emergency = TRUE
    GROUP BY visit_id, patient_id
)
SELECT p.patient_id, p.first_name, p.last_name, ev.emergency_count, c.condition_name,
       CASE
           WHEN r.score_value > 8 THEN 'High Risk'
           ELSE 'Low Risk'
       END AS risk_category
FROM EmergencyVisits ev
JOIN patients p ON ev.patient_id = p.patient_id
JOIN conditions c ON p.patient_id = c.patient_id
JOIN risk_scores r ON p.patient_id = r.patient_id
WHERE EXISTS (SELECT 1 FROM smoking c WHERE c.patient_id = p.patient_id)
GROUP BY p.patient_id, c.condition_name, r.score_value;

-- Query 6: Provider-Patient Interaction
WITH ProviderInteractions AS (
    SELECT provider_id, patient_id, COUNT(*) AS interaction_count
    FROM visits
    GROUP BY provider_id, patient_id
)
SELECT pr.provider_id, pr.first_name AS provider_name, p.patient_id, 
       p.first_name || ' ' || p.last_name AS patient_name, pi.interaction_count,
       CASE
           WHEN pi.interaction_count > 10 THEN 'Frequent'
           ELSE 'Infrequent'
       END AS interaction_level
FROM ProviderInteractions pi
JOIN providers pr ON pi.provider_id = pr.provider_id
JOIN patients p ON pi.patient_id = p.patient_id
HAVING interaction_level = 'Frequent';

-- Query 7: Diagnostic Variation by Demographics
WITH TopDiagnoses AS (
    SELECT diagnosis_code, COUNT(*) AS cod_count
    FROM diagnoses
    GROUP BY diagnosis_code
    ORDER BY cod_count DESC
    LIMIT 5
)
SELECT p.race_ethnicity_id, re.race_ethnicity_name, td.diagnosis_code, COUNT(d.diagnosis_id) AS diag_count,
       SUM(case WHEN p.gender = 'Female' THEN 1 ELSE 0 END) AS female_count
FROM TopDiagnoses td
JOIN diagnoses d ON td.diagnosis_code = d.diagnosis_code
JOIN patients p ON d.visit_id = p.patient_id
JOIN race_ethnicity re ON p.race_ethnicity_id = re.race_ethnicity_id
GROUP BY p.race_ethnicity_id, re.race_ethnicity_name, td.diagnosis_code;

-- Query 8: Medication Adherence Study
WITH Adherence AS (
    SELECT patient_id, medication_id, DATEDIFF('day', MIN(start_date), MAX(end_date)) AS adherence_days
    FROM medications
    GROUP BY patient_id, medication_id
)
SELECT p.first_name || ' ' || p.last_name AS patient_name, SUM(a.adherence_days) AS total_adherence_days,
       (SUM(pa.amount) / COUNT(pa.payment_id)) AS avg_payment_amount
FROM Adherence a
JOIN patients p ON a.patient_id = p.patient_id
JOIN payments pa ON p.patient_id = pa.patient_id
GROUP BY p.patient_id
HAVING total_adherence_days > 180;

-- Query 9: Comprehensive Lab Results
WITH LabAnalysis AS (
    SELECT visit_id, AVG(result_value) OVER (PARTITION BY test_code) AS avg_result,
           MAX(result_value) OVER (PARTITION BY test_code) AS max_result
    FROM labs
)
SELECT p.patient_id, p.first_name, p.last_name, la.test_code, la.avg_result, la.max_result,
       CASE
           WHEN la.avg_result > 100 THEN 'Above Normal'
           ELSE 'Normal'
       END AS result_status
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN LabAnalysis la ON v.visit_id = la.visit_id
WHERE la.test_code IN ('HbA1c', 'LipidPanel')
GROUP BY p.patient_id, la.test_code, la.avg_result, la.max_result;

-- Query 10: Provider Billing Insights
WITH BillingSummary AS (
    SELECT provider_id, SUM(amount) AS total_billed
    FROM billing
    GROUP BY provider_id
)
SELECT pr.provider_id, pr.first_name || ' ' || pr.last_name AS provider_name, bs.total_billed,
       Array_agg(DISTINCT v.reason_for_visit) AS visit_reasons
FROM BillingSummary bs
JOIN providers pr ON bs.provider_id = pr.provider_id
JOIN visits v ON pr.provider_id = v.provider_id
WHERE v.visit_date BETWEEN '2023-01-01' AND '2023-12-31'
GROUP BY pr.provider_id, bs.total_billed
HAVING SUM(bs.total_billed) > 10000;