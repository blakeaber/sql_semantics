WITH AvgHRByPatient AS (
    SELECT 
        v.patient_id,
        AVG(h.heart_rate) AS avg_heart_rate
    FROM 
        visits v
    JOIN 
        vitals h ON v.visit_id = h.visit_id
    GROUP BY 
        v.patient_id
),
RaceLanguageCount AS (
    SELECT
        r.race_ethnicity_name,
        l.language_name,
        COUNT(p.patient_id) AS patient_count
    FROM 
        patients p
    JOIN 
        race_ethnicity r ON p.race_ethnicity_id = r.race_ethnicity_id
    JOIN 
        languages l ON p.language_id = l.language_id
    GROUP BY 
        r.race_ethnicity_name, l.language_name
    HAVING 
        COUNT(p.patient_id) > 10
)
SELECT 
    p.first_name,
    p.last_name,
    COALESCE(pr.specialty, 'Unknown') AS provider_specialty,
    a.avg_heart_rate,
    CASE
        WHEN a.avg_heart_rate > 100 THEN 'High'
        ELSE 'Normal'
    END AS hr_category,
    (SELECT COUNT(*) FROM visits v2 WHERE v2.patient_id = p.patient_id) AS total_visits
FROM 
    AvgHRByPatient a
JOIN 
    patients p ON a.patient_id = p.patient_id
LEFT JOIN 
    visits v ON v.patient_id = p.patient_id
LEFT JOIN 
    providers pr ON v.provider_id = pr.provider_id
WHERE 
    p.created_at >= '2020-01-01'
ORDER BY 
    hr_category DESC;

WITH VisitProcedureCounts AS (
    SELECT 
        v.visit_id,
        COUNT(pr.procedure_id) AS procedure_count
    FROM 
        visits v
    JOIN 
        procedures pr ON v.visit_id = pr.visit_id
    GROUP BY 
        v.visit_id
),
VisitSymptomCounts AS (
    SELECT 
        v.visit_id,
        COUNT(s.symptom_id) AS symptom_count
    FROM 
        visits v
    JOIN 
        symptoms s ON v.visit_id = s.visit_id
    GROUP BY 
        v.visit_id
)
SELECT 
    p.first_name,
    p.last_name,
    v.visit_date,
    COALESCE(pc.procedure_count, 0) AS procedure_count,
    COALESCE(sc.symptom_count, 0) AS symptom_count,
    e.encounter_type_name
FROM 
    visits v
JOIN 
    patients p ON v.patient_id = p.patient_id
JOIN 
    encounter_types e ON v.encounter_type_id = e.encounter_type_id
LEFT JOIN 
    VisitProcedureCounts pc ON v.visit_id = pc.visit_id
LEFT JOIN 
    VisitSymptomCounts sc ON v.visit_id = sc.visit_id
WHERE 
    v.was_emergency = True
ORDER BY 
    v.visit_date DESC;

WITH ClaimAmounts AS (
    SELECT 
        c.patient_id,
        SUM(c.claim_amount) AS total_claim_amount
    FROM 
        claims c
    GROUP BY 
        c.patient_id
),
BillingAmounts AS (
    SELECT 
        b.claim_id,
        SUM(b.amount) AS total_billed_amount
    FROM 
        billing b
    GROUP BY 
        b.claim_id
)
SELECT 
    p.first_name,
    p.last_name,
    CASE 
        WHEN ca.total_claim_amount > 10000 THEN 'High Claims'
        ELSE 'Regular Claims'
    END AS claim_category,
    SUM(pa.amount) AS total_payment_amount
FROM 
    patients p
JOIN 
    claims c ON p.patient_id = c.patient_id
JOIN 
    ClaimAmounts ca ON ca.patient_id = p.patient_id
LEFT JOIN 
    payments pa ON c.claim_id = pa.claim_id
WHERE 
    c.claim_status = 'Paid'
GROUP BY 
    p.first_name, p.last_name, ca.total_claim_amount
ORDER BY 
    total_payment_amount DESC;

WITH LanguagePatientCounts AS (
    SELECT 
        l.language_name,
        COUNT(p.patient_id) AS patient_count
    FROM 
        languages l
    JOIN 
        patients p ON l.language_id = p.language_id
    GROUP BY 
        l.language_name
)
SELECT 
    l.language_name,
    pc.patient_count,
    r.race_ethnicity_name,
    AVG(s.survey_score) AS average_survey_score
FROM 
    LanguagePatientCounts pc
JOIN 
    patients p ON pc.language_name = (SELECT language_name FROM languages WHERE language_id = p.language_id)
JOIN 
    race_ethnicity r ON p.race_ethnicity_id = r.race_ethnicity_id
LEFT JOIN 
    surveys s ON p.patient_id = s.patient_id
GROUP BY 
    l.language_name, pc.patient_count, r.race_ethnicity_name
ORDER BY 
    average_survey_score;

WITH PatientRiskScores AS (
    SELECT 
        rs.patient_id,
        AVG(rs.score_value) AS avg_risk_score
    FROM 
        risk_scores rs
    GROUP BY 
        rs.patient_id
)
SELECT 
    p.first_name,
    p.last_name,
    ps.avg_risk_score,
    e.employment_type,
    hs.housing_type
FROM 
    patients p
JOIN 
    PatientRiskScores ps ON p.patient_id = ps.patient_id
LEFT JOIN 
    employment_status e ON p.patient_id = e.patient_id
LEFT JOIN 
    housing_status hs ON p.patient_id = hs.patient_id
WHERE 
    ps.avg_risk_score > (SELECT AVG(avg_risk_score) FROM PatientRiskScores)
ORDER BY 
    ps.avg_risk_score DESC;

WITH DiagnosesCounts AS (
    SELECT 
        d.visit_id,
        COUNT(d.diagnosis_id) AS diagnosis_count
    FROM 
        diagnoses d
    GROUP BY 
        d.visit_id
)
SELECT 
    v.visit_date,
    p.first_name,
    p.last_name,
    d.diagnosis_description,
    COUNT(dc.diagnosis_count) OVER (PARTITION BY v.visit_id) AS visit_diagnosis_count
FROM 
    visits v
JOIN 
    diagnoses d ON v.visit_id = d.visit_id
JOIN 
    DiagnosesCounts dc ON v.visit_id = dc.visit_id
JOIN 
    patients p ON v.patient_id = p.patient_id
ORDER BY 
    visit_diagnosis_count DESC;

WITH MedicationsOverTime AS (
    SELECT 
        m.medication_name,
        COUNT(m.medication_id) AS medication_count,
        m.start_date
    FROM 
        medications m
    GROUP BY 
        m.medication_name, m.start_date
)
SELECT 
    m.medication_name,
    SUM(mo.medication_count) AS total_medication_count,
    ROUND(EXTRACT(EPOCH FROM AGE(NOW(), MIN(mo.start_date)))/86400, 0) AS medication_day_age
FROM 
    MedicationsOverTime mo
JOIN 
    medications m ON mo.medication_name = m.medication_name
GROUP BY 
    m.medication_name
ORDER BY 
    medication_day_age;

WITH ImagingFindings AS (
    SELECT 
        i.visit_id,
        COUNT(i.imaging_id) AS imaging_count,
        STRING_AGG(i.findings, ', ') AS combined_findings
    FROM 
        imaging i
    GROUP BY 
        i.visit_id
)
SELECT 
    p.first_name,
    p.last_name,
    v.visit_date,
    i.combined_findings,
    CASE
        WHEN i.imaging_count > 5 THEN 'Frequent'
        ELSE 'Infrequent'
    END AS imaging_frequency
FROM 
    ImagingFindings i
JOIN 
    visits v ON i.visit_id = v.visit_id
JOIN 
    patients p ON v.patient_id = p.patient_id
ORDER BY 
    i.imaging_count DESC;

WITH VitalsSummary AS (
    SELECT 
        v.visit_id,
        AVG(h.height_cm) AS avg_height,
        AVG(w.weight_kg) AS avg_weight,
        ROUND(AVG(b.blood_pressure_systolic), 0) AS avg_systolic_bp,
        ROUND(AVG(b.blood_pressure_diastolic), 0) AS avg_diastolic_bp
    FROM 
        vitals h
    JOIN 
        vitals w ON h.visit_id = w.visit_id
    JOIN 
        vitals b ON h.visit_id = b.visit_id
    GROUP BY 
        v.visit_id
)
SELECT 
    v.visit_date,
    p.first_name,
    p.last_name,
    vs.avg_height,
    vs.avg_weight,
    vs.avg_systolic_bp,
    vs.avg_diastolic_bp
FROM 
    VitalsSummary vs
JOIN 
    visits v ON vs.visit_id = v.visit_id
JOIN 
    patients p ON v.patient_id = p.patient_id
WHERE 
    vs.avg_systolic_bp > 120
ORDER BY 
    vs.avg_systolic_bp DESC, vs.avg_diastolic_bp DESC;

WITH VisitDetails AS (
    SELECT 
        v.visit_id,
        MIN(v.admission_time) AS first_admission,
        MAX(v.discharge_time) AS last_discharge,
        MIN(c.claim_date) AS first_claim_date,
        MAX(c.claim_date) AS last_claim_date
    FROM 
        visits v
    LEFT JOIN 
        claims c ON v.visit_id = c.visit_id
    GROUP BY 
        v.visit_id
)
SELECT 
    p.first_name,
    p.last_name,
    vd.first_admission,
    vd.last_discharge,
    DATEDIFF(d, vd.first_claim_date, vd.last_claim_date) AS claim_duration
FROM 
    VisitDetails vd
JOIN 
    visits v ON vd.visit_id = v.visit_id
JOIN 
    patients p ON v.patient_id = p.patient_id
WHERE 
    vd.first_claim_date IS NOT NULL
ORDER BY 
    claim_duration DESC;