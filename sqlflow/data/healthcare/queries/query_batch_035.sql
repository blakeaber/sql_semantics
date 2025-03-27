WITH RecentVisits AS (
    SELECT 
        v.visit_id, 
        v.patient_id, 
        v.visit_date, 
        ROW_NUMBER() OVER (PARTITION BY v.patient_id ORDER BY v.visit_date DESC) AS rn
    FROM visits v
),
EmergencyCount AS (
    SELECT 
        patient_id, 
        COUNT(*) AS emergency_visits
    FROM visits
    WHERE was_emergency = TRUE
    GROUP BY patient_id
),
PatientConditions AS (
    SELECT 
        c.patient_id, 
        MAX(c.diagnosed_date) AS last_condition_date
    FROM conditions c
    GROUP BY c.patient_id
    HAVING COUNT(c.condition_id) > 2
)
SELECT 
    p.patient_id, 
    p.first_name, 
    p.last_name, 
    em.emergency_visits, 
    pc.last_condition_date,
    COALESCE(SUM(cl.claim_amount), 0) AS total_claim_amount,
    CASE 
        WHEN COUNT(distinct vi.visit_id) > 5 THEN 'Frequent Visitor'
        ELSE 'Regular Visitor'
    END AS visit_frequency
FROM patients p
LEFT JOIN RecentVisits rv ON p.patient_id = rv.patient_id
LEFT JOIN EmergencyCount em ON p.patient_id = em.patient_id
LEFT JOIN PatientConditions pc ON p.patient_id = pc.patient_id
LEFT JOIN claims cl ON p.patient_id = cl.patient_id
LEFT JOIN visits vi ON p.patient_id = vi.patient_id
WHERE rv.rn = 1
GROUP BY p.patient_id, p.first_name, p.last_name, em.emergency_visits, pc.last_condition_date
ORDER BY em.emergency_visits DESC, total_claim_amount DESC;

WITH TopConditions AS (
    SELECT 
        d.diagnosis_code, 
        COUNT(*) AS diagnosis_count
    FROM diagnoses d
    JOIN visits v ON d.visit_id = v.visit_id
    GROUP BY d.diagnosis_code
    HAVING COUNT(*) > 50
),
RecentNotes AS (
    SELECT 
        cn.note_id, 
        cn.visit_id, 
        cn.created_at,
        ROW_NUMBER() OVER (PARTITION BY cn.visit_id ORDER BY cn.created_at DESC) AS rn
    FROM clinical_notes cn
)
SELECT 
    d.diagnosis_id, 
    tp.diagnosis_count,
    v.visit_id, 
    v.visit_date, 
    cn.note_summary,
    CONCAT(p.first_name, ' ', p.last_name) AS full_name
FROM diagnoses d
JOIN visits v ON d.visit_id = v.visit_id
JOIN patients p ON v.patient_id = p.patient_id
LEFT JOIN TopConditions tp ON d.diagnosis_code = tp.diagnosis_code
LEFT JOIN RecentNotes cn ON v.visit_id = cn.visit_id AND cn.rn = 1
WHERE tp.diagnosis_count IS NOT NULL
ORDER BY tp.diagnosis_count DESC, v.visit_date DESC;

SELECT 
    i.imaging_id, 
    v.visit_id, 
    v.visit_date, 
    i.body_part, 
    i.impression,
    EXTRACT(YEAR FROM i.performed_date) AS year_performed,
    AVG(l.result_value) OVER(PARTITION BY EXTRACT(YEAR FROM i.performed_date)) AS avg_lab_result
FROM imaging i
JOIN visits v ON i.visit_id = v.visit_id
JOIN labs l ON v.visit_id = l.visit_id
WHERE i.impression IS NOT NULL
UNION ALL
SELECT 
    l.lab_result_id, 
    v.visit_id, 
    v.visit_date, 
    l.test_name AS body_part, 
    NULL AS impression,
    EXTRACT(YEAR FROM l.reported_date) AS year_performed,
    AVG(l.result_value) OVER(PARTITION BY EXTRACT(YEAR FROM l.reported_date)) AS avg_lab_result
FROM labs l
JOIN visits v ON l.visit_id = v.visit_id
LEFT JOIN conditions c ON v.patient_id = c.patient_id
WHERE c.condition_status = 'Active';

WITH MedicationUsage AS (
    SELECT 
        m.medication_code, 
        COUNT(*) AS usage_count
    FROM medications m
    WHERE m.start_date > CURRENT_DATE - INTERVAL '1 year'
    GROUP BY m.medication_code
),
ProviderSpecialties AS (
    SELECT 
        p.provider_id, 
        p.specialty, 
        COUNT(*) AS specialty_count
    FROM providers p
    JOIN visits v ON p.provider_id = v.provider_id
    GROUP BY p.provider_id, p.specialty
)
SELECT 
    mu.medication_code, 
    mu.usage_count, 
    ps.specialty,
    COUNT(m.medication_id) AS total_prescriptions
FROM MedicationUsage mu
JOIN medications m ON mu.medication_code = m.medication_code
JOIN visits v ON m.visit_id = v.visit_id
JOIN providers p ON v.provider_id = p.provider_id
JOIN ProviderSpecialties ps ON p.provider_id = ps.provider_id
WHERE ps.specialty_count > 10
GROUP BY mu.medication_code, mu.usage_count, ps.specialty
HAVING SUM(m.frequency::integer) > 100;

SELECT 
    p.patient_id, 
    p.first_name, 
    p.last_name, 
    COUNT(*) FILTER (WHERE a.severity = 'High') AS high_severity_allergies,
    COUNT(*) FILTER (WHERE s.result = 'Positive') AS positive_screenings,
    AVG(rs.score_value) AS avg_risk_score
FROM patients p
JOIN allergies a ON p.patient_id = a.patient_id
JOIN screenings s ON p.patient_id = s.patient_id
LEFT JOIN risk_scores rs ON p.patient_id = rs.patient_id
WHERE a.recorded_date > CURRENT_DATE - INTERVAL '1 year'
GROUP BY p.patient_id, p.first_name, p.last_name
HAVING COUNT(*) FILTER (WHERE s.screening_type = 'Diabetes') > 2;

WITH IncomeAnalysis AS (
    SELECT 
        income_level, 
        AVG(claim_amount) AS avg_claim_amount
    FROM income_brackets ib
    JOIN claims cl ON ib.patient_id = cl.patient_id
    GROUP BY income_level
)
SELECT 
    i.income_level, 
    i.avg_claim_amount, 
    COUNT(distinct p.patient_id) AS num_patients,
    MAX(b.amount) AS max_billed
FROM IncomeAnalysis i
JOIN patients p ON p.patient_id = i.patient_id
LEFT JOIN billing b ON p.patient_id = b.patient_id
WHERE b.billed_date > CURRENT_DATE - INTERVAL '6 months'
GROUP BY i.income_level, i.avg_claim_amount
ORDER BY num_patients DESC;

SELECT 
    p.provider_id, 
    p.first_name, 
    p.last_name, 
    COALESCE(SUM(b.amount), 0) AS total_billed,
    CASE 
        WHEN COUNT(v.visit_id) > 100 THEN 'High Volume'
        WHEN COUNT(v.visit_id) BETWEEN 50 AND 100 THEN 'Medium Volume'
        ELSE 'Low Volume'
    END AS visit_volume
FROM providers p
JOIN visits v ON p.provider_id = v.provider_id
LEFT JOIN claims cl ON v.visit_id = cl.visit_id
LEFT JOIN billing b ON cl.claim_id = b.claim_id
WHERE p.specialty IN (
    SELECT specialty
    FROM providers
    GROUP BY specialty
    HAVING COUNT(*) > 5
)
GROUP BY p.provider_id, p.first_name, p.last_name
ORDER BY total_billed DESC, visit_volume;

WITH VitalStats AS (
    SELECT 
        v.visit_id, 
        AVG(v.height_cm) AS avg_height, 
        AVG(v.bmi) AS avg_bmi, 
        RANK() OVER(ORDER BY AVG(v.weight_kg) DESC) AS weight_rank
    FROM vitals v
    GROUP BY v.visit_id
)
SELECT 
    v.visit_id, 
    vs.avg_height, 
    vs.avg_bmi, 
    vs.weight_rank, 
    CONCAT(p.first_name, ' ', p.last_name) AS full_name,
    SUM(cl.paid_amount) AS total_paid
FROM VitalStats vs
JOIN visits v ON vs.visit_id = v.visit_id
JOIN patients p ON v.patient_id = p.patient_id
LEFT JOIN claims cl ON v.visit_id = cl.visit_id
WHERE vs.weight_rank <= 10
GROUP BY v.visit_id, vs.avg_height, vs.avg_bmi, vs.weight_rank, p.first_name, p.last_name;

WITH ProcedureCount AS (
    SELECT 
        pc.procedure_code, 
        COUNT(*) AS total_count
    FROM procedures pc
    JOIN visits v ON pc.visit_id = v.visit_id
    GROUP BY pc.procedure_code
    HAVING COUNT(*) > 20
)
SELECT 
    pc.procedure_code, 
    pc.total_count, 
    COUNT(distinct p.patient_id) AS patient_count
FROM ProcedureCount pc
JOIN procedures pr ON pc.procedure_code = pr.procedure_code
JOIN visits v ON pr.visit_id = v.visit_id
JOIN patients p ON v.patient_id = p.patient_id
WHERE v.encounter_type_id IN (
    SELECT encounter_type_id
    FROM encounter_types
    WHERE encounter_type_name LIKE '%Surgery%'
)
GROUP BY pc.procedure_code, pc.total_count
ORDER BY patient_count DESC;

WITH PaymentSummary AS (
    SELECT 
        py.payment_source, 
        SUM(py.amount) AS total_payments
    FROM payments py
    JOIN claims cl ON py.claim_id = cl.claim_id
    GROUP BY py.payment_source
)
SELECT 
    ps.payment_source, 
    ps.total_payments, 
    COUNT(distinct c.claim_id) AS distinct_claims,
    AVG(cl.paid_amount) AS avg_paid
FROM PaymentSummary ps
LEFT JOIN claims cl ON ps.payment_source = cl.claim_id
LEFT JOIN patients p ON cl.patient_id = p.patient_id
WHERE cl.claim_status = 'Processed'
GROUP BY ps.payment_source, ps.total_payments
HAVING AVG(cl.paid_amount) > 1000;

WITH SurveyScores AS (
    SELECT 
        s.survey_type, 
        AVG(s.survey_score) AS avg_score
    FROM surveys s
    WHERE s.survey_date > CURRENT_DATE - INTERVAL '1 year'
    GROUP BY s.survey_type
)
SELECT 
    ss.survey_type, 
    ss.avg_score, 
    s.patient_id,
    MAX(l.recorded_date) AS last_lab_record
FROM SurveyScores ss
JOIN surveys s ON ss.survey_type = s.survey_type
LEFT JOIN labs l ON s.patient_id = l.visit_id
WHERE l.result_flag = 'Abnormal'
GROUP BY ss.survey_type, ss.avg_score, s.patient_id
ORDER BY ss.avg_score DESC;