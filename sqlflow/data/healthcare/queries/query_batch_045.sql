-- Query 1
WITH avg_weights AS (
    SELECT patient_id, AVG(weight_kg) AS avg_weight
    FROM vitals
    GROUP BY patient_id
)
SELECT p.patient_id, p.first_name, p.last_name, v.visit_date,
       AVG(vitals.temperature_c) OVER (PARTITION BY v.patient_id ORDER BY v.visit_date) AS avg_temp,
       CASE WHEN v.visit_date > '2022-01-01' THEN 'Recent' ELSE 'Old' END AS recent_visit
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN avg_weights aw ON p.patient_id = aw.patient_id
JOIN vitals ON v.visit_id = vitals.visit_id
WHERE v.was_emergency = TRUE
HAVING COUNT(v.visit_id) > 1;

-- Query 2
WITH patient_conditions AS (
    SELECT patient_id, COUNT(*) AS condition_count
    FROM conditions
    WHERE condition_status = 'Active'
    GROUP BY patient_id
)
SELECT c.patient_id, COUNT(v.visit_id) AS total_visits,
       SUM(claims.paid_amount) - SUM(claims.billed_amount) AS payment_diff
FROM patient_conditions c
JOIN visits v ON c.patient_id = v.patient_id
JOIN claims ON v.visit_id = claims.visit_id
JOIN procedures ON v.visit_id = procedures.visit_id
WHERE c.condition_count > 3
GROUP BY c.patient_id
HAVING payment_diff > 500;

-- Query 3
WITH latest_housing_status AS (
    SELECT patient_id, housing_type, 
           ROW_NUMBER() OVER (PARTITION BY patient_id ORDER BY status_date DESC) AS rn
    FROM housing_status
)
SELECT hs.patient_id, COALESCE(hs.housing_type, 'Unknown') AS current_housing,
       income.income_level, COUNT(sym.symptom_id) AS symptom_count
FROM latest_housing_status hs
LEFT JOIN income_brackets income ON hs.patient_id = income.patient_id
LEFT JOIN symptoms sym ON hs.patient_id = sym.patient_id
WHERE hs.rn = 1
GROUP BY hs.patient_id, current_housing, income.income_level;

-- Query 4
WITH active_medications AS (
    SELECT visit_id, COUNT(*) AS med_count
    FROM medications
    WHERE end_date IS NULL OR end_date > CURRENT_DATE
    GROUP BY visit_id
)
SELECT p.patient_id, meds.med_count, prov.specialty,
       SUM(CASE WHEN im.imaging_type IS NOT NULL THEN 1 ELSE 0 END) AS imaging_count
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN active_medications meds ON v.visit_id = meds.visit_id
JOIN providers prov ON v.provider_id = prov.provider_id
LEFT JOIN imaging im ON v.visit_id = im.visit_id
GROUP BY p.patient_id, meds.med_count, prov.specialty
HAVING imaging_count > 2;

-- Query 5
WITH insurance_monthly AS (
    SELECT insurance_id, 
           DATE_TRUNC('month', effective_date) AS month, 
           COUNT(DISTINCT patient_id) AS patient_count
    FROM insurance
    GROUP BY insurance_id, month
)
SELECT ins.payer_name, COUNT(cl.claim_id) AS claims_count,
       ROUND(AVG(cl.paid_amount), 2) AS avg_payment
FROM insurance_monthly im
JOIN insurance ins ON im.insurance_id = ins.insurance_id
JOIN claims cl ON ins.insurance_id = cl.insurance_id
JOIN visits v ON cl.visit_id = v.visit_id
WHERE v.was_emergency = FALSE
GROUP BY ins.payer_name
ORDER BY avg_payment DESC;

-- Query 6
WITH recent_lab_results AS (
    SELECT l.visit_id, MAX(l.collected_date) AS recent_date
    FROM labs l 
    GROUP BY l.visit_id
)
SELECT p.patient_id, l.test_name, rec.recent_date,
       AVG(vitals.blood_pressure_systolic) AS avg_systolic,
       CASE WHEN l.result_flag = 'H' THEN 'High' ELSE 'Normal' END AS result_level
FROM labs l
JOIN recent_lab_results rec ON l.visit_id = rec.visit_id
JOIN visits v ON l.visit_id = v.visit_id
JOIN patients p ON v.patient_id = p.patient_id
JOIN vitals ON v.visit_id = vitals.visit_id
WHERE l.collected_date = rec.recent_date
GROUP BY p.patient_id, l.test_name, rec.recent_date, l.result_flag;

-- Query 7
WITH patient_allergies AS (
    SELECT patient_id, COUNT(*) AS allergy_count
    FROM allergies
    GROUP BY patient_id
)
SELECT p.patient_id, langs.language_name, COUNT(diagnoses.diagnosis_id) AS diagnosis_count,
       ROUND(AVG(insurance.claim_amount), 2) AS avg_claim_amount
FROM patients p
LEFT JOIN languages langs ON p.language_id = langs.language_id
LEFT JOIN diagnoses ON p.patient_id = diagnoses.patient_id
LEFT JOIN insurance ON p.insurance_id = insurance.insurance_id
JOIN patient_allergies pa ON p.patient_id = pa.patient_id
WHERE diagnosis_count > 2
GROUP BY p.patient_id, langs.language_name
HAVING pa.allergy_count <= 5;

-- Query 8
WITH top_conditions AS (
    SELECT patient_id, condition_name, 
           ROW_NUMBER() OVER (PARTITION BY patient_id ORDER BY diagnosed_date DESC) AS rn
    FROM conditions
    WHERE condition_status = 'Chronic'
)
SELECT c.patient_id, c.condition_name, COUNT(b.billing_id) AS billing_count,
       MIN(b.amount) AS min_payment
FROM top_conditions c
JOIN visits v ON c.patient_id = v.patient_id
JOIN claims cl ON v.visit_id = cl.visit_id
JOIN billing b ON cl.claim_id = b.claim_id
WHERE c.rn = 1
GROUP BY c.patient_id, c.condition_name
HAVING min_payment > 100;

-- Query 9
WITH emergency_visits AS (
    SELECT visit_id, COUNT(*) AS em_count
    FROM visits
    WHERE was_emergency = TRUE
    GROUP BY visit_id
)
SELECT p.patient_id, eth.race_ethnicity_name,
       SUM(vitals.height_cm) * 2.54 AS total_height_in_inches,
       CASE WHEN ev.em_count > 0 THEN 'Has Emergency' ELSE 'No Emergency' END AS emergency_status
FROM patients p
LEFT JOIN race_ethnicity eth ON p.race_ethnicity_id = eth.race_ethnicity_id
LEFT JOIN visits v ON p.patient_id = v.patient_id
JOIN vitals ON v.visit_id = vitals.visit_id
LEFT JOIN emergency_visits ev ON v.visit_id = ev.visit_id
GROUP BY p.patient_id, eth.race_ethnicity_name, emergency_status;

-- Query 10
WITH visit_durations AS (
    SELECT visit_id, 
           EXTRACT(EPOCH FROM (discharge_time - admission_time))/3600 AS visit_duration_hours
    FROM visits
    WHERE discharge_time IS NOT NULL
)
SELECT p.patient_id, COUNT(v.visit_id) AS visit_count, 
       ROUND(SUM(vd.visit_duration_hours), 2) AS total_visit_hours,
       SUM(CASE WHEN d.diagnosis_type = 'Primary' THEN 1 ELSE 0 END) AS primary_diagnosis
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN visit_durations vd ON v.visit_id = vd.visit_id
LEFT JOIN diagnoses d ON v.visit_id = d.visit_id
WHERE vd.visit_duration_hours > 1
GROUP BY p.patient_id
HAVING visit_count > 5;