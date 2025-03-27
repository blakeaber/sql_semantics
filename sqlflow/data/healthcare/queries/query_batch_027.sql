-- Query 1
WITH RecentConditions AS (
    SELECT patient_id, condition_name,
           ROW_NUMBER() OVER (PARTITION BY patient_id ORDER BY diagnosed_date DESC) AS rn
    FROM conditions
)
SELECT p.first_name, p.last_name, rc.condition_name,
       COUNT(DISTINCT v.visit_id) AS visit_count,
       AVG(l.result_value) AS avg_lab_result
FROM patients p
JOIN (
    SELECT patient_id, MAX(recorded_date) AS latest_record
    FROM allergies
    GROUP BY patient_id
) a ON p.patient_id = a.patient_id
JOIN visits v ON p.patient_id = v.patient_id
JOIN labs l ON v.visit_id = l.visit_id
JOIN RecentConditions rc ON p.patient_id = rc.patient_id AND rc.rn = 1
WHERE l.result_flag = 'High'
GROUP BY p.first_name, p.last_name, rc.condition_name
HAVING COUNT(DISTINCT v.visit_id) > 1;

-- Query 2
WITH AverageVitals AS (
    SELECT visit_id,
           AVG(blood_pressure_systolic) AS avg_systolic,
           AVG(blood_pressure_diastolic) AS avg_diastolic
    FROM vitals
    GROUP BY visit_id
)
SELECT et.encounter_type_name, AVG(vp.avg_systolic) AS avg_systolic_pressure,
       AVG(vp.avg_diastolic) AS avg_diastolic_pressure
FROM (
    SELECT v.visit_id, p.specialty
    FROM visits v
    JOIN providers p ON v.provider_id = p.provider_id
    WHERE v.was_emergency = TRUE
) ep
JOIN AverageVitals vp ON ep.visit_id = vp.visit_id
JOIN encounter_types et ON ep.visit_id = et.encounter_type_id
GROUP BY et.encounter_type_name;

-- Query 3
WITH LatestScreenings AS (
    SELECT patient_id, screening_type, MAX(screening_date) AS recent_screening
    FROM screenings
    GROUP BY patient_id, screening_type
)
SELECT p.first_name, p.last_name, ls.screening_type,
       COUNT(DISTINCT d.diagnosis_id) AS diagnosis_count,
       CASE WHEN AVG(cl.paid_amount) > AVG(cl.billed_amount) * 0.8 THEN 'Highly Satisfied' ELSE 'Unsatisfied' END AS patient_satisfaction
FROM patients p
JOIN LatestScreenings ls ON p.patient_id = ls.patient_id
JOIN visits v ON p.patient_id = v.patient_id
JOIN diagnoses d ON v.visit_id = d.visit_id
JOIN claims cl ON v.visit_id = cl.visit_id
JOIN insurance ins ON p.insurance_id = ins.insurance_id
GROUP BY p.first_name, p.last_name, ls.screening_type;

-- Query 4
WITH ActiveConditions AS (
    SELECT patient_id, condition_name
    FROM conditions
    WHERE condition_status = 'Active'
)
SELECT hv.housing_type, COUNT(DISTINCT ac.patient_id) AS active_patients,
       CONCAT_WS(', ', p.first_name, p.last_name) AS patient_name,
       MAX(cl.claim_date) AS last_claim_date
FROM housing_status hv
JOIN ActiveConditions ac ON hv.patient_id = ac.patient_id
JOIN claims cl ON ac.patient_id = cl.patient_id
JOIN patients p ON ac.patient_id = p.patient_id
GROUP BY hv.housing_type, p.first_name, p.last_name;

-- Query 5
WITH MedicationUse AS (
    SELECT m.visit_id, COUNT(m.medication_id) AS medication_count
    FROM medications m
    WHERE m.start_date >= CURRENT_DATE - INTERVAL '1 year'
    GROUP BY m.visit_id
)
SELECT pt.language_name, COUNT(DISTINCT vu.visit_id) AS frequent_visits,
       (bp.avg_medication_count / bp.total_visits) AS medication_ratio
FROM (
    SELECT p.language_id, COUNT(DISTINCT m.visit_id) AS total_visits,
           AVG(mu.medication_count) AS avg_medication_count
    FROM patients p
    JOIN visits m ON p.patient_id = m.patient_id
    JOIN MedicationUse mu ON m.visit_id = mu.visit_id
    WHERE m.visit_date >= CURRENT_DATE - INTERVAL '6 months'
    GROUP BY p.language_id
) bp
JOIN languages pt ON bp.language_id = pt.language_id
JOIN MedicationUse vu ON vu.visit_id = bp.language_id
GROUP BY pt.language_name, bp.avg_medication_count, bp.total_visits
HAVING COUNT(DISTINCT vu.visit_id) > 2;

-- Query 6
WITH HighRiskPatients AS (
    SELECT patient_id, AVG(score_value) AS avg_risk_score
    FROM risk_scores
    GROUP BY patient_id
    HAVING AVG(score_value) > 70
)
SELECT DISTINCT e.employment_type, p.insurance_id,
       SUM(co.paid_amount - co.claim_amount) AS net_expense
FROM employment_status e
JOIN HighRiskPatients hr ON e.patient_id = hr.patient_id
JOIN insurance i ON hr.patient_id = i.insurance_id
JOIN claims co ON hr.patient_id = co.patient_id
WHERE e.status_date > CURRENT_DATE - INTERVAL '1 year'
GROUP BY e.employment_type, p.insurance_id;

-- Query 7
WITH FrequentClaims AS (
    SELECT cl.claim_id, cl.patient_id,
           ROW_NUMBER() OVER (PARTITION BY cl.patient_id ORDER BY cl.claim_date DESC) AS claim_position
    FROM claims cl
)
SELECT f.race_ethnicity_name, fg.income_level,
       COUNT(fc.claim_id) AS frequent_claim_count
FROM FrequentClaims fc
JOIN patients p ON fc.patient_id = p.patient_id
JOIN race_ethnicity f ON p.race_ethnicity_id = f.race_ethnicity_id
LEFT JOIN income_brackets fg ON p.patient_id = fg.patient_id
WHERE fc.claim_position <= 5
GROUP BY f.race_ethnicity_name, fg.income_level
HAVING COUNT(fc.claim_id) > 3;

-- Query 8
WITH InsuranceCoverage AS (
    SELECT insurance_id, MAX(expiration_date) AS latest_expiry
    FROM insurance
    GROUP BY insurance_id
)
SELECT sdoh.sdoh_type, p.address_id, ins.payer_name,
       COUNT(DISTINCT v.visit_id) as visit_count,
       MIN(v.admission_time) as earliest_admission
FROM sdoh_entries sdoh
JOIN InsuranceCoverage ins ON sdoh.patient_id = ins.insurance_id
JOIN patients p ON sdoh.patient_id = p.patient_id
JOIN visits v ON p.patient_id = v.patient_id
WHERE v.was_emergency = FALSE
GROUP BY sdoh.sdoh_type, p.address_id, ins.payer_name;

-- Query 9
WITH GrowthRates AS (
    SELECT i.insurance_id, g.group_number,
           (COUNT(i.insurance_id) / g.total_count::FLOAT) AS growth_rate
    FROM insurance i
    JOIN (
        SELECT group_number, COUNT(insurance_id) AS total_count
        FROM insurance
        WHERE effective_date > CURRENT_DATE - INTERVAL '1 year'
        GROUP BY group_number
    ) g ON i.group_number = g.group_number
)
SELECT ag.city, ag.state, gr.growth_rate
FROM addresses ag
JOIN GrowthRates gr ON ag.address_id = gr.insurance_id
JOIN patients p ON ag.address_id = p.address_id
WHERE ag.country = 'USA'
ORDER BY gr.growth_rate DESC;

-- Query 10
WITH SymptomDuration AS (
    SELECT visit_id, EXTRACT(DAY FROM (resolved_date - symptom_date)) as symptom_duration
    FROM symptoms
    WHERE resolved_date IS NOT NULL
)
SELECT im.imaging_type, CONCAT(pr.first_name, ' ', pr.last_name) as provider_name,
       MAX(sy.symptom_duration) AS max_symptom_duration,
       COUNT(DISTINCT im.imaging_id) AS imaging_performed
FROM imaging im
JOIN visits vi ON im.visit_id = vi.visit_id
JOIN providers pr ON vi.provider_id = pr.provider_id
JOIN SymptomDuration sy ON im.visit_id = sy.visit_id
WHERE vi.admission_time > CURRENT_DATE - INTERVAL '3 months'
GROUP BY im.imaging_type, pr.first_name, pr.last_name;