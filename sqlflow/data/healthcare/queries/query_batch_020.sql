-- Query 1
WITH monthly_visits AS (
    SELECT
        patient_id,
        COUNT(*) AS total_visits,
        DATE_TRUNC('month', visit_date) AS visit_month
    FROM
        visits
    GROUP BY
        patient_id, visit_month
),
highest_risk_patients AS (
    SELECT
        patient_id,
        MAX(score_value) AS max_risk_score
    FROM
        risk_scores
    GROUP BY
        patient_id
)
SELECT
    p.patient_id,
    p.first_name,
    p.last_name,
    re.race_ethnicity_name,
    lang.language_name,
    COUNT(v.visit_id) AS visit_count,
    AVG(vd.result_value) AS avg_lab_result,
    MAX(hrp.max_risk_score) AS highest_risk_score
FROM
    patients p
JOIN
    monthly_visits mv ON p.patient_id = mv.patient_id
JOIN
    highest_risk_patients hrp ON p.patient_id = hrp.patient_id
JOIN
    visits v ON p.patient_id = v.patient_id
JOIN
    languages lang ON p.language_id = lang.language_id
JOIN
    race_ethnicity re ON p.race_ethnicity_id = re.race_ethnicity_id
JOIN (
    SELECT
        lab_result_id,
        visit_id,
        test_name,
        result_value
    FROM
        labs
    WHERE
        test_code IN ('A1C', 'LDL')
) vd ON v.visit_id = vd.visit_id
GROUP BY
    p.patient_id, re.race_ethnicity_name, lang.language_name
HAVING
    COUNT(v.visit_id) > 3;

-- Query 2
WITH condition_status AS (
    SELECT
        c.patient_id,
        c.condition_name,
        CASE
            WHEN c.resolved_date IS NULL THEN 'Active'
            ELSE 'Resolved'
        END AS condition_status
    FROM
        conditions c
)
SELECT
    c.patient_id,
    p.first_name,
    p.last_name,
    COUNT(DISTINCT ct.care_team_id) AS care_team_count,
    MAX(eo.severity) AS highest_emergency_severity
FROM
    patients p
JOIN
    condition_status cs ON p.patient_id = cs.patient_id
LEFT JOIN
    patient_care_team pct ON p.patient_id = pct.patient_id
JOIN
    care_teams ct ON pct.care_team_id = ct.care_team_id
JOIN
    (
        SELECT
            visit_id,
            MAX(severity) AS severity
        FROM
            (SELECT v.visit_id, v.was_emergency, s.symptom, s.severity FROM visits v JOIN symptoms s ON v.visit_id = s.visit_id WHERE v.was_emergency = TRUE) es
        GROUP BY
            visit_id
    ) eo ON eo.visit_id = p.patient_id
GROUP BY
    c.patient_id, p.first_name, p.last_name;

-- Query 3
WITH patient_allergies AS (
    SELECT
        patient_id,
        COUNT(DISTINCT allergen) AS allergy_count
    FROM
        allergies
    GROUP BY
        patient_id
)
SELECT
    p.patient_id,
    p.first_name || ' ' || p.last_name AS full_name,
    COUNT(DISTINCT v.visit_id) AS visit_count,
    CASE
        WHEN pa.allergy_count > 5 THEN 'High Risk'
        ELSE 'Low Risk'
    END AS allergy_risk_category
FROM
    patients p
JOIN
    visits v ON p.patient_id = v.patient_id
LEFT JOIN
    patient_allergies pa ON p.patient_id = pa.patient_id
WHERE
    v.visit_date > CURRENT_DATE - INTERVAL '1 year'
GROUP BY
    p.patient_id, full_name, pa.allergy_count;

-- Query 4
WITH recent_claims AS (
    SELECT
        claim_id,
        patient_id,
        DATE_TRUNC('month', claim_date) AS claim_month,
        SUM(paid_amount) AS total_paid
    FROM
        claims
    WHERE
        claim_date > CURRENT_DATE - INTERVAL '1 year'
    GROUP BY
        claim_id, patient_id, claim_month
),
provider_specialties AS (
    SELECT
        p.provider_id,
        JSON_AGG(DISTINCT specialty) AS specialties
    FROM
        providers p
    GROUP BY
        p.provider_id
)
SELECT
    rs.patient_id,
    pt.first_name,
    pt.last_name,
    COUNT(rc.claim_id) AS claim_count,
    SUM(rc.total_paid) AS claim_total_paid,
    ps.specialties
FROM
    recent_claims rc
JOIN
    patients pt ON rc.patient_id = pt.patient_id
JOIN
    visits v ON rc.claim_id = v.visit_id
JOIN
    provider_specialties ps ON v.provider_id = ps.provider_id
GROUP BY
    rs.patient_id, pt.first_name, pt.last_name, ps.specialties;

-- Query 5
WITH frequent_procedures AS (
    SELECT
        p.patient_id,
        pr.procedure_code,
        COUNT(pr.procedure_id) AS procedure_count
    FROM
        patients p
JOIN
    visits v ON p.patient_id = v.patient_id
JOIN
    procedures pr ON v.visit_id = pr.visit_id
    GROUP BY
        p.patient_id, pr.procedure_code
    HAVING
        COUNT(pr.procedure_id) > 3
),
avg_vitals AS (
    SELECT
        v.visit_id,
        AVG(vt.blood_pressure_systolic) AS avg_systolic,
        AVG(vt.blood_pressure_diastolic) AS avg_diastolic
    FROM
        visits v
JOIN
    vitals vt ON v.visit_id = vt.visit_id
    GROUP BY
        v.visit_id
)
SELECT
    p.patient_id,
    p.first_name,
    p.last_name,
    fp.procedure_code,
    fp.procedure_count,
    av.avg_systolic,
    av.avg_diastolic
FROM
    patients p
JOIN
    frequent_procedures fp ON p.patient_id = fp.patient_id
JOIN
    avg_vitals av ON av.visit_id = fp.patient_id
WHERE
    av.avg_systolic > 120;

-- Query 6
WITH recent_hospitalizations AS (
    SELECT
        patient_id,
        COUNT(*) AS hospitalization_count
    FROM
        visits
    WHERE
        was_emergency = TRUE
    AND
        visit_date > CURRENT_DATE - INTERVAL '6 months'
    GROUP BY
        patient_id
),
medication_use AS (
    SELECT
        visit_id,
        COUNT(DISTINCT medication_id) AS medication_count
    FROM
        medications
    GROUP BY
        visit_id
)
SELECT
    p.patient_id,
    p.first_name,
    p.last_name,
    rh.hospitalization_count,
    mu.medication_count
FROM
    patients p
LEFT JOIN
    recent_hospitalizations rh ON p.patient_id = rh.patient_id
LEFT JOIN
    visits v ON p.patient_id = v.patient_id
JOIN
    medication_use mu ON v.visit_id = mu.visit_id
WHERE
    mu.medication_count > 2;

-- Query 7
WITH patient_lab_flags AS (
    SELECT
        l.visit_id,
        SUM(CASE WHEN l.result_flag = 'H' THEN 1 ELSE 0 END) AS high_flags
    FROM
        labs l
    GROUP BY
        l.visit_id
)
SELECT
    p.patient_id,
    REPLACE(p.first_name || ' ' || p.last_name, ' ', '-') AS url_safe_name,
    COUNT(v.visit_id) AS total_visits,
    plf.high_flags
FROM
    patients p
JOIN
    visits v ON p.patient_id = v.patient_id
LEFT JOIN
    patient_lab_flags plf ON v.visit_id = plf.visit_id
GROUP BY
    p.patient_id, url_safe_name, plf.high_flags
HAVING
    plf.high_flags > 0;

-- Query 8
WITH bmi_extremes AS (
    SELECT
        visit_id,
        MIN(bmi) AS min_bmi,
        MAX(bmi) AS max_bmi
    FROM
        vitals
    GROUP BY
        visit_id
)
SELECT
    p.patient_id,
    COUNT(DISTINCT e.encounter_type_id) AS encounter_variety,
    LISTAGG(e.encounter_type_name, ', ') WITHIN GROUP (ORDER BY e.encounter_type_name) AS encounter_types,
    be.min_bmi,
    be.max_bmi
FROM
    patients p
JOIN
    visits v ON p.patient_id = v.patient_id
JOIN
    encounter_types e ON v.encounter_type_id = e.encounter_type_id
JOIN
    bmi_extremes be ON v.visit_id = be.visit_id
GROUP BY
    p.patient_id, be.min_bmi, be.max_bmi;

-- Query 9
WITH symptom_counters AS (
    SELECT
        visit_id,
        COUNT(symptom_id) AS symptom_count
    FROM
        symptoms
    GROUP BY
        visit_id
)
SELECT
    p.patient_id,
    p.first_name,
    p.last_name,
    COALESCE(sc.symptom_count, 0) AS total_symptoms,
    COUNT(DISTINCT d.diagnosis_id) AS unique_diagnoses
FROM
    patients p
JOIN
    visits v ON p.patient_id = v.patient_id
LEFT JOIN
    symptom_counters sc ON v.visit_id = sc.visit_id
JOIN
    diagnoses d ON v.visit_id = d.visit_id
GROUP BY
    p.patient_id, p.first_name, p.last_name, sc.symptom_count
HAVING
    COUNT(DISTINCT d.diagnosis_id) > 2;

-- Query 10
WITH provider_locations AS (
    SELECT
        provider_id,
        ARRAY_AGG(DISTINCT location) AS locations
    FROM
        providers
    GROUP BY
        provider_id
)
SELECT
    pc.patient_id,
    ARRAY_AGG(DISTINCT l.lab_result_id) AS lab_results,
    pl.locations,
    CASE
        WHEN MIN(claim_status) = 'Denied' THEN 'Financial Risk'
        ELSE 'Stable'
    END AS financial_status
FROM
    patients pc
JOIN
    visits v ON pc.patient_id = v.patient_id
LEFT JOIN
    claims c ON v.visit_id = c.visit_id
LEFT JOIN
    labs l ON v.visit_id = l.visit_id
LEFT JOIN
    provider_locations pl ON v.provider_id = pl.provider_id
GROUP BY
    pc.patient_id, pl.locations;