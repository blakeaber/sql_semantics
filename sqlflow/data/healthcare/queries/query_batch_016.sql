-- Query 1: Calculate average BMI by race and age group, with complex conditions and joins
WITH age_groups AS (
    SELECT 
        patient_id,
        CASE
            WHEN age < 18 THEN 'Minor'
            WHEN age BETWEEN 18 AND 35 THEN 'Young Adult'
            WHEN age BETWEEN 36 AND 55 THEN 'Adult'
            ELSE 'Senior'
        END AS age_group
    FROM (
        SELECT
            patient_id,
            DATE_PART('year', AGE(CURRENT_DATE, date_of_birth)) AS age
        FROM patients
    ) patient_ages
),
bmi_by_race_age AS (
    SELECT 
        r.race_ethnicity_name,
        a.age_group,
        AVG(v.bmi) AS average_bmi
    FROM patients p
    JOIN vitals v ON p.patient_id = v.visit_id
    JOIN race_ethnicity r ON p.race_ethnicity_id = r.race_ethnicity_id
    JOIN age_groups a ON p.patient_id = a.patient_id
    GROUP BY r.race_ethnicity_name, a.age_group
)
SELECT race_ethnicity_name, age_group, average_bmi
FROM bmi_by_race_age
WHERE average_bmi IS NOT NULL;

-- Query 2: Identify patients with recurring conditions and their visit frequency
WITH condition_counts AS (
    SELECT 
        patient_id,
        COUNT(DISTINCT condition_name) AS condition_count
    FROM conditions
    WHERE condition_status = 'Chronic'
    GROUP BY patient_id
),
visit_counts AS (
    SELECT 
        p.patient_id,
        COUNT(v.visit_id) AS visit_count
    FROM patients p
    JOIN visits v ON p.patient_id = v.patient_id
    GROUP BY p.patient_id
)
SELECT 
    c.patient_id,
    c.condition_count,
    v.visit_count
FROM condition_counts c
JOIN visit_counts v ON c.patient_id = v.patient_id
WHERE v.visit_count > 5;

-- Query 3: Find high-risk patients based on a combination of risk scores and social determinants
WITH high_risk_scores AS (
    SELECT 
        patient_id,
        AVG(score_value) AS avg_risk_score
    FROM risk_scores
    WHERE score_type = 'Health'
    GROUP BY patient_id
    HAVING AVG(score_value) > 7.5
),
unfavorable_sdoh AS (
    SELECT 
        patient_id,
        COUNT(sdoh_id) AS unfavorable_count
    FROM sdoh_entries
    WHERE sdoh_type IN ('Food Insecurity', 'Housing Instability', 'Social Isolation')
    GROUP BY patient_id
)
SELECT 
    hs.patient_id,
    hs.avg_risk_score,
    us.unfavorable_count
FROM high_risk_scores hs
JOIN unfavorable_sdoh us ON hs.patient_id = us.patient_id
WHERE us.unfavorable_count > 1;

-- Query 4: Calculate average visit duration by provider specialty and location
WITH visit_durations AS (
    SELECT 
        v.visit_id,
        EXTRACT(EPOCH FROM (v.discharge_time - v.admission_time))/3600 AS visit_duration_hours,
        v.provider_id
    FROM visits v
    WHERE discharge_time IS NOT NULL AND admission_time IS NOT NULL
),
average_durations AS (
    SELECT 
        p.specialty,
        v.location,
        AVG(vd.visit_duration_hours) AS avg_duration
    FROM visit_durations vd
    JOIN visits v ON vd.visit_id = v.visit_id
    JOIN providers p ON v.provider_id = p.provider_id
    GROUP BY p.specialty, v.location
)
SELECT 
    specialty,
    location,
    avg_duration
FROM average_durations
ORDER BY avg_duration DESC;

-- Query 5: Patients with significant admissions and billing details
WITH significant_admissions AS (
    SELECT 
        v.patient_id,
        COUNT(v.visit_id) AS admission_count
    FROM visits v
    WHERE v.was_emergency
    GROUP BY v.patient_id
    HAVING COUNT(v.visit_id) > 3
),
billing_details AS (
    SELECT 
        c.patient_id,
        SUM(c.claim_amount) AS total_claim_amount,
        COUNT(b.billing_id) AS billing_entries
    FROM claims c
    JOIN billing b ON c.claim_id = b.claim_id
    GROUP BY c.patient_id
)
SELECT 
    sa.patient_id,
    sa.admission_count,
    bd.total_claim_amount,
    bd.billing_entries
FROM significant_admissions sa
JOIN billing_details bd ON sa.patient_id = bd.patient_id
WHERE bd.total_claim_amount > 10000;

-- Query 6: Analyze medication usage patterns and visits frequency
WITH medication_counts AS (
    SELECT 
        visit_id,
        COUNT(medication_id) AS medication_count
    FROM medications
    GROUP BY visit_id
),
frequent_visitors AS (
    SELECT 
        p.patient_id,
        COUNT(v.visit_id) AS visit_frequency
    FROM patients p
    JOIN visits v ON p.patient_id = v.patient_id
    GROUP BY p.patient_id
    HAVING COUNT(v.visit_id) > 5
)
SELECT 
    fv.patient_id,
    fv.visit_frequency,
    AVG(mc.medication_count) AS avg_medications_per_visit
FROM frequent_visitors fv
JOIN visits v ON fv.patient_id = v.patient_id
JOIN medication_counts mc ON v.visit_id = mc.visit_id
GROUP BY fv.patient_id, fv.visit_frequency;

-- Query 7: Impact analysis of care teams on visit outcomes 
WITH team_assignment AS (
    SELECT 
        p.patient_id,
        ct.care_team_id
    FROM patient_care_team ct
    JOIN patients p ON ct.patient_id = p.patient_id
),
positive_outcomes AS (
    SELECT 
        v.patient_id,
        COUNT(DISTINCT v.visit_id) AS positive_visits
    FROM visits v
    JOIN diagnoses d ON v.visit_id = d.visit_id
    WHERE d.diagnosis_type = 'Positive'
    GROUP BY v.patient_id
)
SELECT 
    ta.patient_id,
    ta.care_team_id,
    po.positive_visits
FROM team_assignment ta
JOIN positive_outcomes po ON ta.patient_id = po.patient_id
WHERE po.positive_visits > 1;

-- Query 8: Cross-analysis of clinical notes and lab results
WITH notes_analysis AS (
    SELECT 
        c.visit_id,
        COUNT(c.note_id) AS note_count
    FROM clinical_notes c
    GROUP BY visit_id
),
abnormal_labs AS (
    SELECT 
        l.visit_id,
        COUNT(l.lab_result_id) AS abnormal_lab_count
    FROM labs l
    WHERE l.result_flag = 'Abnormal'
    GROUP BY l.visit_id
)
SELECT 
    n.visit_id,
    n.note_count,
    a.abnormal_lab_count
FROM notes_analysis n
JOIN abnormal_labs a ON n.visit_id = a.visit_id
WHERE n.note_count > 2;

-- Query 9: Trends in imaging usage based on symptoms and diagnosis
WITH symptom_diagnosis AS (
    SELECT 
        d.diagnosis_id,
        s.symptom
    FROM diagnoses d
    JOIN symptoms s ON d.visit_id = s.visit_id
),
imaging_analysis AS (
    SELECT 
        i.visit_id,
        i.imaging_type,
        COUNT(i.imaging_id) AS imaging_count
    FROM imaging i
    GROUP BY i.visit_id, i.imaging_type
)
SELECT 
    sd.symptom,
    ia.imaging_type,
    AVG(ia.imaging_count) AS avg_imaging_per_symptom
FROM symptom_diagnosis sd
JOIN imaging_analysis ia ON sd.diagnosis_id = ia.visit_id
GROUP BY sd.symptom, ia.imaging_type;

-- Query 10: Investigate correlations in insurance coverage and sdoh factors
WITH insurance_coverage AS (
    SELECT 
        i.patient_id,
        COUNT(DISTINCT i.policy_id) AS policy_count
    FROM insurance i
    WHERE i.effective_date <= CURRENT_DATE AND i.expiration_date >= CURRENT_DATE
    GROUP BY i.patient_id
),
social_determinants AS (
    SELECT 
        s.patient_id,
        COUNT(s.sdoh_id) AS sdoh_influences
    FROM sdoh_entries s
    GROUP BY s.patient_id
)
SELECT 
    ic.patient_id,
    ic.policy_count,
    sd.sdoh_influences
FROM insurance_coverage ic
JOIN social_determinants sd ON ic.patient_id = sd.patient_id
WHERE ic.policy_count > 1;