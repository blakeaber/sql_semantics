-- Query 1
WITH AvgVisitDurations AS (
    SELECT
        p.patient_id,
        AVG(EXTRACT(EPOCH FROM (v.discharge_time - v.admission_time))) AS avg_duration_seconds
    FROM patients p
    JOIN visits v ON p.patient_id = v.patient_id
    GROUP BY p.patient_id
)
SELECT 
    p.first_name, 
    p.last_name,
    rt.race_ethnicity_name,
    i.payer_name,
    a.city,
    avd.avg_duration_seconds,
    COUNT(*)
FROM patients p
JOIN AvgVisitDurations avd ON p.patient_id = avd.patient_id
JOIN race_ethnicity rt ON p.race_ethnicity_id = rt.race_ethnicity_id
JOIN addresses a ON p.address_id = a.address_id
JOIN insurance i ON p.insurance_id = i.insurance_id
JOIN visits v ON p.patient_id = v.patient_id
JOIN (
    SELECT 
        visit_id, 
        SUM(claim_amount) AS total_claims
    FROM claims
    GROUP BY visit_id
    HAVING SUM(claim_amount) > 1000
) c ON v.visit_id = c.visit_id
GROUP BY p.patient_id, rt.race_ethnicity_name, i.payer_name, a.city, avd.avg_duration_seconds
HAVING COUNT(*) > 2;

-- Query 2
WITH EmergencyVisits AS (
    SELECT 
        patient_id,
        COUNT(*) AS emergency_count
    FROM visits
    WHERE was_emergency = TRUE
    GROUP BY patient_id
)
SELECT 
    p.first_name, 
    p.last_name,
    e.employment_type,
    hv.housing_type,
    AVG(ls.survey_score) AS avg_survey_score,
    ev.emergency_count,
    CASE 
        WHEN ev.emergency_count > 5 THEN 'High Emergency Usage'
        ELSE 'Low Emergency Usage'
    END AS emergency_category
FROM patients p
JOIN surveys ls ON p.patient_id = ls.patient_id
JOIN employment_status e ON p.patient_id = e.patient_id
JOIN housing_status hv ON p.patient_id = hv.patient_id
LEFT JOIN EmergencyVisits ev ON p.patient_id = ev.patient_id
GROUP BY p.patient_id, e.employment_type, hv.housing_type, ev.emergency_count;

-- Query 3
WITH ActiveConditions AS (
    SELECT 
        patient_id,
        COUNT(*) AS active_conditions
    FROM conditions
    WHERE condition_status = 'Active'
    GROUP BY patient_id
)
SELECT DISTINCT
    p.first_name,
    p.last_name,
    MAX(d.diagnosis_date) OVER (PARTITION BY p.patient_id) AS last_diagnosis_date,
    ac.active_conditions,
    SUM(pb.paid_amount) AS total_paid
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN diagnoses d ON v.visit_id = d.visit_id
JOIN claims c ON v.visit_id = c.visit_id
JOIN payments pb ON c.claim_id = pb.claim_id
LEFT JOIN ActiveConditions ac ON p.patient_id = ac.patient_id
WHERE p.gender IN ('Male', 'Female')
AND ac.active_conditions > 1
GROUP BY p.patient_id, ac.active_conditions;

-- Query 4
WITH RecentMedications AS (
    SELECT 
        m.visit_id,
        m.medication_name
    FROM medications m
    WHERE m.start_date > CURRENT_DATE - INTERVAL '1 year'
)
SELECT 
    DISTINCT CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
    ra.result_value,
    r.score_type,
    CASE
        WHEN ra.result_value > 100 THEN 'Above Normal'
        ELSE 'Normal'
    END AS lab_status
FROM patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN labs l ON v.visit_id = l.visit_id
JOIN risk_scores r ON p.patient_id = r.patient_id
LEFT JOIN RecentMedications rm ON v.visit_id = rm.visit_id
WHERE l.test_name = 'Cholesterol'
ORDER BY ra.result_value DESC;

-- Query 5
WITH FrequentDiagnoses AS (
    SELECT 
        diagnosis_code,
        COUNT(*) AS prevalence
    FROM diagnoses
    GROUP BY diagnosis_code
    HAVING COUNT(*) > 50
)
SELECT 
    CONCAT(pr.first_name, ' ', pr.last_name) AS provider_name,
    dt.description,
    AVG(cl.claim_amount) AS avg_claim_amount,
    fd.prevalence
FROM providers pr
JOIN visits v ON pr.provider_id = v.provider_id
JOIN encounter_types dt ON v.encounter_type_id = dt.encounter_type_id
JOIN claims cl ON v.visit_id = cl.visit_id
JOIN diagnoses d ON v.visit_id = d.visit_id
JOIN FrequentDiagnoses fd ON d.diagnosis_code = fd.diagnosis_code
GROUP BY pr.provider_id, dt.description, fd.prevalence
ORDER BY fd.prevalence DESC;

-- Query 6
WITH HighLabResults AS (
    SELECT 
        l.test_name,
        AVG(l.result_value) AS avg_result_value
    FROM labs l
    WHERE l.result_flag = 'High'
    GROUP BY l.test_name
    HAVING AVG(l.result_value) > 10.0
)
SELECT 
    v.location,
    hlr.test_name,
    psg.score_value,
    COUNT(vb.vital_id) AS vital_count
FROM visits v
JOIN patients p ON v.patient_id = p.patient_id
JOIN vitals vb ON v.visit_id = vb.visit_id
JOIN labs l ON v.visit_id = l.visit_id
JOIN risk_scores psg ON p.patient_id = psg.patient_id
JOIN HighLabResults hlr ON l.test_name = hlr.test_name
GROUP BY v.location, hlr.test_name, psg.score_value
ORDER BY vital_count DESC;

-- Query 7
WITH ImagingFindings AS (
    SELECT 
        imaging_type,
        COUNT(*) AS findings_count
    FROM imaging
    GROUP BY imaging_type
    HAVING COUNT(*) > 20
)
SELECT 
    p.first_name,
    p.last_name,
    MAX(sc.screening_date) OVER (PARTITION BY p.patient_id) AS last_screening_date,
    f.findings_count,
    IFMAX(r.score_value, 0) - IFMIN(r.score_value, 0) AS score_range
FROM patients p
JOIN screenings sc ON p.patient_id = sc.patient_id
JOIN risk_scores r ON p.patient_id = r.patient_id
JOIN imaging i ON i.visit_id = sc.screening_id
JOIN ImagingFindings f ON i.imaging_type = f.imaging_type
GROUP BY p.patient_id, f.findings_count
HAVING score_range > 5;

-- Query 8
WITH TotalExpenses AS (
    SELECT 
        pb.patient_id,
        SUM(c.billed_amount) AS total_billed
    FROM payments pm
    JOIN claims c ON pm.claim_id = c.claim_id
    JOIN visits v ON c.visit_id = v.visit_id
    JOIN patients pb ON v.patient_id = pb.patient_id
    GROUP BY pb.patient_id
)
SELECT 
    p.first_name,
    p.last_name,
    ins.plan_type,
    te.total_billed,
    AVG(bm.amount) AS avg_billed,
    SUM(sm.survey_score) FILTER (WHERE sm.survey_type = 'Satisfaction') AS total_satisfaction
FROM patients p
JOIN insurance ins ON p.insurance_id = ins.insurance_id
JOIN TotalExpenses te ON p.patient_id = te.patient_id
LEFT JOIN screenings scr ON p.patient_id = scr.patient_id
LEFT JOIN surveys sm ON p.patient_id = sm.patient_id
JOIN billing bm ON sm.survey_id = bm.billing_id
GROUP BY p.patient_id, ins.plan_type, te.total_billed
ORDER BY total_billed DESC;

-- Query 9
WITH PatientAllergies AS (
    SELECT 
        patient_id, 
        COUNT(allergy_id) AS allergy_count
    FROM allergies
    GROUP BY patient_id
)
SELECT 
    p.first_name,
    p.last_name,
    MAX(co.diagnosed_date) AS last_condition_date,
    pa.allergy_count,
    nv.vital_count,
    SUM(i.amount) AS total_billed
FROM patients p
JOIN conditions co ON p.patient_id = co.patient_id
JOIN PatientAllergies pa ON p.patient_id = pa.patient_id
JOIN (
    SELECT 
        patient_id, 
        COUNT(vital_id) AS vital_count
    FROM vitals v
    GROUP BY patient_id
) nv ON p.patient_id = nv.patient_id
JOIN claims cl ON p.patient_id = cl.patient_id
JOIN billing i ON cl.claim_id = i.claim_id
GROUP BY p.patient_id, pa.allergy_count, nv.vital_count
HAVING pa.allergy_count > 1;

-- Query 10
WITH MonthlyVisitCounts AS (
    SELECT 
        patient_id,
        DATE_TRUNC('month', visit_date) AS visit_month,
        COUNT(visit_id) AS monthly_visits
    FROM visits
    GROUP BY patient_id, DATE_TRUNC('month', visit_date)
)
SELECT 
    CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
    h.employment_type,
    mc.monthly_visits,
    SUM(e.amount) AS total_expense,
    AVG(r.score_value) OVER (PARTITION BY h.employment_type) AS avg_risk_score
FROM patients p
JOIN MonthlyVisitCounts mc ON p.patient_id = mc.patient_id
JOIN employment_status h ON p.patient_id = h.patient_id
JOIN risk_scores r ON p.patient_id = r.patient_id
JOIN claims cl ON p.patient_id = cl.patient_id
JOIN payments e ON cl.claim_id = e.claim_id
GROUP BY p.patient_id, h.employment_type, mc.monthly_visits
HAVING total_expense > 500;
