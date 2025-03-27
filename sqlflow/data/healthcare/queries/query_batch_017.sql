-- Query 1
WITH recent_diagnoses AS (
    SELECT d.visit_id, MAX(d.diagnosis_date) AS recent_diagnosis_date 
    FROM diagnoses d
    JOIN visits v ON d.visit_id = v.visit_id
    GROUP BY d.visit_id
) 
SELECT 
    p.patient_id, 
    p.first_name, 
    p.last_name, 
    COUNT(v.visit_id) AS total_visits, 
    AVG(ps.score_value) AS avg_risk_score
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN recent_diagnoses rd ON v.visit_id = rd.visit_id
LEFT JOIN risk_scores ps ON ps.patient_id = p.patient_id AND ps.calculated_date = rd.recent_diagnosis_date
GROUP BY p.patient_id
HAVING COUNT(v.visit_id) > 5;

-- Query 2
WITH avg_claims AS (
    SELECT 
        c.patient_id, 
        AVG(c.claim_amount) AS avg_claim_amount
    FROM claims c
    WHERE c.claim_status = 'Paid'
    GROUP BY c.patient_id
)
SELECT 
    p.patient_id,
    p.first_name,
    p.last_name,
    a.avg_claim_amount,
    MIN(v.visit_date) AS first_visit_date,
    MAX(v.visit_date) AS last_visit_date
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
LEFT JOIN avg_claims a ON p.patient_id = a.patient_id
INNER JOIN insurance i ON p.insurance_id = i.insurance_id
WHERE i.plan_type = 'Premium'
GROUP BY p.patient_id, a.avg_claim_amount;

-- Query 3
WITH blood_pressure_stats AS (
    SELECT 
        v.visit_id, 
        AVG(vt.blood_pressure_systolic) AS avg_systolic_bp,
        AVG(vt.blood_pressure_diastolic) AS avg_diastolic_bp
    FROM visits v
    JOIN vitals vt ON v.visit_id = vt.visit_id
    GROUP BY v.visit_id
)
SELECT 
    p.patient_id,
    p.first_name,
    p.last_name,
    CASE 
        WHEN bp.avg_systolic_bp > 120 THEN 'Hypertension'
        ELSE 'Normal'
    END AS bp_status,
    COUNT(v.visit_id) AS total_visits
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
LEFT JOIN blood_pressure_stats bp ON v.visit_id = bp.visit_id
GROUP BY p.patient_id
HAVING COUNT(v.visit_id) > 2;

-- Query 4
WITH patient_employment AS (
    SELECT 
        e.patient_id, 
        MAX(e.status_date) AS latest_employment_date 
    FROM employment_status e
    GROUP BY e.patient_id
)
SELECT 
    p.patient_id,
    p.first_name,
    p.last_name,
    e.employment_type,
    COUNT(distinct v.visit_id) AS unique_visit_count,
    SUM(c.claim_amount) AS total_claim_amount
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
LEFT JOIN patient_employment pe ON p.patient_id = pe.patient_id
INNER JOIN employment_status e ON e.patient_id = pe.patient_id AND e.status_date = pe.latest_employment_date
JOIN claims c ON v.visit_id = c.visit_id
GROUP BY p.patient_id, e.employment_type
HAVING total_claim_amount > 2000;

-- Query 5
WITH recent_lab_results AS (
    SELECT 
        lb.visit_id, 
        MAX(lb.reported_date) AS latest_lab_date
    FROM labs lb
    JOIN visits v ON lb.visit_id = v.visit_id
    GROUP BY lb.visit_id
)
SELECT 
    p.patient_id,
    p.first_name,
    p.last_name,
    (v.weight_kg / POWER(v.height_cm / 100, 2)) AS calculated_bmi,
    lb.test_name,
    lb.result_value
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN recent_lab_results lr ON v.visit_id = lr.visit_id
INNER JOIN labs lb ON lb.visit_id = lr.visit_id AND lb.reported_date = lr.latest_lab_date
JOIN sdoh_entries se ON p.patient_id = se.patient_id
WHERE se.sdoh_type = 'Nutrition'
AND v.was_emergency = FALSE;

-- Query 6
WITH imaging_frequency AS (
    SELECT 
        im.visit_id, 
        COUNT(im.imaging_type) AS imaging_count
    FROM imaging im
    JOIN visits v ON im.visit_id = v.visit_id
    GROUP BY im.visit_id
)
SELECT 
    p.patient_id,
    p.first_name,
    p.last_name,
    CASE 
        WHEN imf.imaging_count > 3 THEN 'Frequent Imaging'
        ELSE 'Rare Imaging'
    END AS imaging_status,
    COUNT(DISTINCT d.diagnosis_code) AS unique_diagnoses
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
LEFT JOIN imaging_frequency imf ON v.visit_id = imf.visit_id
JOIN diagnoses d ON v.visit_id = d.visit_id
GROUP BY p.patient_id, imf.imaging_count;

-- Query 7
WITH prevalent_conditions AS (
    SELECT 
        patient_id, 
        condition_name,
        MAX(diagnosed_date) AS recent_date
    FROM conditions
    GROUP BY patient_id, condition_name
)
SELECT 
    p.patient_id,
    p.first_name,
    p.last_name,
    ic.income_level,
    pc.condition_name,
    pc.recent_date
FROM patients p
JOIN prevalent_conditions pc ON p.patient_id = pc.patient_id
JOIN income_brackets ic ON p.patient_id = ic.patient_id
WHERE ic.recorded_date <= pc.recent_date
AND ic.income_level = 'Low';

-- Query 8
WITH survey_summary AS (
    SELECT 
        survey_id, 
        AVG(survey_score) OVER (PARTITION BY survey_type) AS avg_type_score
    FROM surveys
)
SELECT 
    s.survey_id,
    s.survey_type,
    p.patient_id,
    p.first_name,
    p.last_name,
    s.avg_type_score,
    SUM(b.amount) AS total_billed_amount
FROM survey_summary s
JOIN patients p ON s.patient_id = p.patient_id
LEFT JOIN claims c ON p.patient_id = c.patient_id
JOIN billing b ON c.claim_id = b.claim_id
GROUP BY s.survey_id, p.patient_id, s.avg_type_score
HAVING total_billed_amount > 1000;

-- Query 9
WITH symptom_severity AS (
    SELECT 
        sm.visit_id,
        sm.symptom,
        MAX(CASE 
            WHEN sm.severity = 'Severe' THEN 3
            WHEN sm.severity = 'Moderate' THEN 2
            ELSE 1
        END) AS severity_score
    FROM symptoms sm
    GROUP BY sm.visit_id, sm.symptom
)
SELECT 
    p.patient_id,
    p.first_name,
    p.last_name,
    ss.severity_score,
    SUM(pr.amount) AS total_payments
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
LEFT JOIN symptom_severity ss ON v.visit_id = ss.visit_id
JOIN claims c ON v.visit_id = c.visit_id
JOIN payments pr ON c.claim_id = pr.claim_id
GROUP BY p.patient_id, ss.severity_score;

-- Query 10
WITH allergen_counts AS (
    SELECT 
        a.patient_id, 
        COUNT(a.allergen) AS allergen_count
    FROM allergies a
    GROUP BY a.patient_id
)
SELECT 
    p.patient_id,
    p.first_name,
    p.last_name,
    ac.allergen_count,
    MAX(s.survey_score) AS highest_survey_score
FROM patients p
JOIN allergen_counts ac ON p.patient_id = ac.patient_id
INNER JOIN surveys s ON p.patient_id = s.patient_id
JOIN race_ethnicity re ON p.race_ethnicity_id = re.race_ethnicity_id
WHERE re.race_ethnicity_name = 'Hispanic'
GROUP BY p.patient_id, ac.allergen_count
HAVING allergen_count > 1;