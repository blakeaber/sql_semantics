WITH recent_visits AS (
    SELECT 
        v.visit_id,
        v.patient_id,
        v.visit_date,
        MAX(v.visit_date) OVER (PARTITION BY v.patient_id) AS last_visit_date
    FROM 
        visits v
),
visit_diagnosis AS (
    SELECT 
        d.visit_id,
        COUNT(d.diagnosis_id) AS diagnosis_count
    FROM 
        diagnoses d
    GROUP BY 
        d.visit_id
),
visit_procedures AS (
    SELECT 
        p.visit_id,
        COUNT(p.procedure_id) AS procedure_count
    FROM 
        procedures p
    GROUP BY 
        p.visit_id
)
SELECT 
    p.patient_id,
    COALESCE(SUM(CASE WHEN v.visit_date = r.last_visit_date THEN vd.diagnosis_count ELSE 0 END), 0) AS recent_diagnoses,
    COALESCE(SUM(CASE WHEN v.visit_date = r.last_visit_date THEN vp.procedure_count ELSE 0 END), 0) AS recent_procedures,
    AVG(bmi.weight_kg / (bmi.height_cm * bmi.height_cm)) AS avg_bmi,
    rt.risk_score_value AS risk_score
FROM 
    recent_visits r
JOIN 
    visits v ON r.visit_id = v.visit_id
LEFT JOIN 
    visit_diagnosis vd ON v.visit_id = vd.visit_id
LEFT JOIN 
    visit_procedures vp ON v.visit_id = vp.visit_id
JOIN 
    patients p ON v.patient_id = p.patient_id
LEFT JOIN 
    (SELECT 
        visit_id,
        AVG(weight_kg) AS weight_kg,
        AVG(height_cm) AS height_cm
    FROM 
        vitals
    GROUP BY 
        visit_id) bmi ON v.visit_id = bmi.visit_id
LEFT JOIN 
    (SELECT 
        patient_id,
        MAX(score_value) AS risk_score_value
    FROM 
        risk_scores
    GROUP BY 
        patient_id) rt ON p.patient_id = rt.patient_id
GROUP BY 
    p.patient_id, rt.risk_score_value
HAVING 
    COUNT(v.visit_id) > 1;


WITH patient_condition AS (
    SELECT 
        c.patient_id,
        COUNT(c.condition_id) AS num_conditions,
        MAX(c.diagnosed_date) AS last_condition_date
    FROM 
        conditions c
    GROUP BY 
        c.patient_id
),
patient_medication AS (
    SELECT 
        m.patient_id,
        COUNT(m.medication_id) AS num_medications
    FROM 
        medications m
    JOIN 
        visits v ON m.visit_id = v.visit_id
    GROUP BY 
        m.patient_id
)
SELECT 
    p.patient_id,
    pc.num_conditions,
    pc.last_condition_date,
    pm.num_medications,
    (pc.num_conditions + pm.num_medications) * rs.score_value AS adjusted_risk_score
FROM 
    patients p
JOIN 
    patient_condition pc ON p.patient_id = pc.patient_id
JOIN 
    patient_medication pm ON p.patient_id = pm.patient_id
LEFT JOIN 
    (SELECT 
        patient_id,
        AVG(score_value) AS score_value
    FROM 
        risk_scores
    WHERE 
        calculated_date > CURRENT_DATE - INTERVAL '1 year'
    GROUP BY 
        patient_id) rs ON p.patient_id = rs.patient_id
ORDER BY 
    adjusted_risk_score DESC;


WITH recent_lab_results AS (
    SELECT 
        l.visit_id,
        l.test_name,
        l.result_value
    FROM 
        labs l
    WHERE 
        l.collected_date > CURRENT_DATE - INTERVAL '6 months'
),
high_risk_patients AS (
    SELECT 
        r.patient_id,
        MAX(r.score_value) AS max_risk_score
    FROM 
        risk_scores r
    GROUP BY 
        r.patient_id
    HAVING 
        MAX(r.score_value) > 7.0
)
SELECT 
    p.patient_id,
    SUM(CASE WHEN r.test_name = 'Glucose' THEN rl.result_value ELSE 0 END) AS total_glucose,
    COUNT(DISTINCT v.visit_id) AS visit_count,
    hi.max_risk_score
FROM 
    patients p
JOIN 
    visits v ON p.patient_id = v.patient_id
JOIN 
    recent_lab_results rl ON v.visit_id = rl.visit_id
JOIN 
    high_risk_patients hi ON p.patient_id = hi.patient_id
GROUP BY 
    p.patient_id, hi.max_risk_score
HAVING 
    COUNT(v.visit_id) > 2;


WITH active_conditions AS (
    SELECT 
        c.patient_id,
        COUNT(*) AS condition_count
    FROM 
        conditions c
    WHERE 
        c.condition_status = 'Active'
    GROUP BY 
        c.patient_id
),
emergency_visits AS (
    SELECT 
        v.patient_id,
        COUNT(*) AS emergency_count
    FROM 
        visits v
    WHERE 
        v.was_emergency
    GROUP BY 
        v.patient_id
),
recent_payments AS (
    SELECT 
        p.patient_id,
        AVG(py.amount) AS avg_payment
    FROM 
        payments py
    JOIN 
        claims c ON py.claim_id = c.claim_id
    JOIN 
        patients p ON c.patient_id = p.patient_id
    WHERE 
        py.payment_date > CURRENT_DATE - INTERVAL '1 year'
    GROUP BY 
        p.patient_id
)
SELECT 
    p.patient_id,
    ac.condition_count,
    ev.emergency_count,
    COALESCE(rp.avg_payment, 0) AS avg_recent_payment,
    (ac.condition_count + ev.emergency_count) * rp.avg_payment AS score_metric
FROM 
    patients p
LEFT JOIN 
    active_conditions ac ON p.patient_id = ac.patient_id
LEFT JOIN 
    emergency_visits ev ON p.patient_id = ev.patient_id
LEFT JOIN 
    recent_payments rp ON p.patient_id = rp.patient_id
WHERE 
    ac.condition_count > 0;


WITH procedure_counts AS (
    SELECT 
        v.visit_id,
        COUNT(pr.procedure_id) AS procedure_count
    FROM 
        procedures pr
    JOIN 
        visits v ON pr.visit_id = v.visit_id
    WHERE 
        pr.procedure_date > CURRENT_DATE - INTERVAL '1 year'
    GROUP BY 
        v.visit_id
),
latest_imaging AS (
    SELECT 
        v.visit_id,
        i.imaging_type,
        ROW_NUMBER() OVER (PARTITION BY v.visit_id ORDER BY i.performed_date DESC) as rn
    FROM 
        imaging i
    JOIN 
        visits v ON i.visit_id = v.visit_id
)
SELECT 
    p.patient_id,
    SUM(pc.procedure_count) AS yearly_procedures,
    COUNT(distinct vi.visit_id) FILTER (WHERE li.rn = 1 AND li.imaging_type = 'MRI') AS mri_count
FROM 
    patients p
JOIN 
    visits vi ON p.patient_id = vi.patient_id
JOIN 
    procedure_counts pc ON vi.visit_id = pc.visit_id
LEFT JOIN 
    latest_imaging li ON vi.visit_id = li.visit_id
GROUP BY 
    p.patient_id
HAVING 
    SUM(pc.procedure_count) > 5;


WITH allergy_counts AS (
    SELECT 
        a.patient_id,
        COUNT(a.allergy_id) AS allergy_count
    FROM 
        allergies a
    WHERE 
        EXTRACT(YEAR FROM a.recorded_date) = EXTRACT(YEAR FROM CURRENT_DATE)
    GROUP BY 
        a.patient_id
),
common_lab_tests AS (
    SELECT 
        l.visit_id,
        l.test_name,
        COUNT(l.test_name) OVER (PARTITION BY l.test_name) AS test_freq
    FROM 
        labs l
)
SELECT 
    p.patient_id,
    ac.allergy_count,
    MAX(clt.test_freq) AS highest_test_freq
FROM 
    patients p
LEFT JOIN 
    visits v ON p.patient_id = v.patient_id
LEFT JOIN 
    allergy_counts ac ON p.patient_id = ac.patient_id
JOIN 
    common_lab_tests clt ON v.visit_id = clt.visit_id
WHERE 
    clt.test_freq > 100
GROUP BY 
    p.patient_id, ac.allergy_count
ORDER BY 
    highest_test_freq DESC;


WITH condition_details AS (
    SELECT 
        c.patient_id,
        CASE 
            WHEN COUNT(*) > 3 THEN 'Complex'
            ELSE 'Simple'
        END AS condition_complexity
    FROM 
        conditions c
    GROUP BY 
        c.patient_id
),
medication_summary AS (
    SELECT 
        m.visit_id,
        COUNT(m.medication_id) AS medication_count
    FROM 
        medications m
    GROUP BY 
        m.visit_id
)
SELECT 
    p.patient_id,
    cd.condition_complexity,
    COALESCE(SUM(ms.medication_count), 0) AS medication_total,
    CASE 
        WHEN SUM(ms.medication_count) > 10 THEN 'High Usage'
        ELSE 'Low Usage'
    END AS medication_usage
FROM 
    patients p
LEFT JOIN 
    visits v ON p.patient_id = v.patient_id
LEFT JOIN 
    medication_summary ms ON v.visit_id = ms.visit_id
LEFT JOIN 
    condition_details cd ON p.patient_id = cd.patient_id
GROUP BY 
    p.patient_id, cd.condition_complexity
HAVING 
    cd.condition_complexity = 'Complex';


WITH sdoh_impact AS (
    SELECT 
        s.patient_id,
        s.sdoh_type,
        COUNT(s.sdoh_id) AS sdoh_count
    FROM 
        sdoh_entries s
    WHERE 
        s.recorded_date > CURRENT_DATE - INTERVAL '3 months'
    GROUP BY 
        s.patient_id, s.sdoh_type
),
employment_summary AS (
    SELECT 
        e.patient_id,
        COUNT(e.employment_id) AS employment_changes
    FROM 
        employment_status e
    GROUP BY 
        e.patient_id
)
SELECT 
    p.patient_id,
    si.sdoh_type,
    si.sdoh_count,
    es.employment_changes,
    COALESCE(si.sdoh_count * es.employment_changes, 0) AS soc_impact_score
FROM 
    patients p
LEFT JOIN 
    sdoh_impact si ON p.patient_id = si.patient_id
LEFT JOIN 
    employment_summary es ON p.patient_id = es.patient_id
WHERE 
    si.sdoh_count > 1;


WITH frequent_screenings AS (
    SELECT 
        s.patient_id,
        COUNT(s.screening_id) AS screening_count
    FROM 
        screenings s
    WHERE 
        s.screening_date > CURRENT_DATE - INTERVAL '1 year'
    GROUP BY 
        s.patient_id
),
survey_scores AS (
    SELECT 
        sr.patient_id,
        AVG(sr.survey_score) AS average_survey_score
    FROM 
        surveys sr
    WHERE 
        sr.survey_date > CURRENT_DATE - INTERVAL '1 year'
    GROUP BY 
        sr.patient_id
)
SELECT 
    p.patient_id,
    fs.screening_count,
    ss.average_survey_score,
    (fs.screening_count + ss.average_survey_score) / 2 AS engagement_index
FROM 
    patients p
LEFT JOIN 
    frequent_screenings fs ON p.patient_id = fs.patient_id
LEFT JOIN 
    survey_scores ss ON p.patient_id = ss.patient_id
WHERE 
    fs.screening_count > 5;


WITH recent_billing AS (
    SELECT 
        b.claim_id,
        SUM(b.amount) AS total_billed
    FROM 
        billing b
    WHERE 
        b.billed_date > CURRENT_DATE - INTERVAL '6 months'
    GROUP BY 
        b.claim_id
),
claim_metrics AS (
    SELECT 
        c.patient_id,
        COUNT(*) AS claim_count
    FROM 
        claims c
    WHERE 
        c.claim_date > CURRENT_DATE - INTERVAL '6 months'
    GROUP BY 
        c.patient_id
)
SELECT 
    p.patient_id,
    cm.claim_count,
    COALESCE(rb.total_billed, 0) AS total_billed,
    CASE 
        WHEN cm.claim_count > 10 THEN 'High'
        ELSE 'Medium'
    END AS billing_intensity
FROM 
    patients p
LEFT JOIN 
    claims c ON p.patient_id = c.patient_id
LEFT JOIN 
    recent_billing rb ON c.claim_id = rb.claim_id
LEFT JOIN 
    claim_metrics cm ON p.patient_id = cm.patient_id
WHERE 
    cm.claim_count > 0;
