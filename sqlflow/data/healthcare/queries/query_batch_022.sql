WITH patient_visits AS (
    SELECT 
        p.patient_id, 
        p.first_name, 
        p.last_name,
        v.visit_id,
        v.visit_date,
        ROW_NUMBER() OVER (PARTITION BY p.patient_id ORDER BY v.visit_date DESC) as visit_rank
    FROM patients p
    JOIN visits v ON p.patient_id = v.patient_id
),
latest_diagnosis AS (
    SELECT 
        d.visit_id,
        MAX(d.diagnosis_date) as latest_diagnosis_date
    FROM diagnoses d
    GROUP BY d.visit_id
)
SELECT 
    pv.first_name,
    pv.last_name,
    et.encounter_type_name,
    COUNT(DISTINCT pro.procedure_id) as num_procedures,
    AVG(cl.paid_amount) as avg_paid_amount,
    CASE
        WHEN AVG(cl.paid_amount) > 1000 THEN 'High'
        ELSE 'Low'
    END as payment_category
FROM patient_visits pv
JOIN encounter_types et ON pv.visit_id = v.visit_id
JOIN visits v ON pv.visit_id = v.visit_id
LEFT JOIN procedures pro ON v.visit_id = pro.visit_id
INNER JOIN claims cl ON v.visit_id = cl.visit_id
WHERE pv.visit_rank = 1 
AND v.was_emergency = TRUE
AND pv.patient_id IN (
    SELECT patient_id
    FROM income_brackets
    WHERE income_level = 'Low'
)
GROUP BY pv.first_name, pv.last_name, et.encounter_type_name
HAVING num_procedures > 2;

WITH recent_imaging as (
    SELECT 
        i.visit_id,
        MAX(i.performed_date) as recent_image_date
    FROM imaging i
    GROUP BY i.visit_id
),
patient_medications AS (
    SELECT 
        m.patient_id,
        m.medication_name, 
        COUNT(*) as medication_count
    FROM medications m
    JOIN visits v ON m.visit_id = v.visit_id
    GROUP BY m.patient_id, m.medication_name
    HAVING COUNT(*) > 1
)
SELECT 
    p.first_name,
    p.last_name,
    rg.race_ethnicity_name,
    SUM(d.billed_amount) as total_billed_amount,
    latest_recent_imaging.recent_image_date,
    patient_medications.medication_count
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN claims d ON v.visit_id = d.visit_id
JOIN race_ethnicity rg ON p.race_ethnicity_id = rg.race_ethnicity_id
LEFT JOIN recent_imaging latest_recent_imaging ON v.visit_id = latest_recent_imaging.visit_id
LEFT JOIN patient_medications ON p.patient_id = patient_medications.patient_id
WHERE p.language_id IN (
    SELECT language_id
    FROM languages
    WHERE language_name = 'Spanish'
)
AND p.patient_id IN (
    SELECT patient_id
    FROM sdoh_entries
    WHERE sdoh_type = 'Food Insecurity'
)
GROUP BY p.first_name, p.last_name, rg.race_ethnicity_name, latest_recent_imaging.recent_image_date, patient_medications.medication_count
ORDER BY total_billed_amount DESC;

WITH summarized_vitals AS (
    SELECT 
        v.visit_id,
        AVG(vs.bmi) as avg_bmi,
        MAX(vs.blood_pressure_systolic) as max_systolic,
        MIN(vs.blood_pressure_diastolic) as min_diastolic
    FROM vitals vs
    JOIN visits v ON vs.visit_id = v.visit_id
    WHERE v.visit_date > CURRENT_DATE - INTERVAL '1 year'
    GROUP BY v.visit_id
)
SELECT 
    pr.first_name AS provider_first_name,
    pr.last_name AS provider_last_name,
    COUNT(DISTINCT v.visit_id) as visit_count,
    AVG(summ_vitals.avg_bmi) as mean_bmi,
    CASE WHEN AVG(summ_vitals.avg_bmi) > 30 THEN 'High BMI' ELSE 'Normal BMI' END AS bmi_status
FROM summarized_vitals summ_vitals
JOIN visits v ON summ_vitals.visit_id = v.visit_id
JOIN providers pr ON v.provider_id = pr.provider_id
JOIN conditions c ON v.patient_id = c.patient_id
WHERE c.condition_status = 'Chronic'
AND c.diagnosed_date > CURRENT_DATE - INTERVAL '2 years'
GROUP BY pr.first_name, pr.last_name
HAVING visit_count > 10;

SELECT 
    p.patient_id,
    p.first_name,
    p.last_name,
    MIN(survey_score) AS min_score,
    MAX(survey_score) AS max_score,
    CASE 
        WHEN AVG(survey_score) > 80 THEN 'High Risk'
        ELSE 'Low Risk'
    END as risk_level
FROM patients p
JOIN surveys s ON p.patient_id = s.patient_id
WHERE s.survey_type = 'Mental Health'
AND p.patient_id IN (
    SELECT patient_id FROM screenings
    WHERE screening_type = 'Depression'
    AND result = 'Positive'
)
GROUP BY p.patient_id, p.first_name, p.last_name;

WITH average_lab_results AS (
    SELECT 
        l.visit_id,
        l.test_name,
        AVG(l.result_value) as avg_result_value,
        COUNT(l.lab_result_id) as test_count
    FROM labs l
    GROUP BY l.visit_id, l.test_name
),
provider_impressions AS (
    SELECT 
        i.visit_id,
        i.impression,
        COUNT(i.imaging_id) as imaging_count
    FROM imaging i
    GROUP BY i.visit_id, i.impression
)
SELECT 
    pat.first_name,
    pat.last_name,
    AVG(alr.avg_result_value) as overall_avg_result,
    MAX(alr.test_count) as max_tests,
    CASE 
        WHEN pi.imaging_count > 5 THEN 'Frequent Imaging'
        ELSE 'Normal Imaging'
    END as imaging_frequency
FROM patients pat
JOIN visits v ON pat.patient_id = v.patient_id
JOIN average_lab_results alr ON v.visit_id = alr.visit_id
JOIN provider_impressions pi ON v.visit_id = pi.visit_id
WHERE alr.test_name = 'Blood Glucose'
AND pi.impression LIKE '%Diabetes%'
GROUP BY pat.first_name, pat.last_name, imaging_frequency;

WITH high_value_patients AS (
    SELECT 
        c.patient_id,
        SUM(b.amount) AS total_billed,
        SUM(p.amount) AS total_paid
    FROM claims c
    JOIN billing b ON c.claim_id = b.claim_id
    JOIN payments p ON c.claim_id = p.claim_id
    WHERE c.claim_status = 'Paid'
    GROUP BY c.patient_id
)
SELECT 
    pat.first_name,
    pat.last_name,
    hvp.total_billed,
    hvp.total_paid,
    CASE 
        WHEN (hvp.total_billed - hvp.total_paid) > 200 THEN 'High Outstanding'
        ELSE 'Low Outstanding'
    END as outstanding_status
FROM high_value_patients hvp
JOIN patients pat ON hvp.patient_id = pat.patient_id
WHERE hvp.total_billed > 5000;

WITH lab_results_flags AS (
    SELECT 
        lr.visit_id,
        lr.result_flag,
        COUNT(lr.lab_result_id) as flag_count
    FROM labs lr
    GROUP BY lr.visit_id, lr.result_flag
)
SELECT 
    p.patient_id,
    p.first_name,
    SUM(lrf.flag_count) as total_flags,
    MIN(v.visit_date) as first_visit,
    MAX(v.visit_date) as last_visit,
    CASE 
        WHEN SUM(lrf.flag_count) > 10 THEN 'Requires Attention'
        ELSE 'Stable'
    END as attention_status
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN lab_results_flags lrf ON v.visit_id = lrf.visit_id
WHERE p.gender = 'Female'
GROUP BY p.patient_id, p.first_name;

WITH medication_frequencies AS (
    SELECT 
        m.patient_id,
        m.medication_name,
        COUNT(m.medication_id) as frequency
    FROM medications m
    GROUP BY m.patient_id, m.medication_name
)
SELECT 
    pt.first_name,
    pt.last_name,
    mf.medication_name,
    mf.frequency,
    CASE 
        WHEN mf.frequency > 5 THEN 'Frequent User'
        ELSE 'Infrequent User'
    END as usage_category
FROM medication_frequencies mf
JOIN patients pt ON mf.patient_id = pt.patient_id
WHERE pt.language_id IN (
    SELECT language_id
    FROM languages
    WHERE language_name = 'English'
)
AND mf.medication_name IN (
    SELECT medication_name
    FROM medications
    WHERE start_date > CURRENT_DATE - INTERVAL '6 months'
);

WITH conditions_summary AS (
    SELECT 
        c.patient_id,
        c.condition_name,
        ROW_NUMBER() OVER(PARTITION BY c.patient_id ORDER BY c.diagnosed_date DESC) as condition_rank
    FROM conditions c
)
SELECT 
    p.first_name,
    p.last_name,
    cs.condition_name,
    cl.claim_amount,
    ROW_NUMBER() OVER(PARTITION BY p.patient_id ORDER BY cl.claim_date DESC) as claim_rank
FROM conditions_summary cs
JOIN patients p ON cs.patient_id = p.patient_id
LEFT JOIN claims cl ON p.patient_id = cl.patient_id
WHERE cs.condition_rank = 1
AND cl.claim_status = 'Processed';

WITH active_care_teams AS (
    SELECT 
        pct.patient_id,
        COUNT(pct.care_team_id) as team_count
    FROM patient_care_team pct
    WHERE pct.assigned_date > CURRENT_DATE - INTERVAL '1 year'
    GROUP BY pct.patient_id
)
SELECT 
    p.first_name,
    p.last_name,
    act.team_count,
    COUNT(v.visit_id) as visit_count,
    CASE 
        WHEN COUNT(v.visit_id) > 5 THEN 'Active Participant'
        ELSE 'Passive Participant'
    END as participation_level
FROM active_care_teams act
JOIN patients p ON act.patient_id = p.patient_id
JOIN visits v ON p.patient_id = v.patient_id
WHERE v.encounter_type_id IN (
    SELECT encounter_type_id
    FROM encounter_types
    WHERE encounter_type_name = 'Outpatient'
)
GROUP BY p.first_name, p.last_name, act.team_count;