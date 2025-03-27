SELECT 
    p.patient_id,
    MAX(CASE WHEN enc.encounter_type_name = 'Emergency' THEN v.visit_date ELSE NULL END) AS last_emergency_visit,
    AVG(cl.paid_amount) AS avg_paid_amount,
    COUNT(DISTINCT d.diagnosis_code) AS unique_diagnoses
FROM 
    patients p
INNER JOIN 
    visits v ON p.patient_id = v.patient_id
INNER JOIN 
    diagnoses d ON v.visit_id = d.visit_id
LEFT JOIN 
    (SELECT encounter_type_id, encounter_type_name FROM encounter_types) enc ON v.encounter_type_id = enc.encounter_type_id
INNER JOIN 
    claims cl ON v.visit_id = cl.visit_id
GROUP BY 
    p.patient_id
HAVING 
    COUNT(DISTINCT cl.claim_id) > 5;

WITH recent_diagnoses AS (
    SELECT 
        d1.visit_id, 
        d1.diagnosis_code, 
        d1.diagnosis_date
    FROM 
        diagnoses d1
    WHERE 
        d1.diagnosis_date > current_date - interval '90 days'
)
SELECT 
    p.first_name,
    p.last_name,
    r.race_ethnicity_name,
    COUNT(rd.diagnosis_code) AS recent_diagnosis_count,
    AVG(vt.bmi) AS avg_bmi
FROM 
    patients p
INNER JOIN 
    race_ethnicity r ON p.race_ethnicity_id = r.race_ethnicity_id
INNER JOIN 
    visits v ON p.patient_id = v.patient_id
LEFT JOIN 
    recent_diagnoses rd ON v.visit_id = rd.visit_id
LEFT JOIN 
    vitals vt ON v.visit_id = vt.visit_id
GROUP BY 
    p.patient_id, r.race_ethnicity_name;

SELECT 
    pr.provider_id,
    pr.specialty,
    COUNT(DISTINCT v.visit_id) AS total_visits,
    MIN(v.visit_date) AS first_visit_date,
    MAX(lab.result_value) AS max_lab_result
FROM 
    providers pr
INNER JOIN 
    visits v ON pr.provider_id = v.provider_id
LEFT JOIN 
    (SELECT visit_id, MAX(reported_date) AS last_reported FROM labs GROUP BY visit_id) lr ON v.visit_id = lr.visit_id
LEFT JOIN 
    labs lab ON v.visit_id = lab.visit_id AND lab.reported_date = lr.last_reported
GROUP BY 
    pr.provider_id
HAVING 
    COUNT(v.visit_id) > 10;

WITH monthly_visits AS (
    SELECT 
        visit_date, 
        patient_id, 
        COUNT(visit_id) AS visit_count
    FROM 
        visits
    WHERE 
        visit_date > NOW() - interval '1 year'
    GROUP BY 
        visit_date, patient_id
)
SELECT 
    p.patient_id,
    p.first_name,
    p.last_name,
    MAX(mv.visit_count) AS max_monthly_visits,
    SUM(CASE WHEN t.risk_score_id IS NOT NULL THEN 1 ELSE 0 END) AS risk_score_count
FROM 
    patients p
INNER JOIN 
    monthly_visits mv ON p.patient_id = mv.patient_id
LEFT JOIN 
    risk_scores t ON p.patient_id = t.patient_id
GROUP BY 
    p.patient_id;

SELECT 
    hs.housing_type,
    COUNT(DISTINCT e.employment_id) AS distinct_employment,
    AVG(i.amount) * 0.10 AS ten_percent_avg_billed
FROM 
    housing_status hs
JOIN 
    income_brackets ib ON hs.patient_id = ib.patient_id
JOIN 
    employment_status e ON hs.patient_id = e.patient_id
JOIN 
    billing i ON ib.patient_id = i.patient_id
WHERE 
    hs.status_date > NOW() - interval '6 months'
GROUP BY 
    hs.housing_type;

WITH top_allergies AS (
    SELECT 
        patient_id, 
        COUNT(allergy_id) AS allergy_count
    FROM 
        allergies
    GROUP BY 
        patient_id
    ORDER BY 
        allergy_count DESC
    LIMIT 5
)
SELECT 
    p.patient_id,
    SUM(pg.amount) AS total_pay_amount
FROM 
    top_allergies ta
INNER JOIN 
    patients p ON ta.patient_id = p.patient_id
INNER JOIN 
    payments pg ON p.patient_id = pg.patient_id
GROUP BY 
    p.patient_id;

SELECT 
    v.visit_id,
    SUM(mp.billed_amount - mp.paid_amount) AS outstanding_amount,
    vt.temperature_c,
    COUNT(DISTINCT pr.procedure_code) AS procedure_count
FROM 
    visits v
JOIN 
    claims mp ON v.visit_id = mp.visit_id
LEFT JOIN 
    procedures pr ON v.visit_id = pr.visit_id
LEFT JOIN 
    vitals vt ON v.visit_id = vt.visit_id
GROUP BY 
    v.visit_id, vt.temperature_c
HAVING 
    AVG(vt.heart_rate) > 60;

WITH patient_languages AS (
    SELECT 
        pa.patient_id,
        ln.language_name
    FROM 
        patients pa
    JOIN 
        languages ln ON pa.language_id = ln.language_id
)
SELECT 
    ln.language_name,
    AVG(cs.survey_score) AS avg_survey_score,
    COUNT(pa.patient_id) AS patient_count
FROM 
    patient_languages ln
JOIN 
    surveys cs ON ln.patient_id = cs.patient_id
GROUP BY 
    ln.language_name
ORDER BY 
    patient_count DESC;

SELECT 
    pdi.condition_name,
    COUNT(DISTINCT pb.billing_id) AS billing_entries,
    AVG(pr.result_value) AS avg_lab_value
FROM 
    conditions pdi
INNER JOIN 
    patients lbs ON pdi.patient_id = lbs.patient_id
INNER JOIN 
    billing pb ON lbs.patient_id = pb.patient_id
JOIN 
    labs pr ON lbs.patient_id = pr.patient_id
WHERE 
    pdi.diagnosed_date > current_date - interval '2 years'
GROUP BY 
    pdi.condition_name;

WITH sdoh_counts AS (
    SELECT 
        sdoh_type, 
        COUNT(sdoh_id) AS num_entries
    FROM 
        sdoh_entries
    GROUP BY 
        sdoh_type
)
SELECT 
    sdoh_type,
    num_entries,
    TOTAL_AMOUNT / num_entries AS adjusted_billed_per_entry
FROM 
    sdoh_counts
JOIN 
    (SELECT 
        SUM(billed_amount) AS TOTAL_AMOUNT
    FROM 
        claims) ca ON TRUE;