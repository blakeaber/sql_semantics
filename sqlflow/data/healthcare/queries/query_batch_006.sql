WITH LastDiagnosis AS (
    SELECT 
        patient_id, 
        MAX(diagnosis_date) AS last_diagnosis_date
    FROM 
        diagnoses
    GROUP BY 
        patient_id
)
SELECT 
    p.patient_id,
    p.first_name,
    p.last_name,
    pe.location,
    COUNT(distinct v.visit_id) AS num_visits,
    SUM(c.claim_amount) AS total_claim_amount,
    LEAST(SUM(c.paid_amount), SUM(c.claim_amount)) AS total_paid_or_claim,
    AVG(l.result_value) AS avg_lab_result,
    MAX(d.diagnosis_date) AS latest_diagnosis_date,
    CASE 
        WHEN MAX(d.diagnosis_date) >= last_diagnosis_date 
        THEN 'Active' 
        ELSE 'Inactive'
    END AS diagnosis_status
FROM 
    patients AS p
JOIN 
    visits AS v ON p.patient_id = v.patient_id
JOIN 
    claims AS c ON v.visit_id = c.visit_id
JOIN 
    providers AS pe ON v.provider_id = pe.provider_id
JOIN 
    labs AS l ON v.visit_id = l.visit_id
JOIN 
    LastDiagnosis AS ld ON p.patient_id = ld.patient_id
LEFT JOIN 
    diagnoses AS d ON v.visit_id = d.visit_id
GROUP BY 
    p.patient_id, p.first_name, p.last_name, pe.location, last_diagnosis_date
HAVING 
    COUNT(distinct v.visit_id) > 2;

WITH EmergencyVisits AS (
    SELECT 
        patient_id, 
        COUNT(*) AS emergency_count
    FROM 
        visits
    WHERE 
        was_emergency = TRUE
    GROUP BY 
        patient_id
)
SELECT 
    v.visit_id,
    p.first_name,
    p.last_name,
    et.encounter_type_name,
    COUNT(d.diagnosis_id) OVER (PARTITION BY v.patient_id) AS total_diagnoses_per_patient,
    ev.emergency_count,
    EXTRACT(month FROM v.visit_date) AS visit_month,
    AVG(cl.billed_amount) AS avg_billed_amount,
    MAX(cl.paid_amount) AS max_paid_amount
FROM 
    visits AS v
JOIN 
    patients AS p ON v.patient_id = p.patient_id
JOIN 
    encounter_types AS et ON v.encounter_type_id = et.encounter_type_id
JOIN 
    diagnoses AS d ON v.visit_id = d.visit_id
LEFT JOIN 
    EmergencyVisits AS ev ON p.patient_id = ev.patient_id
LEFT JOIN 
    claims AS cl ON v.visit_id = cl.visit_id
WHERE 
    d.diagnosis_type IN ('Primary', 'Secondary');

WITH ProviderSpecialty AS (
    SELECT 
        p.provider_id, 
        p.specialty, 
        COUNT(v.visit_id) AS num_visits
    FROM 
        providers p
    JOIN 
        visits v ON p.provider_id = v.provider_id
    GROUP BY 
        p.provider_id, p.specialty
)
SELECT 
    pr.provider_id,
    pr.specialty,
    COUNT(v.visit_id) AS total_encounters,
    SUM(c.claim_amount) AS total_claim_revenue,
    AVG(proc_code_summary.procedure_count) AS avg_procedures
FROM 
    ProviderSpecialty pr
JOIN 
    visits v ON pr.provider_id = v.provider_id
JOIN 
    claims c ON v.visit_id = c.visit_id
LEFT JOIN (
    SELECT 
        visit_id, 
        COUNT(*) AS procedure_count
    FROM 
        procedures
    GROUP BY 
        visit_id
) proc_code_summary ON v.visit_id = proc_code_summary.visit_id
GROUP BY 
    pr.provider_id, pr.specialty
HAVING 
    COUNT(v.visit_id) > 5;

WITH PatientMedications AS (
    SELECT 
        patient_id, 
        medication_code,
        COUNT(*) AS medication_count
    FROM 
        medications
    GROUP BY 
        patient_id, medication_code
)
SELECT 
    p.patient_id,
    p.first_name,
    p.last_name,
    COUNT(v.visit_id) AS visit_count,
    SUM(pm.medication_count) AS total_medications,
    CASE 
        WHEN MIN(pm.medication_count) > 5 
        THEN 'High Risk' 
        ELSE 'Normal' 
    END AS risk_level,
    COUNT(DISTINCT sd.sdoh_type) AS unique_sdoh, 
    MAX(surv.survey_score) AS max_survey_score
FROM 
    patients p
LEFT JOIN 
    visits v ON p.patient_id = v.patient_id
LEFT JOIN 
    PatientMedications pm ON p.patient_id = pm.patient_id
LEFT JOIN 
    sdoh_entries sd ON p.patient_id = sd.patient_id
LEFT JOIN 
    surveys surv ON p.patient_id = surv.patient_id
GROUP BY 
    p.patient_id, p.first_name, p.last_name;

WITH RecentImaging AS (
    SELECT 
        visit_id,
        MAX(performed_date) AS last_imaging_date
    FROM 
        imaging
    GROUP BY 
        visit_id
)
SELECT 
    p.patient_id,
    p.first_name,
    p.last_name,
    COUNT(distinct v.visit_id) AS visits_count,
    SUM(cl.paid_amount) AS total_paid,
    MAX(r.score_value) AS max_risk_score,
    ri.last_imaging_date,
    AVG(DATEDIFF('day', i.performed_date, NOW())) AS avg_days_since_last_imaging,
    CASE 
        WHEN COUNT(1) FILTER(WHERE i.impressions = 'Negative') >= 2 
        THEN 'Requires Review' 
        ELSE 'Stable' 
    END AS imaging_status
FROM 
    patients p
JOIN 
    visits v ON p.patient_id = v.patient_id
LEFT JOIN 
    claims cl ON v.visit_id = cl.visit_id
LEFT JOIN 
    risk_scores r ON p.patient_id = r.patient_id
JOIN 
    imaging i ON v.visit_id = i.visit_id
JOIN 
    RecentImaging ri ON i.visit_id = ri.visit_id
GROUP BY 
    p.patient_id, p.first_name, p.last_name, ri.last_imaging_date;

WITH ActiveConditions AS (
    SELECT 
        patient_id, 
        COUNT(*) AS active_condition_count
    FROM 
        conditions
    WHERE 
        condition_status = 'Active'
    GROUP BY 
        patient_id
)
SELECT 
    p.patient_id,
    p.first_name,
    p.last_name,
    a.active_condition_count,
    AVG(cl.claim_amount) AS avg_claim_amount,
    SUM(d.billed_amount) AS total_billed,
    CASE 
        WHEN MAX(paid.amount) > 1000 
        THEN 'High Expense' 
        ELSE 'Regular' 
    END AS expense_status,
    CASE 
        WHEN a.active_condition_count > 3 
        THEN 'High' 
        ELSE 'Normal' 
    END AS condition_risk
FROM 
    patients p
JOIN 
    ActiveConditions a ON p.patient_id = a.patient_id
LEFT JOIN 
    visits v ON p.patient_id = v.patient_id
LEFT JOIN 
    claims cl ON v.visit_id = cl.visit_id
LEFT JOIN 
    billing d ON cl.claim_id = d.claim_id
LEFT JOIN 
    payments paid ON cl.claim_id = paid.claim_id
GROUP BY 
    p.patient_id, p.first_name, p.last_name, a.active_condition_count;

WITH HighHeartRateVitals AS (
    SELECT 
        visit_id,
        AVG(heart_rate) AS avg_heart_rate
    FROM 
        vitals
    GROUP BY 
        visit_id
    HAVING 
        AVG(heart_rate) > 100
)
SELECT 
    p.patient_id, 
    p.first_name, 
    p.last_name, 
    COUNT(v.visit_id) AS num_visits,
    SUM(cl.billed_amount) AS total_billed,
    MAX(l.result_value) AS max_lab_value,
    hrv.avg_heart_rate,
    CASE 
        WHEN hrv.avg_heart_rate > 100 
        THEN 'Monitor' 
        ELSE 'Normal' 
    END AS heart_rate_status
FROM 
    patients p
JOIN 
    visits v ON p.patient_id = v.patient_id
LEFT JOIN 
    claims cl ON v.visit_id = cl.visit_id
LEFT JOIN 
    labs l ON v.visit_id = l.visit_id
JOIN 
    HighHeartRateVitals hrv ON v.visit_id = hrv.visit_id
GROUP BY 
    p.patient_id, p.first_name, p.last_name, hrv.avg_heart_rate;

WITH RecentAdmissions AS (
    SELECT 
        patient_id, 
        MAX(admission_time) AS recent_admission
    FROM 
        visits
    WHERE 
        was_emergency = TRUE
    GROUP BY 
        patient_id
)
SELECT 
    p.patient_id, 
    p.first_name, 
    p.last_name,
    SUM(pm.amount) AS total_payment,
    COUNT(s.screening_id) AS screening_count,
    MAX(rec.recent_admission) AS last_emergency_admission,
    DENSE_RANK() OVER (PARTITION BY rec.patient_id ORDER BY COUNT(s.screening_id) DESC) as screening_rank
FROM 
    patients p
LEFT JOIN 
    payments pm ON p.patient_id = pm.patient_id
LEFT JOIN 
    screenings s ON p.patient_id = s.patient_id
JOIN 
    RecentAdmissions rec ON p.patient_id = rec.patient_id
GROUP BY 
    p.patient_id, p.first_name, p.last_name, rec.recent_admission;

WITH ProviderPerformance AS (
    SELECT 
        provider_id, 
        COUNT(DISTINCT visit_id) AS visit_count,
        AVG(claim_amount) AS avg_claim
    FROM 
        visits
    JOIN 
        claims ON visits.visit_id = claims.visit_id
    GROUP BY 
        provider_id
)
SELECT 
    pr.first_name,
    pr.last_name,
    pp.visit_count,
    pp.avg_claim,
    COUNT(DISTINCT med.medication_id) OVER (PARTITION BY pr.provider_id) AS medications_per_provider,
    LEAST(pp.avg_claim, SUM(claims.paid_amount)) AS minimum_avg_or_paid
FROM 
    providers pr
JOIN 
    ProviderPerformance pp ON pr.provider_id = pp.provider_id
LEFT JOIN 
    visits ON pr.provider_id = visits.provider_id
LEFT JOIN 
    medications med ON visits.visit_id = med.visit_id
LEFT JOIN 
    claims ON visits.visit_id = claims.visit_id;

WITH AllergiesInTreatment AS (
    SELECT 
        patient_id,
        COUNT(*) AS active_allergies
    FROM 
        allergies
    WHERE 
        severity = 'High'
    GROUP BY 
        patient_id
)
SELECT 
    p.patient_id,
    p.first_name,
    p.last_name,
    COUNT(DISTINCT v.visit_id) AS visit_count,
    SUM(cl.billed_amount) AS total_billed_amount,
    AVG(coalesce(ps.survey_score, 0)) AS avg_survey_score,
    ai.active_allergies,
    CASE 
        WHEN ai.active_allergies > 5 THEN 'Critical' 
        ELSE 'Manageable' 
    END AS allergy_status
FROM 
    patients p
JOIN 
    visits v ON p.patient_id = v.patient_id
LEFT JOIN 
    claims cl ON v.visit_id = cl.visit_id
LEFT JOIN 
    surveys ps ON p.patient_id = ps.patient_id
JOIN 
    AllergiesInTreatment ai ON p.patient_id = ai.patient_id
GROUP BY 
    p.patient_id, p.first_name, p.last_name, ai.active_allergies;