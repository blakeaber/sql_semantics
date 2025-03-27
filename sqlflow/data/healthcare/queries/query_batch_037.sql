-- Query 1
WITH visit_summary AS (
    SELECT 
        v.patient_id,
        COUNT(*) AS total_visits,
        SUM(CASE WHEN v.was_emergency THEN 1 ELSE 0 END) AS emergency_visits
    FROM visits v
    GROUP BY v.patient_id
),
avg_vitals AS (
    SELECT 
        d.patient_id,
        AVG(vt.bmi) AS avg_bmi,
        AVG(vt.heart_rate) AS avg_heart_rate
    FROM visits v
    JOIN vitals vt ON v.visit_id = vt.visit_id
    JOIN diagnoses d ON v.visit_id = d.visit_id
    GROUP BY d.patient_id
)
SELECT 
    p.patient_id,
    p.first_name,
    p.last_name,
    vs.total_visits,
    vs.emergency_visits,
    av.avg_bmi,
    av.avg_heart_rate,
    r.race_ethnicity_name,
    co.comorbidity_count
FROM patients p
JOIN (
    SELECT 
        patient_id,
        COUNT(DISTINCT condition_name) AS comorbidity_count
    FROM conditions
    WHERE condition_status = 'active'
    GROUP BY patient_id
) co ON p.patient_id = co.patient_id
JOIN visit_summary vs ON p.patient_id = vs.patient_id
JOIN avg_vitals av ON p.patient_id = av.patient_id
JOIN race_ethnicity r ON p.race_ethnicity_id = r.race_ethnicity_id
WHERE p.patient_id IN (
    SELECT patient_id 
    FROM sdoh_entries 
    WHERE sdoh_type = 'Housing Instability'
);

-- Query 2
WITH recent_payments AS (
    SELECT 
        claim_id,
        SUM(amount) AS total_paid
    FROM payments
    WHERE payment_date >= NOW() - INTERVAL '1 year'
    GROUP BY claim_id
),
billing_summary AS (
    SELECT 
        c.patient_id,
        SUM(b.amount) AS total_billed,
        rp.total_paid
    FROM claims c
    JOIN billing b ON c.claim_id = b.claim_id
    LEFT JOIN recent_payments rp ON c.claim_id = rp.claim_id
    GROUP BY c.patient_id, rp.total_paid
)
SELECT 
    p.patient_id,
    p.first_name,
    p.last_name,
    bs.total_billed,
    COALESCE(bs.total_paid, 0) AS total_paid,
    p.gender,
    COUNT(distinct ct.care_team_id) AS care_team_count
FROM patients p
JOIN billing_summary bs ON p.patient_id = bs.patient_id
LEFT JOIN patient_care_team ct ON p.patient_id = ct.patient_id
WHERE bs.total_billed > 1000
GROUP BY p.patient_id, bs.total_billed, bs.total_paid, p.first_name, p.last_name, p.gender;

-- Query 3
WITH procedure_count AS (
    SELECT 
        v.visit_id,
        COUNT(distinct pr.procedure_code) AS procedure_count
    FROM visits v
    JOIN procedures pr ON v.visit_id = pr.visit_id
    GROUP BY v.visit_id
),
emergency_procedures AS (
    SELECT 
        patient_id,
        SUM(pc.procedure_count) AS emergency_procedure_count
    FROM visits v
    JOIN procedures pr ON v.visit_id = pr.visit_id
    JOIN procedure_count pc ON v.visit_id = pc.visit_id
    WHERE was_emergency = TRUE
    GROUP BY patient_id
)
SELECT 
    p.patient_id,
    p.first_name,
    p.last_name,
    COALESCE(epc.emergency_procedure_count, 0) AS emergency_procedure_count,
    i.payer_name,
    i.plan_type
FROM patients p
LEFT JOIN emergency_procedures epc ON p.patient_id = epc.patient_id
JOIN insurance i ON p.insurance_id = i.insurance_id
WHERE p.patient_id IN (
    SELECT patient_id 
    FROM surveys 
    WHERE survey_score < 50
);

-- Query 4
WITH symptom_summary AS (
    SELECT 
        v.visit_id,
        COUNT(*) AS symptom_count,
        MAX(severity) AS max_severity
    FROM symptoms s
    JOIN visits v ON s.visit_id = v.visit_id
    GROUP BY v.visit_id
),
diagnosis_detail AS (
    SELECT 
        d.visit_id,
        d.diagnosis_type,
        ds.symptom_count
    FROM diagnoses d
    JOIN symptom_summary ds ON d.visit_id = ds.visit_id
)
SELECT 
    p.patient_id,
    p.first_name,
    COUNT(d.visit_id) AS total_diagnoses,
    AVG(sd.symptom_count) AS avg_symptoms_per_diagnosis,
    MAX(sd.max_severity) AS max_severity
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN diagnosis_detail d ON v.visit_id = d.visit_id
JOIN symptom_summary sd ON v.visit_id = sd.visit_id
GROUP BY p.patient_id, p.first_name
HAVING AVG(sd.symptom_count) > 3;

-- Query 5
WITH high_risk_patients AS (
    SELECT 
        patient_id,
        MAX(score_value) AS max_risk_score
    FROM risk_scores
    GROUP BY patient_id
    HAVING MAX(score_value) > 8
),
insurance_detail AS (
    SELECT 
        p.patient_id,
        i.plan_type
    FROM patients p
    JOIN insurance i ON p.insurance_id = i.insurance_id
)
SELECT 
    hr.patient_id,
    hr.max_risk_score,
    id.plan_type,
    COUNT(ct.care_team_id) AS care_team_count
FROM high_risk_patients hr
JOIN insurance_detail id ON hr.patient_id = id.patient_id
LEFT JOIN patient_care_team ct ON hr.patient_id = ct.patient_id
GROUP BY hr.patient_id, hr.max_risk_score, id.plan_type
ORDER BY hr.max_risk_score DESC;

-- Query 6
WITH average_claims AS (
    SELECT 
        p.patient_id,
        AVG(c.claim_amount) AS avg_claim_amount
    FROM patients p
    JOIN claims c ON p.patient_id = c.patient_id
    WHERE c.claim_status = 'approved'
    GROUP BY p.patient_id
),
language_statistics AS (
    SELECT 
        p.language_id,
        COUNT(*) AS num_patients
    FROM patients p
    JOIN languages l ON p.language_id = l.language_id
    GROUP BY p.language_id
)
SELECT 
    avg.patient_id,
    avg.avg_claim_amount,
    l.language_name,
    ls.num_patients
FROM average_claims avg
JOIN patients p ON avg.patient_id = p.patient_id
JOIN languages l ON p.language_id = l.language_id
JOIN language_statistics ls ON l.language_id = ls.language_id
WHERE avg.avg_claim_amount > 1000;

-- Query 7
WITH provider_performance AS (
    SELECT 
        pr.provider_id,
        COUNT(v.visit_id) AS total_visits,
        EXTRACT(YEAR FROM v.visit_date) AS visit_year
    FROM providers pr
    JOIN visits v ON pr.provider_id = v.provider_id
    GROUP BY pr.provider_id, visit_year
    HAVING COUNT(v.visit_id) > 100
)
SELECT 
    pp.provider_id,
    pr.first_name,
    pr.last_name,
    pp.total_visits,
    e.encounter_type_name,
    EXTRACT(MONTH FROM v.visit_date) AS visit_month
FROM provider_performance pp
JOIN providers pr ON pp.provider_id = pr.provider_id
JOIN visits v ON pr.provider_id = v.provider_id
JOIN encounter_types e ON v.encounter_type_id = e.encounter_type_id
WHERE e.encounter_type_name IN (
    SELECT encounter_type_name 
    FROM encounter_types 
    WHERE description LIKE '%annual%'
);

-- Query 8
WITH imaging_details AS (
    SELECT 
        i.visit_id,
        i.imaging_type,
        COUNT(i.imaging_id) AS img_count
    FROM imaging i
    JOIN visits v ON i.visit_id = v.visit_id
    WHERE i.impression <> ''
    GROUP BY i.visit_id, i.imaging_type
),
lab_work AS (
    SELECT 
        l.visit_id,
        SUM(l.result_value) AS total_lab_value
    FROM labs l
    GROUP BY l.visit_id
)
SELECT 
    v.patient_id,
    id.imaging_type,
    id.img_count,
    lw.total_lab_value
FROM visits v
JOIN imaging_details id ON v.visit_id = id.visit_id
LEFT JOIN lab_work lw ON v.visit_id = lw.visit_id
WHERE id.img_count > 2
AND lw.total_lab_value IS NOT NULL;

-- Query 9
WITH combined_conditions AS (
    SELECT 
        patient_id,
        COUNT(condition_name) AS condition_count
    FROM conditions
    WHERE condition_status = 'chronic'
    GROUP BY patient_id
),
active_allergies AS (
    SELECT 
        a.patient_id,
        COUNT(*) AS allergy_count
    FROM allergies a
    WHERE a.severity LIKE '%severe%'
    GROUP BY a.patient_id
)
SELECT 
    p.patient_id,
    p.first_name,
    cc.condition_count,
    aa.allergy_count,
    COALESCE(ins.insurance_issue_count, 0) AS insurance_issue_count
FROM patients p
JOIN combined_conditions cc ON p.patient_id = cc.patient_id
LEFT JOIN active_allergies aa ON p.patient_id = aa.patient_id
LEFT JOIN (
    SELECT 
        patient_id,
        COUNT(*) AS insurance_issue_count
    FROM insurance 
    WHERE expiration_date < NOW()
    GROUP BY patient_id
) ins ON p.patient_id = ins.patient_id;

-- Query 10
WITH medication_use AS (
    SELECT 
        m.visit_id,
        COUNT(m.medication_id) AS medication_count
    FROM medications m
    WHERE m.end_date > NOW() - INTERVAL '6 months'
    GROUP BY m.visit_id
),
examined_vitals AS (
    SELECT 
        vi.visit_id,
        MAX(vi.blood_pressure_systolic) AS max_systolic_bp
    FROM vitals vi
    GROUP BY vi.visit_id
)
SELECT 
    v.patient_id,
    mu.medication_count,
    ev.max_systolic_bp,
    CASE 
        WHEN ev.max_systolic_bp > 140 THEN 'High'
        WHEN ev.max_systolic_bp BETWEEN 120 AND 140 THEN 'Normal'
        ELSE 'Low'
    END AS bp_category
FROM visits v
JOIN medication_use mu ON v.visit_id = mu.visit_id
JOIN examined_vitals ev ON v.visit_id = ev.visit_id
WHERE mu.medication_count > 3;