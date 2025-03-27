SELECT 
    p.patient_id, 
    et.encounter_type_name, 
    COUNT(DISTINCT v.visit_id) AS total_visits,
    AVG(DATE_PART('year', AGE(v.visit_date, p.date_of_birth))) AS avg_age_at_visit,
    CASE 
        WHEN MIN(v.visit_date) IS NOT NULL THEN 'Previous Visits'
        ELSE 'New Patient' 
    END AS patient_status
FROM 
    patients p
JOIN 
    (SELECT 
        patient_id, 
        MAX(race_ethnicity_id) AS race_ethnicity_id FROM patients 
    WHERE 
        gender = 'Female' 
    GROUP BY 
        patient_id) sub 
    ON p.patient_id = sub.patient_id
JOIN 
    visits v 
    ON p.patient_id = v.patient_id
JOIN 
    encounter_types et 
    ON v.encounter_type_id = et.encounter_type_id
LEFT JOIN 
    (SELECT 
        visit_id, 
        COUNT(diagnosis_code) AS total_diagnoses 
    FROM 
        diagnoses 
    WHERE 
        diagnosis_type IN ('chronic', 'acute') 
    GROUP BY 
        visit_id) d 
    ON v.visit_id = d.visit_id
WHERE 
    d.total_diagnoses > 1
GROUP BY 
    p.patient_id, et.encounter_type_name
HAVING 
    AVG(DATE_PART('year', AGE(v.visit_date, p.date_of_birth))) > 30;

WITH PatientRaceCount AS (
    SELECT 
        race_ethnicity_id, 
        COUNT(DISTINCT patient_id) AS patient_count 
    FROM 
        patients 
    GROUP BY 
        race_ethnicity_id
)
SELECT 
    p.first_name, 
    p.last_name, 
    v.visit_date, 
    et.encounter_type_name, 
    pr.specialty,
    COALESCE(prv.procedure_code, 'None') AS last_procedure_code,
    COALESCE(prc.patient_count, 0) AS patients_of_same_race
FROM 
    patients p
JOIN 
    visits v 
    ON p.patient_id = v.patient_id
JOIN 
    encounter_types et 
    ON v.encounter_type_id = et.encounter_type_id
LEFT JOIN 
    providers pr 
    ON v.provider_id = pr.provider_id
LEFT JOIN 
    (SELECT 
        visit_id, 
        procedure_code 
    FROM 
        procedures 
    WHERE 
        procedure_date = (
            SELECT 
                MAX(procedure_date) 
            FROM 
                procedures 
            WHERE 
                visit_id = v.visit_id
            )
    ) prv 
    ON v.visit_id = prv.visit_id
LEFT JOIN 
    PatientRaceCount prc 
    ON p.race_ethnicity_id = prc.race_ethnicity_id
WHERE 
    v.was_emergency = FALSE
ORDER BY 
    v.visit_date DESC;

WITH RecentPatientVisits AS (
    SELECT 
        patient_id, 
        MAX(visit_date) AS last_visit 
    FROM 
        visits 
    WHERE 
        visit_date > current_date - INTERVAL '1 year' 
    GROUP BY 
        patient_id
)
SELECT 
    p.first_name, 
    p.last_name, 
    rs.score_value AS risk_score,
    COALESCE(sum(d.paid_amount), 0) AS total_paid,
    ranked.procedure_code AS last_procedure
FROM 
    patients p
JOIN 
    RecentPatientVisits rpv 
    ON p.patient_id = rpv.patient_id
LEFT JOIN 
    risk_scores rs 
    ON p.patient_id = rs.patient_id 
    AND rs.calculated_date = rpv.last_visit
LEFT JOIN 
    claims c 
    ON p.patient_id = c.patient_id
LEFT JOIN 
    (SELECT 
        visit_id, 
        procedure_code, 
        ROW_NUMBER() OVER (PARTITION BY visit_id ORDER BY procedure_date DESC) AS rn
    FROM 
        procedures) ranked 
    ON c.visit_id = ranked.visit_id AND ranked.rn = 1
LEFT JOIN 
    payments d 
    ON c.claim_id = d.claim_id
GROUP BY 
    p.first_name, 
    p.last_name, 
    rs.score_value, 
    ranked.procedure_code;

WITH MostCommonDiagnosis AS (
    SELECT 
        d.diagnosis_code, 
        COUNT(d.diagnosis_id) AS diagnosis_count 
    FROM 
        diagnoses d
    JOIN 
        visits v 
    ON d.visit_id = v.visit_id
    WHERE 
        v.admission_time > current_date - INTERVAL '6 months'
    GROUP BY 
        d.diagnosis_code
    ORDER BY 
        diagnosis_count DESC 
    LIMIT 3
)
SELECT 
    p.patient_id, 
    v.visit_date,
    COALESCE(max(md.diagnosis_code), 'No Frequent Diagnosis') AS most_common_diagnosis
FROM 
    patients p
JOIN 
    visits v 
    ON p.patient_id = v.patient_id
LEFT JOIN 
    MostCommonDiagnosis md 
    ON v.visit_id IN (
        SELECT 
            visit_id 
        FROM 
            diagnoses 
        WHERE 
            diagnosis_code = md.diagnosis_code
    )
WHERE 
    v.discharge_time IS NOT NULL
GROUP BY 
    p.patient_id, 
    v.visit_date
HAVING 
    COUNT(md.diagnosis_code) > 0;

WITH HighRiskPatients AS (
    SELECT 
        patient_id 
    FROM 
        risk_scores 
    WHERE 
        score_value > 80 
    AND calculated_date > current_date - INTERVAL '1 year'
),
RecentConditions AS (
    SELECT 
        patient_id, 
        condition_name, 
        ROW_NUMBER() OVER (PARTITION BY patient_id ORDER BY diagnosed_date DESC) AS rn
    FROM 
        conditions 
    WHERE 
        diagnosed_date > current_date - INTERVAL '2 years'
)
SELECT 
    hrp.patient_id, 
    rc.condition_name, 
    cs.survey_score,
    COALESCE(lb.test_name, 'No Labs') AS recent_lab
FROM 
    HighRiskPatients hrp
JOIN 
    RecentConditions rc 
    ON hrp.patient_id = rc.patient_id AND rc.rn = 1
LEFT JOIN 
    surveys cs 
    ON hrp.patient_id = cs.patient_id 
    AND cs.survey_date = (
        SELECT 
            MAX(survey_date) 
        FROM 
            surveys 
        WHERE 
            patient_id = hrp.patient_id
    )
LEFT JOIN 
    (SELECT 
        visit_id, 
        test_name 
    FROM 
        labs 
    WHERE 
        collected_date = (
            SELECT 
                MAX(collected_date) 
            FROM 
                labs 
            WHERE 
                patient_id = hrp.patient_id
        )
    ) lb 
    ON hrp.patient_id = (
        SELECT 
            patient_id 
        FROM 
            visits 
        WHERE 
            visit_id = lb.visit_id
    );

SELECT 
    p.patient_id, 
    COUNT(DISTINCT v.visit_id) AS visit_count, 
    AVG(DISTINCT v.visit_date) OVER (PARTITION BY p.patient_id) AS avg_visit_date, 
    CONCAT(p.first_name, ' ', p.last_name) AS full_name,
    ia.imaging_type AS recent_imaging,
    COALESCE(pr.procedure_description, 'None') AS common_procedure
FROM 
    patients p
JOIN 
    visits v 
    ON p.patient_id = v.patient_id
LEFT JOIN 
    (SELECT 
        visit_id, 
        imaging_type 
    FROM 
        imaging 
    WHERE 
        performed_date = (
            SELECT 
                MAX(performed_date) 
            FROM 
                imaging 
            WHERE 
                visit_id = v.visit_id
        )
    ) ia 
    ON v.visit_id = ia.visit_id
LEFT JOIN 
    (SELECT 
        visit_id, 
        procedure_description 
    FROM 
        procedures 
    WHERE 
        procedure_date = (
            SELECT 
                MAX(procedure_date) 
            FROM 
                procedures 
            WHERE 
                visit_id = v.visit_id
        )
    ) pr 
    ON v.visit_id = pr.visit_id
WHERE 
    v.visit_date > current_date - INTERVAL '1 year'
GROUP BY 
    p.patient_id, ia.imaging_type, pr.procedure_description
HAVING 
    visit_count > 5;

WITH RecentMedUpdates AS (
    SELECT 
        visit_id, 
        medication_name, 
        ROW_NUMBER() OVER (PARTITION BY visit_id ORDER BY start_date DESC) AS rn
    FROM 
        medications
)
SELECT 
    p.patient_id, 
    v.visit_date, 
    CASE 
        WHEN i.impression IS NOT NULL THEN 'Impression Available'
        ELSE 'No Impression' 
    END AS imaging_impression,
    COALESCE(rmu.medication_name, 'Unknown') AS latest_medication
FROM 
    patients p
JOIN 
    visits v 
    ON p.patient_id = v.patient_id
LEFT JOIN 
    imaging i 
    ON v.visit_id = i.visit_id
LEFT JOIN 
    RecentMedUpdates rmu 
    ON v.visit_id = rmu.visit_id AND rmu.rn = 1
WHERE 
    v.was_emergency = TRUE
ORDER BY 
    v.visit_date DESC;

WITH LabResultsRanking AS (
    SELECT 
        l.visit_id, 
        l.result_value,
        ROW_NUMBER() OVER (PARTITION BY l.test_name ORDER BY l.collected_date DESC) AS rank
    FROM 
        labs l
)
SELECT 
    p.patient_id, 
    ra.race_ethnicity_name, 
    lrr.result_value AS latest_lab_value,
    CONCAT(l.height_cm, 'cm, ', l.weight_kg, 'kg') AS height_weight,
    cs.claim_amount AS recent_claim_amount
FROM 
    patients p
JOIN 
    race_ethnicity ra 
    ON p.race_ethnicity_id = ra.race_ethnicity_id
JOIN 
    visits v 
    ON p.patient_id = v.patient_id
JOIN 
    vitals l 
    ON v.visit_id = l.visit_id
LEFT JOIN 
    claims cs 
    ON p.patient_id = cs.patient_id 
    AND cs.claim_date = (
        SELECT 
            MAX(claim_date)
        FROM 
            claims 
        WHERE 
            patient_id = p.patient_id
    )
LEFT JOIN 
    LabResultsRanking lrr 
    ON v.visit_id = lrr.visit_id AND lrr.rank = 1
GROUP BY 
    p.patient_id, ra.race_ethnicity_name, lrr.result_value, l.height_cm, l.weight_kg, cs.claim_amount;

SELECT 
    p.patient_id, 
    e.provider_id, 
    MAX(e.condition_name) AS main_condition,
    COALESCE(SUM(INTERVAL '1 day' * (res.resolved_date - res.diagnosed_date)), INTERVAL '0 day') AS condition_duration,
    CASE 
        WHEN bl.billed_amount - pm.amount < 0 THEN 'Overpaid'
        ELSE 'Balance Due'
    END AS payment_status
FROM 
    patients p
JOIN 
    conditions e 
    ON p.patient_id = e.patient_id
LEFT JOIN 
    (SELECT 
        condition_id, 
        diagnosed_date, 
        resolved_date 
    FROM 
        conditions 
    WHERE 
        resolved_date IS NOT NULL) res 
    ON e.condition_id = res.condition_id
LEFT JOIN 
    billing bl 
    ON p.patient_id = (
        SELECT 
            MAX(claim_id) 
        FROM 
            claims 
        WHERE 
            patient_id = p.patient_id
    )
LEFT JOIN 
    payments pm 
    ON bl.claim_id = pm.claim_id
GROUP BY 
    p.patient_id, e.provider_id, bl.billed_amount, pm.amount;

WITH DiagnosisStats AS (
    SELECT 
        diagnosis_code, 
        COUNT(diagnosis_id) AS diagnosis_frequency 
    FROM 
        diagnoses 
    GROUP BY 
        diagnosis_code
)
SELECT 
    p.first_name, 
    p.last_name, 
    MAX(os.onset_date) AS symptom_onset,
    COALESCE(ds.diagnosis_frequency, 0) AS diagnosis_count,
    tariffs.amount - reforms.paid_amount AS unpaid_balance
FROM 
    patients p
JOIN 
    symptoms os 
    ON p.patient_id = (
        SELECT 
            patient_id 
        FROM 
            visits 
        WHERE 
            visit_id = os.visit_id
    )
JOIN 
    visits v 
    ON p.patient_id = v.patient_id
LEFT JOIN 
    DiagnosisStats ds 
    ON (
        SELECT 
            diagnosis_code 
        FROM 
            diagnoses 
        WHERE 
            visit_id = v.visit_id
        LIMIT 1
    ) = ds.diagnosis_code
LEFT JOIN 
    (SELECT 
        billing_id, 
        amount 
    FROM 
        billing 
    WHERE 
        service_code = (
            SELECT 
                MAX(service_code) 
            FROM 
                billing 
            GROUP BY 
                service_code
        )
    ) tariffs 
    ON v.visit_id = tariffs.billing_id
LEFT JOIN 
    payments reforms 
    ON tariffs.billing_id = reforms.claim_id
GROUP BY 
    p.first_name, 
    p.last_name, 
    ds.diagnosis_frequency, 
    tariffs.amount, 
    reforms.paid_amount;