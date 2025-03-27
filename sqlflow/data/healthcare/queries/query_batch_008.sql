-- Query 1
WITH monthly_visits AS (
    SELECT
        patient_id,
        DATE_TRUNC('month', visit_date) AS visit_month,
        COUNT(visit_id) AS visit_count
    FROM visits
    GROUP BY patient_id, visit_month
)
SELECT
    p.first_name,
    p.last_name,
    m.visit_month,
    m.visit_count,
    AVG(vv.blood_pressure_systolic) OVER (PARTITION BY m.patient_id) AS avg_systolic_bp
FROM patients p
JOIN monthly_visits m ON p.patient_id = m.patient_id
JOIN visits v ON p.patient_id = v.patient_id
JOIN vitals vv ON v.visit_id = vv.visit_id
WHERE vv.blood_pressure_systolic > 120;

-- Query 2
WITH recent_conditions AS (
    SELECT
        patient_id,
        MAX(diagnosed_date) AS last_condition_date
    FROM conditions
    GROUP BY patient_id
)
SELECT
    p.first_name,
    p.last_name,
    c.condition_name,
    lc.last_condition_date
FROM patients p
JOIN recent_conditions lc ON p.patient_id = lc.patient_id
JOIN conditions c ON lc.patient_id = c.patient_id
JOIN (SELECT * FROM diagnoses WHERE diagnosis_date > '2022-01-01') d ON c.patient_id = d.visit_id
WHERE c.diagnosed_date = lc.last_condition_date;

-- Query 3
WITH visit_counts AS (
    SELECT
        provider_id,
        COUNT(visit_id) AS total_visits
    FROM visits
    GROUP BY provider_id
)
SELECT
    pr.first_name,
    pr.last_name,
    pr.specialty,
    vc.total_visits,
    CASE 
        WHEN vc.total_visits > 50 THEN 'High'
        ELSE 'Low'
    END AS workload_level
FROM providers pr
JOIN visit_counts vc ON pr.provider_id = vc.provider_id
WHERE pr.specialty IN ('Cardiology', 'Orthopedics');

-- Query 4
WITH frequent_diagnoses AS (
    SELECT
        diagnosis_code,
        COUNT(diagnosis_id) AS frequency
    FROM diagnoses
    GROUP BY diagnosis_code
    HAVING COUNT(diagnosis_id) > 10
)
SELECT
    p.first_name,
    p.last_name,
    fd.diagnosis_code,
    fd.frequency,
    AVG(cl.claim_amount) OVER (PARTITION BY cl.visit_id) AS avg_claim_amount
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN frequent_diagnoses fd ON v.visit_id = fd.diagnosis_code
JOIN claims cl ON p.patient_id = cl.patient_id
WHERE cl.claim_status = 'Paid';

-- Query 5
WITH emergency_visits AS (
    SELECT
        patient_id,
        COUNT(visit_id) AS emergency_count
    FROM visits
    WHERE was_emergency = TRUE
    GROUP BY patient_id
)
SELECT
    p.first_name,
    p.last_name,
    e.emergency_count,
    COALESCE(i.insurance_id, 'None') AS insurance_status,
    SUM(cl.paid_amount) OVER (PARTITION BY p.patient_id) AS total_paid
FROM patients p
LEFT JOIN emergency_visits e ON p.patient_id = e.patient_id
LEFT JOIN insurance i ON p.insurance_id = i.insurance_id
LEFT JOIN (SELECT * FROM claims WHERE claim_status = 'Paid') cl ON p.patient_id = cl.patient_id;

-- Query 6
WITH high_risk_patients AS (
    SELECT
        patient_id,
        MAX(score_value) AS max_risk_score
    FROM risk_scores
    GROUP BY patient_id
    HAVING MAX(score_value) > 80
)
SELECT
    hr.max_risk_score,
    p.first_name,
    p.last_name,
    r.language_name
FROM high_risk_patients hr
JOIN patients p ON hr.patient_id = p.patient_id
JOIN languages r ON p.language_id = r.language_id
JOIN visits v ON p.patient_id = v.patient_id
JOIN (SELECT DISTINCT patient_id FROM sdoh_entries WHERE sdoh_type = 'Housing') sd ON p.patient_id = sd.patient_id;

-- Query 7
WITH bmi_records AS (
    SELECT
        patient_id,
        AVG(bmi) AS avg_bmi
    FROM vitals
    GROUP BY patient_id
)
SELECT
    b.avg_bmi,
    p.first_name,
    p.last_name,
    h.housing_type,
    COALESCE(ic.income_level, 'Unknown') AS income_status
FROM bmi_records b
JOIN patients p ON b.patient_id = p.patient_id
LEFT JOIN housing_status h ON p.patient_id = h.patient_id
LEFT JOIN income_brackets ic ON p.patient_id = ic.patient_id
WHERE b.avg_bmi > 25;

-- Query 8
WITH provider_specialties AS (
    SELECT
        specialty,
        COUNT(provider_id) AS provider_count
    FROM providers
    GROUP BY specialty
)
SELECT 
    ps.specialty,
    ps.provider_count,
    p.first_name,
    p.last_name,
    COUNT(v.visit_id) OVER (PARTITION BY v.location) AS visits_per_location
FROM provider_specialties ps
JOIN providers p ON ps.specialty = p.specialty
JOIN visits v ON p.provider_id = v.provider_id
WHERE ps.provider_count > 5;

-- Query 9
WITH chronic_conditions AS (
    SELECT
        patient_id,
        COUNT(condition_id) AS chronic_count
    FROM conditions
    WHERE condition_status = 'Chronic'
    GROUP BY patient_id
)
SELECT
    c.chronic_count,
    p.first_name,
    p.last_name,
    l.street_address,
    SUM(b.amount) OVER (PARTITION BY p.patient_id) AS total_billed
FROM chronic_conditions c
JOIN patients p ON c.patient_id = p.patient_id
JOIN addresses l ON p.address_id = l.address_id
JOIN claims cl ON p.patient_id = cl.patient_id
JOIN billing b ON cl.claim_id = b.claim_id;

-- Query 10
WITH active_medications AS (
    SELECT
        visit_id,
        COUNT(medication_id) AS medication_count
    FROM medications
    WHERE end_date IS NULL
    GROUP BY visit_id
)
SELECT
    am.medication_count,
    p.first_name,
    p.last_name,
    pr.specialty,
    MAX(l.result_value) OVER (PARTITION BY l.test_name) AS max_lab_value
FROM active_medications am
JOIN visits v ON am.visit_id = v.visit_id
JOIN patients p ON v.patient_id = p.patient_id
JOIN providers pr ON v.provider_id = pr.provider_id
JOIN labs l ON v.visit_id = l.visit_id
WHERE am.medication_count > 3;