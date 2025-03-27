-- Query 1
WITH AgeGroup AS (
    SELECT 
        patient_id,
        (CASE 
            WHEN EXTRACT(YEAR FROM AGE(date_of_birth)) < 18 THEN 'Child'
            WHEN EXTRACT(YEAR FROM AGE(date_of_birth)) BETWEEN 18 AND 64 THEN 'Adult'
            ELSE 'Senior'
        END) AS age_group
    FROM patients
),
VisitSummary AS (
    SELECT 
        patient_id,
        COUNT(*) AS total_visits,
        AVG(DATE_PART('day', discharge_time - admission_time)) AS avg_stay_length
    FROM visits
    GROUP BY patient_id
)
SELECT 
    ag.age_group,
    COUNT(*) AS patient_count,
    AVG(vs.total_visits) AS avg_visits_per_patient
FROM AgeGroup ag
JOIN VisitSummary vs ON ag.patient_id = vs.patient_id
JOIN (
    SELECT 
        DISTINCT patient_id
    FROM symptoms
    WHERE severity = 'High'
) hs ON ag.patient_id = hs.patient_id
GROUP BY ag.age_group;

-- Query 2
WITH HighRiskPatients AS (
    SELECT 
        rp.patient_id,
        AVG(rs.score_value) AS avg_risk_score
    FROM risk_scores rs
    JOIN patients rp ON rs.patient_id = rp.patient_id
    WHERE score_type = 'Cardiovascular'
    GROUP BY rp.patient_id
    HAVING AVG(rs.score_value) > 7.5
)
SELECT 
    hrp.patient_id,
    hrp.avg_risk_score,
    SUM(bp.paid_amount) AS total_paid_amount
FROM HighRiskPatients hrp
JOIN claims cl ON hrp.patient_id = cl.patient_id
JOIN payments bp ON cl.claim_id = bp.claim_id
WHERE cl.claim_status = 'Paid'
GROUP BY hrp.patient_id, hrp.avg_risk_score;

-- Query 3
WITH DiabetesPatients AS (
    SELECT DISTINCT 
        c.patient_id
    FROM conditions c
    WHERE condition_name = 'Diabetes'
),
MultiLangPatients AS (
    SELECT 
        p.patient_id, 
        COUNT(DISTINCT language_id) AS language_count
    FROM patients p
    GROUP BY p.patient_id
)
SELECT 
    dp.patient_id,
    COUNT(*) AS diabetes_visits,
    mlp.language_count
FROM DiabetesPatients dp
JOIN visits v ON dp.patient_id = v.patient_id
JOIN MultiLangPatients mlp ON dp.patient_id = mlp.patient_id
WHERE v.was_emergency IS TRUE
GROUP BY dp.patient_id, mlp.language_count;

-- Query 4
WITH RecentVisits AS (
    SELECT 
        v.visit_id,
        v.patient_id,
        v.visit_date
    FROM visits v
    WHERE visit_date > CURRENT_DATE - INTERVAL '180 days'
)
SELECT 
    rv.patient_id,
    COUNT(DISTINCT p.procedure_id) AS procedure_count,
    COUNT(DISTINCT m.medication_id) AS medication_count
FROM RecentVisits rv
LEFT JOIN procedures p ON rv.visit_id = p.visit_id
LEFT JOIN medications m ON rv.visit_id = m.visit_id
GROUP BY rv.patient_id
HAVING COUNT(DISTINCT p.procedure_id) > 0 OR COUNT(DISTINCT m.medication_id) > 0;

-- Query 5
WITH ChronicDiseasePatients AS (
    SELECT 
        DISTINCT patient_id
    FROM conditions
    WHERE condition_status = 'Chronic'
)
SELECT 
    cdp.patient_id,
    AVG(ls.result_value) AS avg_lab_result
FROM ChronicDiseasePatients cdp
JOIN visits v ON cdp.patient_id = v.patient_id
JOIN labs ls ON v.visit_id = ls.visit_id
GROUP BY cdp.patient_id
HAVING AVG(ls.result_value) > (
    SELECT AVG(result_value) 
    FROM labs 
    WHERE test_name = 'Glucose'
);

-- Query 6
WITH ActivePatients AS (
    SELECT 
        p.patient_id,
        MAX(ls.result_value) AS max_blood_pressure
    FROM patients p
    JOIN visits v ON p.patient_id = v.patient_id
    JOIN vitals vt ON v.visit_id = vt.visit_id
    WHERE vt.blood_pressure_systolic >= 140
    GROUP BY p.patient_id
)
SELECT 
    ap.patient_id,
    ap.max_blood_pressure,
    COUNT(DISTINCT d.diagnosis_id) AS hypertension_diagnoses
FROM ActivePatients ap
JOIN diagnoses d ON ap.patient_id = d.patient_id
WHERE diagnosis_code IN ('I10', 'I11')
GROUP BY ap.patient_id, ap.max_blood_pressure;

-- Query 7
WITH ProviderEfficiency AS (
    SELECT 
        pr.provider_id,
        COUNT(DISTINCT v.visit_id) AS visit_count
    FROM providers pr
    LEFT JOIN visits v ON pr.provider_id = v.provider_id
    WHERE specialty = 'Cardiology'
    GROUP BY pr.provider_id
),
ProviderRating AS (
    SELECT 
        pr.provider_id,
        AVG(sr.survey_score) AS provider_rating
    FROM providers pr
    JOIN visits v ON pr.provider_id = v.provider_id
    JOIN surveys sr ON v.patient_id = sr.patient_id
    WHERE sr.survey_date > CURRENT_DATE - INTERVAL '1 year'
    GROUP BY pr.provider_id
)
SELECT 
    pe.provider_id,
    pe.visit_count,
    pr.provider_rating
FROM ProviderEfficiency pe
JOIN ProviderRating pr ON pe.provider_id = pr.provider_id
WHERE pe.visit_count > (
    SELECT AVG(visit_count) 
    FROM ProviderEfficiency
);

-- Query 8
WITH LabTests AS (
    SELECT 
        DISTINCT test_name
    FROM labs
)
SELECT 
    p.patient_id,
    SUM(cl.claim_amount) AS total_claim,
    AVG(ls.result_value) AS avg_lab_result
FROM patients p
JOIN claims cl ON p.patient_id = cl.patient_id
JOIN visits v ON p.patient_id = v.patient_id
JOIN labs ls ON v.visit_id = ls.visit_id
WHERE ls.test_name IN (SELECT test_name FROM LabTests)
GROUP BY p.patient_id
HAVING SUM(cl.claim_amount) > 10000;

-- Query 9
WITH EmergencyVisits AS (
    SELECT 
        patient_id,
        COUNT(*) AS emergency_counts
    FROM visits
    WHERE was_emergency IS TRUE
    GROUP BY patient_id
)
SELECT 
    ev.patient_id,
    ev.emergency_counts,
    COUNT(pct.care_team_id) AS care_team_involvement
FROM EmergencyVisits ev
LEFT JOIN patient_care_team pct ON ev.patient_id = pct.patient_id
GROUP BY ev.patient_id, ev.emergency_counts
ORDER BY ev.emergency_counts DESC;

-- Query 10
WITH MedicatedVisits AS (
    SELECT 
        v.visit_id,
        COUNT(DISTINCT m.medication_id) AS medication_count
    FROM visits v
    LEFT JOIN medications m ON v.visit_id = m.visit_id
    GROUP BY v.visit_id
),
AllergyPatients AS (
    SELECT 
        DISTINCT a.patient_id
    FROM allergies a
)
SELECT 
    av.patient_id,
    AVG(mv.medication_count) AS avg_medications
FROM AllergicPatients av
JOIN visits v ON av.patient_id = v.patient_id
JOIN MedicatedVisits mv ON v.visit_id = mv.visit_id
GROUP BY av.patient_id
HAVING AVG(mv.medication_count) > 2;