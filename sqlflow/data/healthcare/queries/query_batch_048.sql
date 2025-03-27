WITH RecentVisits AS (
    SELECT patient_id, MAX(visit_date) AS last_visit_date
    FROM visits
    GROUP BY patient_id
),
AggregatedClaims AS (
    SELECT patient_id, SUM(claim_amount) AS total_claims
    FROM claims
    GROUP BY patient_id
)
SELECT
    p.first_name,
    p.last_name,
    p.date_of_birth,
    COALESCE(race_ethnicity_name, 'Unknown') AS race,
    COALESCE(language_name, 'Unknown') AS language,
    COUNT(DISTINCT v.visit_id) AS total_visits,
    AVG(vit.bmi) AS avg_bmi,
    SUM(claims.paid_amount) OVER (PARTITION BY p.patient_id) AS paid_amount_total,
    CASE
        WHEN i.expiration_date >= CURRENT_DATE THEN 'Active'
        ELSE 'Inactive'
    END AS insurance_status
FROM
    patients p
JOIN visits v ON p.patient_id = v.patient_id
JOIN providers pr ON v.provider_id = pr.provider_id
JOIN RecentVisits rv ON p.patient_id = rv.patient_id
LEFT JOIN AggregatedClaims ac ON p.patient_id = ac.patient_id
LEFT JOIN income_brackets ib ON p.patient_id = ib.patient_id
LEFT JOIN languages l ON p.language_id = l.language_id
LEFT JOIN race_ethnicity re ON p.race_ethnicity_id = re.race_ethnicity_id
LEFT JOIN insurance i ON p.insurance_id = i.insurance_id
LEFT JOIN vitals vit ON v.visit_id = vit.visit_id
WHERE v.visit_date <= rv.last_visit_date
GROUP BY p.patient_id, race_ethnicity_name, language_name, i.expiration_date;

WITH VisitMetrics AS (
    SELECT
        v.visit_id,
        v.visit_date,
        v.location,
        ROW_NUMBER() OVER (PARTITION BY v.patient_id ORDER BY v.visit_date DESC) AS rn
    FROM visits v
)
SELECT
    p.first_name,
    p.last_name,
    v.visit_date,
    CASE
        WHEN loc_count > 1 THEN 'Multiple'
        ELSE v.location
    END AS location_summary,
    diag.diagnosis_description,
    pr.procedure_description,
    vitals.heart_rate
FROM
    VisitMetrics vm
JOIN patients p ON vm.rn = 1 AND p.patient_id = vm.patient_id
LEFT JOIN visits v ON vm.visit_id = v.visit_id
LEFT JOIN (
    SELECT
        v.patient_id,
        COUNT(DISTINCT v.location) AS loc_count
    FROM visits v
    GROUP BY v.patient_id
) vl ON p.patient_id = vl.patient_id
LEFT JOIN diagnoses diag ON v.visit_id = diag.visit_id
LEFT JOIN procedures pr ON v.visit_id = pr.visit_id
LEFT JOIN vitals ON v.visit_id = vitals.visit_id;

WITH ActiveCareTeams AS (
    SELECT DISTINCT
        ct.team_name,
        pct.patient_id
    FROM care_teams ct
    JOIN patient_care_team pct ON ct.care_team_id = pct.care_team_id
)
SELECT
    proc.procedure_code,
    proc.procedure_description,
    proc.procedure_date,
    al.allergen,
    al.reaction,
    COALESCE(c.condition_name, 'Unknown') as current_conditions
FROM procedures proc
JOIN visits v ON proc.visit_id = v.visit_id
JOIN patients p ON v.patient_id = p.patient_id
LEFT JOIN allergies al ON p.patient_id = al.patient_id
LEFT JOIN conditions c ON p.patient_id = c.patient_id AND c.resolved_date IS NULL
LEFT JOIN ActiveCareTeams act ON p.patient_id = act.patient_id
WHERE proc.procedure_date >= '2023-01-01';

WITH SummaryStats AS (
    SELECT
        p.patient_id,
        COUNT(v.visit_id) AS visit_count,
        AVG(DISTINCT vs.blood_pressure_systolic) AS avg_systolic_bp
    FROM
        patients p
    LEFT JOIN visits v ON p.patient_id = v.patient_id
    LEFT JOIN vitals vs ON v.visit_id = vs.visit_id
    GROUP BY p.patient_id
)
SELECT
    p.first_name,
    p.last_name,
    p.date_of_birth,
    sum_clm.total_claim_sum,
    co_avg.avg_systolic_bp,
    CASE
        WHEN em.employment_type = 'Employed' THEN 'Employed'
        ELSE 'Unemployed'
    END AS employment_status
FROM patients p
LEFT JOIN SummaryStats co_avg ON p.patient_id = co_avg.patient_id
LEFT JOIN (
    SELECT
        c.patient_id,
        SUM(cl.claim_amount) AS total_claim_sum
    FROM claims cl
    JOIN conditions c ON cl.patient_id = c.patient_id
    WHERE c.resolved_date IS NULL
    GROUP BY c.patient_id
) sum_clm ON p.patient_id = sum_clm.patient_id
LEFT JOIN employment_status em ON p.patient_id = em.patient_id;

WITH VisitDuration AS (
    SELECT 
        patient_id, 
        AVG(EXTRACT(EPOCH FROM (discharge_time - admission_time)) / 3600) AS avg_duration_hours
    FROM visits
    WHERE was_emergency = TRUE
    GROUP BY patient_id
)
SELECT
    v.visit_id,
    p.first_name,
    p.last_name,
    vd.avg_duration_hours,
    m.medication_name,
    m.dosage,
    CASE
        WHEN m.frequency = 'daily' THEN 'High Frequency'
        ELSE 'Low Frequency'
    END AS frequency_category
FROM visits v
JOIN patients p ON v.patient_id = p.patient_id
LEFT JOIN medications m ON v.visit_id = m.visit_id
JOIN VisitDuration vd ON p.patient_id = vd.patient_id
WHERE vd.avg_duration_hours >= 4
ORDER BY vd.avg_duration_hours DESC;

WITH HighRiskPatients AS (
    SELECT
        rs.patient_id,
        MAX(rs.score_value) AS max_risk_score
    FROM risk_scores rs
    WHERE rs.calculated_date > '2023-01-01'
    GROUP BY rs.patient_id
    HAVING MAX(rs.score_value) > 90
)
SELECT
    p.first_name,
    p.last_name,
    s.screening_type,
    s.result,
    c.care_team_id,
    h.max_risk_score
FROM HighRiskPatients h
JOIN patients p ON h.patient_id = p.patient_id
LEFT JOIN screenings s ON p.patient_id = s.patient_id
LEFT JOIN patient_care_team c ON p.patient_id = c.patient_id
WHERE s.result IN ('Positive', 'High Risk');

WITH EmergencyVisits AS (
    SELECT
        visit_id,
        patient_id,
        COUNT(*) FILTER (WHERE was_emergency) AS emergency_count
    FROM visits
    GROUP BY visit_id, patient_id
)
SELECT DISTINCT
    re.race_ethnicity_name,
    EmergencyVisits.emergency_count,
    AVG(cl.claim_amount) AS avg_claim_amount,
    COUNT(pr.procedure_id) AS procedure_count,
    ARRAY_AGG(DISTINCT et.encounter_type_name) AS distinct_encounters
FROM EmergencyVisits
JOIN patients pt ON EmergencyVisits.patient_id = pt.patient_id
LEFT JOIN race_ethnicity re ON pt.race_ethnicity_id = re.race_ethnicity_id
LEFT JOIN claims cl ON EmergencyVisits.visit_id = cl.visit_id
LEFT JOIN procedures pr ON EmergencyVisits.visit_id = pr.visit_id
LEFT JOIN encounter_types et ON pt.race_ethnicity_id = et.encounter_type_id
WHERE EmergencyVisits.emergency_count > 0
GROUP BY re.race_ethnicity_name, EmergencyVisits.emergency_count;

WITH ConditionSummary AS (
    SELECT 
        patient_id, 
        COUNT(condition_id) AS condition_count 
    FROM conditions 
    WHERE condition_status = 'Active'
    GROUP BY patient_id
)
SELECT
    p.first_name,
    p.last_name,
    sum.amount,
    COALESCE(cs.condition_count, 0) AS active_conditions,
    SUM(ph.amount) OVER (PARTITION BY p.patient_id) AS total_payments
FROM patients p
LEFT JOIN payments ph ON p.patient_id = ph.patient_id
LEFT JOIN billing bill ON ph.claim_id = bill.claim_id
LEFT JOIN ConditionSummary cs ON p.patient_id = cs.patient_id
LEFT JOIN insurance i ON p.insurance_id = i.insurance_id
WHERE bill.billed_date BETWEEN '2022-01-01' AND '2022-12-31';

WITH DrugSummary AS (
    SELECT
        m.medication_id,
        COUNT(DISTINCT v.visit_id) AS visit_count
    FROM medications m
    JOIN visits v ON m.visit_id = v.visit_id
    GROUP BY m.medication_id
)
SELECT
    med.medication_name,
    med.dosage,
    COUNT(DISTINCT pt.patient_id) AS patient_count,
    ds.visit_count,
    COALESCE(hs.housing_type, 'Not Available') AS housing_status
FROM medications med
LEFT JOIN visits v ON med.visit_id = v.visit_id
LEFT JOIN patients pt ON v.patient_id = pt.patient_id
LEFT JOIN housing_status hs ON pt.patient_id = hs.patient_id
LEFT JOIN DrugSummary ds ON med.medication_id = ds.medication_id
GROUP BY med.medication_name, med.dosage, ds.visit_count, hs.housing_type
ORDER BY patient_count DESC;

WITH PatientSatisfaction AS (
    SELECT
        s.patient_id,
        AVG(s.survey_score) AS avg_survey_score
    FROM surveys s
    GROUP BY s.patient_id
)
SELECT
    p.first_name,
    p.last_name,
    ps.avg_survey_score,
    sp.symptom,
    sp.onset_date,
    i.impression,
    SUM(l.result_value) OVER (PARTITION BY p.patient_id) AS total_lab_scores
FROM patients p
LEFT JOIN screenings s ON p.patient_id = s.patient_id
LEFT JOIN symptoms sp ON sp.visit_id = s.screening_id
LEFT JOIN imaging i ON sp.visit_id = i.visit_id
LEFT JOIN labs l ON i.visit_id = l.visit_id
LEFT JOIN PatientSatisfaction ps ON p.patient_id = ps.patient_id
WHERE ps.avg_survey_score > 4.0
ORDER BY ps.avg_survey_score DESC;